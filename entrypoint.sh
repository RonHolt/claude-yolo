#!/bin/bash
# File: claude-yolo/entrypoint.sh

set -e

USER_ID=${HOST_UID:-1000}
GROUP_ID=${HOST_GID:-1000}

# --- User & Group Setup ---
# Modify the existing 'node' user to match the host user's IDs for seamless file permissions.
groupmod -g "${GROUP_ID}" -o node
usermod -u "${USER_ID}" -o node

# --- Docker Socket Permissions ---
# Grant access to the host's Docker socket if it's mounted.
if [ -S /var/run/docker.sock ]; then
  DOCKER_GID=$(stat -c '%g' /var/run/docker.sock)
  getent group "${DOCKER_GID}" &>/dev/null || groupadd -g "${DOCKER_GID}" -o docker
  usermod -aG docker node
fi

# --- Bootstrap Settings ---
# If a host config directory is mounted, copy its contents (agents, settings, etc.)
# into the container's home directory. This gives you a consistent setup every time.
# We exclude the useless .credentials.json file.
if [ -d "/tmp/host-claude-config" ]; then
  rsync -a --exclude '.credentials.json' /tmp/host-claude-config/ /home/node/.claude/
fi

# --- Final Ownership Fix ---
# Unconditionally ensure the user owns the entire .claude directory.
# This prevents permission errors when the CLI tries to write new files (like 'todos').
chown -R "${USER_ID}":"${GROUP_ID}" /home/node/.claude

# Drop root privileges and execute the main command (e.g., /bin/bash) as the 'node' user.
exec gosu node "$@"
