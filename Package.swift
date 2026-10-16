// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Hycrypt",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "Hycrypt", targets: ["HycryptApp"]),
        .library(name: "HycryptCore", targets: ["HycryptCore"]),
    ],
    dependencies: [
        .package(url: "https://github.com/weichsel/ZIPFoundation.git", exact: "0.9.20")
    ],
    targets: [
        .target(
            name: "CArgon2", path: "Vendor/argon2",
            sources: [
                "src/argon2.c", "src/core.c", "src/blake2/blake2b.c",
                "src/thread.c", "src/encoding.c", "src/ref.c",
            ], publicHeadersPath: "include", cSettings: [.headerSearchPath("src")]),
        // Owns Argon2 workspace cleanup; Vendor/argon2 stays byte-for-byte upstream.
        .target(name: "CArgon2Shim", dependencies: ["CArgon2"]),
        .target(name: "HycryptCore", dependencies: ["CArgon2", "CArgon2Shim", "ZIPFoundation"]),
        .executableTarget(name: "HycryptApp", dependencies: ["HycryptCore"]),
        .testTarget(
            name: "HycryptCoreTests", dependencies: ["HycryptCore", "ZIPFoundation"]),
        .testTarget(name: "HycryptAppTests", dependencies: ["HycryptApp"]),
    ]
)
