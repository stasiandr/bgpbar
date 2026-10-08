// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "bgpbar",
    platforms: [.macOS(.v15)],
    products: [
        .executable(name: "bgpbar", targets: ["BgpBar"]),
    ],
    targets: [
        .executableTarget(
            name: "BgpBar",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
    ]
)
