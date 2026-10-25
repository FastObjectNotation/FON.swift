import XCTest
@testable import FON


// ==================== STRINGS (ISSUE #1) ====================

final class StringTests: XCTestCase {

    func testScalarStringsOfBoundaryLengthsSurviveIntact() throws {
        for length in [8191, 8192, 100_000] {
            let value: String = String(repeating: "a", count: length)
            let col = FonCollection()
            try col.addString(key: "s", value: value)
            XCTAssertEqual(try col.getString(key: "s"), value, "length \(length) in memory")
            let restored: FonCollection = try roundTripCollection(col)
            XCTAssertEqual(try restored.getString(key: "s"), value, "length \(length) after round trip")
        }
    }

    func testLongStringAsMiddleArrayItem() throws {
        let big: String = String(repeating: "b", count: 8192)
        let col = FonCollection()
        try col.addStringArray(key: "items", value: ["x", big, "y"])
        XCTAssertEqual(try col.getStringArray(key: "items"), ["x", big, "y"])
        let restored: FonCollection = try roundTripCollection(col)
        XCTAssertEqual(try restored.getStringArray(key: "items"), ["x", big, "y"])
    }

    func testMultiByteStringsAreNotCorrupted() throws {
        let cyrillic: String = String(repeating: "ж", count: 5000)
        let emoji: String = String(repeating: "😀", count: 2500)
        let col = FonCollection()
        try col.addString(key: "cyrillic", value: cyrillic)
        try col.addString(key: "emoji", value: emoji)
        let restored: FonCollection = try roundTripCollection(col)
        let restoredCyrillic: String = try restored.getString(key: "cyrillic")
        let restoredEmoji: String = try restored.getString(key: "emoji")
        XCTAssertEqual(restoredCyrillic, cyrillic)
        XCTAssertEqual(restoredEmoji, emoji)
        XCTAssertFalse(restoredCyrillic.contains("\u{FFFD}"))
        XCTAssertFalse(restoredEmoji.contains("\u{FFFD}"))
        XCTAssertEqual(restoredCyrillic.utf8.count, 10_000)
        XCTAssertEqual(restoredEmoji.utf8.count, 10_000)
    }

    func testEmbeddedNulInValueAndKey() throws {
        let key: String = "k\u{0}ey"
        let value: String = "va\u{0}lue\u{0}"
        let col = FonCollection()
        try col.addString(key: key, value: value)
        XCTAssertEqual(try col.getString(key: key), value)
        XCTAssertEqual(try col.keys(), [key])
        let restored: FonCollection = try roundTripCollection(col)
        XCTAssertEqual(try restored.getString(key: key), value)
        XCTAssertEqual(try restored.keys(), [key])
    }

    func testKeyLongerThan512BytesIsEnumeratedAndReadBack() throws {
        let longKey: String = String(repeating: "k", count: 600)
        let col = FonCollection()
        try col.addInt(key: longKey, value: 1)
        XCTAssertEqual(try col.keys(), [longKey])
        XCTAssertEqual(try col.getInt(key: longKey), 1)
        let restored: FonCollection = try roundTripCollection(col)
        XCTAssertEqual(try restored.keys(), [longKey])
        XCTAssertEqual(try restored.getInt(key: longKey), 1)
    }

    func testValueEndingWithBackslashRoundTrips() throws {
        let value: String = "C:\\dir\\"
        let col = FonCollection()
        try col.addString(key: "path", value: value)
        let restored: FonCollection = try roundTripCollection(col)
        XCTAssertEqual(try restored.getString(key: "path"), value)
    }

    func testControlCharactersRoundTrip() throws {
        let value: String = "a\u{01}b\u{1B}c"
        let col = FonCollection()
        try col.addString(key: "ctl", value: value)
        let restored: FonCollection = try roundTripCollection(col)
        XCTAssertEqual(try restored.getString(key: "ctl"), value)
    }

    func testQuotesCommasBracketsAndBracesInsideNestedObjects() throws {
        let tricky: String = "quote\" comma, bracket] brace} [x] {y}, back\\slash\\"
        let child = FonCollection()
        try child.addString(key: "text", value: tricky)

        let sibling = FonCollection()
        try sibling.addString(key: "text", value: "{\"},[")

        let parent = FonCollection()
        try parent.addCollection(key: "nested", value: child)
        try parent.addCollectionArray(key: "items", value: [sibling])

        let restored: FonCollection = try roundTripCollection(parent)
        XCTAssertEqual(try restored.getCollection(key: "nested").getString(key: "text"), tricky)
        XCTAssertEqual(try restored.getCollectionArray(key: "items")[0].getString(key: "text"), "{\"},[")
    }

    func testTrickyStringsInsideADumpRecord() throws {
        let tricky: String = "end with backslash \\"
        let record = FonCollection()
        try record.addString(key: "a", value: tricky)
        try record.addString(key: "b", value: "x\u{0}y")
        let dump = FonDump()
        try dump.add(id: 3, collection: record)
        let restored: FonDump = try roundTripDump(dump)
        // Ids renumber on save (design 7, "Editing records"), so the only record comes back as id 0.
        guard let view = restored.get(at: 0) else {
            XCTFail("record 0 missing after round trip")
            return
        }
        XCTAssertEqual(try view.getString(key: "a"), tricky)
        XCTAssertEqual(try view.getString(key: "b"), "x\u{0}y")
    }
}
