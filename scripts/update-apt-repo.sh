#!/usr/bin/env bash
#
# update-apt-repo.sh
#
# Rebuilds the apt repository indexes and signs them with GPG.
#
# Usage: update-apt-repo.sh <deb-dir> <repo-root> [builds-to-keep]
#
# Expects GPG key to already be imported into the current keyring.
#
set -euo pipefail

DEB_DIR="${1:?Usage: update-apt-repo.sh <deb-dir> <repo-root> [builds-to-keep]}"
REPO_ROOT="${2:?Usage: update-apt-repo.sh <deb-dir> <repo-root> [builds-to-keep]}"
KEEP_BUILDS="${3:-3}"

POOL_DIR="${REPO_ROOT}/pool/main"
DIST_DIR="${REPO_ROOT}/dists/stable"
BINARY_DIR="${DIST_DIR}/main/binary-arm64"

mkdir -p "$POOL_DIR" "$BINARY_DIR"

# Copy new .deb files into pool
echo "==> Copying new .deb files to pool..."
cp "$DEB_DIR"/*.deb "$POOL_DIR/"

# Enforce retention: keep only the last N builds
# Group by package name prefix (linux-image, linux-headers, linux-libc-dev),
# sort by version embedded in filename, remove oldest beyond KEEP_BUILDS
echo "==> Enforcing retention (keeping last ${KEEP_BUILDS} builds)..."
for prefix in linux-image linux-headers linux-libc-dev; do
    # shellcheck disable=SC2012
    files=$(ls -1t "$POOL_DIR"/${prefix}_*.deb 2>/dev/null || true)
    count=0
    while IFS= read -r f; do
        [[ -z "$f" ]] && continue
        count=$((count + 1))
        if [[ $count -gt $KEEP_BUILDS ]]; then
            echo "    Removing old package: $(basename "$f")"
            rm -f "$f"
        fi
    done <<< "$files"
done

# Generate Packages index
echo "==> Generating Packages index..."
cd "$REPO_ROOT"
dpkg-scanpackages --arch arm64 pool/ > "$BINARY_DIR/Packages"
gzip -9fk "$BINARY_DIR/Packages"

# Generate Release file
echo "==> Generating Release file..."
cat > "${DIST_DIR}/release.conf" << CONF
APT::FTPArchive::Release::Origin "rpi-kernel-auto-build";
APT::FTPArchive::Release::Label "Raspberry Pi Kernel Auto-Build";
APT::FTPArchive::Release::Suite "stable";
APT::FTPArchive::Release::Codename "stable";
APT::FTPArchive::Release::Architectures "arm64";
APT::FTPArchive::Release::Components "main";
CONF

apt-ftparchive -c "${DIST_DIR}/release.conf" release "$DIST_DIR" > "${DIST_DIR}/Release.tmp"
mv "${DIST_DIR}/Release.tmp" "${DIST_DIR}/Release"
rm -f "${DIST_DIR}/release.conf"

# GPG sign
echo "==> Signing Release..."
GPG_KEY_ID=$(gpg --list-secret-keys --keyid-format long 2>/dev/null \
    | grep -m1 '^sec' | awk '{print $2}' | cut -d'/' -f2)

if [[ -z "$GPG_KEY_ID" ]]; then
    echo "ERROR: No GPG secret key found in keyring" >&2
    exit 1
fi

gpg --default-key "$GPG_KEY_ID" --armor --detach-sign --output "${DIST_DIR}/Release.gpg" "${DIST_DIR}/Release"
gpg --default-key "$GPG_KEY_ID" --armor --clearsign --output "${DIST_DIR}/InRelease" "${DIST_DIR}/Release"

# Export public key
echo "==> Exporting public key..."
gpg --armor --export "$GPG_KEY_ID" > "${REPO_ROOT}/KEY.gpg"

echo "==> Apt repository updated successfully."
