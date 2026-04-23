// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Lidiculous",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "Lidiculous",
            path: "Sources/Lidiculous",
            resources: [.copy("../../Resources/Info.plist")]
        )
    ]
)
