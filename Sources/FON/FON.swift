import CFonNative
import Foundation


// ==================== ERRORS ====================

/// Errors thrown by FON.
public enum FonError: Error {
    case fileNotFound(String)
    case parseFailed(String)
    case writeFailed(String)
    case invalidArgument(String)
    case nullHandle(String)

    static func from(nativeError error: CFonNative.FonError) -> FonError {
        let message = withUnsafeBytes(of: error.message) { raw in
            let ptr = raw.baseAddress!.assumingMemoryBound(to: CChar.self)
            return String(cString: ptr)
        }
        switch error.code {
        case FON_ERROR_FILE_NOT_FOUND:
            return .fileNotFound(message)
        case FON_ERROR_PARSE_FAILED:
            return .parseFailed(message)
        case FON_ERROR_WRITE_FAILED:
            return .writeFailed(message)
        default:
            return .invalidArgument(message)
        }
    }
}


// ==================== VERSION ====================

/// Returns the FON library version string (e.g. "0.3.0").
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


// ==================== HELPERS ====================

private func checkResult(_ code: Int32, error nativeError: CFonNative.FonError) throws {
    if code != FON_OK {
        throw FonError.from(nativeError: nativeError)
    }
}

private func serializeToBuffer(
    _ call: (_ buffer: UnsafeMutablePointer<UInt8>?, _ size: Int64, _ required: UnsafeMutablePointer<Int64>) -> Int32
) throws -> String {
    let err = CFonNative.FonError()
    var required: Int64 = 0

    // First call: measure size.
    let sizeCode = call(nil, 0, &required)
    if sizeCode != FON_OK {
        throw FonError.from(nativeError: err)
    }
    if required == 0 {
        return ""
    }

    // Second call: fill buffer.
    var bytes = [UInt8](repeating: 0, count: Int(required))
    let fillCode = bytes.withUnsafeMutableBufferPointer { ptr in
        call(ptr.baseAddress, required, &required)
    }
    if fillCode != FON_OK {
        throw FonError.from(nativeError: err)
    }
    return String(bytes: bytes, encoding: .utf8) ?? ""
}


// ==================== FONCOLLECTION ====================

/// A key-value collection representing a single FON record.
///
/// **Ownership:** FonCollection owns its handle unless you transfer it to a
/// FonDump (via `dump.add`) or to a parent collection (via `addCollection`).
/// After an ownership transfer, the Swift object must not be used again.
public final class FonCollection {

    var handle: OpaquePointer?
    private var ownsHandle: Bool

    // Create from an existing owned handle (e.g. from deserialization).
    init(handle: OpaquePointer, owns: Bool = true) {
        self.handle = handle
        self.ownsHandle = owns
    }

    /// Create a new, empty collection.
    public init() {
        guard let h = fon_collection_create() else {
            fatalError("fon_collection_create returned nil")
        }
        self.handle = OpaquePointer(h)
        self.ownsHandle = true
    }

    deinit {
        if ownsHandle, let h = handle {
            fon_collection_free(UnsafeMutableRawPointer(h))
        }
    }

    /// Invalidate this wrapper after transferring ownership to native code.
    func transferOwnership() -> UnsafeMutableRawPointer {
        ownsHandle = false
        let raw = UnsafeMutableRawPointer(handle!)
        handle = nil
        return raw
    }

    // ==================== SCALAR ADDS ====================

    @discardableResult
    public func addInt(key: String, value: Int32) throws -> FonCollection {
        var err = CFonNative.FonError()
        let code = fon_collection_add_int(UnsafeMutableRawPointer(handle), key, value, &err)
        try checkResult(code, error: err)
        return self
    }

    @discardableResult
    public func addLong(key: String, value: Int64) throws -> FonCollection {
        var err = CFonNative.FonError()
        let code = fon_collection_add_long(UnsafeMutableRawPointer(handle), key, value, &err)
        try checkResult(code, error: err)
        return self
    }

    @discardableResult
    public func addFloat(key: String, value: Float) throws -> FonCollection {
        var err = CFonNative.FonError()
        let code = fon_collection_add_float(UnsafeMutableRawPointer(handle), key, value, &err)
        try checkResult(code, error: err)
        return self
    }

