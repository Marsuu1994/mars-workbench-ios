// swift-tools-version: 6.0
import PackageDescription

// Everything the app does that needs no iOS framework: the entry rules, the
// outbox on disk, the API client and the sync loop. Foundation only, so it
// builds and tests on Linux too (`swift test`), where cloud sessions and CI run.
let package = Package(
    name: "DumpCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "DumpCore", targets: ["DumpCore"])
    ],
    targets: [
        .target(name: "DumpCore"),
        .testTarget(name: "DumpCoreTests", dependencies: ["DumpCore"]),
    ]
)
