import CFonNative


// ==================== FONCOLLECTION ====================

/// A key-value collection representing one FON record, or a view of a value inside one.
///
/// An owned collection (made with `init()`, returned by `clone()`, or produced by
/// deserialization) owns its native memory. A view (returned by `FonDump.get(at:)`, dump
/// iteration, `getCollection(key:)` or `getCollectionArray(key:)`) keeps its owner alive,
/// never frees native memory, and is validated on every access: a view whose data has
/// changed throws `FonError.staleView`.
///
/// Storing a collection in another collection or in a dump transfers ownership of the
/// stored argument. The argument must be an owned collection (call `clone()` on a view
/// first). After a successful transfer the argument can no longer be used. A failed store
/// leaves the argument owned and usable.
public final class FonCollection {

    // ==================== STATE ====================

    /// Where a collection's native handle comes from and what keeps it valid.
    internal enum Origin {
        /// Owned root collection.
        case owned
        /// Record view of a dump.
        case record(FonDump, UInt64)
        /// Value nested inside a dump record.
        case nestedInDump(FonDump, UInt64)
        /// Value nested inside an owned root collection.
        case nestedInCollection(FonCollection)
    }

    /// Owned collections: the handle this object owns, nil once transferred.
    /// Views: the borrowed pointer resolved at the last validation.
    internal var handle: UnsafeMutableRawPointer?
    internal let origin: Origin
    /// Record and tree stamps captured for dump-backed views (see `FonDump.Stamp`).
    internal var recordGen: UInt64 = 0
    internal var treeGen: UInt64 = 0
    /// Owner version seen when this view was last validated.
    internal var cachedVersion: UInt64 = 0
    /// Owned root collections: incremented by every mutation anywhere in their tree.
    internal var version: UInt64 = 0


    // ==================== LIFECYCLE ====================

    /// Creates a new, empty owned collection.
    public init() {
        guard let raw = fon_collection_create() else {
            fatalError("fon_collection_create returned nil")
        }
        self.handle = raw
        self.origin = .owned
    }

    /// Wraps a native handle that the caller owns (clone, deserialization).
    internal init(ownedHandle raw: UnsafeMutableRawPointer) {
        self.handle = raw
        self.origin = .owned
    }

    /// Wraps a borrowed native handle together with the validation state captured for it.
    internal init(
        viewHandle raw: UnsafeMutableRawPointer,
        origin: Origin,
        recordGen: UInt64,
        treeGen: UInt64,
        cachedVersion: UInt64
    ) {
        self.handle = raw
        self.origin = origin
        self.recordGen = recordGen
        self.treeGen = treeGen
        self.cachedVersion = cachedVersion
    }

    deinit {
        if case .owned = origin, let raw = handle {
            fon_collection_free(raw)
        }
    }


    // ==================== PUBLIC: INTROSPECTION ====================

    /// Number of fields in the collection. Returns 0 when a view is stale or the collection
    /// was transferred; use `keys()` to get a throwing check.
    public var count: Int {
        guard let target = try? resolve() else {
            return 0
        }
        return Int(fon_collection_size(target))
    }

    /// `true` when `key` is present. Returns `false` when a view is stale or the collection
    /// was transferred.
    public func contains(key: String) -> Bool {
        return kind(key: key) != nil
    }

    /// Kind of the field under `key`, or `nil` when it is absent. Returns `nil` when a view
    /// is stale or the collection was transferred.
    public func kind(key: String) -> FonKind? {
        guard let target = try? resolve() else {
            return nil
        }
        let code: Int32 = withNativeString(key) { keyPointer, keyLength in
            fon_collection_kind_of(target, keyPointer, keyLength)
        }
        return FonKind(nativeCode: code)
    }

    /// Keys in insertion order. One native enumeration call.
    public func keys() throws -> [String] {
        let entries: [(key: String, kind: FonKind?)] = try keyEntries()
        var names: [String] = []
        names.reserveCapacity(entries.count)
        for entry in entries {
            names.append(entry.key)
        }
        return names
    }

