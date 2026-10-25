import XCTest
@testable import FON


// ==================== ROUND TRIP: ALL KINDS ====================

final class KindRoundTripTests: XCTestCase {

    /// One collection holding all 23 kinds, with boundary values where they exist.
    private func makeAllKinds() throws -> FonCollection {
        let col = FonCollection()
        try col.addByte(key: "byte", value: UInt8.max)
        try col.addByte(key: "byteMin", value: UInt8.min)
        try col.addShort(key: "short", value: Int16.min)
        try col.addShort(key: "shortMax", value: Int16.max)
        try col.addInt(key: "int", value: Int32.max)
        try col.addInt(key: "intMin", value: Int32.min)
        try col.addUInt(key: "uint", value: UInt32.max)
        try col.addUInt(key: "uintMin", value: UInt32.min)
        try col.addLong(key: "long", value: Int64.min)
        try col.addLong(key: "longMax", value: Int64.max)
        try col.addULong(key: "ulong", value: UInt64.max)
        try col.addULong(key: "ulongMin", value: UInt64.min)
        try col.addFloat(key: "float", value: Float.nan)
        try col.addDouble(key: "double", value: -Double.infinity)
        try col.addBool(key: "bool", value: true)
        try col.addString(key: "string", value: "héllo, мир")
        try col.addRaw(key: "raw", value: [0, 1, 127, 128, 255])
        try col.addByteArray(key: "byteArray", value: [0, 255])
        try col.addShortArray(key: "shortArray", value: [Int16.min, Int16.max])
        try col.addIntArray(key: "intArray", value: [Int32.min, 0, Int32.max])
        try col.addUIntArray(key: "uintArray", value: [0, UInt32.max])
        try col.addLongArray(key: "longArray", value: [Int64.min, Int64.max])
        try col.addULongArray(key: "ulongArray", value: [0, UInt64.max])
        try col.addFloatArray(key: "floatArray", value: [Float.infinity, -Float.infinity, 1.5])
        try col.addDoubleArray(key: "doubleArray", value: [Double.nan, -Double.infinity, 2.25])
        try col.addBoolArray(key: "boolArray", value: [true, false])
        try col.addStringArray(key: "stringArray", value: ["a", "", "b c"])

        let child = FonCollection()
        try child.addInt(key: "id", value: 7)
        try col.addCollection(key: "object", value: child)

        let first = FonCollection()
        try first.addInt(key: "id", value: 1)
        let second = FonCollection()
        try second.addInt(key: "id", value: 2)
        try col.addCollectionArray(key: "objects", value: [first, second])
        return col
    }

