# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Claude YOLO Sandbox is a Docker-based ephemeral sandbox environment for running the `claude-code` CLI securely. It provides full Docker-in-Docker capabilities while maintaining proper file permissions and security boundaries.

## Key Commands

### Building and Installation
```bash
# Build the Docker image (required after Dockerfile/entrypoint.sh changes)
docker build -t claude-yolo-env .

# Make scripts executable
chmod +x claude-yolo entrypoint.sh

# Install globally (one-time setup)
sudo mv claude-yolo /usr/local/bin/
```

### Testing Changes
```bash
# Test the Docker build locally
docker build -t claude-yolo-env .

# Test the launcher script from any directory
claude-yolo                    # Browser login mode
claude-yolo --apikey          # API key mode
claude-yolo my-network        # Connect to Docker network
```

## Architecture

### Core Components

1. **`claude-yolo`** (launcher script): Handles argument parsing, Docker volume mounting, and authentication setup. Key responsibilities:
   - Mounts current directory to `/project`
   - Mounts Docker socket for Docker-in-Docker
   - Passes host UID/GID for permission matching
   - Handles `--apikey` flag vs browser login modes
   - Manages network connections

2. **`Dockerfile`**: Defines the sandbox environment with:
   - Node.js 20 base image
   - Docker CLI client for container control
   - `gosu` for privilege dropping
   - `rsync` for settings synchronization
   - Official `@anthropic-ai/claude-code` package

3. **`entrypoint.sh`**: Runs as root on container startup to:
   - Match container user to host UID/GID
   - Grant Docker socket access
   - Bootstrap `~/.claude` settings from host
   - Drop to unprivileged user before shell

### Authentication Flow

**Browser Login (Default)**:
- Mounts host `~/.claude` as read-only to `/tmp/host-claude-config`
- `entrypoint.sh` copies settings via rsync (excluding `.credentials.json`)
- User logs in via browser per session (by design for security)

**API Key Mode** (`--apikey`):
- Passes `ANTHROPIC_API_KEY` environment variable
- No settings mounting/copying
- Suitable for automation

### Security Model

- Container runs as non-root with matched host permissions
- Docker socket access granted via group membership
- Settings copied, not bind-mounted (prevents container writes to host)
- Ephemeral containers ensure clean state per session

## Development Workflow

When modifying this project:

1. **Script Changes** (`claude-yolo`): Test directly without rebuild
2. **Dockerfile Changes**: Rebuild image with `docker build -t claude-yolo-env .`
3. **Entrypoint Changes**: Rebuild image (critical for permission/setup logic)

### Key Directories in Container

- `/project`: Mounted host directory (working directory)
- `/home/node/.claude`: Container's Claude settings (copied from host)
- `/var/run/docker.sock`: Docker daemon socket (if mounted)