#!/usr/bin/env bash
#
# build-kernel.sh
#
# Cross-compiles the Raspberry Pi kernel for arm64 and produces .deb packages.
#
# Usage: build-kernel.sh <commit-sha> [output-dir]
#
set -euo pipefail

COMMIT_SHA="${1:?Usage: build-kernel.sh <commit-sha> [output-dir]}"
OUTPUT_DIR="${2:-$(pwd)/output}"
REPO="raspberrypi/linux"
ARCH="arm64"
CROSS_COMPILE="aarch64-linux-gnu-"

mkdir -p "$OUTPUT_DIR"

echo "==> Shallow-cloning raspberrypi/linux at ${COMMIT_SHA}..."
WORK_DIR=$(mktemp -d)
git clone --depth 1 "https://github.com/${REPO}.git" "$WORK_DIR/linux"
cd "$WORK_DIR/linux"
git fetch --depth 1 origin "$COMMIT_SHA"
git checkout "$COMMIT_SHA"

echo "==> Configuring kernel (bcm2712_defconfig)..."
make ARCH=$ARCH CROSS_COMPILE=$CROSS_COMPILE bcm2712_defconfig

echo "==> Building kernel .deb packages..."
KVER=$(make -s kernelversion)
COMMIT_TS=$(git log -1 --format=%ct)
KDEB_PKGVERSION="${KVER}-1.${COMMIT_TS}"

make ARCH=$ARCH \
     CROSS_COMPILE=$CROSS_COMPILE \
     LOCALVERSION=-rpi \
     KDEB_PKGVERSION="$KDEB_PKGVERSION" \
     bindeb-pkg \
     -j"$(nproc)"

echo "==> Collecting .deb packages..."
mv "$WORK_DIR"/*.deb "$OUTPUT_DIR/"

echo "==> Build complete. Packages in ${OUTPUT_DIR}:"
ls -lh "$OUTPUT_DIR"/*.deb

echo "==> Cleaning up work directory..."
rm -rf "$WORK_DIR"
