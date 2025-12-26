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

# Load config if exists
if [[ -f "$CONFIG_FILE" ]]; then
    source "$CONFIG_FILE"
fi

show_help() {
    cat << 'HELP'
Description:
  Capture a specific application window to the clipboard.
  Optionally saves screenshots to disk when SAVE_DIR is configured.

Usage:
  copy-app <AppName> [-t <WindowTitle>]

Options:
  -t, --title <WindowTitle> Window title substring filter (optional)
  -h, --help                Show this help message

Examples:
  copy-app Writer                     # Capture Writer's frontmost window
  copy-app Safari                     # Capture Safari's frontmost window
  copy-app Terminal -t "server-log"   # Capture Terminal window matching title

Configuration:
  Create ~/.config/copy-app/config to enable auto-save:

    SAVE_DIR=~/Screenshots/copy-app

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

    # Create save directory if needed
    if [[ ! -d "$SAVE_DIR" ]]; then
        mkdir -p "$SAVE_DIR" || { echo "Error: Failed to create directory: $SAVE_DIR" >&2; exit 1; }
    fi

    # Generate filename: AppName_2024-01-15_14-30-45.png
    timestamp=$(date +"%Y-%m-%d_%H-%M-%S")
    safe_app_name="${APP_NAME//[^a-zA-Z0-9_-]/_}"
    filename="${safe_app_name}_${timestamp}.png"
    filepath="$SAVE_DIR/$filename"

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
