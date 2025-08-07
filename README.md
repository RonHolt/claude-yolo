# Claude YOLO Sandbox: An Optimized Ephemeral Sandbox for AI-Powered Development

## 1. Philosophy and Purpose

This project provides a secure, flexible, and powerful **ephemeral (temporary)** sandbox for using the `claude-code` CLI. Its primary goal is to empower an AI agent to work on any local project with full Docker-in-Docker capabilities, without compromising the host machine.

After extensive testing, this model accepts and works with the security design of the `claude-code` CLI, which appears to invalidate login tokens between different container sessions. Therefore, to ensure security and stability, **a browser login is required once per session** when using a subscription. This README explains how this process is made as seamless as possible.

## 2. Key Features

- **Single Command Launch**: A single, universal `claude-yolo` command launches a pre-configured sandbox from any directory.
- **Flexible Authentication**: Defaults to the interactive browser login for Claude Pro/Max users. An `--apikey` flag is available for automated or API-based workflows.
- **Automatic Settings Bootstrap**: On every launch, it automatically and seamlessly copies your settings from `~/.claude` on your host (agents, custom commands, etc.) into the sandbox, giving you a consistent experience every time.
- **Full Docker-in-Docker Control**: The sandbox has secure access to the host's Docker daemon, allowing the AI to run `docker` and `docker compose` commands (e.g., `docker exec`, `docker ps`) to inspect and interact with sibling containers.
- **Correct File Permissions**: An intelligent `entrypoint` script ensures that any files created or modified by the AI inside the container have the correct user and group ownership on your host machine, eliminating `permission denied` errors.
- **Works from Anywhere**: You can launch the sandbox from any project directory on your filesystem, and it will correctly mount the current directory.

## 3. How It Works: The Architecture

This solution uses a combination of Docker features to create a robust environment:

1.  **The `claude-yolo` Script**: This is the user-facing command. It parses arguments (like `--apikey` or a network name) and assembles the `docker run` command with the correct flags.
2.  **The `Dockerfile`**: This defines the sandbox environment. It installs `node`, the `claude-code` CLI, the Docker client, `rsync` (for settings copying), and `gosu` (a lightweight tool for user switching).
3.  **The `entrypoint.sh` Script**: This is the heart of the sandbox. It runs as `root` the moment a container starts, before you get a shell. It performs several critical tasks:
    - It matches the container's internal `node` user to your host user's ID.
    - It securely grants the `node` user permission to use the mounted Docker socket.
    - It uses `rsync` to copy your `~/.claude` settings into the container's home directory.
    - It fixes the final file ownership of the settings directory.
    - Finally, it drops root privileges and starts the user's `bash` shell.

## 4. Installation (For New Developers)

Follow these steps to get the sandbox running on a new machine.

**1. Get the Project Files**

You will need the three core files: `Dockerfile`, `entrypoint.sh`, and `claude-yolo`. Clone the repository or otherwise copy them into a single directory on your machine.

**Important for Windows/WSL Users:**
If you're using WSL (Windows Subsystem for Linux), the script files may have Windows line endings that prevent execution. Fix this by running:
```bash
# Convert to Unix line endings
dos2unix claude-yolo entrypoint.sh
# Or if dos2unix isn't available:
sed -i 's/\r$//' claude-yolo entrypoint.sh
```

**2. Make Scripts Executable**

Navigate to the directory containing the files and run:

```bash
chmod +x claude-yolo
chmod +x entrypoint.sh
```

**3. Build the Docker Image (REQUIRED!)**

From within the same directory, build the `claude-yolo-env` image. **This step is mandatory - the container won't work without it!**

```bash
docker build -t claude-yolo-env .
```

If you see errors like "exec /usr/local/bin/entrypoint.sh: no such file or directory", it means the Docker image hasn't been built yet.

**4. Install the Main Script**

Move the `claude-yolo` script to a directory in your system's `PATH` to make it a globally available command.

```bash
sudo mv claude-yolo /usr/local/bin/
```

**5. One-Time Host Setup (Choose One Method)**

- **For Subscription Users (Recommended):** Log in on your host machine once to create the `~/.claude` settings directory.
  ```bash
  claude login
  ```
- **For API Key Users:** Set the `ANTHROPIC_API_KEY` environment variable on your host machine (e.g., in `~/.bashrc` or `~/.zshrc`).
  ```bash
  export ANTHROPIC_API_KEY='sk-ant-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx'
  ```

## 5. Daily Workflow & Usage

#### Default: Interactive Session (Browser Login)

This is the primary use case. It uses your Claude Pro/Max subscription and automatically loads all your settings. Navigate to any project directory and run:

```bash
# Start a session in the current directory
claude-yolo

# Start a session and connect to a running Docker network
claude-yolo my-project_default
```

You will be prompted by the `claude` CLI to log in via your browser. This is expected for each session.

#### Alternative: API Key Session

For automated tasks, use the `--apikey` flag. This will not load your `~/.claude` settings.

```bash
claude-yolo --apikey
```

## 6. Context for AI Assistants (The "Meta-Prompt")

To get an AI agent up to speed quickly, you can give it the following context at the start of a session.

> Hello Claude. To work effectively in this environment, please understand the following context:
>
> **Your Environment:**
>
> - You are running inside a temporary, secure Docker container. My settings, agents, and custom commands have been pre-loaded for you.
> - The project files from my host machine are mounted at your current working directory, `/project`.
> - You have full internet access.
> - You are running as a non-root user that has the same permissions as I do on my host machine.
>
> **Your Superpower: Docker Control**
>
> - You have been granted secure access to my host machine's Docker daemon.
> - This means you can run `docker` and `docker compose` commands to inspect and interact with any other containers I have running.
>
> **The Correct Workflow for Interacting with Other Containers:**
>
> 1.  **Identify the Target:** If you need to know service names, you can ask to read the `docker-compose.yml` file.
> 2.  **Find the Full Container Name:** Service names are not container names. Always run `docker ps` to find the exact, running container name. A great command for this is: `docker ps --format "table {{.Names}}\t{{.Status}}"`
> 3.  **Execute Commands:** Use `docker exec` with the **full container name** to run commands inside the target container. For example: `docker exec my-project-wpcli-1 wp plugin list`.
>
> **Example Thought Process:**
>
> - **My Request:** "Can you list the WordPress plugins?"
> - **Your Plan:**
>   1.  "Okay, first I'll run `docker ps` to find the name of the `wpcli` or `wordpress` container."
>   2.  "The container is named `my-project-wpcli-1`. I will use that full name."
>   3.  "Now I will execute `docker exec my-project-wpcli-1 wp plugin list`."
>
> This workflow will ensure your `docker` commands succeed.

## 7. Troubleshooting for Humans

- **"command not found: claude-yolo"**: Make sure `/usr/local/bin` is in your `PATH`, or that you moved the `claude-yolo` script to a directory that is.
- **"Error: ANTHROPIC_API_KEY environment variable is not set..."**: You ran `claude-yolo --apikey` but did not `export` the variable on your host.
- **Changes to `Dockerfile` or `entrypoint.sh` don't seem to work**: You must run `docker build -t claude-yolo-env .` again after any change to these two files.
