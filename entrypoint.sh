#!/bin/bash
set -e

# This script runs as root to prepare the container for the user.

USER_ID=${HOST_UID:-1000}
GROUP_ID=${HOST_GID:-1000}

# --- DOCKER SOCKET PERMISSIONS ---
# This block dynamically grants the container user access to the host's Docker socket.
if [ -S /var/run/docker.sock ]; then
  # Get the Group ID of the Docker socket on the host.
  DOCKER_GID=$(stat -c '%g' /var/run/docker.sock)

  # Create a 'docker' group inside the container with the same GID.
  # The '-o' flag allows us to use a non-unique GID.
  getent group "${DOCKER_GID}" &>/dev/null || groupadd -g "${DOCKER_GID}" -o docker
fi

# Modify the existing 'node' user to match the host user's IDs.
groupmod -g "${GROUP_ID}" -o node
usermod -u "${USER_ID}" -o node

# Add the 'node' user to the newly created 'docker' group.
# This is the step that grants permission to use the socket.
if [ -S /var/run/docker.sock ]; then
  usermod -aG docker node
fi

# Bootstrap host settings into the volume on the first run.
if [ ! -f "/home/node/.claude/.credentials.json" ]; then
  if [ -d "/tmp/host-claude-config" ] && [ "$(ls -A /tmp/host-claude-config)" ]; then
    echo "--- [CLAUDE-YOLO SETUP] ---"
    echo "First run detected! Bootstrapping settings from host..."
    rsync -a --exclude '.credentials.json' /tmp/host-claude-config/ /home/node/.claude/
    echo "Bootstrap complete. You will now be prompted to log in to create a new, valid session."
    echo "---"
  fi
fi

# Ensure the final home directory has the correct ownership.
chown -R "${USER_ID}":"${GROUP_ID}" /home/node

# Drop root privileges and execute the main command as the 'node' user.
exec gosu node "$@"
