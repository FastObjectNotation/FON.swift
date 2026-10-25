import CFonNative


// ==================== ARRAY FIELDS ====================

extension FonCollection {

    // ==================== BYTE ARRAY ====================

    /// Adds a `byte` array field. Throws `FonError.alreadyExists` when the key is present.
    @discardableResult
    public func addByteArray(key: String, value: [UInt8]) throws -> FonCollection {
        try putArray(key: key, mode: FON_PUT_ADD, values: value) { target, keyPointer, keyLength, valuePointer, valueCount, mode, err in
            fon_collection_put_byte_array(target, keyPointer, keyLength, valuePointer, valueCount, mode, &err)
        }
        return self
    }

    /// Sets a `byte` array field, adding it when absent. Replaces any existing value.
    @discardableResult
    public func setByteArray(key: String, value: [UInt8]) throws -> FonCollection {
        try putArray(key: key, mode: FON_PUT_UPSERT, values: value) { target, keyPointer, keyLength, valuePointer, valueCount, mode, err in
            fon_collection_put_byte_array(target, keyPointer, keyLength, valuePointer, valueCount, mode, &err)
        }
        return self
    }

    /// Reads a `byte` array field. Throws `FonError.notFound` or `FonError.typeMismatch`.
    public func getByteArray(key: String) throws -> [UInt8] {
        return try readBuffer(key: key, zero: UInt8(0)) { target, keyPointer, keyLength, buffer, capacity, actual, err in
            fon_collection_get_byte_array(target, keyPointer, keyLength, buffer, capacity, &actual, &err)
        }
    }


    // ==================== SHORT ARRAY ====================

    /// Adds a `short` array field. Throws `FonError.alreadyExists` when the key is present.
    @discardableResult
    public func addShortArray(key: String, value: [Int16]) throws -> FonCollection {
        try putArray(key: key, mode: FON_PUT_ADD, values: value) { target, keyPointer, keyLength, valuePointer, valueCount, mode, err in
            fon_collection_put_short_array(target, keyPointer, keyLength, valuePointer, valueCount, mode, &err)
        }
        return self
    }

    /// Sets a `short` array field, adding it when absent. Replaces any existing value.
    @discardableResult
    public func setShortArray(key: String, value: [Int16]) throws -> FonCollection {
        try putArray(key: key, mode: FON_PUT_UPSERT, values: value) { target, keyPointer, keyLength, valuePointer, valueCount, mode, err in
            fon_collection_put_short_array(target, keyPointer, keyLength, valuePointer, valueCount, mode, &err)
        }
        return self
    }

    /// Reads a `short` array field. Throws `FonError.notFound` or `FonError.typeMismatch`.
    public func getShortArray(key: String) throws -> [Int16] {
        return try readBuffer(key: key, zero: Int16(0)) { target, keyPointer, keyLength, buffer, capacity, actual, err in
            fon_collection_get_short_array(target, keyPointer, keyLength, buffer, capacity, &actual, &err)
        }
    }


    // ==================== INT ARRAY ====================

    /// Adds an `int` array field. Throws `FonError.alreadyExists` when the key is present.
    @discardableResult
    public func addIntArray(key: String, value: [Int32]) throws -> FonCollection {
        try putArray(key: key, mode: FON_PUT_ADD, values: value) { target, keyPointer, keyLength, valuePointer, valueCount, mode, err in
            fon_collection_put_int_array(target, keyPointer, keyLength, valuePointer, valueCount, mode, &err)
        }
        return self
    }

    /// Adds an `int` array field (same as `addIntArray(key:value:)`).
    @discardableResult
    public func addIntArray(key: String, values: [Int32]) throws -> FonCollection {
        return try addIntArray(key: key, value: values)
    }

    /// Sets an `int` array field, adding it when absent. Replaces any existing value.
    @discardableResult
    public func setIntArray(key: String, value: [Int32]) throws -> FonCollection {
        try putArray(key: key, mode: FON_PUT_UPSERT, values: value) { target, keyPointer, keyLength, valuePointer, valueCount, mode, err in
            fon_collection_put_int_array(target, keyPointer, keyLength, valuePointer, valueCount, mode, &err)
        }
        return self
    }

