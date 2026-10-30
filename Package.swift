// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "InternetCheck",
    platforms: [.macOS(.v13)],
    dependencies: [.package(url: "https://github.com/PhilRoli/menubar-kit", from: "1.3.0")],
    targets: [
        .executableTarget(
            name: "InternetCheck",
            dependencies: [.product(name: "MenuBarKit", package: "menubar-kit")],
            path: "Sources/InternetCheck"
        ),
        .testTarget(
            name: "InternetCheckTests",
            dependencies: ["InternetCheck", .product(name: "MenuBarKit", package: "menubar-kit")],
            path: "Tests/InternetCheckTests"
        )
    ]
)
