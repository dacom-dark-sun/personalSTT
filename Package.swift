// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "PersonalSTT",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "PersonalSTT",
            path: "Sources/PersonalSTT",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("AVFoundation"),
                .linkedFramework("CoreGraphics"),
                .linkedFramework("Carbon"),
                .linkedFramework("AudioToolbox"),
            ]
        )
    ]
)
