import Cocoa
import ApplicationServices

/// Find text in the focused text element and position cursor there
func findTextInFocusedElement(app: NSRunningApplication, text: String) -> Bool {
    let appElement = AXUIElementCreateApplication(app.processIdentifier)

    // Get focused element
    var focusedRef: CFTypeRef?
    guard AXUIElementCopyAttributeValue(appElement, kAXFocusedUIElementAttribute as CFString, &focusedRef) == .success else {
        return false
    }

    let focusedElement = focusedRef as! AXUIElement

    // Get text content
    var valueRef: CFTypeRef?
    guard AXUIElementCopyAttributeValue(focusedElement, kAXValueAttribute as CFString, &valueRef) == .success,
          let content = valueRef as? String else {
        return false
    }

    // Find the text
    guard let range = content.range(of: text, options: .caseInsensitive) else {
        return false
    }

    let position = content.distance(from: content.startIndex, to: range.lowerBound)

    // Set cursor position
    var cfRange = CFRange(location: position, length: 0)
    guard let axRange = AXValueCreate(.cfRange, &cfRange) else {
        return false
    }

    return AXUIElementSetAttributeValue(focusedElement, kAXSelectedTextRangeAttribute as CFString, axRange) == .success
}

/// Press a button by name in an app
func pressButton(app: NSRunningApplication, named title: String) -> Bool {
    let appElement = AXUIElementCreateApplication(app.processIdentifier)

    guard let button = findButton(in: appElement, matching: title) else {
        return false
    }

    // Try AXPress action
    if AXUIElementPerformAction(button, kAXPressAction as CFString) == .success {
        return true
    }

    // Fallback: get button position and click it
    var positionRef: CFTypeRef?
    var sizeRef: CFTypeRef?

    guard AXUIElementCopyAttributeValue(button, kAXPositionAttribute as CFString, &positionRef) == .success,
          AXUIElementCopyAttributeValue(button, kAXSizeAttribute as CFString, &sizeRef) == .success else {
        return false
    }

    var position = CGPoint.zero
    var size = CGSize.zero
    AXValueGetValue(positionRef as! AXValue, .cgPoint, &position)
    AXValueGetValue(sizeRef as! AXValue, .cgSize, &size)

    // Click center of button
    let clickPoint = CGPoint(x: position.x + size.width / 2, y: position.y + size.height / 2)

    let source = CGEventSource(stateID: .hidSystemState)
    guard let mouseDown = CGEvent(mouseEventSource: source, mouseType: .leftMouseDown, mouseCursorPosition: clickPoint, mouseButton: .left),
          let mouseUp = CGEvent(mouseEventSource: source, mouseType: .leftMouseUp, mouseCursorPosition: clickPoint, mouseButton: .left) else {
        return false
    }

    mouseDown.post(tap: .cghidEventTap)
    usleep(50_000)
    mouseUp.post(tap: .cghidEventTap)

    return true
}

/// Recursively find a button matching the title
private func findButton(in element: AXUIElement, matching title: String) -> AXUIElement? {
    var roleRef: CFTypeRef?
    AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &roleRef)
    let role = (roleRef as? String) ?? ""

    // Check title
    var titleRef: CFTypeRef?
    if AXUIElementCopyAttributeValue(element, kAXTitleAttribute as CFString, &titleRef) == .success,
       let elementTitle = titleRef as? String,
       elementTitle.localizedCaseInsensitiveContains(title) {
        // Check if it's a clickable element
        let clickableRoles = ["AXButton", "AXMenuItem", "AXLink", "AXPopUpButton", "AXCheckBox", "AXRadioButton"]
        if clickableRoles.contains(role) {
            return element
        }
    }

    // Also check description attribute
    var descRef: CFTypeRef?
    if AXUIElementCopyAttributeValue(element, kAXDescriptionAttribute as CFString, &descRef) == .success,
       let desc = descRef as? String,
       desc.localizedCaseInsensitiveContains(title) {
        let clickableRoles = ["AXButton", "AXMenuItem", "AXLink", "AXPopUpButton", "AXCheckBox", "AXRadioButton"]
        if clickableRoles.contains(role) {
            return element
        }
    }

    // Search children
    var childrenRef: CFTypeRef?
    if AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &childrenRef) == .success,
       let children = childrenRef as? [AXUIElement] {
        for child in children {
            if let found = findButton(in: child, matching: title) {
                return found
            }
        }
    }

    return nil
}
