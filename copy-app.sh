#!/bin/bash
# copy-app - Capture a window screenshot to clipboard (and optionally save to disk)
#
# PERMISSIONS REQUIRED:
#   - Accessibility: System Settings → Privacy & Security → Accessibility
#   Permission must be granted to the terminal app executing this script
#   (e.g., Terminal.app, iTerm.app, Warp, etc.)

CONFIG_FILE="$HOME/.config/copy-app/config"
HELPER_DIR="$HOME/.local/share/copy-app"
HELPER_BIN="$HELPER_DIR/getwindowid"
SAVE_DIR=""
APP_NAME=""
TITLE_FILTER=""

# Preserve env var if set, then load config
ENV_SAVE_DIR="$SAVE_DIR"
if [[ -f "$CONFIG_FILE" ]]; then
    source "$CONFIG_FILE"
fi
# Environment variable takes precedence over config
[[ -n "$ENV_SAVE_DIR" ]] && SAVE_DIR="$ENV_SAVE_DIR"

install_hook() {
    local HOOK_DIR="$HOME/.claude/hooks"
    local HOOK_FILE="$HOOK_DIR/screenshot-app.sh"
    local SETTINGS="$HOME/.claude/settings.json"
    local SCREENSHOT_DIR="$HOME/copyMac/screenshots"

    mkdir -p "$HOOK_DIR" "$SCREENSHOT_DIR"

    # Create hook script
    cat > "$HOOK_FILE" << 'HOOKSCRIPT'
#!/bin/bash
COPY_APP=$(command -v copy-app 2>/dev/null)
[[ -z "$COPY_APP" ]] && exit 0
SCREENSHOT_DIR="$HOME/copyMac/screenshots"
INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty')
APP_NAME=""
case "$TOOL_NAME" in
    mcp__xcodebuildmcp__launch_mac_app)
        APP_PATH=$(echo "$INPUT" | jq -r '.tool_input.appPath // empty')
        [[ -n "$APP_PATH" ]] && APP_NAME=$(basename "$APP_PATH" .app);;
    mcp__xcodebuildmcp__build_run_macos|mcp__xcodebuildmcp__build_run_sim)
        # Look for "App launched: /path/to/App.app" in the response
        APP_PATH=$(echo "$INPUT" | jq -r '.tool_response | tostring' 2>/dev/null | grep -oE 'App launched: [^"]+\.app' | sed 's/App launched: //' | xargs basename 2>/dev/null | sed 's/\.app$//')
        [[ -n "$APP_PATH" ]] && APP_NAME="$APP_PATH";;
