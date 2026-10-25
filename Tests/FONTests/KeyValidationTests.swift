import XCTest
@testable import FON


// ==================== KEY VALIDATION ====================

final class KeyValidationTests: XCTestCase {

    /// Keys that cannot be written to a FON line without breaking the format.
    private let rejectedKeys: [String] = [
        "a=b",
        "quote\"key",
        "{open",
        "close}",
        "[open",
        "close]",
        "carriage\rreturn",
        "line\nfeed",
    ]

    func testRejectedKeysThrowInvalidArgumentForScalars() throws {
        let parent = FonCollection()
        for key: String in rejectedKeys {
            assertFonError("invalidArgument") { try parent.addInt(key: key, value: 1) }
        }
        XCTAssertEqual(parent.count, 0)
    }

    func testRejectedKeyKeepsCollectionValueOwnedAndUsable() throws {
        let parent = FonCollection()
        for key: String in rejectedKeys {
            let child = FonCollection()
            try child.addInt(key: "v", value: 9)
            assertFonError("invalidArgument") { try parent.addCollection(key: key, value: child) }
            XCTAssertEqual(try child.getInt(key: "v"), 9)
            XCTAssertEqual(child.count, 1)
        }
        XCTAssertEqual(parent.count, 0)
    }

    func testRejectedKeyInCollectionArrayKeepsChildrenUsable() throws {
        let parent = FonCollection()
        let first = FonCollection()
        try first.addInt(key: "v", value: 1)
        let second = FonCollection()
        try second.addInt(key: "v", value: 2)
        assertFonError("invalidArgument") { try parent.addCollectionArray(key: "bad=key", value: [first, second]) }
        XCTAssertEqual(try first.getInt(key: "v"), 1)
        XCTAssertEqual(try second.getInt(key: "v"), 2)
        XCTAssertEqual(parent.count, 0)
    }

    func testKeyWithSpacesIsStillAccepted() throws {
        let parent = FonCollection()
        let child = FonCollection()
        try child.addInt(key: "v", value: 5)
        try parent.addCollection(key: "plain key", value: child)
        XCTAssertEqual(try parent.getCollection(key: "plain key").getInt(key: "v"), 5)
    }
}