    private func assertAllKinds(_ col: FonCollection) throws {
        XCTAssertEqual(try col.keys().count, 29)

        XCTAssertEqual(try col.getByte(key: "byte"), UInt8.max)
        XCTAssertEqual(try col.getByte(key: "byteMin"), UInt8.min)
        XCTAssertEqual(try col.getShort(key: "short"), Int16.min)
        XCTAssertEqual(try col.getShort(key: "shortMax"), Int16.max)
        XCTAssertEqual(try col.getInt(key: "int"), Int32.max)
        XCTAssertEqual(try col.getInt(key: "intMin"), Int32.min)
        XCTAssertEqual(try col.getUInt(key: "uint"), UInt32.max)
        XCTAssertEqual(try col.getUInt(key: "uintMin"), UInt32.min)
        XCTAssertEqual(try col.getLong(key: "long"), Int64.min)
        XCTAssertEqual(try col.getLong(key: "longMax"), Int64.max)
        XCTAssertEqual(try col.getULong(key: "ulong"), UInt64.max)
        XCTAssertEqual(try col.getULong(key: "ulongMin"), UInt64.min)
        XCTAssertTrue(try col.getFloat(key: "float").isNaN)
        XCTAssertEqual(try col.getDouble(key: "double"), -Double.infinity)
        XCTAssertEqual(try col.getBool(key: "bool"), true)
        XCTAssertEqual(try col.getString(key: "string"), "héllo, мир")
        XCTAssertEqual(try col.getRaw(key: "raw"), [0, 1, 127, 128, 255])

        XCTAssertEqual(try col.getByteArray(key: "byteArray"), [0, 255])
        XCTAssertEqual(try col.getShortArray(key: "shortArray"), [Int16.min, Int16.max])
        XCTAssertEqual(try col.getIntArray(key: "intArray"), [Int32.min, 0, Int32.max])
        XCTAssertEqual(try col.getUIntArray(key: "uintArray"), [0, UInt32.max])
        XCTAssertEqual(try col.getLongArray(key: "longArray"), [Int64.min, Int64.max])
        XCTAssertEqual(try col.getULongArray(key: "ulongArray"), [0, UInt64.max])
        XCTAssertEqual(try col.getFloatArray(key: "floatArray"), [Float.infinity, -Float.infinity, 1.5])

        let doubles: [Double] = try col.getDoubleArray(key: "doubleArray")
        XCTAssertTrue(doubles[0].isNaN)
        XCTAssertEqual(doubles[1], -Double.infinity)
        XCTAssertEqual(doubles[2], 2.25)

        XCTAssertEqual(try col.getBoolArray(key: "boolArray"), [true, false])
        XCTAssertEqual(try col.getStringArray(key: "stringArray"), ["a", "", "b c"])

        let object: FonCollection = try col.getCollection(key: "object")
        XCTAssertEqual(try object.getInt(key: "id"), 7)

        let objects: [FonCollection] = try col.getCollectionArray(key: "objects")
        XCTAssertEqual(objects.count, 2)
        XCTAssertEqual(try objects[0].getInt(key: "id"), 1)
        XCTAssertEqual(try objects[1].getInt(key: "id"), 2)

        XCTAssertEqual(col.kind(key: "int"), FonKind(type: .int, isArray: false))
        XCTAssertEqual(col.kind(key: "intArray"), FonKind(type: .int, isArray: true))
        XCTAssertEqual(col.kind(key: "raw"), FonKind(type: .raw, isArray: false))
        XCTAssertEqual(col.kind(key: "object"), FonKind(type: .object, isArray: false))
        XCTAssertEqual(col.kind(key: "objects"), FonKind(type: .object, isArray: true))
        XCTAssertEqual(col.kind(key: "stringArray"), FonKind(type: .string, isArray: true))
        XCTAssertNil(col.kind(key: "missing"))
    }

    func testEveryKindRoundTripsInMemory() throws {
        let col: FonCollection = try makeAllKinds()
        try assertAllKinds(col)
    }

    func testEveryKindRoundTripsThroughSerialization() throws {
        let col: FonCollection = try makeAllKinds()
        let restored: FonCollection = try roundTripCollection(col)
        try assertAllKinds(restored)
    }

    func testEveryKindRoundTripsInsideADump() throws {
        let dump = FonDump()
        try dump.add(id: 0, collection: try makeAllKinds())
        let restored: FonDump = try roundTripDump(dump)
        guard let record = restored.get(at: 0) else {
            XCTFail("record 0 missing after round trip")
            return
        }
        try assertAllKinds(record)
    }

    func testSetOverwritesEveryKindWithItsOwnType() throws {
        let col = FonCollection()
        try col.setInt(key: "v", value: -1)
        try col.setString(key: "v", value: "now a string")
        XCTAssertEqual(try col.getString(key: "v"), "now a string")
        XCTAssertEqual(col.kind(key: "v"), FonKind(type: .string, isArray: false))
        try col.setDoubleArray(key: "d", value: [1.0])
        try col.setDoubleArray(key: "d", value: [2.0, 3.0])
        XCTAssertEqual(try col.getDoubleArray(key: "d"), [2.0, 3.0])
    }
}
