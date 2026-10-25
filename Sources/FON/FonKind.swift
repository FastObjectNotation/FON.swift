import CFonNative


// ==================== FONTYPE ====================

/// Scalar type of a FON field. Raw values are the type names used by the API tables.
public enum FonType: String {
    case byte
    case short
    case int
    case uint
    case long
    case ulong
    case float
    case double
    case bool
    case string
    case raw
    case object
}


// ==================== FONKIND ====================

/// Kind of a field: its scalar type and whether it holds an array of that type.
public struct FonKind: Equatable {

    public let type: FonType
    public let isArray: Bool

    public init(type: FonType, isArray: Bool) {
        self.type = type
        self.isArray = isArray
    }

    /// Decodes a native kind code (type char, plus the array flag). Returns nil for -1
    /// (key absent) and for unknown codes.
    internal init?(nativeCode: Int32) {
        guard nativeCode >= 0 else {
            return nil
        }
        // Type chars are not importable from the header (char literal macros), so they are
        // spelled out here: e=byte t=short i=int u=uint l=long g=ulong f=float d=double
        // b=bool s=string r=raw o=object.
        let typeCode: Int32 = nativeCode & 0xFF
        let decodedType: FonType
        switch typeCode {
        case Int32(UInt8(ascii: "e")):
            decodedType = .byte
        case Int32(UInt8(ascii: "t")):
            decodedType = .short
        case Int32(UInt8(ascii: "i")):
            decodedType = .int
        case Int32(UInt8(ascii: "u")):
            decodedType = .uint
        case Int32(UInt8(ascii: "l")):
            decodedType = .long
        case Int32(UInt8(ascii: "g")):
            decodedType = .ulong
        case Int32(UInt8(ascii: "f")):
            decodedType = .float
        case Int32(UInt8(ascii: "d")):
            decodedType = .double
        case Int32(UInt8(ascii: "b")):
            decodedType = .bool
        case Int32(UInt8(ascii: "s")):
            decodedType = .string
        case Int32(UInt8(ascii: "r")):
            decodedType = .raw
        case Int32(UInt8(ascii: "o")):
            decodedType = .object
        default:
            return nil
        }
        self.type = decodedType
        self.isArray = (nativeCode & FON_KIND_ARRAY) != 0
    }
}