    /// Reads an `int` array field. Throws `FonError.notFound` or `FonError.typeMismatch`.
    public func getIntArray(key: String) throws -> [Int32] {
        return try readBuffer(key: key, zero: Int32(0)) { target, keyPointer, keyLength, buffer, capacity, actual, err in
            fon_collection_get_int_array(target, keyPointer, keyLength, buffer, capacity, &actual, &err)
        }
    }


    // ==================== UINT ARRAY ====================

    /// Adds a `uint` array field. Throws `FonError.alreadyExists` when the key is present.
    @discardableResult
    public func addUIntArray(key: String, value: [UInt32]) throws -> FonCollection {
        try putArray(key: key, mode: FON_PUT_ADD, values: value) { target, keyPointer, keyLength, valuePointer, valueCount, mode, err in
            fon_collection_put_uint_array(target, keyPointer, keyLength, valuePointer, valueCount, mode, &err)
        }
        return self
    }

    /// Sets a `uint` array field, adding it when absent. Replaces any existing value.
    @discardableResult
    public func setUIntArray(key: String, value: [UInt32]) throws -> FonCollection {
        try putArray(key: key, mode: FON_PUT_UPSERT, values: value) { target, keyPointer, keyLength, valuePointer, valueCount, mode, err in
            fon_collection_put_uint_array(target, keyPointer, keyLength, valuePointer, valueCount, mode, &err)
        }
        return self
    }

    /// Reads a `uint` array field. Throws `FonError.notFound` or `FonError.typeMismatch`.
    public func getUIntArray(key: String) throws -> [UInt32] {
        return try readBuffer(key: key, zero: UInt32(0)) { target, keyPointer, keyLength, buffer, capacity, actual, err in
            fon_collection_get_uint_array(target, keyPointer, keyLength, buffer, capacity, &actual, &err)
        }
    }


    // ==================== LONG ARRAY ====================

    /// Adds a `long` array field. Throws `FonError.alreadyExists` when the key is present.
    @discardableResult
    public func addLongArray(key: String, value: [Int64]) throws -> FonCollection {
        try putArray(key: key, mode: FON_PUT_ADD, values: value) { target, keyPointer, keyLength, valuePointer, valueCount, mode, err in
            fon_collection_put_long_array(target, keyPointer, keyLength, valuePointer, valueCount, mode, &err)
        }
        return self
    }

    /// Sets a `long` array field, adding it when absent. Replaces any existing value.
    @discardableResult
    public func setLongArray(key: String, value: [Int64]) throws -> FonCollection {
        try putArray(key: key, mode: FON_PUT_UPSERT, values: value) { target, keyPointer, keyLength, valuePointer, valueCount, mode, err in
            fon_collection_put_long_array(target, keyPointer, keyLength, valuePointer, valueCount, mode, &err)
        }
        return self
    }

    /// Reads a `long` array field. Throws `FonError.notFound` or `FonError.typeMismatch`.
    public func getLongArray(key: String) throws -> [Int64] {
        return try readBuffer(key: key, zero: Int64(0)) { target, keyPointer, keyLength, buffer, capacity, actual, err in
            fon_collection_get_long_array(target, keyPointer, keyLength, buffer, capacity, &actual, &err)
        }
    }


    // ==================== ULONG ARRAY ====================

    /// Adds a `ulong` array field. Throws `FonError.alreadyExists` when the key is present.
    @discardableResult
    public func addULongArray(key: String, value: [UInt64]) throws -> FonCollection {
        try putArray(key: key, mode: FON_PUT_ADD, values: value) { target, keyPointer, keyLength, valuePointer, valueCount, mode, err in
            fon_collection_put_ulong_array(target, keyPointer, keyLength, valuePointer, valueCount, mode, &err)
        }
        return self
    }

    /// Sets a `ulong` array field, adding it when absent. Replaces any existing value.
    @discardableResult
    public func setULongArray(key: String, value: [UInt64]) throws -> FonCollection {
        try putArray(key: key, mode: FON_PUT_UPSERT, values: value) { target, keyPointer, keyLength, valuePointer, valueCount, mode, err in
            fon_collection_put_ulong_array(target, keyPointer, keyLength, valuePointer, valueCount, mode, &err)
        }
        return self
    }

