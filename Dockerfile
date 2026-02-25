# Claude YOLO Sandbox - Hardened Docker Environment
# https://github.com/RonHolt/claude-yolo

ARG NODE_VERSION=20
FROM node:${NODE_VERSION}-slim

LABEL maintainer="Ron Holt <ron@bokkagroup.com>"
LABEL description="Hardened Docker sandbox for fully autonomous Claude Code sessions"
LABEL version="2.0.0"

# Install system dependencies
RUN apt-get update && apt-get install -y \
    git \
    curl \
    gnupg \
    ca-certificates \
    gosu \
    rsync \
    jq \
    socat \
    bubblewrap \
    iptables \
    && rm -rf /var/lib/apt/lists/*

# Install Docker CLI and Compose plugin
RUN install -m 0755 -d /etc/apt/keyrings \
    && curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg \
    && chmod a+r /etc/apt/keyrings/docker.gpg
RUN echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
    | tee /etc/apt/sources.list.d/docker.list > /dev/null
RUN apt-get update && apt-get install -y \
    docker-ce-cli \
    docker-compose-plugin \
    && rm -rf /var/lib/apt/lists/*

# Install Claude Code CLI via native installer
# Install to /opt/claude to avoid conflicts with ~/.claude config mount at runtime
RUN curl -fsSL https://claude.ai/install.sh | bash \
    && cp /root/.local/bin/claude /usr/local/bin/claude \
    && mkdir -p /home/node/.local/bin \
    && cp /root/.local/bin/claude /home/node/.local/bin/claude \
    && chown -R node:node /home/node/.local \
    && rm -rf /root/.local/bin/claude

ENV PATH="/home/node/.local/bin:$PATH"

# Copy scripts into the image
COPY entrypoint.sh /usr/local/bin/
COPY init-firewall.sh /usr/local/bin/
COPY claude-loop /usr/local/bin/
RUN chmod +x /usr/local/bin/entrypoint.sh /usr/local/bin/init-firewall.sh /usr/local/bin/claude-loop

ENTRYPOINT ["entrypoint.sh"]
WORKDIR /project
CMD ["/bin/bash"]
