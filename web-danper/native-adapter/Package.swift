// swift-tools-version: 5.9
import PackageDescription
let package = Package(name: "DanperCloudBridge", platforms: [.iOS(.v16), .macOS(.v13)], products: [.library(name: "DanperCloudBridge", targets: ["DanperCloudBridge"])], targets: [.target(name: "DanperCloudBridge"), .testTarget(name: "DanperCloudBridgeTests", dependencies: ["DanperCloudBridge"])])
