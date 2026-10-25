import XCTest
@testable import FON


// ==================== VIEWS ====================

final class ViewTests: XCTestCase {

    /// Dump with records 0, 1, 2. Each record has `id`, `w`, and two nested collections,
    /// `left` and `right`, each holding a `v` field.
    private func makeDump() throws -> FonDump {
        let dump = FonDump()
        for index in 0..<3 {
            let record = FonCollection()
            try record.addInt(key: "id", value: Int32(index))
            try record.addInt(key: "w", value: 1)

            let left = FonCollection()
            try left.addInt(key: "v", value: 10)
            let right = FonCollection()
            try right.addInt(key: "v", value: 20)
            try record.addCollection(key: "left", value: left)
            try record.addCollection(key: "right", value: right)

            try dump.add(id: UInt64(index), collection: record)
        }
        return dump
    }

    // ==================== RECORD VIEWS ====================

    func testRecordViewSurvivesRepeatedSetOnItself() throws {
        let dump: FonDump = try makeDump()
        let record: FonCollection = try XCTUnwrap(dump.get(at: 0))
        try record.setInt(key: "w", value: 2)
        try record.setInt(key: "w", value: 4)
        XCTAssertEqual(try record.getInt(key: "w"), 4)
        XCTAssertEqual(try record.getInt(key: "id"), 0)
        XCTAssertEqual(try record.getInt(key: "w"), 4)
    }

    func testRecordViewGoesStaleAfterRemove() throws {
        let dump: FonDump = try makeDump()
        let record: FonCollection = try XCTUnwrap(dump.get(at: 0))
        XCTAssertTrue(try dump.remove(id: 0))
        assertFonError("staleView") { try record.getInt(key: "id") }
    }

    func testRecordViewGoesStaleAfterReplace() throws {
        let dump: FonDump = try makeDump()
        let record: FonCollection = try XCTUnwrap(dump.get(at: 0))
        let replacement = FonCollection()
        try replacement.addInt(key: "id", value: 100)
        try dump.replace(id: 0, collection: replacement)
        assertFonError("staleView") { try record.getInt(key: "id") }
    }

    func testRecordViewStaysStaleWhenItsIdIsReused() throws {
        let dump: FonDump = try makeDump()
        let record: FonCollection = try XCTUnwrap(dump.get(at: 0))
        XCTAssertTrue(try dump.remove(id: 0))
        let fresh = FonCollection()
        try fresh.addInt(key: "id", value: 50)
        try dump.add(id: 0, collection: fresh)
        assertFonError("staleView") { try record.getInt(key: "id") }
        XCTAssertEqual(try dump.get(at: 0)?.getInt(key: "id"), 50)
    }

    func testNestedViewStaysStaleWhenItsRecordIdIsReused() throws {
        let dump: FonDump = try makeDump()
        let left: FonCollection = try XCTUnwrap(dump.get(at: 0)).getCollection(key: "left")
        XCTAssertTrue(try dump.remove(id: 0))
        let fresh = FonCollection()
        try fresh.addCollection(key: "left", value: FonCollection())
        try dump.add(id: 0, collection: fresh)
        assertFonError("staleView") { try left.getInt(key: "v") }
    }

    func testViewOfAnotherIdIsUnaffected() throws {
        let dump: FonDump = try makeDump()
        let other: FonCollection = try XCTUnwrap(dump.get(at: 1))
        let zero: FonCollection = try XCTUnwrap(dump.get(at: 0))
        try zero.setInt(key: "w", value: 9)
        let replacement = FonCollection()
        try replacement.addInt(key: "id", value: 50)
        try dump.set(id: 2, collection: replacement)
        XCTAssertEqual(try other.getInt(key: "id"), 1)
        XCTAssertEqual(try other.getInt(key: "w"), 1)
    }

    // ==================== NESTED VIEWS ====================

    func testNestedViewGoesStaleAfterItsFieldIsOverwritten() throws {
        let dump: FonDump = try makeDump()
        let record: FonCollection = try XCTUnwrap(dump.get(at: 0))
        let nested: FonCollection = try record.getCollection(key: "left")
        XCTAssertEqual(try nested.getInt(key: "v"), 10)

        try record.setInt(key: "left", value: 5)

        assertFonError("staleView") { try nested.getInt(key: "v") }
        XCTAssertEqual(try record.getInt(key: "w"), 1)
    }

    func testMutatingThroughNestedViewKeepsItValidAndStalesSiblings() throws {
        let dump: FonDump = try makeDump()
        let record: FonCollection = try XCTUnwrap(dump.get(at: 0))
        let left: FonCollection = try record.getCollection(key: "left")
        let right: FonCollection = try record.getCollection(key: "right")

        try left.setInt(key: "v", value: 11)

        XCTAssertEqual(try left.getInt(key: "v"), 11)
        XCTAssertEqual(try record.getInt(key: "id"), 0)
        assertFonError("staleView") { try right.getInt(key: "v") }
    }

    func testNestedViewOfOwnedCollectionGoesStaleAfterOwnerIsMutated() throws {
        let owner = FonCollection()
        let child = FonCollection()
        try child.addInt(key: "v", value: 1)
        try owner.addCollection(key: "c", value: child)
        try owner.addInt(key: "x", value: 1)

        let view: FonCollection = try owner.getCollection(key: "c")
        XCTAssertEqual(try view.getInt(key: "v"), 1)

        try owner.setInt(key: "x", value: 2)

        assertFonError("staleView") { try view.getInt(key: "v") }
        XCTAssertEqual(try owner.getInt(key: "x"), 2)
    }

    func testViewOfOwnedCollectionIsStaleAfterSiblingFieldChange() throws {
        let owner = FonCollection()
        let child = FonCollection()
        try child.addInt(key: "v", value: 1)
        try owner.addCollection(key: "c", value: child)
        let view: FonCollection = try owner.getCollection(key: "c")
        try owner.addString(key: "unrelated", value: "x")
        assertFonError("staleView") { try view.getInt(key: "v") }
    }

    // ==================== OWNER LIFETIME ====================

    /// Returns a record view while the dump itself goes out of scope.
    private func makeDetachedRecordView() throws -> FonCollection {
        let dump: FonDump = try makeDump()
        return try XCTUnwrap(dump.get(at: 1))
    }

    /// Returns a nested view while its owner goes out of scope.
    private func makeDetachedNestedView() throws -> FonCollection {
        let owner = FonCollection()
        let child = FonCollection()
        try child.addInt(key: "v", value: 33)
        try owner.addCollection(key: "c", value: child)
        return try owner.getCollection(key: "c")
    }

    func testRecordViewKeepsItsDumpAlive() throws {
        // The dump has no reference left once the helper returns; the view must keep it alive.
        let view: FonCollection = try makeDetachedRecordView()
        XCTAssertEqual(try view.getInt(key: "id"), 1)
        XCTAssertEqual(try view.getInt(key: "w"), 1)
        XCTAssertEqual(try view.getCollection(key: "left").getInt(key: "v"), 10)
    }

    func testNestedViewKeepsItsOwnerAlive() throws {
        // The owner has no reference left once the helper returns; the view must keep it alive.
        let view: FonCollection = try makeDetachedNestedView()
        XCTAssertEqual(try view.getInt(key: "v"), 33)
    }
}
