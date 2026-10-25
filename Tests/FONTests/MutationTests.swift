import XCTest
@testable import FON


// ==================== MUTATION ====================

final class MutationTests: XCTestCase {

    /// Dump with records 0, 1, 2; each holds a `row` string equal to its id.
    private func makeNumberedDump() throws -> FonDump {
        let dump = FonDump()
        for id in 0..<3 {
            let record = FonCollection()
            try record.addString(key: "row", value: "row\(id)")
            try dump.add(id: UInt64(id), collection: record)
        }
        return dump
    }

    func testAddExistingKeyThrowsAlreadyExists() throws {
        let col = FonCollection()
        try col.addInt(key: "a", value: 1)
        assertFonError("alreadyExists") { try col.addInt(key: "a", value: 2) }
        XCTAssertEqual(try col.getInt(key: "a"), 1)
    }

    func testSetIsUpsert() throws {
        let col = FonCollection()
        try col.setInt(key: "a", value: 1)
        XCTAssertEqual(try col.getInt(key: "a"), 1)
        try col.setInt(key: "a", value: 2)
        XCTAssertEqual(try col.getInt(key: "a"), 2)
        XCTAssertEqual(try col.keys(), ["a"])
    }

    func testGettersReportNotFoundAndTypeMismatch() throws {
        let col = FonCollection()
        try col.addString(key: "name", value: "x")
        assertFonError("notFound") { try col.getInt(key: "absent") }
        assertFonError("typeMismatch") { try col.getInt(key: "name") }
    }

    func testCollectionRemoveReturnsTrueThenFalse() throws {
        let col = FonCollection()
        try col.addInt(key: "a", value: 1)
        XCTAssertTrue(try col.remove(key: "a"))
        XCTAssertFalse(try col.remove(key: "a"))
        XCTAssertEqual(try col.keys(), [])
    }

    func testDumpReplaceAbsentIdThrowsNotFound() throws {
        let dump = FonDump()
        let record = FonCollection()
        try record.addInt(key: "v", value: 1)
        assertFonError("notFound") { try dump.replace(id: 42, collection: record) }
        XCTAssertEqual(dump.count, 0)
    }

    func testDumpAddExistingIdThrowsAlreadyExists() throws {
        let dump = try makeNumberedDump()
        let record = FonCollection()
        try record.addInt(key: "v", value: 1)
        assertFonError("alreadyExists") { try dump.add(id: 1, collection: record) }
    }

    func testDumpSetIsUpsertAndReplaceReplaces() throws {
        let dump = try makeNumberedDump()
        let replacement = FonCollection()
        try replacement.addString(key: "row", value: "replaced")
        try dump.replace(id: 0, collection: replacement)
        XCTAssertEqual(try dump.get(at: 0)?.getString(key: "row"), "replaced")

        let fresh = FonCollection()
        try fresh.addString(key: "row", value: "fresh")
        try dump.set(id: 9, collection: fresh)
        XCTAssertEqual(try dump.get(at: 9)?.getString(key: "row"), "fresh")
        XCTAssertEqual(dump.count, 4)
    }

    func testDumpRemoveReturnsTrueThenFalse() throws {
        let dump = try makeNumberedDump()
        XCTAssertTrue(try dump.remove(id: 1))
        XCTAssertFalse(try dump.remove(id: 1))
        XCTAssertEqual(dump.count, 2)
        XCTAssertFalse(dump.contains(id: 1))
    }

    func testRemoveManyCountIgnoresAbsentAndDuplicateIds() throws {
        let dump = try makeNumberedDump()
        let removed: Int = try dump.removeMany(ids: [0, 0, 99, 2])
        XCTAssertEqual(removed, 2)
        XCTAssertEqual(try dump.ids(), [1])
    }

    /// Allocates many small buffers so that freed native memory gets reused.
    private func churnAllocations() -> [[UInt8]] {
        return (0..<20000).map { _ in [UInt8](repeating: 0xAA, count: 64) }
    }

    func testViewHeldAcrossNoOpMutationsOnDeserializedDumpStaysValid() throws {
        let dump: FonDump = try roundTripDump(try makeNumberedDump())
        let view: FonCollection = try XCTUnwrap(dump.get(at: 0))

        XCTAssertFalse(try dump.remove(id: 7))
        XCTAssertEqual(try dump.removeMany(ids: []), 0)
        assertFonError("notFound") { try dump.replace(id: 7, collection: FonCollection()) }

        let churn: [[UInt8]] = churnAllocations()
        XCTAssertEqual(churn.count, 20000)
        XCTAssertEqual(try view.getString(key: "row"), "row0")
        XCTAssertEqual(try dump.get(at: 0)?.getString(key: "row"), "row0")
    }

    func testOtherIdsUnchangedAfterRemove() throws {
        let dump = try makeNumberedDump()
        XCTAssertTrue(try dump.remove(id: 1))
        XCTAssertEqual(try dump.get(at: 0)?.getString(key: "row"), "row0")
        XCTAssertEqual(try dump.get(at: 2)?.getString(key: "row"), "row2")
        XCTAssertNil(dump.get(at: 1))
    }

    func testSerializeAfterRemoveRenumbersLines() throws {
        let dump = try makeNumberedDump()
        XCTAssertTrue(try dump.remove(id: 1))
        let text: String = try dump.serialize()
        let lines: [Substring] = text.split(separator: "\n")
        XCTAssertEqual(lines.count, 2)

        let restored: FonDump = try FonDump.deserialize(from: text)
        XCTAssertEqual(try restored.ids(), [0, 1])
        XCTAssertEqual(try restored.get(at: 0)?.getString(key: "row"), "row0")
        XCTAssertEqual(try restored.get(at: 1)?.getString(key: "row"), "row2")
    }

    func testMaxThreadsOneAndTwoSerializeIdenticallyToDefault() throws {
        let dump = FonDump()
        for id in 0..<1000 {
            let record = FonCollection()
            try record.addInt(key: "i", value: Int32(id))
            try record.addString(key: "s", value: "value \(id)")
            try dump.add(id: UInt64(id), collection: record)
        }
        let reference: String = try dump.serialize(maxThreads: 0)
        XCTAssertEqual(try dump.serialize(maxThreads: 1), reference)
        XCTAssertEqual(try dump.serialize(maxThreads: 2), reference)

        XCTAssertEqual(try FonDump.deserialize(from: reference, maxThreads: 1).count, 1000)
        XCTAssertEqual(try FonDump.deserialize(from: reference, maxThreads: 2).count, 1000)
    }

    func testDeserializingMissingFileThrowsFileNotFound() {
        let missing: String = "does-not-exist-\(UUID().uuidString).fon"
        assertFonError("fileNotFound") { try FonDump.deserialize(fromFile: missing) }
    }
}
