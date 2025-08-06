# Claude YOLO Sandbox: A Stateful, Docker-in-Docker AI Environment

This project provides a secure, reusable, and **stateful** containerized environment for running Anthropic's official `claude-code` CLI. It is purpose-built to give an AI agent sandboxed-yet-powerful access to a developer's workflow, including the ability to interact with other `docker-compose` services.

This setup solves many complex challenges, including persistent authentication, user permissions, and granting secure access to the host's Docker daemon.

## Key Features

- **Official Tool**: Uses the correct `@anthropic-ai/claude-code` npm package.
- **Host Protection**: The AI operates entirely inside a Docker container with no access to your host machine's filesystem outside of the current project directory.
- **Persistent, Secure Authentication**: Uses a **Docker Named Volume** to store login credentials. This provides a valid, persistent session for subscription users after a one-time browser login, without exposing host credentials directly.
- **Settings Bootstrap**: On the first run, it intelligently copies your existing `~/.claude` settings (agents, projects, etc.) into the persistent volume, so you start with your familiar configuration.
- **Robust Permission Handling**: An `entrypoint` script dynamically matches the container's user ID to your host user's ID, eliminating all "permission denied" errors.
- **Full Docker-in-Docker Control**: Securely grants the container access to the host's Docker socket, allowing the AI to run `docker` and `docker compose` commands (e.g., `docker exec`, `docker ps`) to interact with sibling containers.

## Prerequisites

- [Docker](https://docs.docker.com/get-docker/) & [Docker Compose](https://docs.docker.com/compose/install/)
- An **Anthropic API Key** OR an active **Claude Pro/Max subscription**.

---

## Installation (For New Developers)

Follow these steps to get the sandbox running on a new machine.

**1. Clone the `claude-yolo` Project**

You only need this project's files to build the sandbox environment.

```bash
# Example:
# git clone <your-repo-url>/claude-yolo.git
# cd claude-yolo
```

**2. Build the Docker Image**

This command creates the `claude-yolo-env` Docker image from the `Dockerfile`. You only need to do this once (or when you update the `Dockerfile` or `entrypoint.sh`).

```bash
docker build -t claude-yolo-env .
```

**3. Install the Launch Script**

Move the `claude-yolo` script to a directory in your system's `PATH` to make it a globally available command.

```bash
chmod +x claude-yolo
sudo mv claude-yolo /usr/local/bin/
```

**4. Configure Your Authentication (Choose One Method)**

You only need to do one of the following.

### Method A: For API Key Users (Stateless)

This method is best for CI/CD or simple automation. Expose your API key as an environment variable on your host machine (e.g., in `~/.bashrc` or `~/.zshrc`).

```bash
export ANTHROPIC_API_KEY='sk-ant-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx'
```

### Method B: For Claude Pro/Max Subscription Users (Stateful)

This method uses a persistent Docker volume and is recommended for daily development.

**First-Time Setup:** The first time you use this method, you must initialize the sandbox's identity.

1.  Navigate to any project directory.
2.  Launch the sandbox with the `--login` flag:
    ```bash
    claude-yolo --login
    ```
3.  The script will detect this is the first run and **bootstrap** your settings from `~/.claude` into the new Docker volume.
4.  Inside the sandbox, run any `claude` command (e.g., `claude list`).
5.  **You will be prompted to log in with your browser.** This is expected. Copy the URL, paste it into your host's browser, and complete the login.
6.  This action saves a new, valid credential token **inside the Docker volume**.
7.  You can now `exit`. The session is now persistent.

---

## Daily Workflow & Usage

### Launching the Sandbox

Navigate to the root of the project you want to work on, then:

**To use your API key:**

```bash
claude-yolo
```

**To use your persistent subscription login:**

```bash
claude-yolo --login
```

**To connect to a running `docker-compose` network:**
Find your network name with `docker network ls` (e.g., `my-project_default`), then:```bash
claude-yolo --login my-project_default

```

## Context for Claude Code & Future AI

To get the AI agent up to speed quickly, you can give it the following context prompt at the start of a session.

> Hello Claude. To work effectively in this environment, please understand the following context:
>
> **Your Environment:**
> *   You are running inside a secure Docker container named `claude-yolo-env`.
> *   The project files from the host machine are mounted at your current working directory, `/project`.
> *   You have full internet access.
> *   You are running as a non-root user (`node`) that has the same user ID as the host user.
>
> **Your Superpower: Docker Control**
> *   You have been granted secure access to the host's Docker daemon socket.
> *   This means you can run `docker` and `docker compose` commands to inspect and interact with any other containers running on the host machine.
>
> **Common Workflow for Interacting with Other Containers:**
> 1.  **Identify the Target:** First, inspect `docker-compose.yml` to understand the service names (e.g., `wpcli`, `wordpress`, `db`).
> 2.  **Find the Full Container Name:** Service names are not always container names. Use `docker ps` to find the exact, running container name. A good command for this is: `docker ps --format "table {{.Names}}\t{{.Image}}\t{{.Status}}"`
> 3.  **Execute Commands:** Use `docker exec` with the **full container name** to run commands inside the target container.
>
> **Example Prompt & Your Thought Process:**
> *   **My Request:** "Can you list the WordPress plugins?"
> *   **Your Plan:**
>     1.  "First, I'll run `docker ps` to find the name of the `wpcli` container."
>     2.  "The name is `chinburg-wpcli-1`. Now I will use that to run the command."
>     3.  "I will execute `docker exec chinburg-wpcli-1 wp plugin list`."
>
> **Troubleshooting for Yourself:**
> *   If you get a "permission denied" error using `docker`, it is a problem with the environment setup, not your commands.
> *   If a `docker exec` command fails with "No such container," it means the service name you used was wrong. Run `docker ps` to get the correct name.
> *   If a `wp-cli` command fails due to a database error, you may need to find and specify the correct `--path`, table prefix, or other configuration, just as a human developer would.

## Security Best Practices

-   **ALWAYS COMMIT FIRST**: `git` is your ultimate safety net. Commit your work before letting the AI make changes.
-   **REVIEW EVERYTHING**: Never trust AI-generated code blindly. Use `git diff` to meticulously review every single change before committing.
-   **MINIMIZE SCOPE**: Only mount the project directory you are actively working on. Avoid running this tool from your home directory or other sensitive locations.
```
