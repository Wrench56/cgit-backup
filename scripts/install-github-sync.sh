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

install_jq() {
    echo "[*] Installing \"jq\"..."
    if command -v jq >/dev/null 2>&1; then
        echo "[*] \"jq\" is already installed"
        return 0
    fi

    OS="$(uname -s)"
    DISTRO=""
    echo "[*] Detecting OS..."

    if [ "$OS" = "Linux" ] && [ -f /etc/os-release ]; then
        . /etc/os-release
        DISTRO="$ID"
        echo "[*] Detected Linux distro: $DISTRO"
    fi

    case "$OS" in
        Darwin)
            if command -v brew >/dev/null 2>&1; then
                brew install jq
            else
                echo "[*] Homebrew not found. Install it from https://brew.sh/"
                return 1
            fi
            ;;

        Linux)
            case "$DISTRO" in
                ubuntu|debian|linuxmint)
                    sudo apt update && sudo apt install -y jq
                    ;;
                fedora)
                    sudo dnf install -y jq
                    ;;
                centos|rhel)
                    sudo yum install -y epel-release && sudo yum install -y jq
                    ;;
                arch|manjaro|cachyos|artix)
                    sudo pacman -Sy --noconfirm jq
                    ;;
                alpine)
                    sudo apk add jq
                    ;;
                clear-linux-os)
                    sudo swupd bundle-add jq
                    ;;
                *)
                    echo "[!] Unknown Linux distro: $DISTRO"
                    ;;
            esac
            ;;

        *)
            echo "[!] Unsupported OS: $OS"
            return 1
            ;;
    esac

    if command -v jq >/dev/null 2>&1; then
        echo "[*] \"jq\" installed successfully"
        return 0
    else
        echo "[!] \"jq\" installation failed"
        return 1
    fi
}

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
