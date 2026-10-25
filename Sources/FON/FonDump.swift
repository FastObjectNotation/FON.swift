import CFonNative


// ==================== FONDUMP ====================

/// A multi-record FON dump: records stored under unique 64-bit ids.
///
/// The dump owns its native memory. Record views (from `get(at:)` or iteration) keep the
/// dump alive and throw `FonError.staleView` once the record they show has been removed or
/// replaced. Ids are stable in memory and renumber when the dump is serialized.
public final class FonDump: Sequence {

    public typealias Element = (id: UInt64, collection: FonCollection)

    /// Iterator over the records of a dump. Yields `(id, view)` pairs in ascending id order.
    public struct Iterator: IteratorProtocol {

        private let dump: FonDump
        private let recordIds: [UInt64]
        private var position: Int = 0

        internal init(dump: FonDump, recordIds: [UInt64]) {
            self.dump = dump
            self.recordIds = recordIds
        }

        public mutating func next() -> (id: UInt64, collection: FonCollection)? {
            while position < recordIds.count {
                let id: UInt64 = recordIds[position]
                position += 1
                if let view = dump.recordView(id: id) {
                    return (id: id, collection: view)
                }
            }
            return nil
        }
    }


    // ==================== STATE ====================

    /// Generations of one record as seen by views: `record` changes when the record is
    /// added, replaced or removed, `tree` changes on every field change inside it.
    internal struct Stamp {
        internal var record: UInt64
        internal var tree: UInt64
    }

    /// Native dump handle, owned by this object.
    internal let handle: UnsafeMutableRawPointer
    /// Incremented by every mutation of the dump, including mutations of its records.
    internal var version: UInt64 = 0
    /// Record stamps kept on the Swift side. The native generation counters are 32-bit and
    /// wrap, which could let a stale view look current; these 64-bit values never repeat.
    /// Records without an entry have stamp `Stamp(record: 0, tree: 0)`.
    internal var stamps: [UInt64: Stamp] = [:]
    /// Source of unique stamp values; starts at 0 so that the first value handed out is 1.
    private var stampSequence: UInt64 = 0


    // ==================== LIFECYCLE ====================

    /// Creates a new, empty dump.
    public init() {
        guard let raw = fon_dump_create() else {
            fatalError("fon_dump_create returned nil")
        }
        self.handle = raw
    }

    /// Wraps a native handle that the caller owns (deserialization).
    internal init(ownedHandle raw: UnsafeMutableRawPointer) {
        self.handle = raw
    }

    deinit {
        fon_dump_free(handle)
    }


    // ==================== PUBLIC: STATE ====================

    /// Number of records in the dump.
    public var count: Int {
        return Int(fon_dump_size(handle))
    }

    /// `true` when a record with `id` exists.
    public func contains(id: UInt64) -> Bool {
        return fon_dump_get(handle, id) != nil
    }

    /// All record ids in ascending order. One native enumeration call.
    public func ids() throws -> [UInt64] {
        var idCount: Int64 = 0
        var err: NativeError = NativeError()
        let sizeCode: Int32 = fon_dump_ids(handle, nil, 0, &idCount, &err)
        try throwOnFailure(sizeCode, err)
        if idCount == 0 {
            return []
        }
        var buffer: [UInt64] = [UInt64](repeating: 0, count: Int(idCount))
        let fillCode: Int32 = buffer.withUnsafeMutableBufferPointer { idBuffer in
            fon_dump_ids(handle, idBuffer.baseAddress, Int64(idBuffer.count), &idCount, &err)
        }
        try throwOnFailure(fillCode, err)
        return buffer
    }

    /// Returns a view of the record with `id`, or `nil` when it does not exist.
    public func get(at index: UInt64) -> FonCollection? {
        return recordView(id: index)
    }

    /// Enumerates the records as `(id, view)` pairs in ascending id order.
    public func makeIterator() -> Iterator {
        // Sequence cannot throw; a live dump always reports its ids.
        let allIds: [UInt64] = (try? self.ids()) ?? []
        return Iterator(dump: self, recordIds: allIds)
    }


    // ==================== PUBLIC: MUTATION ====================

    /// Adds a record under `id`. Throws `FonError.alreadyExists` when the id is present.
    /// Ownership of `collection` transfers to the dump on success.
    public func add(id: UInt64, collection: FonCollection) throws {
        try putRecord(id: id, collection: collection, mode: FON_PUT_ADD)
    }

    /// Stores a record under `id`, replacing any existing record. Ownership of `collection`
    /// transfers to the dump on success.
    public func set(id: UInt64, collection: FonCollection) throws {
        try putRecord(id: id, collection: collection, mode: FON_PUT_UPSERT)
    }

    /// Replaces the record under `id`. Throws `FonError.notFound` when the id is absent.
    /// Ownership of `collection` transfers to the dump on success.
    public func replace(id: UInt64, collection: FonCollection) throws {
        try putRecord(id: id, collection: collection, mode: FON_PUT_SET)
    }

