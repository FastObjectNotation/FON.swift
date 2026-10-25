# FON — Fast Object Notation

[![CI](https://github.com/FastObjectNotation/FON.swift/actions/workflows/ci.yml/badge.svg)](https://github.com/FastObjectNotation/FON.swift/actions/workflows/ci.yml)

A fast, human-readable, line-oriented serialization format — a compact alternative to JSON for record-style data; each line is one record; values are typed and can nest.

## Features

- **Compact, readable wire format** — `key=type:value` pairs, one record per line.
- **Z85 encoding** for raw blobs (5 ASCII characters per 4 bytes).
- **Typed values** — integers from 8 to 64 bits, floats, `bool`, strings, raw bytes and nested collections, with arrays of all of them except raw bytes.
- **Nested objects and arrays of objects**, with a configurable maximum depth.
- **Parallel dump serialization and deserialization**, controlled by `maxThreads`.
- **Editable records and dumps** — add, set, replace and remove fields and records.
- **Safe views** — records and nested values read from a dump keep their owner alive, and stale data is reported as an error instead of being read.

## Format

Each line is one record: a comma-separated list of `key=type:value` pairs. A `.fon` file is a sequence of records. When a dump is loaded, each record id is the 0-based line number of its record.

```
name=s:"John",age=i:30,balance=d:1234.56
scores=i:[95,87,92],tags=s:["admin","user"]
user=o:{id=i:42,name=s:"Bob",addr=o:{city=s:"NY",zip=i:10001}}
items=o:[{id=i:1,qty=i:5},{id=i:2,qty=i:3}]
```

### Type codes

| Code | Swift type | Example                      |
|------|------------|------------------------------|
| `e`  | `UInt8`    | `count=e:255`                |
| `t`  | `Int16`    | `year=t:2024`                |
| `i`  | `Int32`    | `id=i:42`                    |
| `u`  | `UInt32`   | `flags=u:12345`              |
| `l`  | `Int64`    | `ts=l:1700000000`            |
| `g`  | `UInt64`   | `big=g:18446744073709551615` |
| `f`  | `Float`    | `ratio=f:3.14`               |
| `d`  | `Double`   | `pi=d:3.141592653589793`     |
| `s`  | `String`   | `name=s:"Hello"`             |
| `b`  | `Bool`     | `active=b:1`                 |
| `r`  | `[UInt8]`  | `data=r:"00i911"`            |
| `o`  | `FonCollection` | `user=o:{id=i:1}`       |

Every primitive and string type also has an array form (`xs=i:[1,2,3]`). `o` holds either a nested object (`{...}`) or an array of objects (`[{...},{...}]`). Raw bytes have no array form.

## Install

### Requirements

- Swift 5.9 or later.
- A stable Rust toolchain, used to build the native library from source.
- macOS 12 or later, Linux, or Windows with the MSVC toolchain.

### SwiftPM dependency

```swift
// In Package.swift
.package(url: "https://github.com/FastObjectNotation/FON.swift", from: "0.4.0"),
```

SwiftPM does not build the native library `fon_native`. Build it once from a clone:

```bash
git clone --recurse-submodules https://github.com/FastObjectNotation/FON.swift
cargo build --release --manifest-path FON.swift/native/Cargo.toml
```

Then pass the library directory to the linker, and make it visible to the loader at
run time (`DYLD_LIBRARY_PATH` on macOS, `LD_LIBRARY_PATH` on Linux, `PATH` on Windows):

```bash
swift build -Xlinker -L/path/to/FON.swift/native/target/release
```

A path dependency on that clone, `.package(path: "../FON.swift")`, finds the library
directory without the linker flag.

## Usage

### A single record

```swift
import FON

let record = FonCollection()
try record.addInt(key: "id", value: 42)
try record.addString(key: "name", value: "Widget")
try record.addDouble(key: "price", value: 9.99)

// Serialize to a single FON line.
let line = try record.serialize()
// id=i:42,name=s:"Widget",price=d:9.99

// Deserialize back.
let restored = try FonCollection.deserialize(from: line)
let id    = try restored.getInt(key: "id")       // 42
let name  = try restored.getString(key: "name")  // "Widget"
let price = try restored.getDouble(key: "price") // 9.99
```

### Many records

```swift
import FON

let dump = FonDump()
for i in 0..<1000 {
    let record = FonCollection()
    try record.addInt(key: "id", value: Int32(i))
    try record.addString(key: "label", value: "row\(i)")
    // Ownership of `record` transfers to the dump here.
    try dump.add(id: UInt64(i), collection: record)
}

// Serialize the entire dump; maxThreads 0 uses all cores.
let text = try dump.serialize(maxThreads: 0)

// Deserialize back and enumerate the records as (id, record) pairs.
let loaded = try FonDump.deserialize(from: text)
for (id, record) in loaded {
    let label = try record.getString(key: "label")
    print("\(id): \(label)")
}
```

### Nested objects and arrays of objects

```swift
import FON

let address = FonCollection()
try address.addString(key: "city", value: "NY")
try address.addInt(key: "zip", value: 10001)

let user = FonCollection()
try user.addInt(key: "id", value: 42)
try user.addString(key: "name", value: "Bob")
// Ownership of `address` transfers to `user`.
try user.addCollection(key: "addr", value: address)
// id=i:42,name=s:"Bob",addr=o:{city=s:"NY",zip=i:10001}

let row1 = FonCollection()
try row1.addInt(key: "id", value: 1)
try row1.addInt(key: "qty", value: 5)
let row2 = FonCollection()
try row2.addInt(key: "id", value: 2)
try row2.addInt(key: "qty", value: 3)

let order = FonCollection()
try order.addCollectionArray(key: "items", value: [row1, row2])
// items=o:[{id=i:1,qty=i:5},{id=i:2,qty=i:3}]

// Reading nested values returns views of the stored data.
let restored = try FonCollection.deserialize(from: user.serialize())
let city = try restored.getCollection(key: "addr").getString(key: "city")  // "NY"

let items = try FonCollection.deserialize(from: order.serialize())
for row in try items.getCollectionArray(key: "items") {
    print(try row.getInt(key: "qty"))
}
```

### Editing records

Fields can be added, set, read and removed. `add` fails when the key already exists, `set` adds or replaces, and `remove` returns `false` when the key is absent:

```swift
import FON

let record = FonCollection()
try record.addInt(key: "w", value: 3)
try record.addString(key: "name", value: "Box")
try record.setInt(key: "w", value: 6)         // replaces the value
let removed = try record.remove(key: "name")  // true
// try record.addInt(key: "w", value: 1)      // throws FonError.alreadyExists
```

Keys cannot contain `=`, `"`, `{`, `}`, `[`, `]`, carriage return or line feed. A key with any of these characters throws `FonError.invalidArgument`.

Records in a dump are changed the same way:

```swift
import FON

let dump = FonDump()

let a = FonCollection()
try a.addInt(key: "v", value: 1)
try dump.add(id: 1, collection: a)      // throws alreadyExists if id 1 is present

let b = FonCollection()
try b.addInt(key: "v", value: 2)
try dump.replace(id: 1, collection: b)  // throws notFound if id 1 is absent

let c = FonCollection()
try c.addInt(key: "v", value: 3)
try dump.set(id: 2, collection: c)      // adds or replaces

if let record = dump.get(at: 2) {
    try record.setInt(key: "v", value: 30)  // edits the record in place
}

let existed = try dump.remove(id: 1)          // true
let removed = try dump.removeMany(ids: [2, 7]) // 1; absent ids are ignored
```

Ids are stable while the dump is in memory. Serializing the dump writes the records in ascending id order, one per line, so ids are renumbered from 0 when the text is loaded again.

### Binary data and parse options

Raw bytes are stored as `[UInt8]` and written in the `r` form:

```swift
import FON

let blob = FonCollection()
try blob.addRaw(key: "data", value: [0x00, 0x01, 0xFF])
let bytes = try blob.getRaw(key: "data")  // [0, 1, 255]
// data=r:"00i911"
```

`serialize(maxThreads:)` and `deserialize(from:maxThreads:)` on a dump take the number of worker threads for that call: `0` uses all cores, and a positive value caps the worker threads.

`setRawUnpack(_:)` turns decoding of raw blobs during parsing on or off; it is off by default. `setMaxDepth(_:)` sets the maximum nesting depth, which is 64 by default and at least 1. Both settings are process-wide.

## Memory and lifetime

**Owned collections and dumps** own their native memory. A collection made with `FonCollection()`, returned by `clone()`, or produced by `deserialize` is owned, and so is every `FonDump`. The memory is released when the Swift object is deallocated. There is no explicit close.

**Views** are collections read from a dump (`dump.get(at:)`, iteration over the dump) or from another collection (`getCollection(key:)`, `getCollectionArray(key:)`). A view never owns native memory. It keeps the dump or collection it was read from alive, so that owner is not freed while the view is in use.

**Stale views.** Every access to a view checks that the data it points to is unchanged, and throws `FonError.staleView` when it is not:

- A record view goes stale when its record is removed or replaced. It stays valid through repeated `set` calls on itself, and a view of another id is unaffected.
- A nested view goes stale when any field inside its record changes, including a change made through another view of the same record. A change made through a nested view keeps that view valid.
- A nested view of an owned collection goes stale after that collection is changed.

Read the value again from the owner after a view becomes stale.

**Ownership transfer.** Storing a collection with `addCollection`, `setCollection`, `addCollectionArray`, `setCollectionArray`, or a dump's `add`, `set` or `replace` transfers ownership of the stored argument:

- The argument must be an owned collection. Storing a view throws `FonError.invalidArgument`; call `clone()` on the view first.
- A collection cannot be stored inside itself or inside a view of itself, and the same collection cannot appear twice in one array.
- On success the argument is consumed, and any later use of it throws `FonError.nullHandle`.
- On failure the argument stays owned and usable.

**Copies.** `clone()` returns an owned deep copy of a collection, whether it is owned or a view. Changes to the copy do not affect the original.

**Errors.** Failed calls throw a `FonError` case, each carrying a message: `notFound` (key or id absent), `typeMismatch` (key holds another type), `alreadyExists` (`add` on an existing key or id), `staleView`, `invalidArgument`, `nullHandle`, `bufferTooSmall`, `fileNotFound`, `parseFailed` and `writeFailed`.

## API

### FonCollection

| Member | Description |
|--------|-------------|
| `init()` | Creates an empty owned collection. |
| `count: Int` | Number of fields. |
| `contains(key:) -> Bool` | `true` when `key` is present. |
| `kind(key:) -> FonKind?` | Type and array flag of a field, or `nil` when absent. |
| `keys() throws -> [String]` | Keys in insertion order. |
| `remove(key:) throws -> Bool` | Removes a field; `false` when absent. |
| `clone() throws -> FonCollection` | Returns an owned deep copy. |
| `serialize() throws -> String` | Serializes the collection to one FON line. |
| `FonCollection.deserialize(from:) throws -> FonCollection` | Parses one FON line into an owned collection. |

Each field kind has an `add`, `set` and `get` method. `add` and `set` take `key:` and `value:` and return the collection, so calls can be chained. `get` takes `key:`.

| Kind | Swift type | Methods |
|------|------------|---------|
| byte | `UInt8` | `addByte`, `setByte`, `getByte` |
| short | `Int16` | `addShort`, `setShort`, `getShort` |
| int | `Int32` | `addInt`, `setInt`, `getInt` |
| uint | `UInt32` | `addUInt`, `setUInt`, `getUInt` |
| long | `Int64` | `addLong`, `setLong`, `getLong` |
| ulong | `UInt64` | `addULong`, `setULong`, `getULong` |
| float | `Float` | `addFloat`, `setFloat`, `getFloat` |
| double | `Double` | `addDouble`, `setDouble`, `getDouble` |
| bool | `Bool` | `addBool`, `setBool`, `getBool` |
| string | `String` | `addString`, `setString`, `getString` |
| raw | `[UInt8]` | `addRaw`, `setRaw`, `getRaw` |
| byte array | `[UInt8]` | `addByteArray`, `setByteArray`, `getByteArray` |
| short array | `[Int16]` | `addShortArray`, `setShortArray`, `getShortArray` |
| int array | `[Int32]` | `addIntArray`, `setIntArray`, `getIntArray` |
| uint array | `[UInt32]` | `addUIntArray`, `setUIntArray`, `getUIntArray` |
| long array | `[Int64]` | `addLongArray`, `setLongArray`, `getLongArray` |
| ulong array | `[UInt64]` | `addULongArray`, `setULongArray`, `getULongArray` |
| float array | `[Float]` | `addFloatArray`, `setFloatArray`, `getFloatArray` |
| double array | `[Double]` | `addDoubleArray`, `setDoubleArray`, `getDoubleArray` |
| bool array | `[Bool]` | `addBoolArray`, `setBoolArray`, `getBoolArray` |
| string array | `[String]` | `addStringArray`, `setStringArray`, `getStringArray` |
| collection | `FonCollection` | `addCollection(key:value:)`, `setCollection(key:value:)`, `getCollection(key:)` |
| collection array | `[FonCollection]` | `addCollectionArray(key:value:)`, `setCollectionArray(key:value:)`, `getCollectionArray(key:)` |

`getCollection` and `getCollectionArray` return views. The `add` and `set` methods for collections transfer ownership of their argument (see Memory and lifetime).

### FonDump

| Member | Description |
|--------|-------------|
| `init()` | Creates an empty dump. |
| `count: Int` | Number of records. |
| `contains(id:) -> Bool` | `true` when a record with `id` exists. |
| `ids() throws -> [UInt64]` | Ids in ascending order. |
| `get(at:) -> FonCollection?` | Returns a view of the record with `id`, or `nil`. |
| `for (id, record) in dump` | Enumerates the records as `(id, view)` pairs in ascending id order. |
| `add(id:collection:) throws` | Adds a record. Throws `alreadyExists` when `id` is present. |
| `set(id:collection:) throws` | Adds a record, or replaces the record under `id`. |
| `replace(id:collection:) throws` | Replaces an existing record. Throws `notFound` when `id` is absent. |
| `remove(id:) throws -> Bool` | Removes a record; `false` when absent. |
| `removeMany(ids:) throws -> Int` | Removes the records that exist and returns how many were removed. |
| `serialize(maxThreads:) throws -> String` | Serializes the dump, one record per line. |
| `serialize(toFile:maxThreads:) throws` | Writes the dump to a `.fon` file. |
| `FonDump.deserialize(from:maxThreads:) throws -> FonDump` | Parses FON text into a dump. |
| `FonDump.deserialize(fromFile:maxThreads:) throws -> FonDump` | Reads a `.fon` file. Throws `fileNotFound` when the file does not exist. |

### Module-level functions and types

| Name | Description |
|------|-------------|
| `nativeVersion() -> String` | Version of the native library. |
| `setRawUnpack(_ enable: Bool)` | Turns decoding of raw blobs during parsing on or off (off by default). |
| `setMaxDepth(_ depth: Int32)` | Sets the maximum nesting depth (64 by default, at least 1). |
| `FonKind` | Struct with `type: FonType` and `isArray: Bool`, returned by `kind(key:)`. |
| `FonType` | Enum of the field types: `byte`, `short`, `int`, `uint`, `long`, `ulong`, `float`, `double`, `bool`, `string`, `raw`, `object`. |
| `FonError` | Error enum described in Memory and lifetime. |

## Build and test

```bash
git clone --recurse-submodules https://github.com/FastObjectNotation/FON.swift
cd FON.swift

# 1. Build the native library
cargo build --release --manifest-path native/Cargo.toml

# 2. Build and test the Swift package
swift build
swift test
```

The built library is placed in `native/target/release/`, and `Package.swift` adds that directory to the linker search path.

On Windows with the MSVC toolchain, cargo writes `native/target/release/fon_native.dll` and its import library `fon_native.dll.lib`, and the build links against them without extra flags. The test process loads `fon_native.dll` when it starts, so put the release directory on `PATH` before running the tests. Without it, `swift test` exits before any test runs:

```powershell
cargo build --release --manifest-path native/Cargo.toml
swift build
$env:PATH = "$PWD\native\target\release;$env:PATH"
swift test
```
