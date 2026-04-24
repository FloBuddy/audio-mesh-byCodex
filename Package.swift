// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "audio-mesh",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(name: "AudioMeshCore", targets: ["AudioMeshCore"]),
        .executable(name: "audiomesh-source", targets: ["AudioMeshSource"]),
        .executable(name: "audiomesh-receiver", targets: ["AudioMeshReceiver"])
    ],
    targets: [
        .systemLibrary(
            name: "COpus",
            pkgConfig: "opus",
            providers: [
                .brew(["opus"])
            ]
        ),
        .target(
            name: "AudioMeshCore",
            dependencies: ["COpus"]
        ),
        .executableTarget(
            name: "AudioMeshSource",
            dependencies: ["AudioMeshCore"]
        ),
        .executableTarget(
            name: "AudioMeshReceiver",
            dependencies: ["AudioMeshCore"]
        ),
        .testTarget(
            name: "AudioMeshCoreTests",
            dependencies: ["AudioMeshCore"]
        )
    ]
)
