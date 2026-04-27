// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "WarboardIOS",
    platforms: [
        // Apple requires iOS 18 SDK minimum for App Store uploads
        // (Apr 2026). Deployment target also iOS 18 — keeping the
        // Info.plist's MinimumOSVersion in sync (ITMS-90208).
        .iOS(.v18),
        .macOS(.v14),
    ],
    products: [
        // An xtool project should contain exactly one library product,
        // representing the main app.
        .library(
            name: "WarboardIOS",
            targets: ["WarboardIOS"]
        ),
    ],
    targets: [
        .target(
            name: "WarboardIOS",
            // swift-tools-version 6.0 defaults to Swift 6 strict
            // concurrency. Stay on Swift 5 mode for now — the Combine /
            // ObservableObject patterns ported from warboard-mac don't
            // pass strict checks without rewriting actor isolation.
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ]
        ),
    ]
)
