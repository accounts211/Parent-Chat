// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ParentChatApp",
    platforms: [
        .iOS(.v15)
    ],
    products: [
        .library(name: "ParentChatApp", targets: ["ParentChatApp"])
    ],
    targets: [
        .target(name: "ParentChatApp", path: ".")
    ]
)
