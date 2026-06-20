# FON — Fast Object Notation (Swift)

[![CI](https://github.com/FastObjectNotation/FON.swift/actions/workflows/ci.yml/badge.svg)](https://github.com/FastObjectNotation/FON.swift/actions/workflows/ci.yml)

Swift binding for [FON](https://github.com/FastObjectNotation/FON.rust) — a fast, human-readable,
line-oriented serialization format. A compact alternative to JSON for record-style data. Each line
is one record; values are typed and can nest.

The binding wraps a Rust cdylib shim (`fon_native`) via a C header, exposing an idiomatic Swift
API built around `FonCollection` and `FonDump`.

## Features

- **Compact, readable wire format** — `key=type:value` pairs, one record per line.
- **Typed values** — numeric/bool/string primitives, nested objects, and arrays of any of them.
- **Nested objects & arrays of objects** with a configurable maximum depth.
- **Parallel** dump serialization and deserialization via Rayon (configured with `maxThreads`).
- **Idiomatic Swift API** — `FonCollection` and `FonDump` classes with `throws`-based error handling.
- **Build-from-source** — no pre-built binary blobs; the Rust shim is compiled from the bundled
  git submodule.

## Format

Each line is one record: a comma-separated list of `key=type:value` pairs. A `.fon` file is a
sequence of records, indexed by line number (0-based).

```
name=s:"John",age=i:30,balance=d:1234.56
scores=i:[95,87,92],tags=s:["admin","user"]
user=o:{id=i:42,name=s:"Bob",addr=o:{city=s:"NY",zip=i:10001}}
items=o:[{id=i:1,qty=i:5},{id=i:2,qty=i:3}]
```

### Type codes

| Code | Native type     | Example                      |
|------|-----------------|------------------------------|
| `e`  | `u8`            | `count=e:255`                |
| `t`  | `i16`           | `year=t:2024`                |
| `i`  | `i32`           | `id=i:42`                    |
| `u`  | `u32`           | `flags=u:12345`              |
| `l`  | `i64`           | `ts=l:1700000000`            |
| `g`  | `u64`           | `big=g:18446744073709551615` |
| `f`  | `f32`           | `ratio=f:3.14`               |
| `d`  | `f64`           | `pi=d:3.141592653589793`     |
| `s`  | `String`        | `name=s:"Hello"`             |
| `b`  | `bool`          | `active=b:1`                 |
| `r`  | `RawData` (Z85) | `data=r:"nm=QNzv"`           |
| `o`  | `FonCollection` | `user=o:{id=i:1}`            |

Every primitive and string type also has an array form (`xs=i:[1,2,3]`), and `o` supports both
nested objects (`{...}`) and arrays of objects (`[{...},{...}]`).

## Install

### Prerequisites

- Swift 5.9+ (macOS 12+ or Linux with the Swift toolchain)
- Rust (stable) — needed to build the native cdylib

### SwiftPM dependency

```swift
// In Package.swift
.package(url: "https://github.com/FastObjectNotation/FON.swift", from: "0.2.1"),
```

**Important:** because this package builds the native library from source, you must run the Rust
build step before `swift build`:

```bash
git clone --recurse-submodules https://github.com/FastObjectNotation/FON.swift
cd FON.swift
cargo build --release --manifest-path native/Cargo.toml
swift build
```

The compiled `libfon_native` is placed in `native/target/release/`. `Package.swift` adds that
directory to the linker search path automatically via `unsafeFlags`.

## Usage

### Version

```swift
import FON

print(nativeVersion())  // "0.2.1"
```

### A single collection

```swift
import FON

let collection = FonCollection()
try collection.addInt(key: "id", value: 42)
try collection.addString(key: "name", value: "Widget")
try collection.addDouble(key: "price", value: 9.99)

// Serialize to a single FON line.
let line = try collection.serialize()
// id=i:42,name=s:"Widget",price=d:9.99

// Deserialize back.
let restored = try FonCollection.deserialize(from: line)
let id    = try restored.getInt(key: "id")     // 42
let name  = try restored.getString(key: "name") // "Widget"
let price = try restored.getDouble(key: "price") // 9.99
```

### Many records (dump)

```swift
import FON

let dump = FonDump()
for i in 0..<1000 {
    let col = FonCollection()
    try col.addInt(key: "id", value: Int32(i))
    try col.addString(key: "label", value: "row\(i)")
    // Ownership of `col` transfers to the dump here.
    try dump.add(id: UInt64(i), collection: col)
}

// Serialize the entire dump (parallel with maxThreads; 0 = global pool).
let text = try dump.serialize(maxThreads: 0)

// Deserialize back.
let loaded = try FonDump.deserialize(from: text)
for i in 0..<loaded.count {
    if let r = loaded.get(at: UInt64(i)) {
        let label = try r.getString(key: "label")
        print("\(i): \(label)")
    }
}
```

### Ownership rules

`FonCollection` owns its native handle until it is transferred:

- `dump.add(id:collection:)` — transfers ownership to the dump; do not use `collection` afterwards.
- `collection.addCollection(key:child:)` — transfers `child` to the parent collection.

Borrowed handles (from `dump.get(at:)` and `collection.getCollection(key:)`) must not be freed and
are only valid while the owning object is alive.

### Supported types

| Swift API            | FON type |
|----------------------|----------|
| `addInt / getInt`    | `i32`    |
| `addLong / getLong`  | `i64`    |
| `addFloat / getFloat`| `f32`    |
| `addDouble / getDouble` | `f64` |
| `addBool / getBool`  | `bool`   |
| `addString / getString` | `String` |
| `addIntArray / getIntArray` | `i32[]` |
| `addFloatArray / getFloatArray` | `f32[]` |
| `addCollection / getCollection` | nested `FonCollection` |

Array-of-collections, `u32`, `u64`, `i16`, `u8`, `RawData` (Z85), and string arrays are exposed
in the C ABI (`fon.h`) but deferred from the Swift idiomatic layer in this version. They can be
called directly via `CFonNative` if needed.

## Build

```bash
# Clone with submodules
git clone --recurse-submodules https://github.com/FastObjectNotation/FON.swift
cd FON.swift

# 1. Build the Rust cdylib
cargo build --release --manifest-path native/Cargo.toml

# 2. Build and test the Swift package
swift build
swift test
```

### Native library distribution

This package uses a **build-from-source** strategy: the Rust shim lives in `native/` as a git
submodule pointing at [FON.rust](https://github.com/FastObjectNotation/FON.rust). CI builds it
fresh on every run.

An alternative approach — shipping a pre-built XCFramework via SwiftPM's `binaryTarget` — would
eliminate the Rust toolchain requirement for consumers but requires per-platform builds and checksum
management in the release workflow. See `.github/workflows/release.yml` for notes on how this would
be implemented.
