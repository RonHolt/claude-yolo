# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Claude YOLO Sandbox is a hardened Docker sandbox for running fully autonomous Claude Code sessions. It provides hard kernel-level isolation via Docker, full Docker-in-Docker capabilities, and first-class support for headless/unattended operation - with zero risk to the host machine.

### Why This Exists (vs Alternatives)

Claude Code now has native sandboxing (bubblewrap/Seatbelt) and an official devcontainer. Those are great for interactive use, but have limitations for fully autonomous operation:

- **Native sandbox**: Network allowlisting interrupts autonomous workflows. Acknowledged escape vectors (domain fronting, unix sockets). Processes run on the actual host.
- **Official devcontainer**: VS Code focused, not terminal-first. Firewall can be bypassed from inside.
- **Docker Desktop sandbox**: Good but limited customization.

This project provides a **hard Docker boundary** where Claude has full god-mode permissions inside the container, but the host is completely untouched. Perfect for long-running, unattended sessions.

See `docs/RESEARCH-2026-02.md` for full analysis of alternatives.

## Key Commands

### Building and Installation
```bash
# Build the Docker image (required after Dockerfile/entrypoint.sh/claude-loop changes)
docker build -t claude-yolo-env .

# Make launcher executable and install globally (one-time setup)
chmod +x claude-yolo
sudo cp claude-yolo /usr/local/bin/
```

Note: `claude-loop` is baked into the Docker image. Do not install it on the host - it has a guard that prevents running outside the container.

### Testing Changes
```bash
# Test the Docker build locally
docker build -t claude-yolo-env .

# Test the launcher script
claude-yolo                              # Interactive YOLO mode (default, auth persists)
claude-yolo --apikey                     # API key mode
claude-yolo --no-persist                 # Ephemeral mode (settings lost on exit)
claude-yolo --safe                       # Safe mode (copy files in)
claude-yolo --firewall                   # Enable network allowlist
claude-yolo --auto "list all files"      # Headless autonomous mode
claude-yolo --loop tasks.md              # Autonomous task loop
claude-yolo --help                       # Print usage
claude-yolo --version                    # Print version
claude-yolo my-network                   # Connect to Docker network
```

## Architecture

### Core Components

1. **`claude-yolo`** (launcher script - runs on host): Handles argument parsing, Docker/Podman volume mounting, and authentication setup. Key responsibilities:
   - Launches Claude in YOLO mode (`--dangerously-skip-permissions`) automatically
   - Mounts current directory to `/project` (or copies in `--safe` mode)
   - Mounts `~/.claude` (RW by default) and `~/.claude.json` for auth/config persistence
   - Mounts Docker/Podman socket for container-in-container
   - Passes host UID/GID and TERM for permission matching and terminal compatibility
   - Handles multiple auth modes (browser with persist, API key, OAuth token)
   - Manages network connections, firewall, and autonomous modes
   - Smart task file mounting for `--loop` mode (detects if file is inside project dir)

2. **`Dockerfile`**: Defines the sandbox environment with:
   - Node.js 20 base image (matches official devcontainer)
   - Docker CLI + Compose plugin for container control
   - `gosu` for privilege dropping, `rsync` for settings sync
   - `bubblewrap` for optional defense-in-depth native sandbox
   - `jq` for stream-json output parsing
   - `socat` for socket proxying
   - `iptables` for optional firewall
   - Pinnable `@anthropic-ai/claude-code` version via `ARG CLAUDE_VERSION`

3. **`entrypoint.sh`**: Runs as root on container startup to:
   - Match container user to host UID/GID
   - Grant Docker/Podman socket access
   - Handle safe mode (copy project files into container)
   - Bootstrap `~/.claude` settings (rsync or RW mount)
   - Copy `~/.claude.json` config into container if mounted
   - Inject OAuth tokens if provided
   - Apply firewall rules if enabled
   - Drop to unprivileged user before executing command

4. **`init-firewall.sh`**: Optional network allowlisting script:
   - Allowlists: Anthropic API, npm, GitHub, PyPI, Docker Hub
   - General web access configurable via `FIREWALL_ALLOW_WEB`
   - Only runs when `ENABLE_FIREWALL=true`

5. **`claude-loop`** (runs inside container only): Autonomous task loop script:
   - Container guard prevents accidental host execution
   - Reads task file with `[ ]` / `[x]` format
   - Runs `claude -p` per task with `--output-format stream-json --verbose`
   - Streams live progress (tool use events) to terminal via jq
   - Only marks tasks done when Claude makes actual file changes
   - Auto-commits completed work (excludes task-file-only changes)
   - Handles Ctrl+C cleanly via signal trap
   - Supports `--max-iterations`, `--no-commit`, `--continue`

### Authentication Modes

| Mode | Flag | How it works |
|---|---|---|
| Persist auth (default) | (none) | RW mount of `~/.claude` and `~/.claude.json`, auth survives restarts |
| Ephemeral | `--no-persist` | rsync settings from host (read-only copy), lost on exit |
| API key | `--apikey` | Uses `ANTHROPIC_API_KEY` env var |
| OAuth token | (env var) | `CLAUDE_CODE_OAUTH_TOKEN` auto-injected |

### Security Model

- Container runs as non-root with matched host permissions
- Docker socket access granted via group membership
- Default: `~/.claude` mounted RW for auth persistence; use `--no-persist` for ephemeral mode
- `--safe` mode: project files copied in, originals completely untouched
- `--firewall`: optional iptables-based network restriction
- `bubblewrap` available inside container for defense-in-depth
- Ephemeral containers (`--rm`) ensure clean state per session
- `claude-loop` refuses to run outside the container

## Development Workflow

When modifying this project:

1. **Launcher changes** (`claude-yolo`): Test directly, no rebuild needed
2. **Dockerfile changes**: Rebuild with `docker build -t claude-yolo-env .`
3. **Entrypoint/firewall/claude-loop changes**: Rebuild image (baked into image)

### Key Directories in Container

- `/project`: Mounted host directory (working directory)
- `/project-copy`: Read-only mount in safe mode (copied to `/project` by entrypoint)
- `/home/node/.claude`: Container's Claude settings (RW mount in persist mode)
- `/home/node/.claude.json`: Container's Claude config (RW mount in persist mode)
- `/var/run/docker.sock`: Docker daemon socket (if mounted)
- `/run/podman/podman.sock`: Podman socket (if mounted)

### Related Official Docs

- [Claude Code Sandboxing](https://code.claude.com/docs/en/sandboxing)
- [Claude Code Devcontainer](https://code.claude.com/docs/en/devcontainer)
- [Claude Code Headless/SDK](https://code.claude.com/docs/en/headless)
- [Docker Desktop Claude Code Sandbox](https://docs.docker.com/ai/sandboxes/agents/claude-code/)
