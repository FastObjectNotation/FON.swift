import CFonNative


// ==================== NATIVE SUPPORT ====================

/// Error record filled by a failing native call.
internal typealias NativeError = CFonNative.FonError


/// Runs `body` with a pointer to the UTF-8 bytes of `string` and their byte length.
/// The bytes are not NUL-terminated and may contain U+0000.
internal func withNativeString<R>(
    _ string: String,
    _ body: (UnsafePointer<UInt8>?, Int64) throws -> R
) rethrows -> R {
    var copy: String = string
    return try copy.withUTF8 { buffer in
        try body(buffer.baseAddress, Int64(buffer.count))
    }
}


/// Throws the error matching a failing native result code.
internal func throwOnFailure(_ code: Int32, _ error: NativeError) throws {
    if code != FON_OK {
        throw FonError.from(code: code, nativeError: error)
    }
}


/// Reads the NUL-terminated message the native layer wrote into an error record.
internal func nativeMessage(_ error: NativeError) -> String {
    return withUnsafeBytes(of: error.message) { raw in
        String(decoding: raw.prefix(while: { $0 != 0 }), as: UTF8.self)
    }
}


/// Splits `bytes` into items of the given byte lengths, laid out back to back.
internal func splitItems(_ bytes: [UInt8], _ lengths: [Int64]) -> [String] {
    var items: [String] = []
    items.reserveCapacity(lengths.count)
    var offset: Int = 0
    for length in lengths {
        let end: Int = offset + Int(length)
        items.append(String(decoding: bytes[offset..<end], as: UTF8.self))
        offset = end
    }
    return items
}


/// Calls a native serializer that hands out an owned buffer, and returns its contents as a
/// string. The native buffer is released before returning.
internal func takeNativeBuffer(
    _ call: (inout UnsafeMutablePointer<UInt8>?, inout Int64, inout NativeError) -> Int32
) throws -> String {
    var out: UnsafeMutablePointer<UInt8>? = nil
    var length: Int64 = 0
    var err: NativeError = NativeError()
    let code: Int32 = call(&out, &length, &err)
    try throwOnFailure(code, err)
    defer {
        fon_buffer_free(out, length)
    }
    guard let bytes = out, length > 0 else {
        return ""
    }
    return String(decoding: UnsafeBufferPointer(start: bytes, count: Int(length)), as: UTF8.self)
}