    @discardableResult
    public func addDouble(key: String, value: Double) throws -> FonCollection {
        var err = CFonNative.FonError()
        let code = fon_collection_add_double(UnsafeMutableRawPointer(handle), key, value, &err)
        try checkResult(code, error: err)
        return self
    }

    @discardableResult
    public func addBool(key: String, value: Bool) throws -> FonCollection {
        var err = CFonNative.FonError()
        let code = fon_collection_add_bool(UnsafeMutableRawPointer(handle), key, value ? 1 : 0, &err)
        try checkResult(code, error: err)
        return self
    }

    @discardableResult
    public func addString(key: String, value: String) throws -> FonCollection {
        var err = CFonNative.FonError()
        let code = fon_collection_add_string(UnsafeMutableRawPointer(handle), key, value, &err)
        try checkResult(code, error: err)
        return self
    }

    // ==================== ARRAY ADDS ====================

    @discardableResult
    public func addIntArray(key: String, values: [Int32]) throws -> FonCollection {
        var err = CFonNative.FonError()
        let code = values.withUnsafeBufferPointer { ptr in
            fon_collection_add_int_array(UnsafeMutableRawPointer(handle), key, ptr.baseAddress, Int64(values.count), &err)
        }
        try checkResult(code, error: err)
        return self
    }

    @discardableResult
    public func addFloatArray(key: String, values: [Float]) throws -> FonCollection {
        var err = CFonNative.FonError()
        let code = values.withUnsafeBufferPointer { ptr in
            fon_collection_add_float_array(UnsafeMutableRawPointer(handle), key, ptr.baseAddress, Int64(values.count), &err)
        }
        try checkResult(code, error: err)
        return self
    }

    // ==================== NESTED COLLECTIONS ====================

    /**
     * Nest `child` under `key` inside this collection.
     *
     * OWNERSHIP TRANSFER: `child` is owned by the native layer after this call.
     * The `child` wrapper is invalidated — do not use it again.
     */
    @discardableResult
    public func addCollection(key: String, child: FonCollection) throws -> FonCollection {
        var err = CFonNative.FonError()
        let childRaw = child.transferOwnership()
        let code = fon_collection_add_collection(UnsafeMutableRawPointer(handle), key, childRaw, &err)
        try checkResult(code, error: err)
        return self
    }

    /**
     * Nest an array of collections under `key` inside this collection.
     *
     * OWNERSHIP TRANSFER: every element of `children` is owned by the native
     * layer after this call. All `FonCollection` wrappers in the array are
     * invalidated — do not use them again.
     */
    @discardableResult
    public func addCollectionArray(key: String, children: [FonCollection]) throws -> FonCollection {
        var err = CFonNative.FonError()
        // Transfer ownership of each child and collect raw pointers.
        var rawPtrs: [UnsafeMutableRawPointer?] = children.map { $0.transferOwnership() }
        let code = rawPtrs.withUnsafeMutableBufferPointer { ptr in
            fon_collection_add_collection_array(
                UnsafeMutableRawPointer(handle),
                key,
                ptr.baseAddress,
                Int64(children.count),
                &err
            )
        }
        try checkResult(code, error: err)
        return self
    }

    // ==================== SCALAR GETS ====================

    public func getInt(key: String) throws -> Int32 {
        var err = CFonNative.FonError()
        var value: Int32 = 0
        let code = fon_collection_get_int(UnsafeMutableRawPointer(handle), key, &value, &err)
        try checkResult(code, error: err)
        return value
    }

    public func getLong(key: String) throws -> Int64 {
        var err = CFonNative.FonError()
        var value: Int64 = 0
        let code = fon_collection_get_long(UnsafeMutableRawPointer(handle), key, &value, &err)
        try checkResult(code, error: err)
        return value
    }

    public func getFloat(key: String) throws -> Float {
        var err = CFonNative.FonError()
        var value: Float = 0
        let code = fon_collection_get_float(UnsafeMutableRawPointer(handle), key, &value, &err)
        try checkResult(code, error: err)
        return value
    }

    public func getDouble(key: String) throws -> Double {
        var err = CFonNative.FonError()
        var value: Double = 0
        let code = fon_collection_get_double(UnsafeMutableRawPointer(handle), key, &value, &err)
        try checkResult(code, error: err)
        return value
    }

    public func getBool(key: String) throws -> Bool {
        var err = CFonNative.FonError()
        var value: Int32 = 0
        let code = fon_collection_get_bool(UnsafeMutableRawPointer(handle), key, &value, &err)
        try checkResult(code, error: err)
        return value != 0
    }

