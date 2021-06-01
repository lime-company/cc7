// swift-tools-version:5.3
import PackageDescription

let package = Package(
    name: "openssl",
    platforms: [
        .iOS(.v9),
        .tvOS(.v9)
    ],
    products: [
        .library(name: "openssl", targets: ["openssl"])
    ],
    targets: [
        .binaryTarget(
            name: "openssl",
            url: "https://github.com/wultra/cc7/releases/download/0.3.4/openssl-1.1.1h.xcframework.zip",
            checksum: "5d0fe6e2593421d937c57e988d0734041ecb44be7c6dc6db941836549ae27f50")
    ]
)
