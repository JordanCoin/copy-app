import Cocoa

/// Copy an image to the system clipboard
func copyToClipboard(_ image: NSImage) {
    let pasteboard = NSPasteboard.general
    pasteboard.clearContents()
    pasteboard.writeObjects([image])
}

/// Get the save directory for screenshots
func getSaveDirectory() -> String {
    if let envDir = ProcessInfo.processInfo.environment["SAVE_DIR"] {
        return envDir
    }
    return NSHomeDirectory() + "/copyMac/screenshots"
}

/// Check if auto-save is enabled
func isAutoSaveEnabled() -> Bool {
    let configFile = NSHomeDirectory() + "/.config/copy-app/save-enabled"
    return FileManager.default.fileExists(atPath: configFile)
}

/// Handle --save mode
func handleSaveMode(_ mode: String) {
    let configDir = NSHomeDirectory() + "/.config/copy-app"
    let configFile = configDir + "/save-enabled"
    let fm = FileManager.default

    switch mode.lowercased() {
    case "on":
        try? fm.createDirectory(atPath: configDir, withIntermediateDirectories: true)
        fm.createFile(atPath: configFile, contents: nil)
        print("Auto-save enabled. Screenshots will be saved to ~/copyMac/screenshots/")
    case "off":
        try? fm.removeItem(atPath: configFile)
        print("Auto-save disabled. Screenshots will only be copied to clipboard.")
    default:
        // Show status
        if isAutoSaveEnabled() {
            print("Auto-save: ON")
            print("Screenshots saved to: ~/copyMac/screenshots/<AppName>/")
        } else {
            print("Auto-save: OFF (clipboard only)")
            print("Enable with: copy-app --save on")
        }
    }
}

/// Save screenshot to disk if enabled
func saveScreenshot(image: NSImage, appName: String) -> String? {
    // Check environment variable first (for hooks), then config
    let envDir = ProcessInfo.processInfo.environment["SAVE_DIR"]
    guard envDir != nil || isAutoSaveEnabled() else {
        return nil
    }

    let baseDir = envDir ?? (NSHomeDirectory() + "/copyMac/screenshots")
    let appDir = baseDir + "/\(appName)"
    let fm = FileManager.default

    try? fm.createDirectory(atPath: appDir, withIntermediateDirectories: true)

    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
    let timestamp = formatter.string(from: Date())
    let filename = "\(appName)_\(timestamp).png"
    let filepath = appDir + "/" + filename

    guard let tiffData = image.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiffData),
          let pngData = bitmap.representation(using: .png, properties: [:]) else {
        return nil
    }

    do {
        try pngData.write(to: URL(fileURLWithPath: filepath))
        return filepath
    } catch {
        fputs("Warning: Failed to save screenshot: \(error.localizedDescription)\n", stderr)
        return nil
    }
}