    public func getString(key: String) throws -> String {
        var err = CFonNative.FonError()
        // Use a 4 KiB initial buffer; resize if needed.
        let bufSize = 4096
        var buf = [UInt8](repeating: 0, count: bufSize)
        let code = buf.withUnsafeMutableBufferPointer { ptr in
            fon_collection_get_string(UnsafeMutableRawPointer(handle), key, ptr.baseAddress, Int64(bufSize), &err)
        }
        try checkResult(code, error: err)
        return String(cString: buf.map { CChar(bitPattern: $0) })
    }

    // ==================== ARRAY GETS ====================

    public func getIntArray(key: String) throws -> [Int32] {
        var err = CFonNative.FonError()
        var actualSize: Int64 = 0
        var code = fon_collection_get_int_array(UnsafeMutableRawPointer(handle), key, nil, 0, &actualSize, &err)
        try checkResult(code, error: err)
        if actualSize == 0 {
            return []
        }
        var buf = [Int32](repeating: 0, count: Int(actualSize))
        code = buf.withUnsafeMutableBufferPointer { ptr in
            fon_collection_get_int_array(UnsafeMutableRawPointer(handle), key, ptr.baseAddress, actualSize, &actualSize, &err)
        }
        try checkResult(code, error: err)
        return buf
    }

    public func getFloatArray(key: String) throws -> [Float] {
        var err = CFonNative.FonError()
        var actualSize: Int64 = 0
        var code = fon_collection_get_float_array(UnsafeMutableRawPointer(handle), key, nil, 0, &actualSize, &err)
        try checkResult(code, error: err)
        if actualSize == 0 {
            return []
        }
        var buf = [Float](repeating: 0, count: Int(actualSize))
        code = buf.withUnsafeMutableBufferPointer { ptr in
            fon_collection_get_float_array(UnsafeMutableRawPointer(handle), key, ptr.baseAddress, actualSize, &actualSize, &err)
        }
        try checkResult(code, error: err)
        return buf
    }

    // ==================== NESTED GET (BORROWED) ====================

    /**
     * Return a borrowed view of a nested collection under key.
     * The returned FonCollection does NOT own its handle — do not free it.
     * It is only valid while this collection (parent) is alive.
     */
    public func getCollection(key: String) throws -> FonCollection {
        var err = CFonNative.FonError()
        guard let raw = fon_collection_get_collection(UnsafeMutableRawPointer(handle), key, &err) else {
            throw FonError.from(nativeError: err)
        }
        return FonCollection(handle: OpaquePointer(raw), owns: false)
    }

    /**
     * Return borrowed views of a collection array under key (two-call pattern).
     * None of the returned FonCollection wrappers own their handle — do not free them.
     * All are only valid while this collection (parent) is alive.
     */
    public func getCollectionArray(key: String) throws -> [FonCollection] {
        var err = CFonNative.FonError()
        var actualSize: Int64 = 0
        // First call: measure count.
        var code = fon_collection_get_collection_array(
            UnsafeMutableRawPointer(handle), key, nil, 0, &actualSize, &err
        )
        try checkResult(code, error: err)
        if actualSize == 0 {
            return []
        }
        // Second call: fill buffer of raw pointers.
        var rawBuf = [UnsafeMutableRawPointer?](repeating: nil, count: Int(actualSize))
        code = rawBuf.withUnsafeMutableBufferPointer { ptr in
            fon_collection_get_collection_array(
                UnsafeMutableRawPointer(handle),
                key,
                ptr.baseAddress,
                actualSize,
                &actualSize,
                &err
            )
        }
        try checkResult(code, error: err)
        return rawBuf.compactMap { raw in
            guard let r = raw else { return nil }
            return FonCollection(handle: OpaquePointer(r), owns: false)
        }
    }

    // ==================== SERIALIZATION ====================

    /// Serialize this collection to a single FON line string.
    public func serialize() throws -> String {
        var err = CFonNative.FonError()
        return try serializeToBuffer { buffer, size, required in
            fon_serialize_collection_to_buffer(UnsafeMutableRawPointer(self.handle), buffer, size, required, &err)
        }
    }

