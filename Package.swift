// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "Pico",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "Pico",
            path: "Sources/Pico",
            linkerSettings: [
                .linkedFramework("Carbon"),
                .linkedFramework("Security"),
                .linkedFramework("ServiceManagement"),
            ]
        ),
    ]
)
