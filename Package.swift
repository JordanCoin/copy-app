// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "copy-app",
    platforms: [.macOS(.v12)],
    targets: [
        .executableTarget(
            name: "copy-app",
            path: "Sources"
        )
    ]
)
