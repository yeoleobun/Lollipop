// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Lollipop",
    platforms: [
        .macOS(.v15)
    ],
    products: [
        .executable(name: "Lollipop", targets: ["Lollipop"])
    ],
    targets: [
        .executableTarget(
            name: "Lollipop",
            path: "Sources/Lollipop",
            resources: [
                .copy("Resources/Bridge")
            ],
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ],
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("SwiftUI"),
                .linkedFramework("WebKit"),
                .linkedFramework("MediaPlayer")
            ]
        )
    ]
)
