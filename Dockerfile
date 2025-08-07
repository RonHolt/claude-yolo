# File: claude-yolo/Dockerfile

FROM node:20-slim

# Install system dependencies, including rsync for bootstrapping and gosu for user switching
RUN apt-get update && apt-get install -y \
    git \
    curl \
    gnupg \
    ca-certificates \
    gosu \
    rsync \
    && rm -rf /var/lib/apt/lists/*

# Install the Docker CLI Client
RUN install -m 0755 -d /etc/apt/keyrings && curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg && chmod a+r /etc/apt/keyrings/docker.gpg
RUN echo "deb [arch="$(dpkg --print-architecture)" signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian "$(. /etc/os-release && echo "$VERSION_CODENAME")" stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
RUN apt-get update && apt-get install -y docker-ce-cli

# Install the OFFICIAL Claude Code CLI
RUN npm install -g @anthropic-ai/claude-code

# Copy the entrypoint script into the image and make it executable
COPY entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/entrypoint.sh

# Set the entrypoint. This script will now run every time the container starts.
ENTRYPOINT ["entrypoint.sh"]

# Set the default working directory
WORKDIR /project

# Set the default command. This is what the entrypoint will execute after it's done.
CMD ["/bin/bash"]
