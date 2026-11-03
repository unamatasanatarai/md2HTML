// swift-tools-version: 5.7
import PackageDescription

let package = Package(
    name: "md2HTML",
    platforms: [
        .macOS(.v12)
    ],
    products: [
        .executable(
            name: "md2HTML",
            targets: ["md2HTML"]
        )
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "md2HTML",
            dependencies: [],
            path: "Sources/App"
        ),
        .testTarget(
            name: "AppTests",
            dependencies: ["md2HTML"],
            path: "Tests/AppTests"
        )
    ]
)
