// swift-tools-version: 5.9
//
// FON.swift — Swift package for the FON (Fast Object Notation) format.
//
// Build strategy (build-from-source via submodule):
//   1. Build the native library first:
//        cargo build --release --manifest-path native/Cargo.toml
//   2. Then run swift build / swift test.
//
// The `CFonNative` target links the native library `fon_native`
// (`libfon_native.dylib` on macOS, `libfon_native.so` on Linux, `fon_native.dll`
// on Windows).

import PackageDescription
import Foundation


// native/target/release next to this Package.swift.
let repoRoot: String = URL(fileURLWithPath: #file).deletingLastPathComponent().path
let nativeReleaseDir: String = repoRoot + "/native/target/release"

// When the library was built inside this checkout (development, CI, or a path
// dependency), its directory is added to the linker search path. SwiftPM rejects
// such flags in a versioned dependency, so there the flag is left out and the
// consumer supplies the directory instead: swift build -Xlinker -L<dir>.
let nativeLinkerSettings: [LinkerSetting] = FileManager.default.fileExists(atPath: nativeReleaseDir)
    ? [.linkedLibrary("fon_native"), .unsafeFlags(["-L\(nativeReleaseDir)"])]
    : [.linkedLibrary("fon_native")]

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
        // CFonNative — the C declarations of the fon_native library.
        //
        // `publicHeadersPath` points at Sources/CFonNative/include/ where
        // fon.h lives.  SwiftPM picks up module.modulemap from
        // Sources/CFonNative/ for this regular target.
        // ──────────────────────────────────────────────────────────────────
        .target(
            name: "CFonNative",
            path: "Sources/CFonNative",
            publicHeadersPath: "include",
            cSettings: [
                .headerSearchPath("include"),
            ],
            linkerSettings: nativeLinkerSettings
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
