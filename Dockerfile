# File: claude-yolo/Dockerfile

FROM node:20-slim

# Install system dependencies, including 'gosu' and 'rsync'
RUN apt-get update && apt-get install -y \
    git \
    curl \
    gnupg \
    ca-certificates \
    gosu \
    rsync \
    && rm -rf /var/lib/apt/lists/*

# --- Install the Docker CLI Client ---
RUN install -m 0755 -d /etc/apt/keyrings
RUN curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
RUN chmod a+r /etc/apt/keyrings/docker.gpg
RUN echo \
  "deb [arch="$(dpkg --print-architecture)" signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian \
  "$(. /etc/os-release && echo "$VERSION_CODENAME")" stable" | \
  tee /etc/apt/sources.list.d/docker.list > /dev/null
RUN apt-get update && apt-get install -y docker-ce-cli

# --- Install the OFFICIAL Claude Code CLI ---
RUN npm install -g @anthropic-ai/claude-code

# --- Setup Entrypoint ---
COPY entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/entrypoint.sh
ENTRYPOINT ["entrypoint.sh"]

# Set the default working directory
WORKDIR /project

# Set the default command. This is what the entrypoint will execute after it's done.
CMD ["/bin/bash"]