    /// Keys in insertion order with the kind of each one. One native enumeration call.
    internal func keyEntries() throws -> [(key: String, kind: FonKind?)] {
        let target: UnsafeMutableRawPointer = try resolve()
        var entryCount: Int64 = 0
        var totalBytes: Int64 = 0
        var err: NativeError = NativeError()
        let sizeCode: Int32 = fon_collection_keys(target, nil, 0, nil, 0, nil, &entryCount, &totalBytes, &err)
        try throwOnFailure(sizeCode, err)
        if entryCount == 0 {
            return []
        }
        var lengths: [Int64] = [Int64](repeating: 0, count: Int(entryCount))
        var bytes: [UInt8] = [UInt8](repeating: 0, count: Int(totalBytes))
        var kindCodes: [Int32] = [Int32](repeating: -1, count: Int(entryCount))
        let fillCode: Int32 = lengths.withUnsafeMutableBufferPointer { lengthBuffer in
            bytes.withUnsafeMutableBufferPointer { byteBuffer in
                kindCodes.withUnsafeMutableBufferPointer { kindBuffer in
                    fon_collection_keys(
                        target,
                        lengthBuffer.baseAddress,
                        Int64(lengthBuffer.count),
                        byteBuffer.baseAddress,
                        Int64(byteBuffer.count),
                        kindBuffer.baseAddress,
                        &entryCount,
                        &totalBytes,
                        &err
                    )
                }
            }
        }
        try throwOnFailure(fillCode, err)
        let names: [String] = splitItems(bytes, lengths)
        var entries: [(key: String, kind: FonKind?)] = []
        entries.reserveCapacity(names.count)
        for index in 0..<names.count {
            entries.append((key: names[index], kind: FonKind(nativeCode: kindCodes[index])))
        }
        return entries
    }


    // ==================== PUBLIC: REMOVE, CLONE, SERIALIZATION ====================

    /// Removes the field under `key`. Returns `false` when the key is absent.
    @discardableResult
    public func remove(key: String) throws -> Bool {
        return try mutate { target in
            withNativeString(key) { keyPointer, keyLength in
                fon_collection_remove(target, keyPointer, keyLength) == 1
            }
        }
    }

    /// Returns an owned deep copy of this collection (owned or view).
    public func clone() throws -> FonCollection {
        let target: UnsafeMutableRawPointer = try resolve()
        var err: NativeError = NativeError()
        let raw: UnsafeMutableRawPointer? = fon_collection_clone(target, &err)
        guard let copy = raw else {
            throw FonError.from(code: err.code, nativeError: err)
        }
        return FonCollection(ownedHandle: copy)
    }

    /// Serializes this collection to a single FON line.
    public func serialize() throws -> String {
        let target: UnsafeMutableRawPointer = try resolve()
        return try takeNativeBuffer { out, length, err in
            fon_serialize_collection(target, &out, &length, &err)
        }
    }

    /// Deserializes a single FON line into a new owned collection.
    public static func deserialize(from string: String) throws -> FonCollection {
        let bytes: [UInt8] = Array(string.utf8)
        var err: NativeError = NativeError()
        let raw: UnsafeMutableRawPointer? = bytes.withUnsafeBufferPointer { buffer in
            fon_deserialize_collection(buffer.baseAddress, Int64(buffer.count), &err)
        }
        guard let handle = raw else {
            throw FonError.from(code: err.code, nativeError: err)
        }
        return FonCollection(ownedHandle: handle)
    }


    // ==================== INTERNAL: VALIDATION ====================

