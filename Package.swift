// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Liris",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "Liris", targets: ["LirisApp"]), .executable(name: "LirisBridge", targets: ["LirisBridge"])],
    targets: [
        .target(name: "LirisCore"),
        .executableTarget(name: "LirisBridge", dependencies: ["LirisCore"]),
        .executableTarget(name: "LirisApp", dependencies: ["LirisCore"], resources: [.copy("Resources")]),
        .testTarget(name: "LirisCoreTests", dependencies: ["LirisCore"]),
        .testTarget(name: "LirisAppTests", dependencies: ["LirisApp"])
    ]
)
