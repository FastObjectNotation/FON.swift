import XCTest
@testable import FON


final class FONTests: XCTestCase {

    // ==================== VERSION ====================

    func testNativeVersion() {
        XCTAssertEqual(nativeVersion(), "0.2.1")
    }

    // ==================== ROUNDTRIP: DUMP ====================

    func testDumpRoundtrip() throws {
        // Build a collection with id, name, price.
        let collection = FonCollection()
        try collection.addInt(key: "id", value: 42)
        try collection.addString(key: "name", value: "Widget")
        try collection.addDouble(key: "price", value: 9.99)

        // Add to a dump.
        let dump = FonDump()
        try dump.add(id: 0, collection: collection)

        XCTAssertEqual(dump.count, 1)

        // Serialize dump to string.
        let serialized = try dump.serialize()
        XCTAssertFalse(serialized.isEmpty)

        // Deserialize back.
        let loaded = try FonDump.deserialize(from: serialized)
        XCTAssertEqual(loaded.count, 1)

        // Inspect the first collection.
        guard let record = loaded.get(at: 0) else {
            XCTFail("Expected collection at index 0")
            return
        }

        XCTAssertEqual(try record.getInt(key: "id"), 42)
        XCTAssertEqual(try record.getString(key: "name"), "Widget")
        XCTAssertEqual(try record.getDouble(key: "price"), 9.99, accuracy: 1e-9)
    }

    // ==================== ROUNDTRIP: SINGLE COLLECTION ====================

    func testCollectionRoundtrip() throws {
        let col = FonCollection()
        try col.addInt(key: "x", value: 100)
        try col.addBool(key: "active", value: true)
        try col.addString(key: "tag", value: "test")

        let line = try col.serialize()
        XCTAssertFalse(line.isEmpty)

        let restored = try FonCollection.deserialize(from: line)
        XCTAssertEqual(try restored.getInt(key: "x"), 100)
        XCTAssertEqual(try restored.getBool(key: "active"), true)
        XCTAssertEqual(try restored.getString(key: "tag"), "test")
    }

    // ==================== SCALAR TYPES ====================

    func testScalarTypes() throws {
        let col = FonCollection()
        try col.addInt(key: "i", value: -1)
        try col.addLong(key: "l", value: 9_000_000_000)
        try col.addFloat(key: "f", value: 3.14)
        try col.addDouble(key: "d", value: 2.718281828)
        try col.addBool(key: "b", value: false)
        try col.addString(key: "s", value: "hello")

        let line = try col.serialize()
        let r = try FonCollection.deserialize(from: line)

        XCTAssertEqual(try r.getInt(key: "i"), -1)
        XCTAssertEqual(try r.getLong(key: "l"), 9_000_000_000)
        XCTAssertEqual(try r.getFloat(key: "f"), 3.14, accuracy: 1e-5)
        XCTAssertEqual(try r.getDouble(key: "d"), 2.718281828, accuracy: 1e-9)
        XCTAssertEqual(try r.getBool(key: "b"), false)
        XCTAssertEqual(try r.getString(key: "s"), "hello")
    }

    // ==================== ARRAYS ====================

    func testIntArray() throws {
        let col = FonCollection()
        try col.addIntArray(key: "nums", values: [1, 2, 3, 4, 5])

        let line = try col.serialize()
        let r = try FonCollection.deserialize(from: line)

        let nums = try r.getIntArray(key: "nums")
        XCTAssertEqual(nums, [1, 2, 3, 4, 5])
    }

    func testFloatArray() throws {
        let col = FonCollection()
        try col.addFloatArray(key: "vals", values: [1.0, 2.5, 3.75])

        let line = try col.serialize()
        let r = try FonCollection.deserialize(from: line)

        let vals = try r.getFloatArray(key: "vals")
        XCTAssertEqual(vals.count, 3)
        XCTAssertEqual(vals[0], 1.0, accuracy: 1e-6)
        XCTAssertEqual(vals[1], 2.5, accuracy: 1e-6)
        XCTAssertEqual(vals[2], 3.75, accuracy: 1e-6)
    }

