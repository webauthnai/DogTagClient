// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "DogTagClient",
    platforms: [
        .macOS(.v14) // Required for SwiftData support
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "DogTagClient",
            targets: ["DogTagClient"]),
    ],
    dependencies: [
        // External dependency to DogTagStorage - ensure this repository exists and is accessible
        .package(url: "https://github.com/webauthnai/DogTagStorage.git", exact: "1.0.2")
    ],
    targets: [
        .target(
            name: "DogTagClient",
            dependencies: ["DogTagStorage"],
        ),
        .testTarget(
            name: "DogTagClientTests",
            dependencies: ["DogTagClient"]
        ),
    ]
)
