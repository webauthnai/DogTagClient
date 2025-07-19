// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "DogTagClient",
    platforms: [
        .macOS(.v14) // Updated to support SwiftData requirements
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "DogTagClient",
            targets: ["DogTagClient"]),
    ],
    dependencies: [
        // External dependency to DogTagStorage - ensure this repository exists and is accessible
        .package(url: "https://github.com/webauthnai/DogTagStorage.git", from: "1.0.3")
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "DogTagClient",
            dependencies: ["DogTagStorage"],
            exclude: ["SignatureCounterSolutions.md", "KEY_ACCESS_FIXES.md"]
        ),
        .testTarget(
            name: "DogTagClientTests",
            dependencies: ["DogTagClient"]
        ),
    ]
)
