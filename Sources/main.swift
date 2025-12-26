import Foundation

// MARK: - Argument Parsing

struct Options {
    var appName: String?
    var windowTitle: String?
    var typeText: String?
    var keys: String?
    var clickCoords: String?
    var pressButton: String?
    var findText: String?
    var goToTop: Bool = false
    var newline: Bool = false
    var delay: Double = 0.5
    var saveMode: String?  // "on", "off", or nil to show status
    var installHook: Bool = false
    var uninstallHook: Bool = false
}

func printUsage() {
    print("""
    Usage: copy-app <AppName> [options]

    Options:
      -t, --title <text>    Filter by window title
      --type <text>         Type text into the app
      --keys <combo>        Press key combination (e.g., "cmd+n")
      --click <x,y>         Click at coordinates
      --press <name>        Click button by name
      --find <text>         Navigate to text in focused field
      --top                 Move cursor to start of document
      --newline             Press Enter before typing
      --delay <seconds>     Delay after action (default: 0.5)
      --save [on|off]       Enable/disable auto-save, or show status
      --install-hook        Install Claude Code hook
      --uninstall-hook      Remove Claude Code hook
      -h, --help            Show this help
    """)
}

func parseArguments() -> Options {
    var opts = Options()
    var args = Array(CommandLine.arguments.dropFirst())

    while !args.isEmpty {
        let arg = args.removeFirst()

        switch arg {
        case "-h", "--help":
            printUsage()
            exit(0)
        case "-t", "--title":
            guard !args.isEmpty else { fputs("Error: --title requires a value\n", stderr); exit(1) }
            opts.windowTitle = args.removeFirst()
        case "--type":
            guard !args.isEmpty else { fputs("Error: --type requires a value\n", stderr); exit(1) }
            opts.typeText = args.removeFirst()
        case "--keys":
            guard !args.isEmpty else { fputs("Error: --keys requires a value\n", stderr); exit(1) }
            opts.keys = args.removeFirst()
        case "--click":
            guard !args.isEmpty else { fputs("Error: --click requires coordinates\n", stderr); exit(1) }
            opts.clickCoords = args.removeFirst()
        case "--press":
            guard !args.isEmpty else { fputs("Error: --press requires a button name\n", stderr); exit(1) }
            opts.pressButton = args.removeFirst()
        case "--find":
            guard !args.isEmpty else { fputs("Error: --find requires text\n", stderr); exit(1) }
            opts.findText = args.removeFirst()
        case "--top":
            opts.goToTop = true
        case "--newline":
            opts.newline = true
        case "--delay":
            guard !args.isEmpty else { fputs("Error: --delay requires a value\n", stderr); exit(1) }
            opts.delay = Double(args.removeFirst()) ?? 0.5
        case "--save":
            if args.isEmpty || args.first?.hasPrefix("-") == true {
                opts.saveMode = ""  // empty = show status
            } else {
                opts.saveMode = args.removeFirst()
            }
        case "--install-hook":
            opts.installHook = true
        case "--uninstall-hook":
            opts.uninstallHook = true
        default:
            if arg.hasPrefix("-") {
                fputs("Unknown option: \(arg)\n", stderr)
                exit(1)
            } else if opts.appName == nil {
                opts.appName = arg
            }
        }
    }

    return opts
}

// MARK: - Main

let opts = parseArguments()

// Handle --save mode
if let saveMode = opts.saveMode {
    handleSaveMode(saveMode)
    exit(0)
}

// Handle hook install/uninstall
if opts.installHook {
    installHook()
    exit(0)
}
if opts.uninstallHook {
    uninstallHook()
    exit(0)
}

// Require app name for capture
guard let appName = opts.appName else {
    fputs("Error: App name required\n", stderr)
    printUsage()
    exit(1)
}

// Find the app
guard let app = findApp(named: appName) else {
    fputs("Error: App '\(appName)' not found or not running\n", stderr)
    exit(1)
}

// Activate the app for UI automation
if opts.typeText != nil || opts.keys != nil || opts.clickCoords != nil ||
   opts.pressButton != nil || opts.findText != nil || opts.goToTop || opts.newline {
    app.activate()
    usleep(300_000)  // 0.3s for app to come to front
}

// Perform UI actions
var actionPerformed = false

if let findText = opts.findText {
    if !findTextInFocusedElement(app: app, text: findText) {
        fputs("Warning: Could not find '\(findText)'\n", stderr)
    }
    actionPerformed = true
}

if let buttonName = opts.pressButton {
    if !pressButton(app: app, named: buttonName) {
        fputs("Warning: Could not press '\(buttonName)'\n", stderr)
    }
    actionPerformed = true
}

if opts.goToTop {
    sendKeyCombo("cmd+up", to: app)
    actionPerformed = true
}

if opts.newline {
    sendKeyCombo("return", to: app)
    actionPerformed = true
}

if let keys = opts.keys {
    sendKeyCombo(keys, to: app)
    actionPerformed = true
}

if let coords = opts.clickCoords {
    let parts = coords.split(separator: ",").compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
    if parts.count == 2 {
        clickAt(x: parts[0], y: parts[1], in: app)
    }
    actionPerformed = true
}

if let text = opts.typeText {
    typeText(text, to: app)
    actionPerformed = true
}

if actionPerformed {
    usleep(UInt32(opts.delay * 1_000_000))
}

// Find and capture window
guard let windowID = findWindowID(for: app, titleFilter: opts.windowTitle) else {
    fputs("Error: No capturable window found for '\(appName)'\n", stderr)
    exit(1)
}

guard let image = captureWindow(id: windowID) else {
    fputs("Error: Failed to capture window\n", stderr)
    exit(1)
}

// Copy to clipboard
copyToClipboard(image)

// Save to disk if enabled
if let savePath = saveScreenshot(image: image, appName: appName) {
    print(savePath)
} else {
    print("Copied to clipboard")
}
