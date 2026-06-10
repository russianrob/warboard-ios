// swift-tools-version:5.9
import PackageDescription

// Thin SwiftPM manifest ALONGSIDE the xcodegen project (project.yml).
// Purpose: run the pure-Swift userscript-engine unit tests headlessly
// on Linux CI via `swift test`. The full app (WebKit/SwiftUI/UIKit,
// Live Activities, Watch) builds only through xcodebuild on a Mac.
// Library target is named WarboardIOS so the unit tests' `@testable
// import WarboardIOS` resolves both here and (via the app module) on Mac.
let package = Package(
    name: "WarboardIOS",
    platforms: [.macOS(.v13)],
    targets: [
        .target(
            name: "WarboardIOS",
            path: "WarboardIOS/Sources/WarboardIOS/Userscripts",
            // Files that import WebKit/SwiftUI/UIKit cannot compile under
            // plain SwiftPM on Linux. They are app-only and verified by
            // xcodebuild on a Mac. Keep this list in sync as the engine grows.
            exclude: [
                "GMBridge.swift",
                "GMMessageHandler.swift",
                "UserscriptController.swift",
                "BrowserView.swift",
                "ScriptsView.swift"
            ],
            // The GM bootstrap JS is an embedded resource (not a Swift source).
            // `.process` copies it into Bundle.module so GMBootstrap.body can
            // load it under `swift test` on Linux; the Mac app build bundles
            // the same file via project.yml's resources build phase.
            resources: [
                .process("Resources/gm-bootstrap.js")
            ]
        ),
        .testTarget(
            name: "WarboardIOSTests",
            dependencies: ["WarboardIOS"],
            path: "WarboardIOS/Tests/WarboardIOSTests",
            // Integration tests that import WebKit are Mac-only (xcodebuild
            // test). Exclude them from the Linux SwiftPM test run.
            exclude: [
                "GMBridgeIntegrationTests.swift",
                "InjectionPipelineTests.swift"
            ]
        )
    ]
)
