#!/bin/bash

set -e

REPO="codebycruz/lpm"
LPM_DIR="$HOME/.lpm"
BINARY_NAME="lpm"
ARTIFACT="lpm-linux-x86-64"

echo "Installing lpm..."

# Create .lpm directory if it doesn't exist
mkdir -p "$LPM_DIR"

# Get latest release tag
echo "Fetching latest release..."
TAG=$(curl -s "https://api.github.com/repos/$REPO/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')

if [ -z "$TAG" ]; then
    echo "Error: Could not fetch latest release"
    exit 1
fi

echo "Latest version: $TAG"

# Download binary
DOWNLOAD_URL="https://github.com/$REPO/releases/download/$TAG/$ARTIFACT"
echo "Downloading $ARTIFACT..."
TMP_FILE="/tmp/$ARTIFACT"
curl -L -o "$TMP_FILE" "$DOWNLOAD_URL"

# Install
chmod +x "$TMP_FILE"
echo "Installing to $LPM_DIR/$BINARY_NAME..."
mv "$TMP_FILE" "$LPM_DIR/$BINARY_NAME"

# Add to PATH if not already there
add_to_path() {
    local shell_rc="$1"
    local path_line="export PATH=\"\$HOME/.lpm:\$PATH\""

    if [ -f "$shell_rc" ]; then
        if ! grep -q "\.lpm" "$shell_rc"; then
            echo "" >> "$shell_rc"
            echo "# Added by lpm installer" >> "$shell_rc"
            echo "$path_line" >> "$shell_rc"
            echo "Added $LPM_DIR to PATH in $shell_rc"
            return 0
        else
            echo "$LPM_DIR already in PATH in $shell_rc"
            return 1
        fi
    fi
    return 1
}

# Try to add to shell configuration files
PATH_ADDED=false

if [ -n "$ZSH_VERSION" ] || [ -f "$HOME/.zshrc" ]; then
    if add_to_path "$HOME/.zshrc"; then
        PATH_ADDED=true
    fi
elif [ -n "$BASH_VERSION" ] || [ -f "$HOME/.bashrc" ]; then
    if add_to_path "$HOME/.bashrc"; then
        PATH_ADDED=true
    fi
fi

# Fallback to .profile
if [ "$PATH_ADDED" = false ]; then
    if add_to_path "$HOME/.profile"; then
        PATH_ADDED=true
    fi
fi

echo ""
echo "Installation complete!"
echo ""
echo "lpm has been installed to: $LPM_DIR/$BINARY_NAME"

if [ "$PATH_ADDED" = true ]; then
    echo "PATH has been updated. Please restart your shell or run:"
    echo "  source ~/.bashrc  # or ~/.zshrc or ~/.profile"
    echo ""
    echo "Then run 'lpm' to get started."
else
    echo "Could not automatically add to PATH. Please add the following to your shell configuration:"
    echo "  export PATH=\"\$HOME/.lpm:\$PATH\""
    echo ""
    echo "Or run lpm directly: $LPM_DIR/$BINARY_NAME"
fi