    /// Deserialize a single FON line string into a new FonCollection.
    public static func deserialize(from string: String) throws -> FonCollection {
        let bytes = Array(string.utf8)
        var err = CFonNative.FonError()
        guard let raw = bytes.withUnsafeBufferPointer({ ptr in
            fon_deserialize_collection_from_buffer(ptr.baseAddress, Int64(bytes.count), &err)
        }) else {
            throw FonError.from(nativeError: err)
        }
        return FonCollection(handle: OpaquePointer(raw), owns: true)
    }

    // ==================== METADATA ====================

    /// Number of fields stored in this collection.
    public var count: Int {
        return Int(fon_collection_size(UnsafeMutableRawPointer(handle)))
    }
}


// ==================== FONDUMP ====================

/// A multi-record FON dump (sequence of collections, one per line).
public final class FonDump {

    private var handle: OpaquePointer?

    /// Create a new, empty dump.
    public init() {
        guard let h = fon_dump_create() else {
            fatalError("fon_dump_create returned nil")
        }
        self.handle = OpaquePointer(h)
    }

    // Create from an existing owned handle (deserialization).
    init(handle: OpaquePointer) {
        self.handle = handle
    }

    deinit {
        if let h = handle {
            fon_dump_free(UnsafeMutableRawPointer(h))
        }
    }

    // ==================== MUTATIONS ====================

    /**
     * Add a collection under the given id.
     *
     * OWNERSHIP TRANSFER: `collection` is owned by the dump after this call.
     * The Swift wrapper is invalidated — do not use it again.
     */
    public func add(id: UInt64, collection: FonCollection) throws {
        var err = CFonNative.FonError()
        let raw = collection.transferOwnership()
        let code = fon_dump_add(UnsafeMutableRawPointer(handle), id, raw, &err)
        try checkResult(code, error: err)
    }

    // ==================== ACCESS ====================

    /**
     * Return a borrowed view of the collection at the given index.
     * The returned FonCollection does NOT own its handle.
     * It is only valid while this dump is alive.
     */
    public func get(at index: UInt64) -> FonCollection? {
        guard let raw = fon_dump_get(UnsafeMutableRawPointer(handle), index) else {
            return nil
        }
        return FonCollection(handle: OpaquePointer(raw), owns: false)
    }

    /// Number of collections stored in the dump.
    public var count: Int {
        return Int(fon_dump_size(UnsafeMutableRawPointer(handle)))
    }

    // ==================== SERIALIZATION ====================

    /**
     * Serialize the entire dump to a FON string (one collection per line).
     * `maxThreads`: Rayon thread pool hint; 0 uses the global pool.
     */
    public func serialize(maxThreads: Int32 = 0) throws -> String {
        var err = CFonNative.FonError()
        return try serializeToBuffer { buffer, size, required in
            fon_serialize_dump_to_buffer(UnsafeMutableRawPointer(self.handle), buffer, size, required, maxThreads, &err)
        }
    }

    /// Deserialize a multi-line FON string into a new FonDump.
    public static func deserialize(from string: String, maxThreads: Int32 = 0) throws -> FonDump {
        let bytes = Array(string.utf8)
        var err = CFonNative.FonError()
        guard let raw = bytes.withUnsafeBufferPointer({ ptr in
            fon_deserialize_dump_from_buffer(ptr.baseAddress, Int64(bytes.count), maxThreads, &err)
        }) else {
            throw FonError.from(nativeError: err)
        }
        return FonDump(handle: OpaquePointer(raw))
    }

    /**
     * Serialize the dump to a .fon file at the given path.
     * `maxThreads`: Rayon thread pool hint; 0 uses the global pool.
     */
    public func serialize(toFile path: String, maxThreads: Int32 = 0) throws {
        var err = CFonNative.FonError()
        let code = fon_serialize_to_file(UnsafeMutableRawPointer(handle), path, maxThreads, &err)
        try checkResult(code, error: err)
    }

    /**
     * Deserialize a .fon file at the given path into a new FonDump.
     * `maxThreads`: Rayon thread pool hint; 0 uses the global pool.
     */
    public static func deserialize(fromFile path: String, maxThreads: Int32 = 0) throws -> FonDump {
        var err = CFonNative.FonError()
        guard let raw = fon_deserialize_from_file(path, maxThreads, &err) else {
            throw FonError.from(nativeError: err)
        }
        return FonDump(handle: OpaquePointer(raw))
    }
}
