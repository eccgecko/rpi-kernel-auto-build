#!/usr/bin/env bash
#
# build-kernel.sh
#
# Natively builds the Raspberry Pi kernel and produces .deb packages.
# Intended to run on an arm64 runner.
#
# Usage: build-kernel.sh <commit-sha> [output-dir]
#
set -euo pipefail

COMMIT_SHA="${1:?Usage: build-kernel.sh <commit-sha> [output-dir]}"
OUTPUT_DIR="${2:-$(pwd)/output}"
REPO="raspberrypi/linux"
ARCH="arm64"

mkdir -p "$OUTPUT_DIR"

echo "==> Shallow-cloning raspberrypi/linux at ${COMMIT_SHA}..."
WORK_DIR=$(mktemp -d)
git clone --depth 1 "https://github.com/${REPO}.git" "$WORK_DIR/linux"
cd "$WORK_DIR/linux"
git fetch --depth 1 origin "$COMMIT_SHA"
git checkout "$COMMIT_SHA"

echo "==> Configuring kernel (bcm2712_defconfig)..."
make ARCH=$ARCH bcm2712_defconfig

echo "==> Building kernel .deb packages..."
KVER=$(make -s kernelversion)
COMMIT_TS=$(git log -1 --format=%ct)
KDEB_PKGVERSION="${KVER}-1.${COMMIT_TS}"

make ARCH=$ARCH \
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
