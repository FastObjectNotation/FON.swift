import XCTest
@testable import FON


/// Malformed text is an error, an empty line is an empty record, and a tree cannot be made
/// to contain itself.
final class StrictTests: XCTestCase {

    func testMalformedRecordsAreRejected() {
        let lines: [String] = [
            "a=b:[[]]",
            "a=i:12abc",
            "a=i:+",
            "a=b:false",
            "a=i:1,junk",
            "a=i:1,a=i:2",
            "a=i:1,",
            "a=i:[1,,2]",
            "a=s:\"\\q\"",
        ]
        for line in lines {
            assertFonError("parseFailed") {
                try FonCollection.deserialize(from: line)
            }
        }
    }


    func testDumpParseErrorNamesTheLine() {
        let threadCounts: [Int32] = [1, 2, 0]
        for threads in threadCounts {
            do {
                _ = try FonDump.deserialize(from: "a=i:1\na=b:[[]]\nc=i:3\n", maxThreads: threads)
                XCTFail("malformed dump was accepted with \(threads) threads")
            } catch FonError.parseFailed(let message) {
                XCTAssertTrue(message.hasPrefix("line 2: "), message)
            } catch {
                XCTFail("expected FonError.parseFailed, got \(error)")
            }
        }
    }


    func testEmptyRecordSurvivesSaveAndLoad() throws {
        let dump: FonDump = FonDump()
        try dump.add(id: 0, collection: try FonCollection().addInt(key: "x", value: 1))
        try dump.add(id: 1, collection: FonCollection())
        try dump.add(id: 2, collection: try FonCollection().addInt(key: "x", value: 3))

        let text: String = try dump.serialize()
        XCTAssertEqual(text, "x=i:1\n\nx=i:3\n")

        let loaded: FonDump = try FonDump.deserialize(from: text)
        XCTAssertEqual(loaded.count, 3)
        XCTAssertEqual(loaded.get(at: 1)?.count, 0)
        XCTAssertEqual(try loaded.get(at: 2)?.getInt(key: "x"), 3)
    }


    func testCollectionCannotBeStoredInsideItsOwnNestedCollection() throws {
        let root: FonCollection = FonCollection()
        let middle: FonCollection = try FonCollection().addCollection(key: "leaf", child: FonCollection())
        _ = try root.addCollection(key: "middle", child: middle)
        let leaf: FonCollection = try root.getCollection(key: "middle").getCollection(key: "leaf")

        assertFonError("invalidArgument") {
            try leaf.addCollection(key: "back", child: root)
        }
        assertFonError("invalidArgument") {
            try leaf.addCollectionArray(key: "backs", children: [root])
        }
        XCTAssertEqual(try root.serialize(), "middle=o:{leaf=o:{}}")
    }
}
