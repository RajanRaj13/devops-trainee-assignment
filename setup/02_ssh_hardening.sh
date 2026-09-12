#!/usr/bin/env bash
# Run this AFTER you have verified you can log in as `trainee` with your SSH key
# on the default port 22. This script:
#   - moves SSH to port 2222
#   - disables root login
#   - disables password authentication (key-based only)
#
# WARNING: Test the new key-based login in a SEPARATE terminal before closing
# your current session, or you can lock yourself out.

set -euo pipefail

SSHD_CONFIG="/etc/ssh/sshd_config"
BACKUP="/etc/ssh/sshd_config.bak.$(date +%Y%m%d%H%M%S)"

cp "$SSHD_CONFIG" "$BACKUP"
echo "Backed up original config to ${BACKUP}"

set_sshd_option() {
    local key="$1"
    local value="$2"
    if grep -qE "^\s*#?\s*${key}\s+" "$SSHD_CONFIG"; then
        sed -i "s|^\s*#\?\s*${key}\s\+.*|${key} ${value}|" "$SSHD_CONFIG"
    else
        echo "${key} ${value}" >> "$SSHD_CONFIG"
    fi
}

set_sshd_option "Port" "2222"
set_sshd_option "PermitRootLogin" "no"
set_sshd_option "PasswordAuthentication" "no"
set_sshd_option "PubkeyAuthentication" "yes"
set_sshd_option "ChallengeResponseAuthentication" "no"

# Validate config before restarting
sshd -t
echo "sshd config syntax OK."

# If ufw is active, allow the new port before restarting sshd
if command -v ufw >/dev/null 2>&1; then
    ufw allow 2222/tcp comment 'SSH (hardened port)' || true
fi

systemctl restart sshd

echo ""
echo "SSH hardening applied:"
echo "  - Port changed to 2222"
echo "  - Root login disabled"
echo "  - Password authentication disabled (key-based only)"
echo ""
echo "IMPORTANT: In a NEW terminal (keep this session open), test:"
echo "  ssh -i ~/.ssh/id_ed25519 -p 2222 trainee@<server-ip>"
echo "Only close this session after that succeeds."
