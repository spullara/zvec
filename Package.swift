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
            path: "build-xcframework/zvec.xcframework"
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
                .unsafeFlags(["-Xlinker", "-ObjC"]),
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