esac
[[ -z "$APP_NAME" ]] && exit 0
APP_DIR="$SCREENSHOT_DIR/$APP_NAME"
mkdir -p "$APP_DIR"
sleep 1.5
SAVE_DIR="$APP_DIR" "$COPY_APP" "$APP_NAME" >/dev/null 2>&1
LATEST=$(ls -t "$APP_DIR"/*.png 2>/dev/null | head -1)
[[ -n "$LATEST" && -f "$LATEST" ]] && echo "{\"hookSpecificOutput\":{\"hookEventName\":\"PostToolUse\",\"additionalContext\":\"📸 Screenshot: $LATEST\"}}"
exit 0
HOOKSCRIPT
    chmod +x "$HOOK_FILE"

    # Set up config for auto-save
    mkdir -p "$HOME/.config/copy-app"
    echo "SAVE_DIR=$SCREENSHOT_DIR" > "$HOME/.config/copy-app/config"

    # Add hook to settings.json if not already present
    if [[ -f "$SETTINGS" ]] && command -v jq &>/dev/null; then
        if ! grep -q "screenshot-app.sh" "$SETTINGS"; then
            local HOOK_ENTRY='{"matcher":"mcp__xcodebuildmcp__launch_mac_app|mcp__xcodebuildmcp__build_run_macos|mcp__xcodebuildmcp__build_run_sim","hooks":[{"type":"command","command":"bash ~/.claude/hooks/screenshot-app.sh"}]}'
            jq ".hooks.PostToolUse += [$HOOK_ENTRY]" "$SETTINGS" > "$SETTINGS.tmp" && mv "$SETTINGS.tmp" "$SETTINGS"
            echo "✓ Hook added to settings.json"
        else
            echo "✓ Hook already configured in settings.json"
        fi
    elif [[ ! -f "$SETTINGS" ]]; then
        echo "⚠️  Create ~/.claude/settings.json with the hook config (see README)"
    fi

    echo "✓ Hook installed: $HOOK_FILE"
    echo "✓ Screenshots will save to: $SCREENSHOT_DIR"
}

uninstall_hook() {
    local HOOK_FILE="$HOME/.claude/hooks/screenshot-app.sh"
    local CONFIG_FILE="$HOME/.config/copy-app/config"
    local SETTINGS="$HOME/.claude/settings.json"

    if [[ -f "$HOOK_FILE" ]]; then
        rm "$HOOK_FILE"
        echo "✓ Hook removed: $HOOK_FILE"
    else
        echo "Hook not found: $HOOK_FILE"
    fi

    if [[ -f "$CONFIG_FILE" ]]; then
        rm "$CONFIG_FILE"
        echo "✓ Config removed: $CONFIG_FILE"
    fi

    # Remove hook entry from settings.json
    if [[ -f "$SETTINGS" ]] && command -v jq &>/dev/null; then
        if grep -q "screenshot-app.sh" "$SETTINGS"; then
            jq 'del(.hooks.PostToolUse[] | select(.hooks[]?.command | contains("screenshot-app.sh")))' "$SETTINGS" > "$SETTINGS.tmp" && mv "$SETTINGS.tmp" "$SETTINGS"
            echo "✓ Hook entry removed from settings.json"
        fi
    fi
}

full_uninstall() {
    echo "Uninstalling copy-app..."

    # Remove hook and settings entry
    local HOOK_FILE="$HOME/.claude/hooks/screenshot-app.sh"
    local SETTINGS="$HOME/.claude/settings.json"

    if [[ -f "$HOOK_FILE" ]]; then
        rm "$HOOK_FILE"
        echo "✓ Hook removed"
    fi

    if [[ -f "$SETTINGS" ]] && command -v jq &>/dev/null && grep -q "screenshot-app.sh" "$SETTINGS"; then
        jq 'del(.hooks.PostToolUse[] | select(.hooks[]?.command | contains("screenshot-app.sh")))' "$SETTINGS" > "$SETTINGS.tmp" && mv "$SETTINGS.tmp" "$SETTINGS"
        echo "✓ Hook entry removed from settings.json"
    fi

    # Remove config
    if [[ -d "$HOME/.config/copy-app" ]]; then
        rm -rf "$HOME/.config/copy-app"
        echo "✓ Config removed"
    fi

    # Remove Swift helper
    if [[ -d "$HOME/.local/share/copy-app" ]]; then
        rm -rf "$HOME/.local/share/copy-app"
        echo "✓ Swift helper removed"
    fi

    # Remove binary
    local SELF_PATH="$(command -v copy-app 2>/dev/null)"
    if [[ -n "$SELF_PATH" && -f "$SELF_PATH" ]]; then
        rm "$SELF_PATH"
        echo "✓ Binary removed: $SELF_PATH"
    fi

    echo ""
    echo "copy-app uninstalled. Screenshots in ~/copyMac/screenshots were kept."
}

save_toggle() {
    local CONFIG_DIR="$HOME/.config/copy-app"
    local CONFIG_FILE="$CONFIG_DIR/config"
    local SAVE_DIR="$HOME/copyMac/screenshots"

    case "$1" in
        on)
            mkdir -p "$CONFIG_DIR"
            echo "SAVE_DIR=$SAVE_DIR" > "$CONFIG_FILE"
            echo "✓ Auto-save enabled: $SAVE_DIR"
            ;;
        off)
            if [[ -f "$CONFIG_FILE" ]]; then
                rm "$CONFIG_FILE"
                echo "✓ Auto-save disabled (clipboard only)"
            else
                echo "Auto-save is already disabled"
            fi
            ;;
        *)
            if [[ -f "$CONFIG_FILE" ]]; then
                echo "Auto-save: ON ($SAVE_DIR)"
            else
                echo "Auto-save: OFF (clipboard only)"
            fi
            ;;
    esac
}

show_help() {
    cat << 'HELP'
Description:
  Capture a specific application window to the clipboard.
  Optionally saves screenshots to disk.

Usage:
  copy-app <AppName> [-t <WindowTitle>]
  copy-app --save [on|off]
  copy-app --install-hook | --uninstall-hook

Options:
  -t, --title <WindowTitle> Window title substring filter (optional)
  --save [on|off]           Enable/disable auto-save, or show status
  --install-hook            Install Claude Code hook for xcodebuildmcp
  --uninstall-hook          Remove Claude Code hook
  --uninstall               Completely remove copy-app and all config
  -h, --help                Show this help message

Examples:
  copy-app Writer                     # Capture Writer's frontmost window
  copy-app Safari                     # Capture Safari's frontmost window
  copy-app Terminal -t "server-log"   # Capture Terminal window matching title
  copy-app --save on                  # Enable auto-save to ~/copyMac/screenshots
  copy-app --save off                 # Disable auto-save (clipboard only)
  copy-app --install-hook             # Set up Claude Code integration

  When SAVE_DIR is set, screenshots are saved with timestamps
  AND copied to clipboard. When unset, clipboard only.

Permissions:
  This script requires Accessibility permission.
  Grant in: System Settings → Privacy & Security → Accessibility
  Permission must be granted to the terminal app executing this script
  (e.g., Terminal.app, iTerm.app).
HELP
}

# Build the Swift helper if needed
ensure_helper() {
    if [[ -x "$HELPER_BIN" ]]; then
        return 0
    fi

    mkdir -p "$HELPER_DIR"

    cat > "$HELPER_DIR/getwindowid.swift" << 'SWIFT'
import Cocoa
import ApplicationServices

guard CommandLine.arguments.count >= 2 else {
    print("USAGE_ERROR")
    exit(1)
}

let appName = CommandLine.arguments[1]
let titleFilter = CommandLine.arguments.count >= 3 ? CommandLine.arguments[2] : ""

// Get the app's PID
let runningApps = NSWorkspace.shared.runningApplications.filter { $0.localizedName == appName }
guard let app = runningApps.first else {
    print("APP_NOT_FOUND")
    exit(1)
}

let pid = app.processIdentifier

// Get window list
let options = CGWindowListOption(arrayLiteral: .optionOnScreenOnly, .excludeDesktopElements)
guard let windowList = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
    print("NO_WINDOW_LIST")
    exit(1)
}

// Find window matching PID and optional title filter
for window in windowList {
    guard let ownerPID = window[kCGWindowOwnerPID as String] as? Int32,
          ownerPID == pid,
          let layer = window[kCGWindowLayer as String] as? Int,
          layer == 0,
          let windowID = window[kCGWindowNumber as String] as? Int else {
        continue
    }

    // If title filter specified, check window name
    if !titleFilter.isEmpty {
        guard let windowName = window[kCGWindowName as String] as? String,
              windowName.contains(titleFilter) else {
            continue
        }
    }

    print(windowID)
    exit(0)
}

print("WINDOW_NOT_FOUND")
exit(1)
SWIFT

    if ! swiftc "$HELPER_DIR/getwindowid.swift" -o "$HELPER_BIN" 2>/dev/null; then
        echo "Error: Failed to compile helper. Ensure Xcode Command Line Tools are installed." >&2
        exit 1
    fi
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -a|--app)
            [[ -z "$2" || "$2" == -* ]] && { echo "Error: --app requires a value." >&2; exit 1; }
            APP_NAME="$2"
            shift 2
            ;;
        -t|--title)
            [[ -z "$2" || "$2" == -* ]] && { echo "Error: --title requires a value." >&2; exit 1; }
            TITLE_FILTER="$2"
            shift 2
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        --install-hook)
            install_hook
            exit 0
            ;;
        --uninstall-hook)
            uninstall_hook
            exit 0
            ;;
        --save)
            save_toggle "$2"
            exit 0
            ;;
        --uninstall)
            full_uninstall
            exit 0
            ;;
        -*)
            echo "Error: Unknown option: $1" >&2
            echo "Use --help for usage information." >&2
            exit 1
            ;;
        *)
            # Positional argument = app name
            if [[ -z "$APP_NAME" ]]; then
                APP_NAME="$1"
            else
                echo "Error: Unexpected argument: $1" >&2
                exit 1
            fi
            shift
            ;;
    esac
done

# Validate required arguments
if [[ -z "$APP_NAME" ]]; then
    echo "Error: App name required." >&2
    echo "Usage: copy-app <AppName> [-t <WindowTitle>]" >&2
    exit 1
fi

# Expand SAVE_DIR if set (handle ~)
if [[ -n "$SAVE_DIR" ]]; then
    SAVE_DIR="${SAVE_DIR/#\~/$HOME}"
fi

# Ensure helper is built
ensure_helper

# Get window ID using Swift helper
if [[ -n "$TITLE_FILTER" ]]; then
    window_id=$("$HELPER_BIN" "$APP_NAME" "$TITLE_FILTER" 2>&1)
else
    window_id=$("$HELPER_BIN" "$APP_NAME" 2>&1)
fi

# Handle errors
case "$window_id" in
    "APP_NOT_FOUND")
        echo "Error: Application '$APP_NAME' is not running." >&2
        exit 1
        ;;
    "NO_WINDOW_LIST")
        echo "Error: Could not get window list." >&2
        exit 1
        ;;
    "WINDOW_NOT_FOUND")
        if [[ -n "$TITLE_FILTER" ]]; then
            echo "Error: No window of '$APP_NAME' matches title filter '$TITLE_FILTER'." >&2
        else
            echo "Error: No capturable window found for '$APP_NAME'." >&2
        fi
        exit 1
        ;;
    "USAGE_ERROR")
        echo "Error: Internal helper error." >&2
        exit 1
        ;;
esac

# Validate window_id is numeric
if ! [[ "$window_id" =~ ^[0-9]+$ ]]; then
    echo "Error: Unexpected result: $window_id" >&2
    exit 1
fi

# Capture the window
if [[ -n "$SAVE_DIR" ]]; then
    # Save to file AND copy to clipboard

    # Organize by app: SAVE_DIR/AppName/AppName_timestamp.png
    safe_app_name="${APP_NAME//[^a-zA-Z0-9_-]/_}"
    app_dir="$SAVE_DIR/$safe_app_name"

    # Create app directory if needed
    if [[ ! -d "$app_dir" ]]; then
        mkdir -p "$app_dir" || { echo "Error: Failed to create directory: $app_dir" >&2; exit 1; }
    fi

    # Generate filename: AppName_2024-01-15_14-30-45.png
    timestamp=$(date +"%Y-%m-%d_%H-%M-%S")
    filename="${safe_app_name}_${timestamp}.png"
    filepath="$app_dir/$filename"

    # Capture window to file
    if screencapture -l"$window_id" "$filepath" 2>/dev/null; then
        # Copy file to clipboard using AppleScript
        osascript -e "set the clipboard to (read (POSIX file \"$filepath\") as «class PNGf»)" 2>/dev/null
        echo "Screenshot saved: $filepath"
        echo "Screenshot copied to clipboard."
    else
        echo "Error: Failed to capture window." >&2
        exit 1
    fi
else
    # Clipboard only
    if screencapture -c -l"$window_id" 2>/dev/null; then
        echo "Screenshot of '$APP_NAME' window copied to clipboard."
    else
        echo "Error: Failed to capture window." >&2
        exit 1
    fi
fi
