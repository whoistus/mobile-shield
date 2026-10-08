// swift-tools-version: 5.9
import PackageDescription

let mobileShieldVersion = "0.1.0"

let package = Package(
    name: "mobile_shield",
    platforms: [.iOS("13.0")],
    products: [
        .library(name: "mobile-shield", targets: ["mobile_shield"])
    ],
    targets: [
        .binaryTarget(
            name: "MobileShieldCore",
            path: "Frameworks/MobileShieldCore.xcframework"
        ),
        .target(
            name: "mobile_shield",
            dependencies: ["MobileShieldCore"]
        )
    ]
)
