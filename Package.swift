// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Snipost",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "Snipost",
            path: "Sources/Snipost"
        )
    ]
)
