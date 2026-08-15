// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ShellLite",
    platforms: [
        .iOS(.v18),
        .macOS(.v15),
    ],
    products: [
        .library(name: "ShellLiteCore", targets: ["ShellLiteCore"]),
        .library(name: "ShellLite",     targets: ["ShellLite"]),
    ],
    dependencies: [
        .package(
            url: "https://github.com/apple/swift-nio-ssh.git",
            from: "0.15.0"
        ),
        // Explicit dependency so Crypto module is directly importable.
        // swift-crypto 4.5.1 is already resolved as a transitive dep of swift-nio-ssh.
        .package(
            url: "https://github.com/apple/swift-crypto.git",
            from: "4.0.0"
        ),
    ],
    targets: [
        // ── Core: platform-portable (Linux buildable) ──────────────────
        .target(
            name: "ShellLiteCore",
            dependencies: [
                .product(name: "NIOSSH",  package: "swift-nio-ssh"),
                .product(name: "Crypto",  package: "swift-crypto"),
            ],
            path: "Sources/ShellLiteCore"
        ),
        // ── Full iOS app library (SwiftUI/UIKit — macOS/iOS only) ──────
        .target(
            name: "ShellLite",
            dependencies: ["ShellLiteCore"],
            path: "Sources/ShellLite"
        ),
        // ── Unit tests ─────────────────────────────────────────────────
        .testTarget(
            name: "ShellLiteTests",
            dependencies: ["ShellLiteCore"],
            path: "Tests/ShellLiteTests"
        ),
    ]
)
