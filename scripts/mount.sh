#!/bin/bash -e

set -e -x

if [ -z "$1" ]
then
    echo "$0 [chroot directory]"
    exit 1
fi
CHROOT="$(realpath "$1")"

install_chroot_resolv() {
    local dest="$1"
    sudo rm -f "$dest"
    if [ -f /run/systemd/resolve/resolv.conf ]; then
        sudo cp /run/systemd/resolve/resolv.conf "$dest"
    elif grep -q '^nameserver' /etc/resolv.conf 2>/dev/null \
        && ! grep -q '^nameserver 127.0.0.53' /etc/resolv.conf 2>/dev/null; then
        sudo cp /etc/resolv.conf "$dest"
    else
        printf 'nameserver 1.1.1.1\nnameserver 8.8.8.8\n' | sudo tee "$dest" > /dev/null
    fi
}

if [ -d "$CHROOT" ]
then
    sudo mount --bind /dev "$CHROOT/dev"
    sudo mount -t devpts devpts "$CHROOT/dev/pts" -o gid=5,mode=620,ptmxmode=666 2>/dev/null || \
        sudo mount -t devpts devpts "$CHROOT/dev/pts" -o gid=5,mode=620
    sudo mount -t tmpfs run "$CHROOT/run" -o mode=0755,nosuid,nodev
    sudo mount -t proc proc "$CHROOT/proc" -o nosuid,nodev,noexec
    sudo mount -t sysfs sys "$CHROOT/sys" -o nosuid,nodev,noexec,ro

    # Chroot cannot use the host stub resolver (127.0.0.53). Copy real DNS config.
    install_chroot_resolv "$CHROOT/etc/resolv.conf"
fi
