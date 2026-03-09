// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SwiftTavern",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .executable(name: "SwiftTavern", targets: ["SwiftTavern"]),
    ],
    dependencies: [
        .package(url: "https://github.com/jpsim/Yams.git", from: "5.0.0"),
    ],
    targets: [
        .executableTarget(
            name: "SwiftTavern",
            dependencies: ["Yams"],
            path: "Sources/SwiftTavern",
            resources: [
                .process("../../Resources"),
            ]
        ),
        .testTarget(
            name: "SwiftTavernTests",
            dependencies: ["SwiftTavern"],
            path: "Tests/SwiftTavernTests"
        ),
    ]
)
