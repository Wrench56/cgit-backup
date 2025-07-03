#!/bin/sh

# Install required dependencies

install_package() {
    PACKAGE="$1"

    if [ -z "$PACKAGE" ]; then
        echo "[!] No package specified"
        return 1
    fi

    echo "[*] Checking for \"$PACKAGE\"..."
    if command -v "$PACKAGE" >/dev/null 2>&1; then
        echo "[*] \"$PACKAGE\" is already installed"
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
                brew install "$PACKAGE"
            else
                echo "[!] Homebrew not found. Install it from https://brew.sh/"
                return 1
            fi
            ;;
        Linux)
            case "$DISTRO" in
                ubuntu|debian|linuxmint)
                    sudo apt update && sudo apt install -y "$PACKAGE"
                    ;;
                fedora)
                    sudo dnf install -y "$PACKAGE"
                    ;;
                centos|rhel)
                    sudo yum install -y epel-release && sudo yum install -y "$PACKAGE"
                    ;;
                arch|manjaro|cachyos|artix)
                    sudo pacman -Sy --noconfirm "$PACKAGE"
                    ;;
                alpine)
                    sudo apk add "$PACKAGE"
                    ;;
                clear-linux-os)
                    sudo swupd bundle-add "$PACKAGE"
                    ;;
                *)
                    echo "[!] Unknown Linux distro: $DISTRO"
                    return 1
                    ;;
            esac
            ;;
        *)
            echo "[!] Unsupported OS: $OS"
            return 1
            ;;
    esac

    if command -v "$PACKAGE" >/dev/null 2>&1; then
        echo "[*] \"$PACKAGE\" installed successfully"
        return 0
    else
        echo "[!] \"$PACKAGE\" installation failed"
        return 1
    fi
}

echo "[*] Installing required dependencies..."
install_package curl
install_package git
install_package jq
echo "[$] Done!"
