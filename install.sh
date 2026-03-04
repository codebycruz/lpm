#!/bin/sh

set -e

REPO="codebycruz/lpm"
LPM_DIR="$HOME/.lpm"

case "$(uname -m)" in
    x86_64)   ARTIFACT="lpm-linux-x86-64" ;;
    aarch64|arm64) ARTIFACT="lpm-linux-aarch64" ;;
    *) echo "Error: Unsupported architecture: $(uname -m)"; exit 1 ;;
esac

TAG=$(curl -sf "https://api.github.com/repos/$REPO/releases/latest" \
    | grep '"tag_name":' \
    | sed -E 's/.*"([^"]+)".*/\1/') \
    || { echo "Error: Could not fetch latest release"; exit 1; }

mkdir -p "$LPM_DIR"
curl -fL "https://github.com/$REPO/releases/download/$TAG/$ARTIFACT" -o "$LPM_DIR/lpm"
chmod +x "$LPM_DIR/lpm"

"$LPM_DIR/lpm" --setup
