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
            url: "https://github.com/wultra/cc7/releases/download/0.3.1/openssl-1.1.1h.xcframework.zip",
            checksum: "786059205ca88c9dce0a213dbfa3f9b2886edc050cc9b36d2cc777da4f1ffcd0")
    ]
)
