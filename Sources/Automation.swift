import Cocoa
import CoreGraphics

// MARK: - Key Code Mapping

private let keyCodeMap: [String: CGKeyCode] = [
    "a": 0, "b": 11, "c": 8, "d": 2, "e": 14, "f": 3, "g": 5, "h": 4,
    "i": 34, "j": 38, "k": 40, "l": 37, "m": 46, "n": 45, "o": 31, "p": 35,
    "q": 12, "r": 15, "s": 1, "t": 17, "u": 32, "v": 9, "w": 13, "x": 7,
    "y": 16, "z": 6,
    "0": 29, "1": 18, "2": 19, "3": 20, "4": 21, "5": 23, "6": 22, "7": 26,
    "8": 28, "9": 25,
    "return": 36, "enter": 36, "tab": 48, "space": 49, "delete": 51,
    "backspace": 51, "escape": 53, "esc": 53,
    "up": 126, "down": 125, "left": 123, "right": 124,
    "f1": 122, "f2": 120, "f3": 99, "f4": 118, "f5": 96, "f6": 97,
    "f7": 98, "f8": 100, "f9": 101, "f10": 109, "f11": 103, "f12": 111,
    "[": 33, "]": 30, "\\": 42, ";": 41, "'": 39, ",": 43, ".": 47, "/": 44,
    "`": 50, "-": 27, "=": 24,
]

/// Parse key combo string and send to app
func sendKeyCombo(_ combo: String, to app: NSRunningApplication) {
    let parts = combo.lowercased().split(separator: "+").map { String($0).trimmingCharacters(in: .whitespaces) }

    var modifiers: CGEventFlags = []
    var keyCode: CGKeyCode = 0

    for part in parts {
        switch part {
        case "cmd", "command":
            modifiers.insert(.maskCommand)
        case "ctrl", "control":
            modifiers.insert(.maskControl)
        case "alt", "option", "opt":
            modifiers.insert(.maskAlternate)
        case "shift":
            modifiers.insert(.maskShift)
        default:
            if let code = keyCodeMap[part] {
                keyCode = code
            } else if part.count == 1, let scalar = part.unicodeScalars.first {
                // Try to find by character
                if let code = keyCodeMap[String(scalar)] {
                    keyCode = code
                }
            }
        }
    }

    sendKey(keyCode, modifiers: modifiers, to: app)
}

/// Send a single key event
private func sendKey(_ keyCode: CGKeyCode, modifiers: CGEventFlags, to app: NSRunningApplication) {
    let source = CGEventSource(stateID: .hidSystemState)

    guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true),
          let keyUp = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false) else {
        return
    }

    keyDown.flags = modifiers
    keyUp.flags = modifiers

    let pid = app.processIdentifier
    keyDown.postToPid(pid)
    keyUp.postToPid(pid)
}

/// Type text using CGEvents
func typeText(_ text: String, to app: NSRunningApplication) {
    let source = CGEventSource(stateID: .hidSystemState)
    let pid = app.processIdentifier

    for char in text {
        guard let event = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true) else { continue }

        var unichar = Array(String(char).utf16)
        event.keyboardSetUnicodeString(stringLength: unichar.count, unicodeString: &unichar)
        event.postToPid(pid)

        // Key up
        if let upEvent = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false) {
            upEvent.postToPid(pid)
        }

        usleep(10_000)  // Small delay between characters
    }
}

/// Click at coordinates within an app's window
func clickAt(x: Int, y: Int, in app: NSRunningApplication) {
    let pid = app.processIdentifier

    // Get the app's main window position
    let appElement = AXUIElementCreateApplication(pid)
    var windowRef: CFTypeRef?

    guard AXUIElementCopyAttributeValue(appElement, kAXFocusedWindowAttribute as CFString, &windowRef) == .success else {
        fputs("Warning: Could not get focused window for click\n", stderr)
        return
    }

    let window = windowRef as! AXUIElement
    var positionRef: CFTypeRef?
    guard AXUIElementCopyAttributeValue(window, kAXPositionAttribute as CFString, &positionRef) == .success else {
        return
    }

    var windowPos = CGPoint.zero
    AXValueGetValue(positionRef as! AXValue, .cgPoint, &windowPos)

    // Calculate absolute screen position
    let clickPoint = CGPoint(x: windowPos.x + CGFloat(x), y: windowPos.y + CGFloat(y))

    let source = CGEventSource(stateID: .hidSystemState)

    guard let mouseDown = CGEvent(mouseEventSource: source, mouseType: .leftMouseDown, mouseCursorPosition: clickPoint, mouseButton: .left),
          let mouseUp = CGEvent(mouseEventSource: source, mouseType: .leftMouseUp, mouseCursorPosition: clickPoint, mouseButton: .left) else {
        return
    }

    mouseDown.post(tap: .cghidEventTap)
    usleep(50_000)
    mouseUp.post(tap: .cghidEventTap)
}
