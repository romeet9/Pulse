// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MenuBarApp",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "Pulse", targets: ["Pulse"])
    ],
    targets: [
        .executableTarget(
            name: "Pulse",
            path: "Sources/MenuBarApp" // Keeping path same to minimize churn, just logic rename
        )
    ]
)
