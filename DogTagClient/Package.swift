// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "DogTagClient",
    platforms: [
        .macOS(.v12)
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "DogTagClient",
            targets: ["DogTagClient"]),
    ],
    dependencies: [
        // Local path dependency to DogTagStorage
        .package(url: "https://github.com/webauthnai/DogTagStorage.git", from: "1.0.1")
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "DogTagClient",
            dependencies: ["DogTagStorage"],
            exclude: ["SignatureCounterSolutions.md"]
        ),
        .testTarget(
            name: "DogTagClientTests",
            dependencies: ["DogTagClient"]
        ),
    ]
)
