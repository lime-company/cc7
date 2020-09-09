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
            url: "https://github.com/wultra/cc7/releases/download/0.3.0/openssl-1.1.1g.xcframework.zip",
            checksum: "5d4c39f779ec6b1e56524689b30baffc0fcf16c90e8f9d12c75703edd772dc99")
    ]
)
