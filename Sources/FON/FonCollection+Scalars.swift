import CFonNative


// ==================== SCALAR AND STRING FIELDS ====================

extension FonCollection {

    // ==================== BYTE ====================

    /// Adds a `byte` field. Throws `FonError.alreadyExists` when the key is present.
    @discardableResult
    public func addByte(key: String, value: UInt8) throws -> FonCollection {
        try putValue(key: key, mode: FON_PUT_ADD) { target, keyPointer, keyLength, mode, err in
            fon_collection_put_byte(target, keyPointer, keyLength, value, mode, &err)
        }
        return self
    }

    /// Sets a `byte` field, adding it when absent. Replaces any existing value.
    @discardableResult
    public func setByte(key: String, value: UInt8) throws -> FonCollection {
        try putValue(key: key, mode: FON_PUT_UPSERT) { target, keyPointer, keyLength, mode, err in
            fon_collection_put_byte(target, keyPointer, keyLength, value, mode, &err)
        }
        return self
    }

    /// Reads a `byte` field. Throws `FonError.notFound` or `FonError.typeMismatch`.
    public func getByte(key: String) throws -> UInt8 {
        return try getScalar(key: key, initial: UInt8(0)) { target, keyPointer, keyLength, out, err in
            fon_collection_get_byte(target, keyPointer, keyLength, out, &err)
        }
    }


    // ==================== SHORT ====================

    /// Adds a `short` field. Throws `FonError.alreadyExists` when the key is present.
    @discardableResult
    public func addShort(key: String, value: Int16) throws -> FonCollection {
        try putValue(key: key, mode: FON_PUT_ADD) { target, keyPointer, keyLength, mode, err in
            fon_collection_put_short(target, keyPointer, keyLength, value, mode, &err)
        }
        return self
    }

    /// Sets a `short` field, adding it when absent. Replaces any existing value.
    @discardableResult
    public func setShort(key: String, value: Int16) throws -> FonCollection {
        try putValue(key: key, mode: FON_PUT_UPSERT) { target, keyPointer, keyLength, mode, err in
            fon_collection_put_short(target, keyPointer, keyLength, value, mode, &err)
        }
        return self
    }

    /// Reads a `short` field. Throws `FonError.notFound` or `FonError.typeMismatch`.
    public func getShort(key: String) throws -> Int16 {
        return try getScalar(key: key, initial: Int16(0)) { target, keyPointer, keyLength, out, err in
            fon_collection_get_short(target, keyPointer, keyLength, out, &err)
        }
    }


    // ==================== INT ====================

    /// Adds an `int` field. Throws `FonError.alreadyExists` when the key is present.
    @discardableResult
    public func addInt(key: String, value: Int32) throws -> FonCollection {
        try putValue(key: key, mode: FON_PUT_ADD) { target, keyPointer, keyLength, mode, err in
            fon_collection_put_int(target, keyPointer, keyLength, value, mode, &err)
        }
        return self
    }

    /// Sets an `int` field, adding it when absent. Replaces any existing value.
    @discardableResult
    public func setInt(key: String, value: Int32) throws -> FonCollection {
        try putValue(key: key, mode: FON_PUT_UPSERT) { target, keyPointer, keyLength, mode, err in
            fon_collection_put_int(target, keyPointer, keyLength, value, mode, &err)
        }
        return self
    }

    /// Reads an `int` field. Throws `FonError.notFound` or `FonError.typeMismatch`.
    public func getInt(key: String) throws -> Int32 {
        return try getScalar(key: key, initial: Int32(0)) { target, keyPointer, keyLength, out, err in
            fon_collection_get_int(target, keyPointer, keyLength, out, &err)
        }
    }


    // ==================== UINT ====================

    /// Adds a `uint` field. Throws `FonError.alreadyExists` when the key is present.
    @discardableResult
    public func addUInt(key: String, value: UInt32) throws -> FonCollection {
        try putValue(key: key, mode: FON_PUT_ADD) { target, keyPointer, keyLength, mode, err in
            fon_collection_put_uint(target, keyPointer, keyLength, value, mode, &err)
        }
        return self
    }

    /// Sets a `uint` field, adding it when absent. Replaces any existing value.
    @discardableResult
    public func setUInt(key: String, value: UInt32) throws -> FonCollection {
        try putValue(key: key, mode: FON_PUT_UPSERT) { target, keyPointer, keyLength, mode, err in
            fon_collection_put_uint(target, keyPointer, keyLength, value, mode, &err)
        }
        return self
    }

