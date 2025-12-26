# copy-app

Capture any macOS application window to your clipboard with a single command. No clicking, no dragging, no window switching.

```bash
copy-app Safari
```

**Before:** Your cluttered desktop
![Before](assets/before.png)

**After:** Just the window you need, on your clipboard
![After](assets/example.png)

The window is captured directly from its compositing layer - even if it's hidden behind other windows.

## Installation

### Homebrew (recommended)

```bash
brew tap JordanCoin/tap
brew install copy-app
```

### Quick Install

```bash
curl -fsSL https://raw.githubusercontent.com/JordanCoin/copy-app/main/install.sh | bash
```

### Manual

```bash
git clone https://github.com/JordanCoin/copy-app.git
cd copy-app
./install.sh
```

> **First run:** Grant Accessibility permission to your terminal, then restart it.
> System Settings → Privacy & Security → Accessibility → add your terminal app
>
> ![Accessibility settings](assets/accessibility.png)

## Usage

```bash
# Capture an app's frontmost window
copy-app Writer
copy-app Safari
copy-app Finder

# Filter by window title
copy-app Terminal -t "server-log"
copy-app Safari -t "GitHub"
```

## Auto-Save Screenshots

By default, screenshots are only copied to clipboard. To also save them to disk:

```bash
copy-app --save on    # Enable auto-save
copy-app --save off   # Disable (clipboard only)
copy-app --save       # Show current status
```

Screenshots are organized by app: `~/copyMac/screenshots/<AppName>/AppName_2024-01-15_14-30-45.png`

## Requirements

- **macOS 12+** (Monterey or later)
- **Xcode Command Line Tools** - for compiling the Swift helper on first run
  ```bash
  xcode-select --install
  ```

## How It Works

1. A Swift helper queries `CGWindowListCopyWindowInfo` to find the window ID by app name
2. `screencapture -l <windowid>` captures the window's composited image directly
3. The image is copied to clipboard (and optionally saved to disk)

This captures the actual window content regardless of what's on top of it - no need to bring the window to front.

## Troubleshooting

**"No capturable window found"**
- Make sure the app is running and has at least one open window
- Check the exact app name (use `copy-app "Google Chrome"` for Chrome)

**"Failed to compile helper"**
- Install Xcode Command Line Tools: `xcode-select --install`

**Permission errors**
- Grant Accessibility permission to your terminal app
- Fully quit and restart your terminal after granting permission

## Claude Code Integration

Automatically screenshot apps when Claude launches them via [XcodeBuildMCP](https://github.com/cameroncooke/XcodeBuildMCP):

```bash
copy-app --install-hook    # Set up hook
copy-app --uninstall-hook  # Remove hook
```

This sets up a Claude Code hook so when xcodebuildmcp launches your app, copy-app captures a screenshot and Claude can view it with the Read tool.

Screenshots are organized by app: `~/copyMac/screenshots/<AppName>/`.

## License

MIT
