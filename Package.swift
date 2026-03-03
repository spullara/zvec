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
            url: "https://github.com/spullara/zvec/releases/download/v0.2.0-ios/zvec.xcframework.zip",
            checksum: "6f595ce98563ddc0b6df2a08de780ea04c1203cd331c6ccb235fde6b5a6655b5"
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