    /// Reads a `uint` field. Throws `FonError.notFound` or `FonError.typeMismatch`.
    public func getUInt(key: String) throws -> UInt32 {
        return try getScalar(key: key, initial: UInt32(0)) { target, keyPointer, keyLength, out, err in
            fon_collection_get_uint(target, keyPointer, keyLength, out, &err)
        }
    }


    // ==================== LONG ====================

    /// Adds a `long` field. Throws `FonError.alreadyExists` when the key is present.
    @discardableResult
    public func addLong(key: String, value: Int64) throws -> FonCollection {
        try putValue(key: key, mode: FON_PUT_ADD) { target, keyPointer, keyLength, mode, err in
            fon_collection_put_long(target, keyPointer, keyLength, value, mode, &err)
        }
        return self
    }

    /// Sets a `long` field, adding it when absent. Replaces any existing value.
    @discardableResult
    public func setLong(key: String, value: Int64) throws -> FonCollection {
        try putValue(key: key, mode: FON_PUT_UPSERT) { target, keyPointer, keyLength, mode, err in
            fon_collection_put_long(target, keyPointer, keyLength, value, mode, &err)
        }
        return self
    }

    /// Reads a `long` field. Throws `FonError.notFound` or `FonError.typeMismatch`.
    public func getLong(key: String) throws -> Int64 {
        return try getScalar(key: key, initial: Int64(0)) { target, keyPointer, keyLength, out, err in
            fon_collection_get_long(target, keyPointer, keyLength, out, &err)
        }
    }


    // ==================== ULONG ====================

    /// Adds a `ulong` field. Throws `FonError.alreadyExists` when the key is present.
    @discardableResult
    public func addULong(key: String, value: UInt64) throws -> FonCollection {
        try putValue(key: key, mode: FON_PUT_ADD) { target, keyPointer, keyLength, mode, err in
            fon_collection_put_ulong(target, keyPointer, keyLength, value, mode, &err)
        }
        return self
    }

    /// Sets a `ulong` field, adding it when absent. Replaces any existing value.
    @discardableResult
    public func setULong(key: String, value: UInt64) throws -> FonCollection {
        try putValue(key: key, mode: FON_PUT_UPSERT) { target, keyPointer, keyLength, mode, err in
            fon_collection_put_ulong(target, keyPointer, keyLength, value, mode, &err)
        }
        return self
    }

    /// Reads a `ulong` field. Throws `FonError.notFound` or `FonError.typeMismatch`.
    public func getULong(key: String) throws -> UInt64 {
        return try getScalar(key: key, initial: UInt64(0)) { target, keyPointer, keyLength, out, err in
            fon_collection_get_ulong(target, keyPointer, keyLength, out, &err)
        }
    }


    // ==================== FLOAT ====================

    /// Adds a `float` field. Throws `FonError.alreadyExists` when the key is present.
    @discardableResult
    public func addFloat(key: String, value: Float) throws -> FonCollection {
        try putValue(key: key, mode: FON_PUT_ADD) { target, keyPointer, keyLength, mode, err in
            fon_collection_put_float(target, keyPointer, keyLength, value, mode, &err)
        }
        return self
    }

    /// Sets a `float` field, adding it when absent. Replaces any existing value.
    @discardableResult
    public func setFloat(key: String, value: Float) throws -> FonCollection {
        try putValue(key: key, mode: FON_PUT_UPSERT) { target, keyPointer, keyLength, mode, err in
            fon_collection_put_float(target, keyPointer, keyLength, value, mode, &err)
        }
        return self
    }

    /// Reads a `float` field. Throws `FonError.notFound` or `FonError.typeMismatch`.
    public func getFloat(key: String) throws -> Float {
        return try getScalar(key: key, initial: Float(0)) { target, keyPointer, keyLength, out, err in
            fon_collection_get_float(target, keyPointer, keyLength, out, &err)
        }
    }


    // ==================== DOUBLE ====================

    /// Adds a `double` field. Throws `FonError.alreadyExists` when the key is present.
    @discardableResult
    public func addDouble(key: String, value: Double) throws -> FonCollection {
        try putValue(key: key, mode: FON_PUT_ADD) { target, keyPointer, keyLength, mode, err in
            fon_collection_put_double(target, keyPointer, keyLength, value, mode, &err)
        }
        return self
    }

    /// Sets a `double` field, adding it when absent. Replaces any existing value.
    @discardableResult
    public func setDouble(key: String, value: Double) throws -> FonCollection {
        try putValue(key: key, mode: FON_PUT_UPSERT) { target, keyPointer, keyLength, mode, err in
            fon_collection_put_double(target, keyPointer, keyLength, value, mode, &err)
        }
        return self
    }

