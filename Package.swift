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
            url: "https://github.com/spullara/zvec/releases/download/v0.3.0-ios/zvec.xcframework.zip",
            checksum: "030cf2b35f44b1ba2d3ecc7d50f98aff8f7d41bd087cc4796bd6472e3a7d32a3"
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

