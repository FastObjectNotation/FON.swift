#ifndef FON_H
#define FON_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif


// ==================== RESULT CODES ====================

#define FON_OK                    0
#define FON_ERROR_FILE_NOT_FOUND  1
#define FON_ERROR_PARSE_FAILED    2
#define FON_ERROR_WRITE_FAILED    3
#define FON_ERROR_INVALID_ARGUMENT 4


// ==================== ERROR STRUCT ====================

/**
 * Error information returned by native functions.
 * `code` is one of the FON_ERROR_* constants above (0 = OK).
 * `message` is a null-terminated UTF-8 string (max 255 bytes + NUL).
 */
typedef struct {
    int32_t code;
    char    message[256];
} FonError;


// ==================== VERSION ====================

/**
 * Returns a pointer to a static null-terminated UTF-8 string with the library
 * version, e.g. "0.2.1". The pointer is valid for the lifetime of the process.
 */
const char *fon_version(void);


// ==================== CONFIGURATION ====================

/** Enable (enable != 0) or disable raw-data unpacking during deserialization. */
void fon_set_raw_unpack(int32_t enable);

/** Set the maximum nesting depth for deserialization (default: 64, minimum: 1). */
void fon_set_max_depth(int32_t depth);


// ==================== MEMORY MANAGEMENT ====================

/**
 * Create a new, empty FonDump. The caller owns the returned handle and must
 * release it via fon_dump_free (unless ownership is transferred elsewhere).
 */
void *fon_dump_create(void);

/** Free a FonDump previously created by fon_dump_create or fon_deserialize_*. */
void fon_dump_free(void *dump);

/** Return the number of collections stored in the dump. */
int64_t fon_dump_size(void *dump);

/**
 * Return a borrowed pointer to the collection at the given index inside the dump.
 * The returned handle is owned by the dump — do NOT call fon_collection_free on it.
 * Returns NULL if the dump is null or the index is out of range.
 */
void *fon_dump_get(void *dump, uint64_t index);

/**
 * Create a new, empty FonCollection. The caller owns the returned handle and
 * must release it via fon_collection_free (unless ownership is transferred via
 * fon_dump_add or fon_collection_add_collection).
 */
void *fon_collection_create(void);

/**
 * Free a FonCollection previously created by fon_collection_create or
 * fon_deserialize_collection_from_buffer.
 * WARNING: Do NOT call this after transferring ownership via fon_dump_add or
 * fon_collection_add_collection — that causes a double-free.
 */
void fon_collection_free(void *collection);

/** Return the number of fields in the collection. */
int64_t fon_collection_size(void *collection);


// ==================== SERIALIZATION ====================

/**
 * Serialize a dump to a .fon file at the given UTF-8 path.
 * `max_threads`: hint for the Rayon thread pool; 0 uses the global pool.
 * Returns FON_OK on success, or an error code with details in *error.
 */
int32_t fon_serialize_to_file(
    void       *dump,
    const char *path,
    int32_t     max_threads,
    FonError   *error
);


// ==================== DESERIALIZATION ====================

/**
 * Deserialize a .fon file at the given UTF-8 path into a new FonDump.
 * The caller owns the returned handle and must free it via fon_dump_free.
 * Returns NULL on error with details in *error.
 */
void *fon_deserialize_from_file(
    const char *path,
    int32_t     max_threads,
    FonError   *error
);


// ==================== BUFFER SERIALIZATION ====================

/**
 * Serialize a dump to a caller-supplied UTF-8 buffer (two-call pattern).
 *
 * First call: pass buffer=NULL, buffer_size=0 — *required_size receives the
 * exact byte count needed.
 * Second call: allocate buffer of *required_size bytes and call again to fill it.
 * Output is NOT null-terminated; *required_size is the exact byte count.
 */
int32_t fon_serialize_dump_to_buffer(
    void     *dump,
    uint8_t  *buffer,
    int64_t   buffer_size,
    int64_t  *required_size,
    int32_t   max_threads,
    FonError *error
);

/**
 * Serialize a single collection to a caller-supplied UTF-8 buffer (two-call pattern).
 * See fon_serialize_dump_to_buffer for the protocol.
 */
int32_t fon_serialize_collection_to_buffer(
    void     *collection,
    uint8_t  *buffer,
    int64_t   buffer_size,
    int64_t  *required_size,
    FonError *error
);


// ==================== BUFFER DESERIALIZATION ====================

/**
 * Parse a multi-line UTF-8 buffer into a new FonDump.
 * The input does not need to be null-terminated.
 * The caller owns the returned handle and must free it via fon_dump_free.
 * Returns NULL on error with details in *error.
 */
void *fon_deserialize_dump_from_buffer(
    const uint8_t *data,
    int64_t        size,
    int32_t        max_threads,
    FonError      *error
);

