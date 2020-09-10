// swift-tools-version:5.0

import PackageDescription

let package = Package(
    name: "Carting",
    products: [
        .executable(name: "Carting", targets: ["Carting"]),
        .library(name: "Carting", targets: ["CartingCore"])
    ],
    dependencies: [
        .package(url: "https://github.com/JohnSundell/Files.git", from: "4.1.1"),
        .package(url: "https://github.com/JohnSundell/ShellOut.git", from: "2.3.0"),
        .package(url: "https://github.com/apple/swift-argument-parser", from: "0.3.1"),
        .package(url: "https://github.com/tuist/xcodeproj.git", .upToNextMajor(from: "7.14.0"))
    ],
    targets: [
        .target(name: "Carting", dependencies: ["CartingCore", "ArgumentParser"]),
        .target(name: "CartingCore", dependencies: ["Files", "ShellOut", "XcodeProj"])
    ]
)
