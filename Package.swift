// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Glance",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "Glance", targets: ["Glance"]),
        .executable(name: "glance", targets: ["GlanceCLI"]),
    ],
    targets: [
        .target(
            name: "Glance",
            linkerSettings: [
                .linkedFramework("ApplicationServices"),
                .linkedFramework("AppKit"),
            ]
        ),
        .executableTarget(
            name: "GlanceCLI",
            dependencies: ["Glance"]
        ),
    ]
)