/**
 * Parse a single-line UTF-8 buffer into a new FonCollection.
 * The input does not need to be null-terminated.
 * The caller owns the returned handle and must free it via fon_collection_free
 * (unless ownership is transferred via fon_dump_add or fon_collection_add_collection).
 * Returns NULL on error with details in *error.
 */
void *fon_deserialize_collection_from_buffer(
    const uint8_t *data,
    int64_t        size,
    FonError      *error
);


// ==================== DUMP ADD OPERATIONS ====================

/**
 * Add a collection to a dump under the given id.
 * OWNERSHIP TRANSFER: after a successful call, the collection handle is owned by
 * the dump. The caller MUST NOT use it again and MUST NOT call fon_collection_free
 * on it — doing so causes a double-free.
 */
int32_t fon_dump_add(
    void     *dump,
    uint64_t  id,
    void     *collection,
    FonError *error
);


// ==================== COLLECTION ADD OPERATIONS ====================

int32_t fon_collection_add_int(
    void       *collection,
    const char *key,
    int32_t     value,
    FonError   *error
);

int32_t fon_collection_add_long(
    void       *collection,
    const char *key,
    int64_t     value,
    FonError   *error
);

int32_t fon_collection_add_float(
    void       *collection,
    const char *key,
    float       value,
    FonError   *error
);

int32_t fon_collection_add_double(
    void       *collection,
    const char *key,
    double      value,
    FonError   *error
);

/** value: 0 = false, non-zero = true */
int32_t fon_collection_add_bool(
    void       *collection,
    const char *key,
    int32_t     value,
    FonError   *error
);

int32_t fon_collection_add_string(
    void       *collection,
    const char *key,
    const char *value,
    FonError   *error
);

int32_t fon_collection_add_int_array(
    void          *collection,
    const char    *key,
    const int32_t *values,
    int64_t        count,
    FonError      *error
);

int32_t fon_collection_add_float_array(
    void         *collection,
    const char   *key,
    const float  *values,
    int64_t       count,
    FonError     *error
);

/**
 * Add a nested collection under key inside parent.
 * OWNERSHIP TRANSFER: child is owned by parent after this call.
 * Do NOT free child or use it again after a successful call.
 */
int32_t fon_collection_add_collection(
    void       *parent,
    const char *key,
    void       *child,
    FonError   *error
);

/**
 * Add an array of nested collections under key inside parent.
 * OWNERSHIP TRANSFER: every handle in children[] is owned by parent after this call.
 */
int32_t fon_collection_add_collection_array(
    void        *parent,
    const char  *key,
    void *const *children,
    int64_t      count,
    FonError    *error
);


// ==================== COLLECTION GET OPERATIONS ====================

int32_t fon_collection_get_int(
    void       *collection,
    const char *key,
    int32_t    *value,
    FonError   *error
);

int32_t fon_collection_get_long(
    void       *collection,
    const char *key,
    int64_t    *value,
    FonError   *error
);

int32_t fon_collection_get_float(
    void       *collection,
    const char *key,
    float      *value,
    FonError   *error
);

int32_t fon_collection_get_double(
    void       *collection,
    const char *key,
    double     *value,
    FonError   *error
);

/** Writes 1 for true, 0 for false into *value. */
int32_t fon_collection_get_bool(
    void       *collection,
    const char *key,
    int32_t    *value,
    FonError   *error
);

/**
 * Write a null-terminated UTF-8 string into buffer.
 * buffer_size must be large enough to hold the value + NUL byte.
 */
int32_t fon_collection_get_string(
    void       *collection,
    const char *key,
    uint8_t    *buffer,
    int64_t     buffer_size,
    FonError   *error
);

/**
 * Two-call pattern: pass buffer=NULL, buffer_size=0 to read *actual_size,
 * then allocate and call again to fill the array.
 */
int32_t fon_collection_get_int_array(
    void       *collection,
    const char *key,
    int32_t    *buffer,
    int64_t     buffer_size,
    int64_t    *actual_size,
    FonError   *error
);

int32_t fon_collection_get_float_array(
    void       *collection,
    const char *key,
    float      *buffer,
    int64_t     buffer_size,
    int64_t    *actual_size,
    FonError   *error
);

/**
 * Return a borrowed pointer to a nested collection under key.
 * OWNED BY PARENT — do NOT free the returned handle.
 * Returns NULL if key is missing or value is not a nested collection.
 */
void *fon_collection_get_collection(
    void       *parent,
    const char *key,
    FonError   *error
);

/**
 * Two-call pattern for an array of nested collection handles.
 * All returned handles are owned by parent — do NOT free them.
 */
int32_t fon_collection_get_collection_array(
    void      *parent,
    const char *key,
    void      **buffer,
    int64_t    buffer_size,
    int64_t   *actual_size,
    FonError  *error
);


#ifdef __cplusplus
}
#endif

#endif /* FON_H */
