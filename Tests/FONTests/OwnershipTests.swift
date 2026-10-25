import XCTest
@testable import FON


// ==================== OWNERSHIP ====================

final class OwnershipTests: XCTestCase {

    /// Dump with one record `{ id: 1 }`, and a view of that record.
    private func makeRecordView() throws -> (FonDump, FonCollection) {
        let dump = FonDump()
        let record = FonCollection()
        try record.addInt(key: "id", value: 1)
        try dump.add(id: 0, collection: record)
        let view: FonCollection = try XCTUnwrap(dump.get(at: 0))
        return (dump, view)
    }

    func testStoringAViewThrowsInvalidArgumentThenCloneWorks() throws {
        let (_, view) = try makeRecordView()
        let parent = FonCollection()

        assertFonError("invalidArgument") { try parent.addCollection(key: "v", value: view) }
        XCTAssertEqual(parent.count, 0)

        let copy: FonCollection = try view.clone()
        try parent.addCollection(key: "v", value: copy)
        XCTAssertEqual(try parent.getCollection(key: "v").getInt(key: "id"), 1)
    }

    func testAViewCannotBeAddedToADumpEither() throws {
        let (_, view) = try makeRecordView()
        let other = FonDump()
        assertFonError("invalidArgument") { try other.add(id: 5, collection: view) }
        XCTAssertEqual(try view.getInt(key: "id"), 1)
    }

    func testStoredWrapperIsUnusableAfterSuccessfulTransfer() throws {
        let parent = FonCollection()
        let child = FonCollection()
        try child.addInt(key: "v", value: 3)
        try parent.addCollection(key: "c", value: child)

        assertFonError("nullHandle") { try child.getInt(key: "v") }
        assertFonError("nullHandle") { try child.setInt(key: "v", value: 4) }
        XCTAssertEqual(try parent.getCollection(key: "c").getInt(key: "v"), 3)
    }

    func testTransferredToDumpIsUnusable() throws {
        let dump = FonDump()
        let record = FonCollection()
        try record.addInt(key: "v", value: 8)
        try dump.add(id: 2, collection: record)
        assertFonError("nullHandle") { try record.getInt(key: "v") }
        XCTAssertEqual(try dump.get(at: 2)?.getInt(key: "v"), 8)
    }

    func testFailedAddKeepsChildOwnedAndUsable() throws {
        let parent = FonCollection()
        try parent.addInt(key: "c", value: 1)
        let child = FonCollection()
        try child.addInt(key: "v", value: 5)

        assertFonError("alreadyExists") { try parent.addCollection(key: "c", value: child) }

        XCTAssertEqual(try child.getInt(key: "v"), 5)
        try parent.setCollection(key: "c", value: child)
        XCTAssertEqual(try parent.getCollection(key: "c").getInt(key: "v"), 5)
    }

    func testRootCannotBeInsertedIntoItsOwnNestedView() throws {
        let root = FonCollection()
        try root.addCollection(key: "n", value: FonCollection())
        let nested: FonCollection = try root.getCollection(key: "n")

        assertFonError("invalidArgument") { try nested.addCollection(key: "loop", value: root) }

        XCTAssertEqual(try root.keys(), ["n"])
        XCTAssertEqual(try root.getCollection(key: "n").count, 0, "root must stay usable after the rejected store")
    }

    func testCollectionCannotContainItself() throws {
        let node = FonCollection()
        try node.addInt(key: "v", value: 1)
        assertFonError("invalidArgument") { try node.addCollection(key: "me", value: node) }
        XCTAssertEqual(try node.getInt(key: "v"), 1)
    }

    func testSameChildTwiceInArrayIsRejected() throws {
        let parent = FonCollection()
        let child = FonCollection()
        try child.addInt(key: "v", value: 9)

        assertFonError("invalidArgument") { try parent.addCollectionArray(key: "items", value: [child, child]) }

        XCTAssertEqual(parent.count, 0)
        XCTAssertEqual(try child.getInt(key: "v"), 9)
    }

    func testArrayWithAViewIsRejectedAndTransfersNothing() throws {
        let (_, view) = try makeRecordView()
        let first = FonCollection()
        try first.addInt(key: "v", value: 1)
        let parent = FonCollection()

        assertFonError("invalidArgument") { try parent.addCollectionArray(key: "items", value: [first, view]) }

        XCTAssertEqual(parent.count, 0)
        XCTAssertEqual(try first.getInt(key: "v"), 1)
    }

    func testViewOfTransferredRootIsUnusable() throws {
        let parent = FonCollection()
        let child = FonCollection()
        try child.addCollection(key: "n", value: FonCollection())
        let nested: FonCollection = try child.getCollection(key: "n")
        try parent.addCollection(key: "c", value: child)
        assertFonError("nullHandle") { try nested.keys() }
    }
}
