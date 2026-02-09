# rpi-kernel-auto-build

Automated Raspberry Pi 5 kernel builds with headers for DKMS module compilation.

Built from the [`rpi-6.18.y`](https://github.com/raspberrypi/linux/tree/rpi-6.18.y) branch of `raspberrypi/linux`, using only CI-verified commits.

## Why?

The official `rpi-update --next` path installs bleeding-edge kernels but **does not provide kernel headers**. Without headers, DKMS modules (e.g. out-of-tree drivers) cannot be compiled. This project solves that by building both `linux-image` and `linux-headers` as `.deb` packages and publishing them via an apt repository.

## Install (Raspberry Pi 5)

```bash
# Add the signing key
curl -fsSL https://eccgecko.github.io/rpi-kernel-auto-build/KEY.gpg \
  | sudo gpg --dearmor -o /usr/share/keyrings/rpi-kernel-auto-build.gpg

# Add the repository
echo "deb [arch=arm64 signed-by=/usr/share/keyrings/rpi-kernel-auto-build.gpg] \
  https://eccgecko.github.io/rpi-kernel-auto-build stable main" \
  | sudo tee /etc/apt/sources.list.d/rpi-kernel-auto-build.list

# Install the kernel and headers
sudo apt update
sudo apt install linux-image-*-rpi linux-headers-*-rpi

# Reboot into the new kernel
sudo reboot
```

After rebooting, verify with:
```bash
uname -r
```

## How it works

1. **Weekly check** (Monday 06:00 UTC) or manual trigger via GitHub Actions
2. Fetches the latest 20 commits on `raspberrypi/linux` `rpi-6.18.y`
3. Finds the newest commit where **all** CI check-runs have passed
4. Compares against the latest GitHub Release to avoid duplicate builds
5. Cross-compiles the kernel for `arm64` with `bcm2712_defconfig` (Pi 5)
6. Produces `linux-image`, `linux-headers`, and `linux-libc-dev` `.deb` packages
7. Creates a GitHub Release with the `.deb` files attached
8. Updates the GitHub Pages apt repository with GPG-signed indexes

## Version scheme

Packages use the format `<kernel-version>-1.<commit-timestamp>`, e.g. `6.18.9-1.1738836546`. This ensures apt correctly sorts newer builds higher.

## Manual download

`.deb` files are also available on the [Releases](https://github.com/eccgecko/rpi-kernel-auto-build/releases) page. Install manually with:

```bash
sudo dpkg -i linux-image-*.deb linux-headers-*.deb
sudo reboot
```

## One-time setup (for maintainers)

### 1. Generate a GPG key pair

```bash
gpg --batch --gen-key <<EOF
%no-protection
Key-Type: EDDSA
Key-Curve: ed25519
Name-Real: rpi-kernel-auto-build
Name-Email: noreply@eccgecko.github.io
Expire-Date: 0
%commit
EOF
```

### 2. Export and store the private key as a repository secret

```bash
gpg --armor --export-secret-keys noreply@eccgecko.github.io
```

Copy the output and add it as `GPG_PRIVATE_KEY` in **Settings > Secrets and variables > Actions**.

### 3. Enable GitHub Pages

Go to **Settings > Pages** and set the source to the `gh-pages` branch.

### 4. Trigger the first build

Go to **Actions > Build Raspberry Pi Kernel > Run workflow** and click **Run workflow**.

## License

The kernel is licensed under the [GPLv2](https://www.gnu.org/licenses/old-licenses/gpl-2.0.html). Build scripts and workflow configuration in this repository are provided as-is.
