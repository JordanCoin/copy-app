import Cocoa
import CoreGraphics

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

/// Find a window ID for an app, optionally filtering by title
func findWindowID(for app: NSRunningApplication, titleFilter: String? = nil) -> CGWindowID? {
    let pid = app.processIdentifier

    guard let windowList = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else {
        return nil
    }

    for window in windowList {
        guard let windowPID = window[kCGWindowOwnerPID as String] as? Int32,
              windowPID == pid,
              let windowID = window[kCGWindowNumber as String] as? CGWindowID,
              let layer = window[kCGWindowLayer as String] as? Int,
              layer == 0  // Normal window layer
        else { continue }

        // Skip tiny windows (toolbars, etc)
        if let bounds = window[kCGWindowBounds as String] as? [String: CGFloat],
           let width = bounds["Width"], let height = bounds["Height"],
           width < 100 || height < 100 {
            continue
        }

        // Check title filter if provided
        if let filter = titleFilter {
            let title = window[kCGWindowName as String] as? String ?? ""
            if !title.lowercased().contains(filter.lowercased()) {
                continue
            }
        }

        return windowID
    }

    return nil
}

/// Capture a window by its ID
func captureWindow(id: CGWindowID) -> NSImage? {
    guard let cgImage = CGWindowListCreateImage(
        .null,
        .optionIncludingWindow,
        id,
        [.boundsIgnoreFraming, .bestResolution]
    ) else {
        return nil
    }

    return NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
}
