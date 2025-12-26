#!/bin/bash
# copy-app installer
# Usage: curl -fsSL https://raw.githubusercontent.com/JordanCoin/copy-app/main/install.sh | bash

set -e

REPO="JordanCoin/copy-app"
INSTALL_DIR="/usr/local/bin"
SCRIPT_NAME="copy-app"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

info() { echo -e "${GREEN}==>${NC} $1"; }
warn() { echo -e "${YELLOW}==>${NC} $1"; }
error() { echo -e "${RED}==>${NC} $1"; exit 1; }

# Check macOS
if [[ "$(uname)" != "Darwin" ]]; then
    error "copy-app only works on macOS"
fi

# Check for Xcode Command Line Tools
if ! xcode-select -p &>/dev/null; then
    warn "Xcode Command Line Tools not found. Installing..."
    xcode-select --install
    echo "Please run this installer again after Xcode tools are installed."
    exit 1
fi

info "Installing copy-app..."

# Download the script
TEMP_DIR=$(mktemp -d)
trap "rm -rf $TEMP_DIR" EXIT

curl -fsSL "https://raw.githubusercontent.com/${REPO}/main/copy-app.sh" -o "$TEMP_DIR/copy-app"
chmod +x "$TEMP_DIR/copy-app"

# Install to /usr/local/bin (may need sudo)
if [[ -w "$INSTALL_DIR" ]]; then
    mv "$TEMP_DIR/copy-app" "$INSTALL_DIR/$SCRIPT_NAME"
else
    info "Installing to $INSTALL_DIR (requires sudo)..."
    sudo mv "$TEMP_DIR/copy-app" "$INSTALL_DIR/$SCRIPT_NAME"
fi

info "Installed successfully!"
echo ""
echo "Usage:"
echo "  copy-app Safari           # Capture Safari window"
echo "  copy-app Terminal -t log  # Capture Terminal with 'log' in title"
echo ""
warn "Note: Grant Accessibility permission to your terminal on first run."
echo "      System Settings → Privacy & Security → Accessibility"
