// swift-tools-version: 6.3
import PackageDescription

let package = Package(
    name: "xppen-utility",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "XPPenCore", targets: ["XPPenCore"]),
    ],
    targets: [
        .target(
            name: "XPPenCore"
        ),
        .executableTarget(
            name: "xppen-utility",
            dependencies: ["XPPenCore"]
        ),
        .executableTarget(
            name: "ack05-daemon",
            dependencies: ["XPPenCore"]
        ),
        .testTarget(
            name: "ack05-daemonTests",
            dependencies: ["ack05-daemon"]
        ),
        .executableTarget(
            name: "xppen-config-app",
            dependencies: ["XPPenCore"]
        ),
        .testTarget(
            name: "XPPenCoreTests",
            dependencies: ["XPPenCore"]
        ),
        .testTarget(
            name: "xppen-utilityTests",
            dependencies: ["xppen-utility"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
