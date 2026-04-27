// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "WarboardIOS",
    platforms: [
        .iOS(.v17),
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
            // Userscripts and the GM_* shim are loaded from app assets
            // at runtime via Bundle.module.url(forResource:withExtension:).
            // Process means SwiftPM lowercases extensions and validates
            // them; .copy keeps the original filename verbatim. We use
            // .copy because the userscripts have multi-dot extensions
            // (.user.js) that Process would mangle.
            resources: [
                .copy("Resources/factionops.user.js"),
                .copy("Resources/oc-spawn-assistance.user.js"),
                .copy("Resources/gm-shim.js"),
            ],
            // swift-tools-version 6.0 defaults to Swift 6 strict
            // concurrency, which trips on UNUserNotificationCenterDelegate
            // conformance and a few WKWebView call sites. Stay on
            // Swift 5 mode until those are addressed properly.
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ]
        ),
    ]
)