    /// Reads a `ulong` array field. Throws `FonError.notFound` or `FonError.typeMismatch`.
    public func getULongArray(key: String) throws -> [UInt64] {
        return try readBuffer(key: key, zero: UInt64(0)) { target, keyPointer, keyLength, buffer, capacity, actual, err in
            fon_collection_get_ulong_array(target, keyPointer, keyLength, buffer, capacity, &actual, &err)
        }
    }


    // ==================== FLOAT ARRAY ====================

    /// Adds a `float` array field. Throws `FonError.alreadyExists` when the key is present.
    @discardableResult
    public func addFloatArray(key: String, value: [Float]) throws -> FonCollection {
        try putArray(key: key, mode: FON_PUT_ADD, values: value) { target, keyPointer, keyLength, valuePointer, valueCount, mode, err in
            fon_collection_put_float_array(target, keyPointer, keyLength, valuePointer, valueCount, mode, &err)
        }
        return self
    }

    /// Adds a `float` array field (same as `addFloatArray(key:value:)`).
    @discardableResult
    public func addFloatArray(key: String, values: [Float]) throws -> FonCollection {
        return try addFloatArray(key: key, value: values)
    }

    /// Sets a `float` array field, adding it when absent. Replaces any existing value.
    @discardableResult
    public func setFloatArray(key: String, value: [Float]) throws -> FonCollection {
        try putArray(key: key, mode: FON_PUT_UPSERT, values: value) { target, keyPointer, keyLength, valuePointer, valueCount, mode, err in
            fon_collection_put_float_array(target, keyPointer, keyLength, valuePointer, valueCount, mode, &err)
        }
        return self
    }

    /// Reads a `float` array field. Throws `FonError.notFound` or `FonError.typeMismatch`.
    public func getFloatArray(key: String) throws -> [Float] {
        return try readBuffer(key: key, zero: Float(0)) { target, keyPointer, keyLength, buffer, capacity, actual, err in
            fon_collection_get_float_array(target, keyPointer, keyLength, buffer, capacity, &actual, &err)
        }
    }


    // ==================== DOUBLE ARRAY ====================

    /// Adds a `double` array field. Throws `FonError.alreadyExists` when the key is present.
    @discardableResult
    public func addDoubleArray(key: String, value: [Double]) throws -> FonCollection {
        try putArray(key: key, mode: FON_PUT_ADD, values: value) { target, keyPointer, keyLength, valuePointer, valueCount, mode, err in
            fon_collection_put_double_array(target, keyPointer, keyLength, valuePointer, valueCount, mode, &err)
        }
        return self
    }

    /// Sets a `double` array field, adding it when absent. Replaces any existing value.
    @discardableResult
    public func setDoubleArray(key: String, value: [Double]) throws -> FonCollection {
        try putArray(key: key, mode: FON_PUT_UPSERT, values: value) { target, keyPointer, keyLength, valuePointer, valueCount, mode, err in
            fon_collection_put_double_array(target, keyPointer, keyLength, valuePointer, valueCount, mode, &err)
        }
        return self
    }

    /// Reads a `double` array field. Throws `FonError.notFound` or `FonError.typeMismatch`.
    public func getDoubleArray(key: String) throws -> [Double] {
        return try readBuffer(key: key, zero: Double(0)) { target, keyPointer, keyLength, buffer, capacity, actual, err in
            fon_collection_get_double_array(target, keyPointer, keyLength, buffer, capacity, &actual, &err)
        }
    }


    // ==================== BOOL ARRAY ====================

    /// Adds a `bool` array field. Throws `FonError.alreadyExists` when the key is present.
    @discardableResult
    public func addBoolArray(key: String, value: [Bool]) throws -> FonCollection {
        let flags: [UInt8] = value.map { flag in flag ? UInt8(1) : UInt8(0) }
        try putArray(key: key, mode: FON_PUT_ADD, values: flags) { target, keyPointer, keyLength, valuePointer, valueCount, mode, err in
            fon_collection_put_bool_array(target, keyPointer, keyLength, valuePointer, valueCount, mode, &err)
        }
        return self
    }

