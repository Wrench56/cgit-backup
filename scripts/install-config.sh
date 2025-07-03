#!/bin/sh

# Install the selected configuration

install_lighttpd() {
    printf "[*] Installing lighttpd configurations\n"
    sudo mkdir -p /etc/lighttpd/conf.d
    sudo cp configs/lighttpd/cgit.conf /etc/lighttpd/conf.d/
    if sudo grep -Fxq 'include "conf.d/cgit.conf"' /etc/lighttpd/lighttpd.conf; then
        printf "[*] Lighttpd config include already present, skipping insert.\n"
        return
    fi
    sudo awk '
    BEGIN { inserted = 0 }
    {
        if (!inserted && $0 !~ /^#/ && $0 ~ /\S/) {
            print
            print "include \"conf.d/cgit.conf\"\n"
            inserted = 1
        } else {
            print
        }
    }
    END {
        if (!inserted) {
            print "include \"conf.d/cgit.conf\"\n"
        }
    }
    ' /etc/lighttpd/lighttpd.conf > /tmp/lighttpd.conf
    sudo mv /tmp/lighttpd.conf /etc/lighttpd/lighttpd.conf
}

case "$1" in
    "lighttpd")
        install_lighttpd
        ;;
esac

printf "[$] Done!\n"
