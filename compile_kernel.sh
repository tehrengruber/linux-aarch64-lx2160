#!/bin/bash
# Build linux-aarch64-lx2160 package inside a Podman container.
# On x86_64 hosts, QEMU user-mode emulation (binfmt_misc) is used.
# On native aarch64, emulation is skipped automatically.
#
# Prerequisites (x86_64 only):
#   sudo pacman -S podman qemu-user-static qemu-user-static-binfmt
#   sudo systemctl restart systemd-binfmt

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

KEEP_ON_FAIL=false
SRC_CACHE_DIR="$SCRIPT_DIR/src"
while [[ "${1:-}" ]]; do
    case "$1" in
        --keep-on-fail) KEEP_ON_FAIL=true ;;
        --src-cache-dir) SRC_CACHE_DIR="$2"; shift ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
    shift
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_IMAGE="archlinuxarm-lx2160-build"
ALARM_TARBALL="$SCRIPT_DIR/ArchLinuxARM-aarch64-latest.tar.gz"
ALARM_URL="http://os.archlinuxarm.org/os/ArchLinuxARM-aarch64-latest.tar.gz"

# Source URLs and branches from PKGBUILD
eval "$(grep -E '^(_pkgver|_linux_url|_lx2160a_url|_lx2160a_branch)=' "$SCRIPT_DIR/PKGBUILD")"
LINUX_URL="$_linux_url"
LINUX_BRANCH="$_pkgver"
LX2160A_URL="$_lx2160a_url"
LX2160A_BRANCH="$_lx2160a_branch"

LINUX_SRC="$SRC_CACHE_DIR/src/linux"
LX2160A_SRC="$SRC_CACHE_DIR/src/lx2160a_build"

# ---------------------------------------------------------------------------
# Checks
# ---------------------------------------------------------------------------

if ! command -v podman &>/dev/null; then
    echo "ERROR: podman not found. Install it with: sudo pacman -S podman"
    exit 1
fi

if [[ "$(uname -m)" == "aarch64" ]]; then
    echo "Native aarch64 host detected, no emulation needed."
else
    if [ ! -f /proc/sys/fs/binfmt_misc/qemu-aarch64 ] && \
       ! podman run --rm --platform linux/arm64 --quiet alpine:latest uname -m 2>/dev/null | grep -q aarch64; then
        echo "ERROR: aarch64 QEMU user-mode emulation not available."
        echo "  sudo pacman -S qemu-user-static qemu-user-static-binfmt"
        echo "  sudo systemctl restart systemd-binfmt"
        exit 1
    fi
    echo "aarch64 emulation: OK"
fi

# ---------------------------------------------------------------------------
# Download Arch Linux ARM rootfs tarball (referenced by Containerfile ADD)
# ---------------------------------------------------------------------------

if [ ! -f "$ALARM_TARBALL" ]; then
    echo "Downloading Arch Linux ARM aarch64 rootfs..."
    wget -O "$ALARM_TARBALL" "$ALARM_URL"
else
    echo "Arch Linux ARM tarball already present, skipping download."
fi

# ---------------------------------------------------------------------------
# Clone sources on host (overlayfs-mounted into the build; PKGBUILD skips
# cloning when the directories already exist)
# ---------------------------------------------------------------------------

mkdir -p "$SRC_CACHE_DIR"

if [ ! -d "$LINUX_SRC" ]; then
    echo "Cloning linux kernel..."
    git clone --depth 1 -b "$LINUX_BRANCH" "$LINUX_URL" "$LINUX_SRC"
else
    echo "Linux source already present, skipping clone."
fi

if [ ! -d "$LX2160A_SRC" ]; then
    echo "Cloning lx2160a_build..."
    git clone --depth 1 -b "$LX2160A_BRANCH" "$LX2160A_URL" "$LX2160A_SRC"
else
    echo "lx2160a_build already present, skipping clone."
fi

# ---------------------------------------------------------------------------
# Build image and export packages
# ---------------------------------------------------------------------------

echo ""
echo "Building kernel inside aarch64 container (layers are cached after first run)..."
podman build \
    --platform linux/arm64 \
    --tag "$BUILD_IMAGE" \
    --build-arg "KEEP_ON_FAIL=$KEEP_ON_FAIL" \
    -v "$LINUX_SRC:/build/src/linux:O" \
    -v "$LX2160A_SRC:/build/src/lx2160a_build:O" \
    "$SCRIPT_DIR"

echo ""
echo "To enter the build container interactively:"
echo "  podman run --rm -it --platform linux/arm64 \\"
echo "    -v $LINUX_SRC:/build/src/linux:O \\"
echo "    -v $LX2160A_SRC:/build/src/lx2160a_build:O \\"
echo "    $BUILD_IMAGE /bin/bash"

echo ""
echo "Exporting packages..."
TMP_CONTAINER=$(podman create --platform linux/arm64 "$BUILD_IMAGE")
podman cp "$TMP_CONTAINER:/build/." "$SCRIPT_DIR/"
podman rm "$TMP_CONTAINER"

echo ""
echo "Build complete. Packages:"
ls -lh "$SCRIPT_DIR"/*.pkg.tar.* 2>/dev/null || echo "(no .pkg.tar.* files found in $SCRIPT_DIR)"