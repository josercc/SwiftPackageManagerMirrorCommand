// swift-tools-version: 5.6
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SwiftPackageManagerMirrorCommand",
    platforms: [.macOS(.v10_12)],
    products: [
        .executable(name: "spmmc", targets: ["SwiftPackageManagerMirrorCommand"])
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        // .package(url: /* package url */, from: "1.0.0"),
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.0.0"),
        .package(url: "https://github.com/kareman/SwiftShell", from: "5.1.0"),
        .package(url: "https://github.com/Alamofire/Alamofire.git", .upToNextMajor(from: "5.5.0"))
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
        .executableTarget(name: "SwiftPackageManagerMirrorCommand",
                          dependencies: [
                    // other dependencies
                    .product(name: "ArgumentParser", package: "swift-argument-parser"),
                    "SwiftShell",
                    "Alamofire"
                ]),
        .testTarget(
            name: "SwiftPackageManagerMirrorCommandTests",
            dependencies: ["SwiftPackageManagerMirrorCommand"]),
    ]
)
