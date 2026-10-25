import CFonNative


// ==================== NESTED COLLECTIONS ====================

extension FonCollection {

    // ==================== SINGLE NESTED COLLECTION ====================

    /// Stores `value` under `key`, transferring ownership of `value` on success. Throws
    /// `FonError.alreadyExists` when the key is present; `value` then stays owned.
    ///
    /// `value` must be an owned collection (call `clone()` on a view first) and must not
    /// create a cycle. After a successful call `value` can no longer be used.
    @discardableResult
    public func addCollection(key: String, value: FonCollection) throws -> FonCollection {
        try putCollection(key: key, value: value, mode: FON_PUT_ADD)
        return self
    }

    /// Stores `child` under `key` (same as `addCollection(key:value:)`).
    @discardableResult
    public func addCollection(key: String, child: FonCollection) throws -> FonCollection {
        try putCollection(key: key, value: child, mode: FON_PUT_ADD)
        return self
    }

    /// Stores `value` under `key`, replacing any existing value. Ownership transfer rules are
    /// the same as for `addCollection(key:value:)`.
    @discardableResult
    public func setCollection(key: String, value: FonCollection) throws -> FonCollection {
        try putCollection(key: key, value: value, mode: FON_PUT_UPSERT)
        return self
    }

    /// Returns a view of the nested collection under `key`. The view keeps this collection's
    /// owner alive and goes stale when the nested value or its owner changes.
    public func getCollection(key: String) throws -> FonCollection {
        let target: UnsafeMutableRawPointer = try resolve()
        var err: NativeError = NativeError()
        let raw: UnsafeMutableRawPointer? = withNativeString(key) { keyPointer, keyLength in
            fon_collection_get_collection(target, keyPointer, keyLength, &err)
        }
        guard let child = raw else {
            throw FonError.from(code: err.code, nativeError: err)
        }
        return nestedView(child)
    }


    // ==================== COLLECTION ARRAY ====================

    /// Stores `children` under `key`, transferring ownership of every element on success. The
    /// same collection may not appear twice. Throws `FonError.alreadyExists` when the key is
    /// present; the elements then stay owned.
    @discardableResult
    public func addCollectionArray(key: String, value: [FonCollection]) throws -> FonCollection {
        try putCollections(key: key, values: value, mode: FON_PUT_ADD)
        return self
    }

    /// Stores `children` under `key` (same as `addCollectionArray(key:value:)`).
    @discardableResult
    public func addCollectionArray(key: String, children: [FonCollection]) throws -> FonCollection {
        try putCollections(key: key, values: children, mode: FON_PUT_ADD)
        return self
    }

    /// Stores `values` under `key`, replacing any existing value. Ownership transfer rules are
    /// the same as for `addCollectionArray(key:value:)`.
    @discardableResult
    public func setCollectionArray(key: String, value: [FonCollection]) throws -> FonCollection {
        try putCollections(key: key, values: value, mode: FON_PUT_UPSERT)
        return self
    }

    /// Returns views of the nested collections under `key`.
    public func getCollectionArray(key: String) throws -> [FonCollection] {
        let target: UnsafeMutableRawPointer = try resolve()
        var itemCount: Int64 = 0
        var err: NativeError = NativeError()
        let sizeCode: Int32 = withNativeString(key) { keyPointer, keyLength in
            fon_collection_get_collection_array(target, keyPointer, keyLength, nil, 0, &itemCount, &err)
        }
        try throwOnFailure(sizeCode, err)
        if itemCount == 0 {
            return []
        }
        var raws: [UnsafeMutableRawPointer?] = [UnsafeMutableRawPointer?](repeating: nil, count: Int(itemCount))
        let fillCode: Int32 = raws.withUnsafeMutableBufferPointer { rawBuffer in
            withNativeString(key) { keyPointer, keyLength in
                fon_collection_get_collection_array(
                    target,
                    keyPointer,
                    keyLength,
                    rawBuffer.baseAddress,
                    Int64(rawBuffer.count),
                    &itemCount,
                    &err
                )
            }
        }
        try throwOnFailure(fillCode, err)
        var views: [FonCollection] = []
        views.reserveCapacity(raws.count)
        for raw in raws {
            guard let child = raw else {
                throw FonError.nullHandle("an element under key '\(key)' has no native handle; the array was not read")
            }
            views.append(nestedView(child))
        }
        return views
    }


    // ==================== INTERNAL: TRANSFER ====================

    /// Stores one owned collection under `key` with the given put mode.
    internal func putCollection(key: String, value: FonCollection, mode: Int32) throws {
        let childHandle: UnsafeMutableRawPointer = try value.transferableHandle()
        try rejectCycle(value)
        try mutate { target in
            var err: NativeError = NativeError()
            let code: Int32 = withNativeString(key) { keyPointer, keyLength in
                fon_collection_put_collection(target, keyPointer, keyLength, childHandle, mode, &err)
            }
            try throwOnFailure(code, err)
            value.handle = nil
            return true
        }
    }

    /// Stores owned collections under `key` with the given put mode. The whole array is
    /// validated before the native call, so a rejected array transfers nothing.
    internal func putCollections(key: String, values: [FonCollection], mode: Int32) throws {
        var seen: Set<ObjectIdentifier> = []
        var childHandles: [UnsafeMutableRawPointer?] = []
        childHandles.reserveCapacity(values.count)
        for child in values {
            let childHandle: UnsafeMutableRawPointer = try child.transferableHandle()
            try rejectCycle(child)
            guard seen.insert(ObjectIdentifier(child)).inserted else {
                throw FonError.invalidArgument("the same collection appears more than once in the array; each element must be a distinct collection")
            }
            childHandles.append(childHandle)
        }
        try mutate { target in
            var err: NativeError = NativeError()
            let code: Int32 = childHandles.withUnsafeBufferPointer { handleBuffer in
                withNativeString(key) { keyPointer, keyLength in
                    fon_collection_put_collection_array(
                        target,
                        keyPointer,
                        keyLength,
                        handleBuffer.baseAddress,
                        Int64(handleBuffer.count),
                        mode,
                        &err
                    )
                }
            }
            try throwOnFailure(code, err)
            for child in values {
                child.handle = nil
            }
            return true
        }
    }
}
