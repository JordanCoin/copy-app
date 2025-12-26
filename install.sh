#!/bin/bash
# copy-app installer
# Usage: curl -fsSL https://raw.githubusercontent.com/JordanCoin/copy-app/main/install.sh | bash

set -e

REPO="JordanCoin/copy-app"
INSTALL_DIR="$HOME/.local/bin"
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

TEMP_DIR=$(mktemp -d)
trap "rm -rf $TEMP_DIR" EXIT

# Determine architecture
ARCH=$(uname -m)

# Try downloading pre-built binary from latest release
RELEASE_URL="https://github.com/${REPO}/releases/latest/download/copy-app-${ARCH}"
if curl -fsSL "$RELEASE_URL" -o "$TEMP_DIR/copy-app" 2>/dev/null; then
    info "Downloaded pre-built binary for ${ARCH}"
    chmod +x "$TEMP_DIR/copy-app"
else
    # Fall back to building from source
    info "Building from source..."
    git clone --depth 1 "https://github.com/${REPO}.git" "$TEMP_DIR/repo"
    cd "$TEMP_DIR/repo"
    swift build -c release
    cp .build/release/copy-app "$TEMP_DIR/copy-app"
    cd - >/dev/null
fi

# Install to ~/.local/bin
mkdir -p "$INSTALL_DIR"
mv "$TEMP_DIR/copy-app" "$INSTALL_DIR/$SCRIPT_NAME"

# Check if ~/.local/bin is in PATH
if [[ ":$PATH:" != *":$INSTALL_DIR:"* ]]; then
    warn "Add ~/.local/bin to your PATH:"
    echo "  echo 'export PATH=\"\$HOME/.local/bin:\$PATH\"' >> ~/.zshrc"
    echo "  source ~/.zshrc"
    echo ""
fi

info "Installed successfully!"
echo ""
echo "Usage:"
echo "  copy-app Safari           # Capture Safari window"
echo "  copy-app Terminal -t log  # Capture Terminal with 'log' in title"
echo ""
warn "Note: Grant Accessibility permission to your terminal on first run."
echo "      System Settings → Privacy & Security → Accessibility"
echo ""

# Ask about Claude Code hook (only if interactive)
if [[ -t 0 ]]; then
    read -p "$(echo -e "${GREEN}==>${NC} Set up Claude Code integration? [y/N] ")" -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        "$INSTALL_DIR/$SCRIPT_NAME" --install-hook
    fi
else
    echo "For Claude Code integration:"
    echo "  copy-app --install-hook"
fi
