// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Zvec",
    platforms: [.iOS(.v15), .macCatalyst(.v15), .macOS(.v12)],
    products: [
        .library(name: "Zvec", targets: ["Zvec"])
    ],
    targets: [
        .binaryTarget(
            name: "zvec",
            url: "https://github.com/spullara/zvec/releases/download/v0.1.0-ios/zvec.xcframework.zip",
            checksum: "2934d9e5aa5f9c9abab46897685922ca75cb990ddbc21c97965ebebe5e2b9305"
        ),
        .target(
            name: "CZvec",
            dependencies: ["zvec"],
            path: "Sources/CZvec",
            publicHeadersPath: "include",
            cxxSettings: [
                .headerSearchPath("../../build-xcframework/zvec.xcframework/ios-arm64/Headers"),
                .unsafeFlags(["-std=c++17"]),
            ],
            linkerSettings: [
                .linkedLibrary("c++"),
                .unsafeFlags(["-Xlinker", "-all_load"]),
            ]
        ),
        .target(
            name: "Zvec",
            dependencies: ["CZvec"],
            path: "Sources/Zvec"
        ),
        .testTarget(
            name: "ZvecTests",
            dependencies: ["Zvec"]
        )
    ]
)