    // ==================== MULTIPLE RECORDS ====================

    func testMultipleRecords() throws {
        let dump = FonDump()

        for i in 0..<10 {
            let col = FonCollection()
            try col.addInt(key: "idx", value: Int32(i))
            try col.addString(key: "label", value: "row\(i)")
            try dump.add(id: UInt64(i), collection: col)
        }

        let text = try dump.serialize()
        let loaded = try FonDump.deserialize(from: text)

        XCTAssertEqual(loaded.count, 10)

        for i in 0..<10 {
            guard let r = loaded.get(at: UInt64(i)) else {
                XCTFail("Missing record \(i)")
                continue
            }
            XCTAssertEqual(try r.getInt(key: "idx"), Int32(i))
            XCTAssertEqual(try r.getString(key: "label"), "row\(i)")
        }
    }

    // ==================== COLLECTION ARRAY ROUNDTRIP ====================

    func testCollectionArrayRoundtrip() throws {
        // Build three child collections (objects).
        let child0 = FonCollection()
        try child0.addInt(key: "id", value: 10)
        try child0.addString(key: "name", value: "alpha")

        let child1 = FonCollection()
        try child1.addInt(key: "id", value: 20)
        try child1.addString(key: "name", value: "beta")

        let child2 = FonCollection()
        try child2.addInt(key: "id", value: 30)
        try child2.addString(key: "name", value: "gamma")

        // Nest them as an array of objects inside a parent collection.
        let parent = FonCollection()
        try parent.addCollectionArray(key: "items", children: [child0, child1, child2])

        // Roundtrip through string serialization.
        let line = try parent.serialize()
        XCTAssertFalse(line.isEmpty)

        let restored = try FonCollection.deserialize(from: line)

        // Retrieve the array and verify each element.
        let items = try restored.getCollectionArray(key: "items")
        XCTAssertEqual(items.count, 3)

        XCTAssertEqual(try items[0].getInt(key: "id"), 10)
        XCTAssertEqual(try items[0].getString(key: "name"), "alpha")

        XCTAssertEqual(try items[1].getInt(key: "id"), 20)
        XCTAssertEqual(try items[1].getString(key: "name"), "beta")

        XCTAssertEqual(try items[2].getInt(key: "id"), 30)
        XCTAssertEqual(try items[2].getString(key: "name"), "gamma")
    }

    // ==================== FILE ROUNDTRIP ====================

    func testFileRoundtrip() throws {
        // Build a dump with two collections.
        let dump = FonDump()

        let col0 = FonCollection()
        try col0.addInt(key: "seq", value: 1)
        try col0.addString(key: "msg", value: "first")
        try dump.add(id: 0, collection: col0)

        let col1 = FonCollection()
        try col1.addInt(key: "seq", value: 2)
        try col1.addString(key: "msg", value: "second")
        try dump.add(id: 1, collection: col1)

        // Write to a temp file.
        let tmpDir = FileManager.default.temporaryDirectory
        let tmpFile = tmpDir.appendingPathComponent("fon_test_\(UUID().uuidString).fon")
        let path = tmpFile.path

        defer {
            try? FileManager.default.removeItem(atPath: path)
        }

        try dump.serialize(toFile: path)
        XCTAssertTrue(FileManager.default.fileExists(atPath: path))

        // Read it back.
        let loaded = try FonDump.deserialize(fromFile: path)
        XCTAssertEqual(loaded.count, 2)

        guard let r0 = loaded.get(at: 0), let r1 = loaded.get(at: 1) else {
            XCTFail("Expected two records in loaded dump")
            return
        }

        XCTAssertEqual(try r0.getInt(key: "seq"), 1)
        XCTAssertEqual(try r0.getString(key: "msg"), "first")

        XCTAssertEqual(try r1.getInt(key: "seq"), 2)
        XCTAssertEqual(try r1.getString(key: "msg"), "second")
    }
}