    /// Sets a `bool` array field, adding it when absent. Replaces any existing value.
    @discardableResult
    public func setBoolArray(key: String, value: [Bool]) throws -> FonCollection {
        let flags: [UInt8] = value.map { flag in flag ? UInt8(1) : UInt8(0) }
        try putArray(key: key, mode: FON_PUT_UPSERT, values: flags) { target, keyPointer, keyLength, valuePointer, valueCount, mode, err in
            fon_collection_put_bool_array(target, keyPointer, keyLength, valuePointer, valueCount, mode, &err)
        }
        return self
    }

    /// Reads a `bool` array field. Throws `FonError.notFound` or `FonError.typeMismatch`.
    public func getBoolArray(key: String) throws -> [Bool] {
        let flags: [UInt8] = try readBuffer(key: key, zero: UInt8(0)) { target, keyPointer, keyLength, buffer, capacity, actual, err in
            fon_collection_get_bool_array(target, keyPointer, keyLength, buffer, capacity, &actual, &err)
        }
        return flags.map { flag in flag != 0 }
    }


    // ==================== STRING ARRAY ====================

    /// Adds a `string` array field. Throws `FonError.alreadyExists` when the key is present.
    @discardableResult
    public func addStringArray(key: String, value: [String]) throws -> FonCollection {
        try putStringArray(key: key, mode: FON_PUT_ADD, values: value)
        return self
    }

    /// Sets a `string` array field, adding it when absent. Replaces any existing value.
    @discardableResult
    public func setStringArray(key: String, value: [String]) throws -> FonCollection {
        try putStringArray(key: key, mode: FON_PUT_UPSERT, values: value)
        return self
    }

    /// Reads a `string` array field in one native round trip. Throws `FonError.notFound` or
    /// `FonError.typeMismatch`.
    public func getStringArray(key: String) throws -> [String] {
        let target: UnsafeMutableRawPointer = try resolve()
        var itemCount: Int64 = 0
        var totalBytes: Int64 = 0
        var err: NativeError = NativeError()
        let sizeCode: Int32 = withNativeString(key) { keyPointer, keyLength in
            fon_collection_get_string_array(target, keyPointer, keyLength, nil, 0, nil, 0, &itemCount, &totalBytes, &err)
        }
        try throwOnFailure(sizeCode, err)
        if itemCount == 0 {
            return []
        }
        var lengths: [Int64] = [Int64](repeating: 0, count: Int(itemCount))
        var bytes: [UInt8] = [UInt8](repeating: 0, count: Int(totalBytes))
        let fillCode: Int32 = lengths.withUnsafeMutableBufferPointer { lengthBuffer in
            bytes.withUnsafeMutableBufferPointer { byteBuffer in
                withNativeString(key) { keyPointer, keyLength in
                    fon_collection_get_string_array(
                        target,
                        keyPointer,
                        keyLength,
                        lengthBuffer.baseAddress,
                        Int64(lengthBuffer.count),
                        byteBuffer.baseAddress,
                        Int64(byteBuffer.count),
                        &itemCount,
                        &totalBytes,
                        &err
                    )
                }
            }
        }
        try throwOnFailure(fillCode, err)
        return splitItems(bytes, lengths)
    }


    // ==================== INTERNAL ====================

    /// Stores a string array in one native call. Items are sent as lengths plus back-to-back bytes.
    internal func putStringArray(key: String, mode: Int32, values: [String]) throws {
        var lengths: [Int64] = []
        var bytes: [UInt8] = []
        lengths.reserveCapacity(values.count)
        for item in values {
            let encoded: [UInt8] = Array(item.utf8)
            lengths.append(Int64(encoded.count))
            bytes.append(contentsOf: encoded)
        }
        let itemCount: Int64 = Int64(values.count)
        try mutate { target in
            var err: NativeError = NativeError()
            let code: Int32 = lengths.withUnsafeBufferPointer { lengthBuffer in
                bytes.withUnsafeBufferPointer { byteBuffer in
                    withNativeString(key) { keyPointer, keyLength in
                        fon_collection_put_string_array(
                            target,
                            keyPointer,
                            keyLength,
                            lengthBuffer.baseAddress,
                            byteBuffer.baseAddress,
                            itemCount,
                            mode,
                            &err
                        )
                    }
                }
            }
            try throwOnFailure(code, err)
            return true
        }
    }
}
