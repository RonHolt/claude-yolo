# Claude YOLO Sandbox

A hardened Docker sandbox for fully autonomous Claude Code sessions - with zero risk to the host machine.

## Why This Exists

Claude Code now has [native sandboxing](https://code.claude.com/docs/en/sandboxing) (bubblewrap/Seatbelt), an [official devcontainer](https://code.claude.com/docs/en/devcontainer), and [Docker Desktop integration](https://docs.docker.com/ai/sandboxes/agents/claude-code/). Those are great for interactive use. But for **fully unattended autonomous operation** - running Claude for hours without any human intervention - Docker containers remain the strongest isolation boundary:

- **Inside the container**: Claude has full god-mode permissions and unrestricted network access
- **Outside the container**: Your host is completely untouched. Worst case = kill the container
- **No prompts**: No domain allowlist interruptions, no permission prompts, no escape hatches

### When to Use This vs Alternatives

| Feature | Native Sandbox | Official Devcontainer | Docker Desktop | **claude-yolo** |
|---|---|---|---|---|
| Host isolation | OS-level (bubblewrap) | Docker + firewall | Docker | **Docker** |
| Fully autonomous (no prompts) | Domain prompts interrupt | Yes (with DSP) | Yes | **Yes** |
| Unrestricted network | Allowlist-only | Allowlist-only | Varies | **Full access** |
| Docker-in-Docker | No | No | No | **Yes** |
| Terminal-first (no VS Code) | Yes | No (VS Code focused) | CLI | **Yes** |
| Zero host risk | Has escape vectors | Firewall can be bypassed | Good | **Hard boundary** |
| Long unattended runs | Prompts block | Good | Good | **Built for this** |
| Headless/auto mode | Manual setup | Manual setup | Manual setup | **First-class** |

**Use native sandbox** for everyday interactive Claude Code use.
**Use claude-yolo** when you want to let Claude run autonomously with zero risk to your host.

See [docs/RESEARCH-2026-02.md](docs/RESEARCH-2026-02.md) for the full research behind this decision.

## Quick Start

### 1. Build the Docker image

```bash
git clone https://github.com/RonHolt/claude-yolo.git
cd claude-yolo
docker build -t claude-yolo-env .
```

### 2. Install the launcher

```bash
chmod +x claude-yolo
sudo cp claude-yolo /usr/local/bin/
```

Note: `claude-loop` runs inside the container (baked into the Docker image). You do not need to install it on the host.

### 3. Set up authentication (choose one)

**Browser login (default)** - log in on your host once to create `~/.claude`:
```bash
claude login
```

**API key** - set the environment variable:
```bash
export ANTHROPIC_API_KEY='sk-ant-...'
```

**OAuth token** - for CI/automation:
```bash
export CLAUDE_CODE_OAUTH_TOKEN='your-token-here'
```

### 4. Launch

```bash
cd /path/to/your/project
claude-yolo
```

Claude launches automatically in YOLO mode (`--dangerously-skip-permissions`) with auth persisted across sessions.

## Usage

### Interactive Mode (Default)

```bash
# Launch Claude in YOLO mode (auth persists by default)
claude-yolo

# API key authentication
claude-yolo --apikey

# Ephemeral mode (settings not persisted, lost on exit)
claude-yolo --no-persist

# Connect to a Docker network
claude-yolo my-project_default
```

### Autonomous Mode

Run Claude headless - it executes the prompt and exits:

```bash
# Single autonomous task
claude-yolo --auto "fix all lint errors and run the test suite"

# Resume a previous session
claude-yolo --auto "continue where you left off" --resume <session-id>
```

### Autonomous Loop

Run multiple tasks from a file, committing progress after each:

```bash
# Create a task file
cat > tasks.md << 'EOF'
[ ] Set up project scaffolding with TypeScript
[ ] Implement user authentication with JWT
[ ] Add input validation to all API endpoints
[ ] Write unit tests for auth module
[ ] Add API documentation
EOF

# Run the loop
claude-yolo --loop tasks.md
```

The loop reads tasks marked `[ ]`, runs Claude on each, marks them `[x]` when done, and auto-commits. Live progress is streamed to the terminal showing which tools Claude is using. Press Ctrl+C to stop the loop at any time.

`claude-loop` is designed to only run inside the container. Running it directly on the host will exit with an error.

### Safe Mode

Copy project files into the container instead of bind-mounting. Your originals are completely untouched - even if Claude deletes everything inside the container:

```bash
claude-yolo --safe
```

### Firewall Mode

Enable network allowlisting inside the container. Only Anthropic API, npm, GitHub, and PyPI are reachable by default:

```bash
claude-yolo --firewall
```

### All Options

```
claude-yolo [options] [network-name]

Authentication:
  (default)              Persists auth across sessions (mounts ~/.claude read-write)
  --no-persist           Ephemeral mode (copies ~/.claude read-only, lost on exit)
  --apikey               Use ANTHROPIC_API_KEY environment variable

Isolation:
  --safe                 Copy project files into container (originals untouched)
  --firewall             Enable network allowlisting inside container

Autonomous Mode:
  --auto <prompt>        Run Claude headless with the given prompt, then exit
  --loop <task-file>     Run autonomous task loop with a PRD/todo file
  --resume <session-id>  Continue a previous headless session

Other:
  network-name           Connect container to a Docker network
  --version              Print version and exit
  --help                 Print this help and exit

Environment Variables:
  ANTHROPIC_API_KEY          API key for --apikey mode
  CLAUDE_CODE_OAUTH_TOKEN    OAuth token (auto-injected into container)
```

## How It Works

### Architecture

```
Host Machine                         Docker Container
+---------------------------+        +---------------------------+
|                           |        |                           |
|  ~/.claude (settings) ----+--rw--->|  /home/node/.claude       |
|  ~/.claude.json (config) -+--rw--->|  /home/node/.claude.json  |
|                           |        |                           |
|  $(pwd) (project) -------+------->|  /project (workdir)       |
|                           |        |                           |
|  /var/run/docker.sock ----+------->|  Docker CLI (DinD)        |
|                           |        |                           |
|  HOST_UID/GID env --------+------->|  node user (matched IDs)  |
|  TERM env ----------------+------->|  terminal type            |
|                           |        |                           |
+---------------------------+        +---------------------------+
```

1. **`claude-yolo`** (launcher): Assembles the `docker run` command with correct volumes, env vars, and flags. Detects Docker or Podman automatically. Launches Claude in YOLO mode (`--dangerously-skip-permissions`) by default.

2. **`Dockerfile`**: Node.js 20 image with Claude Code CLI, Docker CLI + Compose, bubblewrap (defense-in-depth), jq, socat, iptables, rsync, gosu.

3. **`entrypoint.sh`**: Runs as root to match UID/GID, set up socket permissions, copy settings and `~/.claude.json` config, apply firewall if enabled, then drops to unprivileged `node` user.

4. **`init-firewall.sh`**: Optional iptables rules that allowlist Anthropic API, package registries, and GitHub. General web access is configurable.

5. **`claude-loop`**: Ralph-inspired autonomous loop that reads a task file, runs `claude -p` per task with live streaming progress, commits after each task, and repeats. Includes a container guard to prevent accidental host execution.

### Security Model

- **Kernel-level isolation**: Docker provides hard process/filesystem/network boundaries
- **Non-root execution**: Container user matches host UID/GID via gosu
- **Persistent auth by default**: `~/.claude` mounted read-write for session persistence; use `--no-persist` for ephemeral mode
- **Safe mode**: Project files copied into container - originals physically cannot be modified
- **Ephemeral containers**: `--rm` flag ensures containers are destroyed on exit
- **Optional firewall**: iptables network restriction for additional paranoia
- **Defense-in-depth**: bubblewrap available inside container for layered sandboxing
- **Loop guard**: `claude-loop` refuses to run outside the container since it uses `--dangerously-skip-permissions`

### File Permissions

Files created or modified inside the container have correct host ownership thanks to UID/GID matching. The entrypoint script reads `HOST_UID` and `HOST_GID` environment variables and adjusts the container's `node` user to match.

## Working with Images

Image pasting via clipboard is not supported inside the container (Docker has no access to the host clipboard). To share images with Claude:

1. Save the image to your project directory on the host
2. Inside the container, ask Claude to look at it: `look at screenshot.png`

The project directory is mounted at `/project/`, so any files you add are immediately available.

## Context for AI Assistants (Meta-Prompt)

When starting a session inside the sandbox, you can give Claude this context:

> You are running inside a hardened Docker container (claude-yolo sandbox). Key facts:
>
> - Your working directory `/project` contains the mounted project files from the host
> - You have full `--dangerously-skip-permissions` access - use it freely
> - You have Docker CLI access to the host's Docker daemon (`docker ps`, `docker exec`, etc.)
> - You are running as a non-root user with host-matched permissions
> - Any files you create/modify will have correct ownership on the host
> - You have unrestricted internet access (unless `--firewall` was used)
> - This container is ephemeral - it will be destroyed when you exit
>
> **Docker workflow**: Always run `docker ps` to find container names before using `docker exec`.

## Podman Support

claude-yolo automatically detects Podman if Docker is not available. It checks for the Podman socket at `/run/podman/podman.sock` and uses the `podman` CLI as a drop-in replacement.

## Troubleshooting

- **"Docker image not found"**: Run `docker build -t claude-yolo-env .` in the project directory
- **"ANTHROPIC_API_KEY not set"**: Export the variable or use browser login (drop `--apikey`)
- **"claude-loop should only run inside the claude-yolo container"**: Use `claude-yolo --loop <task-file>` instead of running `claude-loop` directly
- **Permission errors on mounted files**: Ensure `HOST_UID`/`HOST_GID` match your host user (`id -u` / `id -g`)
- **Changes to Dockerfile/entrypoint.sh/claude-loop not taking effect**: Rebuild with `docker build -t claude-yolo-env .`
- **Launcher script changes (`claude-yolo`)**: No rebuild needed, takes effect immediately
- **Firewall mode fails**: Container needs `NET_ADMIN` capability (added automatically with `--firewall`)
- **Windows/WSL line endings**: Run `dos2unix claude-yolo entrypoint.sh` or `sed -i 's/\r$//' claude-yolo entrypoint.sh`

## Development

```bash
# Rebuild after Dockerfile, entrypoint.sh, or claude-loop changes
docker build -t claude-yolo-env .

# Test launcher script changes (no rebuild needed)
./claude-yolo --help
./claude-yolo --version

# Test inside the container
claude-yolo              # interactive session
docker ps                # verify Docker-in-Docker works
```
