import Cocoa
import CoreGraphics
import ApplicationServices

/// Find a running application by name
func findApp(named name: String) -> NSRunningApplication? {
    let workspace = NSWorkspace.shared

    // Try exact match first
    if let app = workspace.runningApplications.first(where: { $0.localizedName == name }) {
        return app
    }

    // Try case-insensitive match
    if let app = workspace.runningApplications.first(where: {
        $0.localizedName?.lowercased() == name.lowercased()
    }) {
        return app
    }

    // Try partial match
    return workspace.runningApplications.first(where: {
        $0.localizedName?.lowercased().contains(name.lowercased()) == true
    })
}

/// Find window bounds using Accessibility APIs (no Screen Recording permission needed)
func findWindowBounds(for app: NSRunningApplication, titleFilter: String? = nil) -> CGRect? {
    let pid = app.processIdentifier
    let appElement = AXUIElementCreateApplication(pid)

    // Get windows array via Accessibility
    var windowsValue: CFTypeRef?
    let result = AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &windowsValue)

    guard result == .success,
          let windows = windowsValue as? [AXUIElement] else {
        return nil
    }

    for window in windows {
        // Check title filter if provided
        if let filter = titleFilter {
            var titleValue: CFTypeRef?
            AXUIElementCopyAttributeValue(window, kAXTitleAttribute as CFString, &titleValue)
            let title = titleValue as? String ?? ""
            if !title.lowercased().contains(filter.lowercased()) {
                continue
            }
        }

        // Get window position and size
        var positionValue: CFTypeRef?
        var sizeValue: CFTypeRef?

        AXUIElementCopyAttributeValue(window, kAXPositionAttribute as CFString, &positionValue)
        AXUIElementCopyAttributeValue(window, kAXSizeAttribute as CFString, &sizeValue)

        guard let positionRef = positionValue,
              let sizeRef = sizeValue else {
            continue
        }

        var position = CGPoint.zero
        var size = CGSize.zero

        AXValueGetValue(positionRef as! AXValue, .cgPoint, &position)
        AXValueGetValue(sizeRef as! AXValue, .cgSize, &size)

        // Skip tiny windows
        if size.width < 100 || size.height < 100 {
            continue
        }

        return CGRect(origin: position, size: size)
    }

    return nil
}

/// Legacy function for backwards compatibility
func findWindowID(for app: NSRunningApplication, titleFilter: String? = nil) -> CGWindowID? {
    // Return a dummy ID since we now use bounds-based capture
    if findWindowBounds(for: app, titleFilter: titleFilter) != nil {
        return 1  // Non-nil indicates window found
    }
    return nil
}

/// Capture a window using system screencapture command (no Screen Recording permission needed)
func captureWindow(id: CGWindowID) -> NSImage? {
    // This is called after findWindowID, but we need bounds
    // Re-lookup the app and get bounds
    // For now, this requires the app to be passed differently
    // This function signature is kept for compatibility but won't work standalone
    return nil
}

/// Capture a window by its bounds using system screencapture
func captureWindowByBounds(_ bounds: CGRect) -> NSImage? {
    let tempFile = NSTemporaryDirectory() + "screencapture_\(UUID().uuidString).png"

    // Use screencapture -R to capture a specific region
    // This uses the system's trusted screencapture tool
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
    process.arguments = [
        "-R", "\(Int(bounds.origin.x)),\(Int(bounds.origin.y)),\(Int(bounds.width)),\(Int(bounds.height))",
        "-x",  // No sound
        tempFile
    ]

    do {
        try process.run()
        process.waitUntilExit()
    } catch {
        return nil
    }

    guard process.terminationStatus == 0 else {
        return nil
    }

    defer {
        try? FileManager.default.removeItem(atPath: tempFile)
    }

    return NSImage(contentsOfFile: tempFile)
}
