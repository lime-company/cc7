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
            url: "https://github.com/wultra/cc7/releases/download/0.3.2/openssl-1.1.1h.xcframework.zip",
            checksum: "581ed53913f101bac718b166ab348033bd8e9dcc60632b341ffc7fbc92752411")
    ]
)
