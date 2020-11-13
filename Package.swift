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
            url: "https://github.com/wultra/cc7/releases/download/0.3.3/openssl-1.1.1h.xcframework.zip",
            checksum: "1d4f781f19eee2dee63069e244b8d0ae9431d1354d55a8351043491c2e91a637")
    ]
)
