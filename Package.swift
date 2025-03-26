// swift-tools-version: 5.10
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "CleanerKit",
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "CleanerKit",
            targets: ["CleanerKit"]),
    ],
    dependencies: [
        // Добавляем зависимость CocoaImageHashing
        .package(url: "https://github.com/ameingast/cocoaimagehashing.git", from: "1.9.0")  // Используйте версию, которая вам нужна
    ],
    targets: [
        // Определение основного таргета
        .target(
            name: "CleanerKit",
            dependencies: ["CocoaImageHashing"]),  // Указываем зависимость для таргета
        // Определение тестового таргета
        .testTarget(
            name: "CleanerKitTests",
            dependencies: ["CleanerKit"]),
    ]
)
