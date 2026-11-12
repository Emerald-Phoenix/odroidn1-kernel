#!/bin/sh
# Cross-compile the ODROID-N1 (RK3399, arm64) kernel on an x86-64 host.
#
# Usage:
#   ./build.sh              build Image + odroid-n1 dtb + modules + boot.scr
#   ./build.sh config       (re)generate .config from odroidn1_defconfig
#   ./build.sh menuconfig   interactive config editor (needs libncurses-dev)
#   ./build.sh dtb          build rk3399-odroid-n1.dtb only
#   ./build.sh modules      build modules only
#   ./build.sh boot         (re)generate boot.scr from boot.txt (needs mkimage)
#   ./build.sh clean        make clean
#   ./build.sh distclean    make distclean (removes .config)
set -eu

export ARCH=arm64
export CROSS_COMPILE=aarch64-linux-gnu-
JOBS="${JOBS:-$(nproc)}"

if ! command -v "${CROSS_COMPILE}gcc" >/dev/null 2>&1; then
    echo "error: ${CROSS_COMPILE}gcc not found" >&2
    echo "install it with: sudo apt-get install gcc-aarch64-linux-gnu" >&2
    exit 1
fi

# Compile the u-boot boot script from boot.txt. Regenerated on every build so
# boot.scr always matches the kernel version being built.
build_boot_scr() {
    if [ ! -f boot.txt ]; then
        echo "error: boot.txt not found - cannot build boot.scr" >&2
        return 1
    fi
    if ! command -v mkimage >/dev/null 2>&1; then
        echo "error: mkimage not found - cannot build boot.scr" >&2
        echo "install it with: sudo apt-get install u-boot-tools" >&2
        return 1
    fi
    mkimage -A arm -T script -C none -d boot.txt boot.scr
    echo "built boot.scr (u-boot script, kernel $(make -s kernelversion 2>/dev/null || echo '?'))"
}

target="build"
[ $# -gt 0 ] && target="$1"

case "$target" in
    config)
        make odroidn1_defconfig
        ;;
    menuconfig)
        [ -f .config ] || make odroidn1_defconfig
        make menuconfig
        ;;
    dtb)
        # goal is relative to arch/arm64/boot/dts (see %.dtb rule in top Makefile)
        make rockchip/rk3399-odroid-n1.dtb
        ;;
    modules)
        make -j"$JOBS" modules
        ;;
    boot)
        build_boot_scr
        ;;
    clean)
        make clean
        ;;
    distclean)
        make distclean
        ;;
    build)
        [ -f .config ] || make odroidn1_defconfig
        make -j"$JOBS" Image rockchip/rk3399-odroid-n1.dtb modules
        build_boot_scr
        ;;
    *)
        echo "unknown target: $target (see header of this script)" >&2
        exit 1
        ;;
esac
