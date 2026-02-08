#!/usr/bin/env bash
#
# setup-passwordless-ssh.sh
# Establishes passwordless SSH login to a remote server by copying the local
# public key. Prompts for user, host (IP or domain), and password when needed.
#

set -e

SSH_KEY="${SSH_KEY:-$HOME/.ssh/id_ed25519}"
SSH_KEY_PUB="${SSH_KEY}.pub"

usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Sets up passwordless SSH login to a remote server."
    echo "You will be prompted for: remote user, host (IP or domain), and password."
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

echo "=== Passwordless SSH setup ==="
echo ""

# Prompt for user
read -r -p "Remote user: " REMOTE_USER
[[ -z "$REMOTE_USER" ]] && { echo "User is required."; exit 1; }

# Prompt for host (IP or domain)
read -r -p "Host (IP or domain): " REMOTE_HOST
[[ -z "$REMOTE_HOST" ]] && { echo "Host is required."; exit 1; }

TARGET="${REMOTE_USER}@${REMOTE_HOST}"
echo "Target: $TARGET"
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
if ssh -i "$SSH_KEY" -o BatchMode=yes -o ConnectTimeout=10 "$TARGET" "echo OK" 2>/dev/null; then
    echo ""
    echo "Success. You can now connect without a password:"
    echo "  ssh -i $SSH_KEY $TARGET"
    echo "  or (if this is your default key): ssh $TARGET"
else
    echo "Connection test failed. Check that the key was added and try: ssh $TARGET"
    exit 1
fi
