import XCTest
@testable import FON


// ==================== TEST SUPPORT ====================

extension FonError {

    /// Name of the case, used to compare thrown errors without matching payloads.
    var caseName: String {
        switch self {
        case .fileNotFound:
            return "fileNotFound"
        case .parseFailed:
            return "parseFailed"
        case .writeFailed:
            return "writeFailed"
        case .invalidArgument:
            return "invalidArgument"
        case .nullHandle:
            return "nullHandle"
        case .notFound:
            return "notFound"
        case .typeMismatch:
            return "typeMismatch"
        case .alreadyExists:
            return "alreadyExists"
        case .staleView:
            return "staleView"
        case .bufferTooSmall:
            return "bufferTooSmall"
        }
    }
}


/// Asserts that `body` throws a `FonError` whose case is named `expectedCase`.
func assertFonError<T>(
    _ expectedCase: String,
    file: StaticString = #filePath,
    line: UInt = #line,
    _ body: () throws -> T
) {
    do {
        _ = try body()
        XCTFail("expected FonError.\(expectedCase), but nothing was thrown", file: file, line: line)
    } catch let error as FonError {
        XCTAssertEqual(error.caseName, expectedCase, "unexpected FonError: \(error)", file: file, line: line)
    } catch {
        XCTFail("expected FonError.\(expectedCase), got \(error)", file: file, line: line)
    }
}


/// Serializes `collection` and parses the line back into a new owned collection.
func roundTripCollection(_ collection: FonCollection) throws -> FonCollection {
    let line: String = try collection.serialize()
    return try FonCollection.deserialize(from: line)
}


/// Serializes `dump` and parses the text back into a new dump.
func roundTripDump(_ dump: FonDump) throws -> FonDump {
    let text: String = try dump.serialize()
    return try FonDump.deserialize(from: text)
}