    /// Returns the native handle after checking that this object is still valid.
    internal func resolve() throws -> UnsafeMutableRawPointer {
        switch origin {
        case .owned:
            return try liveHandle()
        case .record(let dump, let id):
            if dump.version != cachedVersion {
                try checkRecordGen(dump, id)
                guard let raw = fon_dump_get(dump.handle, id) else {
                    throw FonError.staleView("record \(id) was removed after this view was obtained")
                }
                handle = raw
                cachedVersion = dump.version
            }
            return try liveHandle()
        case .nestedInDump(let dump, let id):
            if dump.version != cachedVersion {
                try checkTreeGen(dump, id)
                cachedVersion = dump.version
            }
            return try liveHandle()
        case .nestedInCollection(let root):
            if root.handle == nil {
                throw FonError.nullHandle("the collection this view was read from was transferred to another collection or dump and can no longer be used")
            }
            if root.version != cachedVersion {
                throw FonError.staleView("the collection this view was read from has changed; read the value again from its owner")
            }
            return try liveHandle()
        }
    }

    /// Runs a native mutation on this collection's tree and records it for view validation.
    /// `body` returns `true` when the tree changed.
    @discardableResult
    internal func mutate(_ body: (UnsafeMutableRawPointer) throws -> Bool) throws -> Bool {
        let target: UnsafeMutableRawPointer = try resolve()
        let changed: Bool = try body(target)
        if changed {
            noteMutation()
        }
        return changed
    }

    /// Checks that this collection is owned and live, and returns its handle, so it can be
    /// transferred into another collection or dump.
    internal func transferableHandle() throws -> UnsafeMutableRawPointer {
        guard case .owned = origin else {
            throw FonError.invalidArgument("a view cannot be stored in a collection or dump; call clone() on it first")
        }
        return try liveHandle()
    }

    /// Throws when storing `child` under this collection would create a cycle.
    internal func rejectCycle(_ child: FonCollection) throws {
        if let root = rootCollection, root === child {
            throw FonError.invalidArgument("storing this collection here would create a cycle; a collection cannot contain itself")
        }
    }

    /// Creates the view for a nested value `raw` that was read from this collection. The
    /// caller has already resolved this collection.
    internal func nestedView(_ raw: UnsafeMutableRawPointer) -> FonCollection {
        switch origin {
        case .owned:
            return FonCollection(
                viewHandle: raw,
                origin: .nestedInCollection(self),
                recordGen: 0,
                treeGen: 0,
                cachedVersion: version
            )
        case .nestedInCollection(let root):
            return FonCollection(
                viewHandle: raw,
                origin: .nestedInCollection(root),
                recordGen: 0,
                treeGen: 0,
                cachedVersion: root.version
            )
        case .record(let dump, let id), .nestedInDump(let dump, let id):
            let current: FonDump.Stamp = dump.stamp(of: id)
            return FonCollection(
                viewHandle: raw,
                origin: .nestedInDump(dump, id),
                recordGen: current.record,
                treeGen: current.tree,
                cachedVersion: dump.version
            )
        }
    }


    // ==================== INTERNAL: NATIVE CALL HELPERS ====================

    /// Stores a value under `key`. `call` performs the native put with the given mode.
    internal func putValue(
        key: String,
        mode: Int32,
        _ call: (UnsafeMutableRawPointer, UnsafePointer<UInt8>?, Int64, Int32, inout NativeError) -> Int32
    ) throws {
        try mutate { target in
            var err: NativeError = NativeError()
            let code: Int32 = withNativeString(key) { keyPointer, keyLength in
                call(target, keyPointer, keyLength, mode, &err)
            }
            try throwOnFailure(code, err)
            return true
        }
    }

    /// Stores an array (or raw bytes) under `key`. `call` performs the native put.
    internal func putArray<T>(
        key: String,
        mode: Int32,
        values: [T],
        _ call: (UnsafeMutableRawPointer, UnsafePointer<UInt8>?, Int64, UnsafePointer<T>?, Int64, Int32, inout NativeError) -> Int32
    ) throws {
        try mutate { target in
            var err: NativeError = NativeError()
            let code: Int32 = values.withUnsafeBufferPointer { valueBuffer in
                withNativeString(key) { keyPointer, keyLength in
                    call(target, keyPointer, keyLength, valueBuffer.baseAddress, Int64(valueBuffer.count), mode, &err)
                }
            }
            try throwOnFailure(code, err)
            return true
        }
    }

