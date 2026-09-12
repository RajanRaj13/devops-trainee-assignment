#!/usr/bin/env bash
# Run this as root (or with sudo) on a fresh Ubuntu box.
# Creates a "trainee" user with sudo privileges and sets up their SSH key dir.

set -euo pipefail

USERNAME="trainee"

if id "$USERNAME" &>/dev/null; then
    echo "User '${USERNAME}' already exists, skipping creation."
else
    adduser --gecos "" "$USERNAME"
    echo "User '${USERNAME}' created."
fi

usermod -aG sudo "$USERNAME"
echo "User '${USERNAME}' added to sudo group."

# Prepare .ssh directory for key-based auth
install -d -m 700 -o "$USERNAME" -g "$USERNAME" "/home/${USERNAME}/.ssh"
touch "/home/${USERNAME}/.ssh/authorized_keys"
chmod 600 "/home/${USERNAME}/.ssh/authorized_keys"
chown "${USERNAME}:${USERNAME}" "/home/${USERNAME}/.ssh/authorized_keys"

echo ""
echo "Next step: from your LOCAL machine, copy your public key to the server:"
echo "  ssh-copy-id -i ~/.ssh/id_ed25519.pub -p 22 ${USERNAME}@<server-ip>"
echo ""
echo "(Use port 22 for this copy - SSH hardening happens in the next script,"
echo " AFTER you've confirmed key-based login works.)"
