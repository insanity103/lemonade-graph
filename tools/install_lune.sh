#!/usr/bin/env bash
# tools/install_lune.sh | Install the pinned Lune (standalone Luau runtime) that runs tests/.
#
#   tools/install_lune.sh                 # installs to ~/.local/bin/lune
#   LUNE_INSTALL_DIR=/usr/local/bin tools/install_lune.sh
#
# The version and the SHA-256 of each release zip are pinned here, so CI and every machine run the
# same binary and a tampered download fails loudly. To upgrade: bump LUNE_VERSION, download the new
# zips from https://github.com/lune-org/lune/releases, and replace the checksums below
# (`sha256sum lune-<ver>-<platform>.zip`). Rokit users can instead `rokit install` (rokit.toml pins
# the same version). Idempotent: an installed binary of the right version is left alone.
set -euo pipefail

LUNE_VERSION="0.10.5"
INSTALL_DIR="${LUNE_INSTALL_DIR:-$HOME/.local/bin}"

case "$(uname -s)-$(uname -m)" in
	Linux-x86_64)  PLATFORM="linux-x86_64";  SHA256="1fb5dee6a1afa1d300092805c6e660fe06144d29dd68c45cf6956f040667f791" ;;
	Linux-aarch64) PLATFORM="linux-aarch64"; SHA256="176e1272d41ba3d9ea30087b528048a4a97e3d74cfa0eaa5d35d9e0d4122caa6" ;;
	Darwin-arm64)  PLATFORM="macos-aarch64"; SHA256="bdb94f47bc1d3af3e3fe796cfce9c7f406042d4aada9cc41a1c53836f3e3b411" ;;
	Darwin-x86_64) PLATFORM="macos-x86_64";  SHA256="f4b43cfd495994b7ef783ac2bb0aa24f1f940f3804b28018121bb3cc2171c1a7" ;;
	*) echo "install_lune: unsupported platform $(uname -s)-$(uname -m)" >&2; exit 1 ;;
esac

if [ -x "$INSTALL_DIR/lune" ] && "$INSTALL_DIR/lune" --version 2>/dev/null | grep -q " $LUNE_VERSION\$"; then
	echo "lune $LUNE_VERSION already installed at $INSTALL_DIR/lune"
	exit 0
fi

url="https://github.com/lune-org/lune/releases/download/v${LUNE_VERSION}/lune-${LUNE_VERSION}-${PLATFORM}.zip"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
echo "Downloading $url"
curl -fsSL --retry 3 -o "$tmp/lune.zip" "$url"

if [ -n "$SHA256" ]; then
	actual="$( (sha256sum "$tmp/lune.zip" 2>/dev/null || shasum -a 256 "$tmp/lune.zip") | cut -d" " -f1)"
	[ "$actual" = "$SHA256" ] \
		|| { echo "install_lune: checksum mismatch for $url" >&2; exit 1; }
else
	echo "install_lune: no pinned checksum for $PLATFORM; add one to this script" >&2
fi

if command -v unzip >/dev/null 2>&1; then
	unzip -q -o "$tmp/lune.zip" -d "$tmp"
else
	python3 -c 'import sys, zipfile; zipfile.ZipFile(sys.argv[1]).extractall(sys.argv[2])' "$tmp/lune.zip" "$tmp"
fi
mkdir -p "$INSTALL_DIR"
install -m 0755 "$tmp/lune" "$INSTALL_DIR/lune"
echo "Installed $("$INSTALL_DIR/lune" --version) to $INSTALL_DIR/lune"
case ":$PATH:" in *":$INSTALL_DIR:"*) ;; *) echo "Note: $INSTALL_DIR is not on PATH (tests/run.sh finds it anyway)";; esac
