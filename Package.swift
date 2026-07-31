// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "DisplayWindowMover",
    platforms: [
        .macOS(.v12)
    ],
    products: [
        .executable(name: "monmove", targets: ["monmove"])
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "monmove",
            dependencies: [],
            path: "Sources"
        )
    ]
)
