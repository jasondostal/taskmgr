// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "TaskMgr",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "TaskMgr",
            path: "Sources"
        )
    ]
)
