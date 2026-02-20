#!/bin/bash
# entrypoint.sh - Container initialization script
# Runs as root on startup, then drops to unprivileged user.

set -e

USER_ID=${HOST_UID:-1000}
GROUP_ID=${HOST_GID:-1000}

# --- User & Group Setup ---
groupmod -g "${GROUP_ID}" -o node
usermod -u "${USER_ID}" -o node

# --- Docker / Podman Socket Permissions ---
# Grant access to the container runtime socket if mounted.
for SOCK in /var/run/docker.sock /run/podman/podman.sock; do
    if [ -S "$SOCK" ]; then
        SOCK_GID=$(stat -c '%g' "$SOCK")
        SOCK_GROUP=$(getent group "${SOCK_GID}" | cut -d: -f1 || true)
        if [ -z "${SOCK_GROUP}" ]; then
            SOCK_GROUP="container-runtime"
            groupadd -g "${SOCK_GID}" -o "${SOCK_GROUP}"
        fi
        usermod -aG "${SOCK_GROUP}" node
    fi
done

# --- Safe Mode: Copy Project Files ---
# When SAFE_MODE=true, project files were copied into /project-copy by the launcher.
# Move them into /project so the working directory is correct.
if [ "${SAFE_MODE}" = "true" ] && [ -d "/project-copy" ]; then
    cp -a /project-copy/. /project/
    chown -R "${USER_ID}":"${GROUP_ID}" /project
    echo "[safe mode] Project files copied into container. Originals are untouched."
fi

# --- Authentication & Settings ---
if [ "${PERSIST_AUTH}" = "true" ]; then
    # Read-write mount mode: ~/.claude is already bind-mounted directly.
    # Just ensure ownership is correct.
    if [ -d "/home/node/.claude" ]; then
        chown -R "${USER_ID}":"${GROUP_ID}" /home/node/.claude
    fi
elif [ -d "/tmp/host-claude-config" ]; then
    # Default rsync mode: copy settings from read-only host mount.
    rsync -a --exclude '.credentials.json' /tmp/host-claude-config/ /home/node/.claude/
fi

# Copy ~/.claude.json config if mounted from host
if [ -f "/tmp/host-claude.json" ]; then
    cp /tmp/host-claude.json /home/node/.claude.json
    chown "${USER_ID}":"${GROUP_ID}" /home/node/.claude.json
fi

# --- OAuth Token Injection ---
# If CLAUDE_CODE_OAUTH_TOKEN is set, write it to the credentials file.
if [ -n "${CLAUDE_CODE_OAUTH_TOKEN}" ]; then
    mkdir -p /home/node/.claude
    echo "{\"oauthToken\":\"${CLAUDE_CODE_OAUTH_TOKEN}\"}" > /home/node/.claude/.credentials.json
fi

# --- Final Ownership Fix ---
if [ -d "/home/node/.claude" ]; then
    chown -R "${USER_ID}":"${GROUP_ID}" /home/node/.claude
fi

# --- Optional Firewall ---
if [ "${ENABLE_FIREWALL}" = "true" ]; then
    if command -v iptables &>/dev/null; then
        /usr/local/bin/init-firewall.sh
    else
        echo "[firewall] WARNING: iptables not available, firewall not applied."
    fi
fi

# --- Launch ---
# Drop root and execute the command as the 'node' user.
exec gosu node "$@"