    /// Reads a scalar stored under `key`. `call` performs the native get.
    internal func getScalar<T>(
        key: String,
        initial: T,
        _ call: (UnsafeMutableRawPointer, UnsafePointer<UInt8>?, Int64, UnsafeMutablePointer<T>, inout NativeError) -> Int32
    ) throws -> T {
        let target: UnsafeMutableRawPointer = try resolve()
        var value: T = initial
        var err: NativeError = NativeError()
        let code: Int32 = withNativeString(key) { keyPointer, keyLength in
            call(target, keyPointer, keyLength, &value, &err)
        }
        try throwOnFailure(code, err)
        return value
    }

    /// Reads a string, raw blob or array stored under `key` with the size-query pattern: the
    /// exact element count is queried first, then the buffer is filled in one more call.
    internal func readBuffer<T>(
        key: String,
        zero: T,
        _ call: (UnsafeMutableRawPointer, UnsafePointer<UInt8>?, Int64, UnsafeMutablePointer<T>?, Int64, inout Int64, inout NativeError) -> Int32
    ) throws -> [T] {
        let target: UnsafeMutableRawPointer = try resolve()
        var elementCount: Int64 = 0
        var err: NativeError = NativeError()
        let sizeCode: Int32 = withNativeString(key) { keyPointer, keyLength in
            call(target, keyPointer, keyLength, nil, 0, &elementCount, &err)
        }
        try throwOnFailure(sizeCode, err)
        if elementCount == 0 {
            return []
        }
        var buffer: [T] = [T](repeating: zero, count: Int(elementCount))
        let fillCode: Int32 = buffer.withUnsafeMutableBufferPointer { elementBuffer in
            withNativeString(key) { keyPointer, keyLength in
                call(target, keyPointer, keyLength, elementBuffer.baseAddress, Int64(elementBuffer.count), &elementCount, &err)
            }
        }
        try throwOnFailure(fillCode, err)
        return buffer
    }


    // ==================== PRIVATE ====================

    private var rootCollection: FonCollection? {
        switch origin {
        case .owned:
            return self
        case .nestedInCollection(let root):
            return root
        case .record, .nestedInDump:
            return nil
        }
    }

    private func liveHandle() throws -> UnsafeMutableRawPointer {
        guard let raw = handle else {
            throw FonError.nullHandle("this collection was transferred to another collection or dump and can no longer be used")
        }
        return raw
    }

    private func checkRecordGen(_ dump: FonDump, _ id: UInt64) throws {
        guard dump.isLive(id: id), dump.stamp(of: id).record == recordGen else {
            throw FonError.staleView("record \(id) was removed or replaced after this view was obtained")
        }
    }

    private func checkTreeGen(_ dump: FonDump, _ id: UInt64) throws {
        let current: FonDump.Stamp = dump.stamp(of: id)
        guard dump.isLive(id: id), current.record == recordGen, current.tree == treeGen else {
            throw FonError.staleView("the record changed after this view was obtained; read the value again from the record")
        }
    }

    /// Records a successful mutation made through this object: bumps the counter of the
    /// owner, touches the dump record when needed, and refreshes this object's own captures
    /// (it stays valid; sibling and descendant views go stale).
    private func noteMutation() {
        switch origin {
        case .owned:
            version &+= 1
        case .record(let dump, let id):
            _ = fon_dump_touch(dump.handle, id)
            dump.noteTreeChanged(id: id)
            dump.version &+= 1
            if let raw = fon_dump_get(dump.handle, id) {
                handle = raw
            }
            cachedVersion = dump.version
        case .nestedInDump(let dump, let id):
            _ = fon_dump_touch(dump.handle, id)
            dump.noteTreeChanged(id: id)
            dump.version &+= 1
            let current: FonDump.Stamp = dump.stamp(of: id)
            recordGen = current.record
            treeGen = current.tree
            cachedVersion = dump.version
        case .nestedInCollection(let root):
            root.version &+= 1
            cachedVersion = root.version
        }
    }
}
