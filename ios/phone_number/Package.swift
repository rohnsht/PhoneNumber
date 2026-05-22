// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "phone_number",
    platforms: [
        .iOS("13.0")
    ],
    products: [
        .library(name: "phone-number", targets: ["phone_number"])
    ],
    dependencies: [
        .package(name: "FlutterFramework", path: "../FlutterFramework"),
        .package(url: "https://github.com/marmelroy/PhoneNumberKit.git", from: "4.2.0")
    ],
    targets: [
        .target(
            name: "phone_number",
            dependencies: [
                .product(name: "FlutterFramework", package: "FlutterFramework"),
                .product(name: "PhoneNumberKit", package: "PhoneNumberKit")
            ]
        )
    ]
)
