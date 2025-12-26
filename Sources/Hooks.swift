import Foundation

private let hookScript = #"""
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
        APP_PATH=$(echo "$INPUT" | jq -r '.tool_response | tostring' 2>/dev/null | grep -oE 'App launched: [^"]+\.app' | sed 's/App launched: //' | xargs basename 2>/dev/null | sed 's/\.app$//')
        [[ -n "$APP_PATH" ]] && APP_NAME="$APP_PATH";;
esac
[[ -z "$APP_NAME" ]] && exit 0
APP_DIR="$SCREENSHOT_DIR/$APP_NAME"
mkdir -p "$APP_DIR"
sleep 1.5
SAVE_DIR="$APP_DIR" "$COPY_APP" "$APP_NAME" >/dev/null 2>&1
LATEST=$(ls -t "$APP_DIR"/*.png 2>/dev/null | head -1)
[[ -n "$LATEST" && -f "$LATEST" ]] && echo "{\"hookSpecificOutput\":{\"hookEventName\":\"PostToolUse\",\"additionalContext\":\"📸 Screenshot: $LATEST\\n💡 UI actions: copy-app $APP_NAME --type \\\"text\\\" | --keys \\\"cmd+n\\\" | --press \\\"Button\\\" | --find \\\"text\\\" | --top | --newline\"}}"
exit 0
"""#

private let hooksSettings = """
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "mcp__xcodebuildmcp__launch_mac_app OR mcp__xcodebuildmcp__build_run_macos OR mcp__xcodebuildmcp__build_run_sim",
        "hooks": [
          {
            "type": "command",
            "command": "~/.claude/hooks/screenshot-app.sh"
          }
        ]
      }
    ]
  }
}
"""

func installHook() {
    let fm = FileManager.default
    let hookDir = NSHomeDirectory() + "/.claude/hooks"
    let hookPath = hookDir + "/screenshot-app.sh"
    let settingsPath = NSHomeDirectory() + "/.claude/settings.json"

    // Create hooks directory
    try? fm.createDirectory(atPath: hookDir, withIntermediateDirectories: true)

    // Write hook script
    do {
        try hookScript.write(toFile: hookPath, atomically: true, encoding: .utf8)
        // Make executable
        try fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: hookPath)
        print("✓ Installed hook: \(hookPath)")
    } catch {
        fputs("Error writing hook script: \(error.localizedDescription)\n", stderr)
        return
    }

    // Check/update settings.json
    if fm.fileExists(atPath: settingsPath) {
        // Read existing settings
        if let data = fm.contents(atPath: settingsPath),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            if json["hooks"] != nil {
                print("✓ Hook configuration already exists in settings.json")
                print("\nHook installed! Claude will auto-screenshot apps launched via XcodeBuildMCP.")
                return
            }
        }
        // Merge with existing
        print("⚠ Add hook configuration to ~/.claude/settings.json manually:")
        print(hooksSettings)
    } else {
        // Create new settings file
        do {
            try hooksSettings.write(toFile: settingsPath, atomically: true, encoding: .utf8)
            print("✓ Created settings.json with hook configuration")
        } catch {
            fputs("Error writing settings: \(error.localizedDescription)\n", stderr)
        }
    }

    print("\nHook installed! Claude will auto-screenshot apps launched via XcodeBuildMCP.")
}

func uninstallHook() {
    let fm = FileManager.default
    let hookPath = NSHomeDirectory() + "/.claude/hooks/screenshot-app.sh"

    if fm.fileExists(atPath: hookPath) {
        do {
            try fm.removeItem(atPath: hookPath)
            print("✓ Removed hook: \(hookPath)")
        } catch {
            fputs("Error removing hook: \(error.localizedDescription)\n", stderr)
        }
    } else {
        print("Hook not installed")
    }

    print("\nNote: You may want to remove the hook configuration from ~/.claude/settings.json")
}
