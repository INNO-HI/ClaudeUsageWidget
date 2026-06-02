// swift-tools-version:5.9
import PackageDescription

// Test-only package. The main app is built by build.sh which compiles
// the Sources/ directory directly with swiftc — we deliberately do NOT
// declare an executable target here so the two build paths don't fight.
//
// To run tests:
//   swift test --package-path .
//
// CI runs this via the test job in .github/workflows/release-macos.yml.
let package = Package(
    name: "ClaudeUsageWidgetCore",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "ClaudeUsageWidgetCore", targets: ["ClaudeUsageWidgetCore"]),
    ],
    targets: [
        .target(
            name: "ClaudeUsageWidgetCore",
            path: "CoreLogic"
        ),
        .testTarget(
            name: "CoreLogicTests",
            dependencies: ["ClaudeUsageWidgetCore"],
            path: "Tests/CoreLogicTests"
        ),
    ]
)
