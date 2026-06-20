// swift-tools-version: 5.9
//
// FON.swift — Swift package for the FON (Fast Object Notation) format.
//
// Build strategy (build-from-source via submodule):
//   1. Build the native library first:
//        cargo build --release --manifest-path native/Cargo.toml
//   2. Then run swift build / swift test.
//
// The `CFonNative` target links the built native library.  The linker search
// path is provided via unsafeFlags pointing at `native/target/release/`.
// On macOS the library is `libfon_native.dylib`; on Linux it is `libfon_native.so`.

import PackageDescription
import Foundation


// Resolve the path to native/target/release relative to this Package.swift.
// On macOS / Linux `#file` gives the source path; we walk two levels up from
// `Package.swift` to the repo root, then into native/target/release.
let repoRoot = URL(fileURLWithPath: #file).deletingLastPathComponent().path
let nativeReleaseDir = repoRoot + "/native/target/release"

let package = Package(
    name: "FON",
    platforms: [
        .macOS(.v12),
    ],
    products: [
        .library(
            name: "FON",
            targets: ["FON"]
        ),
    ],
    targets: [
        // ──────────────────────────────────────────────────────────────────
        // CFonNative — thin C-module wrapper around the fon_native cdylib.
        //
        // `publicHeadersPath` points at Sources/CFonNative/include/ where
        // fon.h lives.  The module.modulemap in Sources/CFonNative/ is picked
        // up automatically by SwiftPM because the target is a `systemLibrary`
        // (we use a regular `target` here so SwiftPM handles the modulemap).
        // ──────────────────────────────────────────────────────────────────
        .target(
            name: "CFonNative",
            path: "Sources/CFonNative",
            publicHeadersPath: "include",
            cSettings: [
                .headerSearchPath("include"),
            ],
            linkerSettings: [
                .linkedLibrary("fon_native"),
                .unsafeFlags(["-L\(nativeReleaseDir)"]),
            ]
        ),

        // ──────────────────────────────────────────────────────────────────
        // FON — the idiomatic Swift API layer.
        // ──────────────────────────────────────────────────────────────────
        .target(
            name: "FON",
            dependencies: ["CFonNative"],
            path: "Sources/FON"
        ),

        // ──────────────────────────────────────────────────────────────────
        // FONTests — XCTest suite.
        // ──────────────────────────────────────────────────────────────────
        .testTarget(
            name: "FONTests",
            dependencies: ["FON"],
            path: "Tests/FONTests"
        ),
    ]
)
