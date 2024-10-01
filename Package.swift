// swift-tools-version:5.4
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "pixivloader",
    platforms: [.macOS(.v10_13)],
    products: [
        .executable(name: "pixivloader", targets: ["pixivloader"])
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "0.3.0"),
        .package(url: "https://github.com/theBreadCompany/pixivswift.git", from: "1.1.0"),
        .package(url: "https://github.com/theBreadCompany/swiftbar.git", .branchItem("main"))
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
        .executableTarget(
            name: "pixivloader",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .product(name: "pixivswiftWrapper", package: "pixivswift"),
                .product(name: "pixivauth", package: "pixivswift"),
                .product(name: "swiftbar", package: "swiftbar")]),
    ]
)