    /// Reads a `double` field. Throws `FonError.notFound` or `FonError.typeMismatch`.
    public func getDouble(key: String) throws -> Double {
        return try getScalar(key: key, initial: Double(0)) { target, keyPointer, keyLength, out, err in
            fon_collection_get_double(target, keyPointer, keyLength, out, &err)
        }
    }


    // ==================== BOOL ====================

    /// Adds a `bool` field. Throws `FonError.alreadyExists` when the key is present.
    @discardableResult
    public func addBool(key: String, value: Bool) throws -> FonCollection {
        let flag: Int32 = value ? 1 : 0
        try putValue(key: key, mode: FON_PUT_ADD) { target, keyPointer, keyLength, mode, err in
            fon_collection_put_bool(target, keyPointer, keyLength, flag, mode, &err)
        }
        return self
    }

    /// Sets a `bool` field, adding it when absent. Replaces any existing value.
    @discardableResult
    public func setBool(key: String, value: Bool) throws -> FonCollection {
        let flag: Int32 = value ? 1 : 0
        try putValue(key: key, mode: FON_PUT_UPSERT) { target, keyPointer, keyLength, mode, err in
            fon_collection_put_bool(target, keyPointer, keyLength, flag, mode, &err)
        }
        return self
    }

    /// Reads a `bool` field. Throws `FonError.notFound` or `FonError.typeMismatch`.
    public func getBool(key: String) throws -> Bool {
        let flag: Int32 = try getScalar(key: key, initial: Int32(0)) { target, keyPointer, keyLength, out, err in
            fon_collection_get_bool(target, keyPointer, keyLength, out, &err)
        }
        return flag != 0
    }


    // ==================== STRING ====================

    /// Adds a `string` field. Any length and any Unicode scalar values, including U+0000, are kept.
    /// Throws `FonError.alreadyExists` when the key is present.
    @discardableResult
    public func addString(key: String, value: String) throws -> FonCollection {
        try putString(key: key, value: value, mode: FON_PUT_ADD)
        return self
    }

    /// Sets a `string` field, adding it when absent. Replaces any existing value.
    @discardableResult
    public func setString(key: String, value: String) throws -> FonCollection {
        try putString(key: key, value: value, mode: FON_PUT_UPSERT)
        return self
    }

    /// Reads a `string` field. Throws `FonError.notFound` or `FonError.typeMismatch`.
    public func getString(key: String) throws -> String {
        let bytes: [UInt8] = try readBuffer(key: key, zero: UInt8(0)) { target, keyPointer, keyLength, buffer, capacity, actual, err in
            fon_collection_get_string(target, keyPointer, keyLength, buffer, capacity, &actual, &err)
        }
        return String(decoding: bytes, as: UTF8.self)
    }

    private func putString(key: String, value: String, mode: Int32) throws {
        try putValue(key: key, mode: mode) { target, keyPointer, keyLength, putMode, err in
            withNativeString(value) { valuePointer, valueLength in
                fon_collection_put_string(target, keyPointer, keyLength, valuePointer, valueLength, putMode, &err)
            }
        }
    }


    // ==================== RAW ====================

    /// Adds a `raw` (binary) field. Throws `FonError.alreadyExists` when the key is present.
    @discardableResult
    public func addRaw(key: String, value: [UInt8]) throws -> FonCollection {
        try putArray(key: key, mode: FON_PUT_ADD, values: value) { target, keyPointer, keyLength, dataPointer, dataLength, mode, err in
            fon_collection_put_raw(target, keyPointer, keyLength, dataPointer, dataLength, mode, &err)
        }
        return self
    }

    /// Sets a `raw` (binary) field, adding it when absent. Replaces any existing value.
    @discardableResult
    public func setRaw(key: String, value: [UInt8]) throws -> FonCollection {
        try putArray(key: key, mode: FON_PUT_UPSERT, values: value) { target, keyPointer, keyLength, dataPointer, dataLength, mode, err in
            fon_collection_put_raw(target, keyPointer, keyLength, dataPointer, dataLength, mode, &err)
        }
        return self
    }

    /// Reads a `raw` (binary) field. Throws `FonError.notFound` or `FonError.typeMismatch`.
    public func getRaw(key: String) throws -> [UInt8] {
        return try readBuffer(key: key, zero: UInt8(0)) { target, keyPointer, keyLength, buffer, capacity, actual, err in
            fon_collection_get_raw(target, keyPointer, keyLength, buffer, capacity, &actual, &err)
        }
    }
}