    /// Removes the record under `id`. Returns `false` when the id is absent.
    @discardableResult
    public func remove(id: UInt64) throws -> Bool {
        let removed: Int32 = fon_dump_remove(handle, id)
        // The native call may relocate records even when nothing is removed, so every call
        // invalidates the cached record pointers of the views.
        version &+= 1
        if removed == 1 {
            stamps.removeValue(forKey: id)
            return true
        }
        return false
    }

    /// Removes the records under `ids`. Absent and duplicate ids are ignored. Returns the
    /// number of records removed.
    @discardableResult
    public func removeMany(ids: [UInt64]) throws -> Int {
        let removed: Int64 = ids.withUnsafeBufferPointer { idBuffer in
            fon_dump_remove_many(handle, idBuffer.baseAddress, Int64(idBuffer.count))
        }
        // Counted even when nothing is removed: the native call may relocate records.
        version &+= 1
        for id in ids {
            stamps.removeValue(forKey: id)
        }
        return Int(removed)
    }


    // ==================== PUBLIC: SERIALIZATION ====================

    /// Serializes the whole dump to a FON string, one record per line.
    /// `maxThreads`: worker threads for this call; 0 uses all cores.
    public func serialize(maxThreads: Int32 = 0) throws -> String {
        return try takeNativeBuffer { out, length, err in
            fon_serialize_dump(handle, maxThreads, &out, &length, &err)
        }
    }

    /// Deserializes a multi-line FON string into a new dump.
    /// `maxThreads`: worker threads for this call; 0 uses all cores.
    public static func deserialize(from string: String, maxThreads: Int32 = 0) throws -> FonDump {
        let bytes: [UInt8] = Array(string.utf8)
        var err: NativeError = NativeError()
        let raw: UnsafeMutableRawPointer? = bytes.withUnsafeBufferPointer { buffer in
            fon_deserialize_dump(buffer.baseAddress, Int64(buffer.count), maxThreads, &err)
        }
        guard let handle = raw else {
            throw FonError.from(code: err.code, nativeError: err)
        }
        return FonDump(ownedHandle: handle)
    }

    /// Serializes the dump to the file at `path`.
    /// `maxThreads`: worker threads for this call; 0 uses all cores.
    public func serialize(toFile path: String, maxThreads: Int32 = 0) throws {
        var err: NativeError = NativeError()
        let code: Int32 = withNativeString(path) { pathPointer, pathLength in
            fon_serialize_to_file(handle, pathPointer, pathLength, maxThreads, &err)
        }
        try throwOnFailure(code, err)
    }

    /// Deserializes the .fon file at `path` into a new dump. Throws `FonError.fileNotFound`
    /// when the file does not exist.
    /// `maxThreads`: worker threads for this call; 0 uses all cores.
    public static func deserialize(fromFile path: String, maxThreads: Int32 = 0) throws -> FonDump {
        var err: NativeError = NativeError()
        let raw: UnsafeMutableRawPointer? = withNativeString(path) { pathPointer, pathLength in
            fon_deserialize_from_file(pathPointer, pathLength, maxThreads, &err)
        }
        guard let handle = raw else {
            throw FonError.from(code: err.code, nativeError: err)
        }
        return FonDump(ownedHandle: handle)
    }


    // ==================== INTERNAL ====================

    /// `true` when a live record with `id` exists.
    internal func isLive(id: UInt64) -> Bool {
        var recordGen: UInt32 = 0
        var treeGen: UInt32 = 0
        return fon_dump_gens(handle, id, &recordGen, &treeGen) == 1
    }

    /// Current stamp of the record with `id`.
    internal func stamp(of id: UInt64) -> Stamp {
        return stamps[id] ?? Stamp(record: 0, tree: 0)
    }

    /// Returns a record view for `id`, capturing its generations so later changes are detected.
    internal func recordView(id: UInt64) -> FonCollection? {
        guard isLive(id: id) else {
            return nil
        }
        guard let raw = fon_dump_get(handle, id) else {
            return nil
        }
        let current: Stamp = stamp(of: id)
        return FonCollection(
            viewHandle: raw,
            origin: .record(self, id),
            recordGen: current.record,
            treeGen: current.tree,
            cachedVersion: version
        )
    }

    /// Gives a new unique stamp value.
    internal func nextStamp() -> UInt64 {
        stampSequence &+= 1
        return stampSequence
    }

    /// Records that the record with `id` was added or replaced: its views go stale.
    internal func noteRecordChanged(id: UInt64) {
        let value: UInt64 = nextStamp()
        stamps[id] = Stamp(record: value, tree: value)
    }

    /// Records that a field inside the record with `id` changed: views of its tree go stale.
    internal func noteTreeChanged(id: UInt64) {
        stamps[id, default: Stamp(record: 0, tree: 0)].tree = nextStamp()
    }

    /// Stores `collection` under `id` with the given put mode. Ownership transfers on success.
    private func putRecord(id: UInt64, collection: FonCollection, mode: Int32) throws {
        let childHandle: UnsafeMutableRawPointer = try collection.transferableHandle()
        var err: NativeError = NativeError()
        let code: Int32 = fon_dump_put(handle, id, childHandle, mode, &err)
        // Counted before the result is checked: a failed put may still have relocated records.
        version &+= 1
        try throwOnFailure(code, err)
        noteRecordChanged(id: id)
        collection.handle = nil
    }
}
