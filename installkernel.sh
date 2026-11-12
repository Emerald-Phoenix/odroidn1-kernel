#!/bin/sh
# Install the kernel built in this tree (run from anywhere; it cds in).
#
# Safety model: the U-Boot boot partition /media/boot is only wiped AFTER every
# artifact (modules, initrd, kernel image, dtb, boot.scr) has been built
# successfully. If anything fails before that point, /media/boot is left
# untouched and the previously installed kernel still boots.
set -eu
cd "$(dirname "$0")"

# kernelrelease (NOT kernelversion): the release string may carry a local
# version suffix (e.g. "+" when the tree is past a version tag) that
# kernelversion never has. modules_install installs into
# /lib/modules/<kernelrelease> and boot.scr loads
# vmlinuz-<kernelrelease> / initrd.img-<kernelrelease>, so every name in
# this script must use the same string.
KVER=$(make -s kernelrelease)

echo Backing up previous kernel
tar -cf - /lib/modules /media/boot | zstd -4 -T2 > /root/kernel-backup-`date +%Y%m%d-%H%M`.tar.zst

echo Installing kernel modules for ${KVER}
rm -fr /lib/modules/*
make modules_install && sync

# Debian's mkinitramfs decides which initramfs compression the kernel supports
# by grepping /boot/config-<version> (it does NOT look in /media/boot and it
# does NOT use the running kernel's /proc/config.gz, since we are building for
# a different version than the one currently booted). That file does not exist
# until we put it there, so install the build config BEFORE running mkinitramfs.
# Without this, mkinitramfs fails with:
#   E: gzip compression (CONFIG_RD_GZIP) not supported by kernel
mkdir -p /boot
cp .config /boot/config-${KVER}

if [ ! -d "/lib/modules/${KVER}" ]; then
    echo "error: /lib/modules/${KVER} not found after modules_install - listing /lib/modules:" >&2
    ls /lib/modules >&2 || true
    exit 1
fi

echo Building initrd for ${KVER}
if ! command -v mkinitramfs >/dev/null 2>&1; then
    echo "error: mkinitramfs not found - cannot build initrd.img-${KVER}" >&2
    echo "       boot.scr passes an initrd to booti, so the new kernel would not boot." >&2
    echo "       /media/boot was left untouched; the old kernel still boots." >&2
    exit 1
fi
# Build to a temp file first so a failure cannot leave /media/boot without a
# boot.scr (which would make the box unbootable). ${KVER} must match the
# /lib/modules/${KVER} tree just installed.
mkinitramfs -k "${KVER}" -o /tmp/initrd.img-${KVER}

echo Installing new kernel to /media/boot
rm -fr /media/boot/*
cp arch/arm64/boot/Image /media/boot/vmlinuz-${KVER} && sync
cp System.map /media/boot/System.map-${KVER}
cp .config /media/boot/config-${KVER}
cp arch/arm64/boot/dts/rockchip/rk3399-odroid-n1.dtb /media/boot && sync
mv /tmp/initrd.img-${KVER} /media/boot/initrd.img-${KVER}
if [ ! -f boot.scr ]; then
    echo "error: boot.scr not found in kernel tree - run ./build.sh (or ./build.sh boot) first" >&2
    exit 1
fi
cp boot.scr /media/boot && sync
