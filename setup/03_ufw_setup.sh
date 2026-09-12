#!/usr/bin/env bash
# Configures ufw to allow only SSH (2222), HTTP (80), and HTTPS (443).
# Run AFTER SSH hardening (02_ssh_hardening.sh), so port 2222 already exists.

set -euo pipefail

# Set safe defaults
ufw default deny incoming
ufw default allow outgoing

# Allow only the required services
ufw allow 2222/tcp comment 'SSH hardened port'
ufw allow 80/tcp comment 'HTTP'
ufw allow 443/tcp comment 'HTTPS'

# Explicitly make sure default SSH port 22 is NOT allowed
ufw deny 22/tcp comment 'default SSH port blocked' || true

# Enable ufw (non-interactive)
ufw --force enable

ufw status verbose
