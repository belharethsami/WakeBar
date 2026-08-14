// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "WakeBar",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "WakeBar", targets: ["WakeBar"]),
        .executable(name: "WakeBarLogicTests", targets: ["WakeBarLogicTests"])
    ],
    targets: [
        .target(
            name: "WakeBarCore",
            path: "Sources/WakeBarCore"
        ),
        .executableTarget(
            name: "WakeBar",
            dependencies: ["WakeBarCore"],
            path: "Sources/WakeBar"
        ),
        .executableTarget(
            name: "WakeBarLogicTests",
            dependencies: ["WakeBarCore"],
            path: "Tests/WakeBarLogicTests"
        )
    ]
)
