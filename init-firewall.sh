#!/bin/bash
# init-firewall.sh - Optional network allowlisting for the container
# Inspired by the official Claude Code devcontainer init-firewall.sh
#
# Usage: Called by entrypoint.sh when ENABLE_FIREWALL=true
# Requires: iptables, running as root (before privilege drop)

set -e

echo "[firewall] Configuring network allowlist..."

# Flush existing rules
iptables -F OUTPUT 2>/dev/null || true
iptables -F INPUT 2>/dev/null || true

# Allow loopback
iptables -A OUTPUT -o lo -j ACCEPT
iptables -A INPUT -i lo -j ACCEPT

# Allow established/related connections
iptables -A OUTPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT

# Allow DNS
iptables -A OUTPUT -p udp --dport 53 -j ACCEPT
iptables -A OUTPUT -p tcp --dport 53 -j ACCEPT

# --- Allowlisted Destinations ---

# Anthropic API
iptables -A OUTPUT -p tcp -d api.anthropic.com --dport 443 -j ACCEPT
iptables -A OUTPUT -p tcp -d sentry.io --dport 443 -j ACCEPT
iptables -A OUTPUT -p tcp -d statsig.anthropic.com --dport 443 -j ACCEPT

# Claude Code auth
iptables -A OUTPUT -p tcp -d auth.anthropic.com --dport 443 -j ACCEPT
iptables -A OUTPUT -p tcp -d console.anthropic.com --dport 443 -j ACCEPT

# npm registry
iptables -A OUTPUT -p tcp -d registry.npmjs.org --dport 443 -j ACCEPT

# GitHub
iptables -A OUTPUT -p tcp -d github.com --dport 443 -j ACCEPT
iptables -A OUTPUT -p tcp -d github.com --dport 22 -j ACCEPT
iptables -A OUTPUT -p tcp -d api.github.com --dport 443 -j ACCEPT
iptables -A OUTPUT -p tcp -d raw.githubusercontent.com --dport 443 -j ACCEPT
iptables -A OUTPUT -p tcp -d objects.githubusercontent.com --dport 443 -j ACCEPT

# PyPI
iptables -A OUTPUT -p tcp -d pypi.org --dport 443 -j ACCEPT
iptables -A OUTPUT -p tcp -d files.pythonhosted.org --dport 443 -j ACCEPT

# Docker Hub (for Docker-in-Docker)
iptables -A OUTPUT -p tcp -d registry-1.docker.io --dport 443 -j ACCEPT
iptables -A OUTPUT -p tcp -d auth.docker.io --dport 443 -j ACCEPT
iptables -A OUTPUT -p tcp -d production.cloudflare.docker.com --dport 443 -j ACCEPT

# General web access for research (optional - comment out for strict mode)
# This allows HTTPS to any destination. Remove these lines for maximum restriction.
if [ "${FIREWALL_ALLOW_WEB:-true}" = "true" ]; then
    echo "[firewall] Allowing general HTTPS for web research"
    iptables -A OUTPUT -p tcp --dport 443 -j ACCEPT
    iptables -A OUTPUT -p tcp --dport 80 -j ACCEPT
fi

# Docker socket (local)
iptables -A OUTPUT -p tcp -d 127.0.0.1 --dport 2375 -j ACCEPT
iptables -A OUTPUT -p tcp -d 127.0.0.1 --dport 2376 -j ACCEPT

# --- Default Deny ---
iptables -A OUTPUT -j REJECT --reject-with icmp-port-unreachable

echo "[firewall] Network allowlist active."
if [ "${FIREWALL_ALLOW_WEB:-true}" = "true" ]; then
    echo "[firewall] General web access: ALLOWED (set FIREWALL_ALLOW_WEB=false for strict mode)"
else
    echo "[firewall] General web access: BLOCKED (strict mode)"
fi
