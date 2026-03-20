// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "MediaRemoteKit",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "MediaRemoteKit",
            targets: ["MediaRemoteKit"]
        ),
    ],
    targets: [
        .target(
            name: "MediaRemoteKit",
            dependencies: [],
            resources: [
                .copy("Resources")
            ]
        ),
        .testTarget(
            name: "MediaRemoteKitTests",
            dependencies: ["MediaRemoteKit"]
        ),
    ]
)
