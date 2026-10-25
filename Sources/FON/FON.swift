import CFonNative


// ==================== ERRORS ====================

/// Errors thrown by FON.
///
/// Native result codes map to the cases below and carry the native message.
/// `nullHandle` is raised when a collection that was transferred into another collection
/// or dump is used again. `invalidArgument` covers misuse such as storing a view where an
/// owned collection is required. `staleView` is raised when a view outlived the data it
/// points to.
public enum FonError: Error {
    case fileNotFound(String)
    case parseFailed(String)
    case writeFailed(String)
    case invalidArgument(String)
    case nullHandle(String)
    case notFound(String)
    case typeMismatch(String)
    case alreadyExists(String)
    case staleView(String)
    case bufferTooSmall(String)

    internal static func from(code: Int32, nativeError: NativeError) -> FonError {
        let message: String = nativeMessage(nativeError)
        switch code {
        case FON_ERROR_FILE_NOT_FOUND:
            return .fileNotFound(message)
        case FON_ERROR_PARSE_FAILED:
            return .parseFailed(message)
        case FON_ERROR_WRITE_FAILED:
            return .writeFailed(message)
        case FON_ERROR_BUFFER_TOO_SMALL:
            return .bufferTooSmall(message)
        case FON_ERROR_NOT_FOUND:
            return .notFound(message)
        case FON_ERROR_TYPE_MISMATCH:
            return .typeMismatch(message)
        case FON_ERROR_ALREADY_EXISTS:
            return .alreadyExists(message)
        case FON_ERROR_STALE_VIEW:
            return .staleView(message)
        default:
            return .invalidArgument(message)
        }
    }
}


// ==================== VERSION ====================

/// Returns the FON native library version string (e.g. "0.4.0").
public func nativeVersion() -> String {
    guard let ptr = fon_version() else {
        return ""
    }
    return String(cString: ptr)
}


// ==================== CONFIGURATION ====================

/// Enable or disable raw-data unpacking during deserialization (global setting).
public func setRawUnpack(_ enable: Bool) {
    fon_set_raw_unpack(enable ? 1 : 0)
}

/// Set the maximum nesting depth for deserialization (default: 64, minimum: 1).
public func setMaxDepth(_ depth: Int32) {
    fon_set_max_depth(depth)
}
