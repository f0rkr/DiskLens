// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "DiskLens",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "DiskLens",
            path: "Sources/DiskLens",
            swiftSettings: [
                // Treat top-level files as a library so @main is the entry point.
                .unsafeFlags(["-parse-as-library"])
            ]
        ),
        .testTarget(
            name: "DiskLensTests",
            dependencies: ["DiskLens"],
            path: "Tests/DiskLensTests"
        )
    ],
    // Build targets in Swift 5 language mode so passing the (non-Sendable) file
    // tree across actor boundaries stays a warning, not a hard error.
    swiftLanguageModes: [.v5]
)
