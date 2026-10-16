// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "DanperCore",
    platforms: [.iOS(.v17), .macOS(.v13)],
    products: [.library(name: "DanperCore", targets: ["DanperCore"])],
    targets: [
        .target(name: "DanperCore", path: "Sources/DanperCore"),
        .testTarget(name: "DanperCoreTests", dependencies: ["DanperCore"], path: "Tests/DanperCoreTests")
    ]
)
