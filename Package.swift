// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "xtr-openmail-macos",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "xtr-openmail-macos", targets: ["XtrOpenMail"]),
        .library(name: "MsgKit", targets: ["MsgKit"])
    ],
    targets: [
        // Core: parsing dei file .msg (CFB / MAPI), indipendente dalla UI
        .target(
            name: "MsgKit",
            path: "Sources/MsgKit"
        ),
        // App SwiftUI
        .executableTarget(
            name: "XtrOpenMail",
            dependencies: ["MsgKit"],
            path: "Sources/XtrOpenMail"
        ),
        // Test del parser
        .testTarget(
            name: "MsgKitTests",
            dependencies: ["MsgKit"],
            path: "Tests/MsgKitTests"
        )
    ]
)
