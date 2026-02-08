#!/usr/bin/env bash
#
# setup-passwordless-ssh-with-alias.sh
# Establishes passwordless SSH login and adds an alias to ~/.ssh/config.
# Prompts for: remote user, host (IP or domain), alias name, and password when needed.
#

set -e

SSH_KEY="${SSH_KEY:-$HOME/.ssh/id_ed25519}"
SSH_KEY_PUB="${SSH_KEY}.pub"
SSH_CONFIG="${SSH_CONFIG:-$HOME/.ssh/config}"

usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Sets up passwordless SSH login and adds a Host alias to SSH config."
    echo "You will be prompted for: remote user, host (IP or domain), alias, and password."
    echo ""
    echo "Options:"
    echo "  -k, --key PATH    Use this key (default: \$HOME/.ssh/id_ed25519)"
    echo "  -h, --help        Show this help"
    exit 0
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        -k|--key)
            SSH_KEY="$2"
            SSH_KEY_PUB="${SSH_KEY}.pub"
            shift 2
            ;;
        -h|--help)
            usage
            ;;
        *)
            echo "Unknown option: $1"
            usage
            ;;
    esac
done

# Ensure key files are absolute
[[ "$SSH_KEY" != /* ]] && SSH_KEY="$HOME/.ssh/${SSH_KEY#*/}"
SSH_KEY_PUB="${SSH_KEY}.pub"

echo "=== Passwordless SSH setup (with alias) ==="
echo ""

# Prompt for user
read -r -p "Remote user: " REMOTE_USER
[[ -z "$REMOTE_USER" ]] && { echo "User is required."; exit 1; }

# Prompt for host (IP or domain)
read -r -p "Host (IP or domain): " REMOTE_HOST
[[ -z "$REMOTE_HOST" ]] && { echo "Host is required."; exit 1; }

# Prompt for alias (single word for SSH config Host)
while true; do
    read -r -p "Alias for this connection (e.g. myserver, vps-prod): " ALIAS
    ALIAS="${ALIAS// /}"
    if [[ -z "$ALIAS" ]]; then
        echo "Alias is required."
        continue
    fi
    if [[ "$ALIAS" =~ [^a-zA-Z0-9._-] ]]; then
        echo "Use only letters, numbers, dots, hyphens, and underscores."
        continue
    fi
    break
done

TARGET="${REMOTE_USER}@${REMOTE_HOST}"
echo "Target: $TARGET  →  alias: $ALIAS"
echo ""

# Create .ssh if missing
mkdir -p "$HOME/.ssh"
chmod 700 "$HOME/.ssh"

# Generate key if it doesn't exist
if [[ ! -f "$SSH_KEY" ]]; then
    echo "No SSH key found at $SSH_KEY"
    read -r -p "Generate new key? [Y/n] " GEN
    GEN="${GEN:-Y}"
    if [[ "${GEN^}" != "N" ]]; then
        ssh-keygen -t ed25519 -f "$SSH_KEY" -N "" -C "passwordless-setup"
        echo "Key generated."
    else
        echo "Aborted. Create a key first with: ssh-keygen -t ed25519 -f $SSH_KEY"
        exit 1
    fi
fi

# Copy public key to remote (will prompt for password)
echo ""
echo "You will be prompted for the remote user's password to install the public key."
if command -v ssh-copy-id &>/dev/null; then
    ssh-copy-id -i "$SSH_KEY_PUB" "$TARGET"
else
    echo "ssh-copy-id not found. Installing key manually..."
    cat "$SSH_KEY_PUB" | ssh "$TARGET" "mkdir -p ~/.ssh && chmod 700 ~/.ssh && cat >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys"
fi

echo ""
echo "Testing passwordless connection..."
if ! ssh -i "$SSH_KEY" -o BatchMode=yes -o ConnectTimeout=10 "$TARGET" "echo OK" 2>/dev/null; then
    echo "Connection test failed. Check that the key was added and try: ssh $TARGET"
    exit 1
fi

# Ensure SSH config exists and has correct permissions
touch "$SSH_CONFIG"
chmod 600 "$SSH_CONFIG"

# Append alias block (add newline if file doesn't end with one)
[[ -s "$SSH_CONFIG" ]] && [[ $(tail -c1 "$SSH_CONFIG" | wc -l) -eq 0 ]] && echo "" >> "$SSH_CONFIG"

{
    echo ""
    echo "Host $ALIAS"
    echo "    HostName $REMOTE_HOST"
    echo "    User $REMOTE_USER"
    echo "    IdentityFile $SSH_KEY"
} >> "$SSH_CONFIG"

echo ""
echo "Success. Passwordless login and alias are set up."
echo "Connect with:  ssh $ALIAS"
