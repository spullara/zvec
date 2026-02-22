import Foundation
import CZvec

/// A document in a zvec collection
public class Doc {
    internal let handle: zvec_doc_t
    internal let ownsHandle: Bool

    /// Create a new document with a primary key
    /// - Parameter pk: The primary key string
    public init(pk: String) {
        self.handle = zvec_doc_create(pk)
        self.ownsHandle = true
    }

    /// Wrap an existing C handle (used for query results)
    internal init(handle: zvec_doc_t, ownsHandle: Bool = true) {
        self.handle = handle
        self.ownsHandle = ownsHandle
    }

    deinit {
        if ownsHandle {
            zvec_doc_destroy(handle)
        }
    }

    /// The primary key of this document
    public var pk: String {
        guard let cstr = zvec_doc_get_pk(handle) else { return "" }
        return String(cString: cstr)
    }

    /// The relevance score (set after query)
    public var score: Float {
        return zvec_doc_get_score(handle)
    }

    // MARK: - Field Setters

    /// Set a string field value
    @discardableResult
    public func set(_ field: String, string value: String) throws -> Doc {
        try ZvecError.check(zvec_doc_set_string(handle, field, value))
        return self
    }

    /// Set an Int32 field value
    @discardableResult
    public func set(_ field: String, int32 value: Int32) throws -> Doc {
        try ZvecError.check(zvec_doc_set_int32(handle, field, value))
        return self
    }

    /// Set an Int64 field value
    @discardableResult
    public func set(_ field: String, int64 value: Int64) throws -> Doc {
        try ZvecError.check(zvec_doc_set_int64(handle, field, value))
        return self
    }

    /// Set a Float field value
    @discardableResult
    public func set(_ field: String, float value: Float) throws -> Doc {
        try ZvecError.check(zvec_doc_set_float(handle, field, value))
        return self
    }

    /// Set a Double field value
    @discardableResult
    public func set(_ field: String, double value: Double) throws -> Doc {
        try ZvecError.check(zvec_doc_set_double(handle, field, value))
        return self
    }

    /// Set a Bool field value
    @discardableResult
    public func set(_ field: String, bool value: Bool) throws -> Doc {
        try ZvecError.check(zvec_doc_set_bool(handle, field, value))
        return self
    }

    /// Set a vector (float array) field value
    @discardableResult
    public func set(_ field: String, vector value: [Float]) throws -> Doc {
        try value.withUnsafeBufferPointer { buf in
            try ZvecError.check(zvec_doc_set_vector_float(handle, field, buf.baseAddress, UInt32(value.count)))
        }
        return self
    }

    // MARK: - Field Getters

    /// Get a string field value
    public func getString(_ field: String) throws -> String {
        var cstr: UnsafePointer<CChar>?
        try ZvecError.check(zvec_doc_get_string(handle, field, &cstr))
        guard let cstr = cstr else { throw ZvecError.notFound("field \(field)") }
        return String(cString: cstr)
    }

    /// Get an Int64 field value
    public func getInt64(_ field: String) throws -> Int64 {
        var value: Int64 = 0
        try ZvecError.check(zvec_doc_get_int64(handle, field, &value))
        return value
    }

    /// Get a Float field value
    public func getFloat(_ field: String) throws -> Float {
        var value: Float = 0
        try ZvecError.check(zvec_doc_get_float(handle, field, &value))
        return value
    }

    /// Get a Double field value
    public func getDouble(_ field: String) throws -> Double {
        var value: Double = 0
        try ZvecError.check(zvec_doc_get_double(handle, field, &value))
        return value
    }

    /// Get a vector (float array) field value
    public func getVectorFloat(_ field: String) throws -> [Float] {
        var ptr: UnsafePointer<Float>?
        var dim: UInt32 = 0
        try ZvecError.check(zvec_doc_get_vector_float(handle, field, &ptr, &dim))
        guard let ptr = ptr, dim > 0 else { return [] }
        return Array(UnsafeBufferPointer(start: ptr, count: Int(dim)))
    }
}

