#!/bin/sh
set -e

DIR="$HOME/.lpm"
REPO="codebycruz/lpm"

OS="$(uname -s)"
ARCH="$(uname -m)"

case "$OS-$ARCH" in
    Linux-x86_64)          BIN="lpm-linux-x86-64" ;;
    Linux-aarch64)         BIN="lpm-linux-aarch64" ;;
    Darwin-x86_64)         BIN="lpm-macos-x86-64" ;;
    Darwin-arm64)          BIN="lpm-macos-aarch64" ;;
    *) echo "Unsupported platform: $OS $ARCH"; exit 1 ;;
esac

TAG=$(curl -sf "https://api.github.com/repos/$REPO/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')

mkdir -p "$DIR"
curl -fL "https://github.com/$REPO/releases/download/$TAG/$BIN" -o "$DIR/lpm"
chmod +x "$DIR/lpm" && "$DIR/lpm" --setup
