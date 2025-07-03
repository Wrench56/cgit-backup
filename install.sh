#!/bin/sh

# Autoinstall the project

set -e

SCRIPT_DIR="./scripts"

if [ $# -ne 2 ]; then
    echo "Usage: $0 (lighttpd) <github-username>"
    exit 1
fi

SERVER="$1"
GITHUB_USER="$2"

case "$SERVER" in
    apache|nginx|lighttpd)
        ;;
    *)
        echo "Error: Invalid server \"$SERVER\". Choose: lighttpd."
        exit 1
        ;;
esac

if [ -d "$SCRIPT_DIR" ]; then
    for file in "$SCRIPT_DIR"/*.sh; do
        [ -f "$file" ] && chmod +x "$file"
    done
else
    echo "[!] \"$SCRIPT_DIR\" directory not found." >&2
    exit 1
fi

sudo "$SCRIPT_DIR/install-config.sh" "$SERVER"
sudo "$SCRIPT_DIR/install-github-sync.sh" "$GITHUB_USER"
