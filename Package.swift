// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PrinciplesBeforePersonalities",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "PrinciplesBeforePersonalities",
            path: "Sources/PrinciplesBeforePersonalities",
            resources: [.process("Resources")]
        )
    ]
)
