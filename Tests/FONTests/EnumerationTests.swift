import XCTest
@testable import FON


// ==================== ENUMERATION ====================

final class EnumerationTests: XCTestCase {

    func testKeysKeepInsertionOrderAndKinds() throws {
        let col = FonCollection()
        try col.addString(key: "b", value: "first")
        try col.addIntArray(key: "a", value: [1, 2])
        try col.addDouble(key: "c", value: 0.5)
        XCTAssertEqual(try col.keys(), ["b", "a", "c"])
        let entries: [(key: String, kind: FonKind?)] = try col.keyEntries()
        XCTAssertEqual(entries.map { $0.key }, ["b", "a", "c"])
        XCTAssertEqual(entries.map { $0.kind }, [
            FonKind(type: .string, isArray: false),
            FonKind(type: .int, isArray: true),
            FonKind(type: .double, isArray: false),
        ])
        XCTAssertEqual(col.kind(key: "b"), FonKind(type: .string, isArray: false))
        XCTAssertEqual(col.kind(key: "a"), FonKind(type: .int, isArray: true))
        XCTAssertEqual(col.kind(key: "c"), FonKind(type: .double, isArray: false))
        XCTAssertEqual(col.count, 3)
        XCTAssertTrue(col.contains(key: "a"))
        XCTAssertFalse(col.contains(key: "z"))
    }

    func testEmptyCollectionHasNoKeys() throws {
        let col = FonCollection()
        XCTAssertEqual(try col.keys(), [])
        XCTAssertEqual(col.count, 0)
    }

    func testDumpIdsAscendingAfterSparseAddsAndRemovals() throws {
        let dump = FonDump()
        for id in [5, 1, 9, 3, 7] {
            try dump.add(id: UInt64(id), collection: FonCollection())
        }
        XCTAssertEqual(try dump.ids(), [1, 3, 5, 7, 9])
        XCTAssertEqual(try dump.remove(id: 1), true)
        XCTAssertEqual(try dump.remove(id: 7), true)
        XCTAssertEqual(try dump.ids(), [3, 5, 9])
        try dump.add(id: 2, collection: FonCollection())
        XCTAssertEqual(try dump.ids(), [2, 3, 5, 9])
        XCTAssertEqual(try dump.ids().count, dump.count)
    }

    func testIterationYieldsIdsInAscendingOrder() throws {
        let dump = FonDump()
        for id in [4, 2, 8] {
            let record = FonCollection()
            try record.addInt(key: "id", value: Int32(id))
            try dump.add(id: UInt64(id), collection: record)
        }
        var seen: [UInt64] = []
        for (id, record) in dump {
            seen.append(id)
            XCTAssertEqual(try record.getInt(key: "id"), Int32(id))
        }
        XCTAssertEqual(seen, [2, 4, 8])
    }

    func testEnumerating100kRecordDumpIsFast() throws {
        let dump = FonDump()
        for index in 0..<100_000 {
            let record = FonCollection()
            try record.addInt(key: "i", value: Int32(index))
            try dump.add(id: UInt64(index), collection: record)
        }
        let loaded: FonDump = try roundTripDump(dump)
        XCTAssertEqual(loaded.count, 100_000)

        let start: Date = Date()
        var visited: Int = 0
        for _ in loaded {
            visited += 1
        }
        let elapsed: TimeInterval = Date().timeIntervalSince(start)

        XCTAssertEqual(visited, 100_000)
        XCTAssertLessThan(elapsed, 2.0, "enumerating 100 000 records took \(elapsed) s")
    }
}
