// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "DanperCore",
    platforms: [.iOS(.v17), .macOS(.v13)],
    products: [.library(name: "DanperCore", targets: ["DanperCore"])],
    dependencies: [
        // Pin audited major compatible with Xcode 16/Swift 5.10+ and Linux.
        .package(url: "https://github.com/apple/swift-crypto.git", exact: "3.15.1")
    ],
    targets: [
        .target(name: "DanperCore",
                dependencies: [.product(name: "Crypto", package: "swift-crypto")],
                path: "Sources/DanperCore"),
        .testTarget(name: "DanperCoreTests", dependencies: ["DanperCore"],
                    path: "Tests/DanperCoreTests")
    ]
)
