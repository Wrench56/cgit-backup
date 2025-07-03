#!/bin/sh

# Fully automated installer for syncing GitHub repos to cgit
# Dependencies:
# - [P] jq (autoinstalled)

set -e

GITHUB_USER="$1"
CRON_FILE="/etc/cron.d/github-sync"
SYNC_SCRIPT="/usr/local/bin/github-sync.sh"
REPO_DIR="/var/lib/git"
LOGFILE="/var/log/github-sync.log"

if [ "$(id -u)" -ne 0 ]; then
    echo "[!] Please run this installer as root (e.g. via sudo)"
    exit 1
fi

if [ -z "$GITHUB_USER" ]; then
    echo "[!] Usage: $0 <github-user>"
    exit 1
fi

if ! install_jq; then
    echo "[!] Try installing \"jq\" manually"
    exit 1
fi

printf "[*] Installing GitHub sync script for user: %s\n" "$GITHUB_USER"

install -d -o root -g root -m 755 "$REPO_DIR"
touch "$LOGFILE"
chmod 644 "$LOGFILE"

cat <<EOF > "$CRON_FILE"
# Part of https://github.com/Wrench56/cgit-backup
0 0 * * * root "$SYNC_SCRIPT"

EOF

chown root:root "$CRON_FILE"
chmod 644 "$CRON_FILE"

cat <<EOF > "$SYNC_SCRIPT"
#!/bin/sh

# Part of https://github.com/Wrench56/cgit-backup

USER="$GITHUB_USER"
BASE_DIR="$REPO_DIR"
LOGFILE="$LOGFILE"
LOCKFILE="/tmp/cgit-backup.lock"

if [ -e "\$LOCKFILE" ]; then
    if kill -0 "\$(cat "\$LOCKFILE")" 2>/dev/null; then
        echo "[\$(date)] [!] Another instance is running. Exiting." >> "\$LOGFILE"
        exit 1
    else
        echo "[\$(date)] [!] Stale lockfile found. Removing." >> "\$LOGFILE"
        rm -f "\$LOCKFILE"
    fi
fi

echo \$\$ > "\$LOCKFILE"
trap 'rm -f "\$LOCKFILE"' EXIT INT TERM

mkdir -p "\$BASE_DIR"

curl -s "https://api.github.com/users/\$USER/repos?per_page=99999" | jq -c '.[]' |
while read -r repo; do
    url=\$(echo "\$repo" | jq -r '.clone_url')
    name=\$(echo "\$repo" | jq -r '.name')
    description=\$(echo "\$repo" | jq -r '.description // empty')
    repo_path="\$BASE_DIR/\$name.git"

    if [ ! -d "\$repo_path" ]; then
        echo "[\$(date)] [+] Cloning \$name" >> "\$LOGFILE"
        git clone --mirror "\$url" "\$repo_path"
    else
        echo "[\$(date)] [*] Updating \$name" >> "\$LOGFILE"
        git -C "\$repo_path" remote update --prune
    fi

    echo "\$description" > "\$repo_path/description"
    echo "[\$(date)] [i] Wrote description for \$name" >> "\$LOGFILE"
done

EOF

chmod 755 "$SYNC_SCRIPT"
chown root:root "$SYNC_SCRIPT"

printf "[*] Installed sync script to: %s\n" "$SYNC_SCRIPT"
printf "[$] Done.\n"
