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
# Build the Docker image (required after Dockerfile/entrypoint.sh changes)
docker build -t claude-yolo-env .

# Make scripts executable
chmod +x claude-yolo entrypoint.sh init-firewall.sh claude-loop

# Install globally (one-time setup)
sudo cp claude-yolo /usr/local/bin/
sudo cp claude-loop /usr/local/bin/
```

### Testing Changes
```bash
# Test the Docker build locally
docker build -t claude-yolo-env .

# Test the launcher script
claude-yolo                              # Browser login mode
claude-yolo --apikey                     # API key mode
claude-yolo --safe                       # Safe mode (copy files in)
claude-yolo --persist                    # Persist auth across sessions
claude-yolo --firewall                   # Enable network allowlist
claude-yolo --auto "list all files"      # Headless autonomous mode
claude-yolo --loop tasks.md              # Autonomous task loop
claude-yolo --help                       # Print usage
claude-yolo --version                    # Print version
claude-yolo my-network                   # Connect to Docker network
```

## Architecture

### Core Components

1. **`claude-yolo`** (launcher script): Handles argument parsing, Docker/Podman volume mounting, and authentication setup. Key responsibilities:
   - Mounts current directory to `/project` (or copies in `--safe` mode)
   - Mounts Docker/Podman socket for container-in-container
   - Passes host UID/GID for permission matching
   - Handles multiple auth modes (browser, API key, OAuth token, persist)
   - Manages network connections, firewall, and autonomous modes

2. **`Dockerfile`**: Defines the sandbox environment with:
   - Node.js 20 base image (matches official devcontainer)
   - Docker CLI + Compose plugin for container control
   - `gosu` for privilege dropping, `rsync` for settings sync
   - `bubblewrap` for optional defense-in-depth native sandbox
   - `jq` for headless JSON output parsing
   - `socat` for socket proxying
   - `iptables` for optional firewall
   - Pinnable `@anthropic-ai/claude-code` version via `ARG CLAUDE_VERSION`

3. **`entrypoint.sh`**: Runs as root on container startup to:
   - Match container user to host UID/GID
   - Grant Docker/Podman socket access
   - Handle safe mode (copy project files into container)
   - Bootstrap `~/.claude` settings (rsync or RW mount)
   - Inject OAuth tokens if provided
   - Apply firewall rules if enabled
   - Drop to unprivileged user before shell

4. **`init-firewall.sh`**: Optional network allowlisting script:
   - Allowlists: Anthropic API, npm, GitHub, PyPI, Docker Hub
   - General web access configurable via `FIREWALL_ALLOW_WEB`
   - Only runs when `ENABLE_FIREWALL=true`

5. **`claude-loop`**: Autonomous task loop script (Ralph-inspired):
   - Reads task file with `[ ]` / `[x]` format
   - Runs `claude -p` per task with `--dangerously-skip-permissions`
   - Auto-commits completed work
   - Supports `--max-iterations`, `--no-commit`, `--continue`

### Authentication Modes

| Mode | Flag | How it works |
|---|---|---|
| Browser login (default) | (none) | rsync settings from host, browser login per session |
| API key | `--apikey` | Uses `ANTHROPIC_API_KEY` env var |
| Persist auth | `--persist` | RW mount of `~/.claude`, auth survives restarts |
| OAuth token | (env var) | `CLAUDE_CODE_OAUTH_TOKEN` auto-injected |

### Security Model

- Container runs as non-root with matched host permissions
- Docker socket access granted via group membership
- Default: settings copied (not bind-mounted) to prevent container writes to host
- `--safe` mode: project files copied in, originals completely untouched
- `--firewall`: optional iptables-based network restriction
- `bubblewrap` available inside container for defense-in-depth
- Ephemeral containers ensure clean state per session

## Development Workflow

When modifying this project:

1. **Script changes** (`claude-yolo`, `claude-loop`): Test directly without rebuild
2. **Dockerfile changes**: Rebuild with `docker build -t claude-yolo-env .`
3. **Entrypoint/firewall changes**: Rebuild image (baked into image)

### Key Directories in Container

- `/project`: Mounted host directory (working directory)
- `/project-copy`: Read-only mount in safe mode (copied to `/project` by entrypoint)
- `/home/node/.claude`: Container's Claude settings
- `/var/run/docker.sock`: Docker daemon socket (if mounted)
- `/run/podman/podman.sock`: Podman socket (if mounted)

### Related Official Docs

- [Claude Code Sandboxing](https://code.claude.com/docs/en/sandboxing)
- [Claude Code Devcontainer](https://code.claude.com/docs/en/devcontainer)
- [Claude Code Headless Mode](https://code.claude.com/docs/en/headless)
- [Docker Desktop Claude Code Sandbox](https://docs.docker.com/ai/sandboxes/agents/claude-code/)
