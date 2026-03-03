import Foundation
import CZvec

/// A zvec vector database collection
public class Collection {
    internal let handle: zvec_collection_t

    private init(handle: zvec_collection_t) {
        self.handle = handle
    }

    deinit {
        zvec_collection_destroy(handle)
    }

    /// Create and open a new collection at the given path
    /// - Parameters:
    ///   - path: File system path for the collection data
    ///   - schema: The collection schema
    /// - Returns: A new Collection instance
    public static func createAndOpen(path: String, schema: CollectionSchema) throws -> Collection {
        var handle: zvec_collection_t?
        let status = zvec_collection_create_and_open(path, schema.handle, &handle)
        try ZvecError.check(status)
        guard let handle = handle else {
            throw ZvecError.internalError("Failed to create collection handle")
        }
        return Collection(handle: handle)
    }

    /// Open an existing collection at the given path
    /// - Parameters:
    ///   - path: File system path for the collection data
    ///   - readOnly: Whether to open in read-only mode
    /// - Returns: A Collection instance
    public static func open(path: String, readOnly: Bool = false) throws -> Collection {
        var handle: zvec_collection_t?
        let status = zvec_collection_open(path, readOnly, &handle)
        try ZvecError.check(status)
        guard let handle = handle else {
            throw ZvecError.internalError("Failed to open collection handle")
        }
        return Collection(handle: handle)
    }

    /// Flush pending writes to disk
    public func flush() throws {
        try ZvecError.check(zvec_collection_flush(handle))
    }

    /// Compact segment files on disk by merging small segments into larger ones.
    /// Call after bulk writes to reduce file descriptor usage.
    public func optimize() throws {
        try ZvecError.check(zvec_collection_optimize(handle))
    }

    /// Get the number of documents in the collection
    public func docCount() throws -> UInt64 {
        var count: UInt64 = 0
        try ZvecError.check(zvec_collection_doc_count(handle, &count))
        return count
    }

    // MARK: - Insert / Upsert / Delete

    /// Insert documents into the collection
    /// - Parameter docs: Array of Doc objects to insert
    public func insert(_ docs: [Doc]) throws {
        var handles = docs.map { $0.handle as zvec_doc_t? }
        try handles.withUnsafeMutableBufferPointer { buf in
            try ZvecError.check(zvec_collection_insert(handle, buf.baseAddress, Int32(docs.count)))
        }
    }

    /// Upsert documents into the collection (insert or update)
    /// - Parameter docs: Array of Doc objects to upsert
    public func upsert(_ docs: [Doc]) throws {
        var handles = docs.map { $0.handle as zvec_doc_t? }
        try handles.withUnsafeMutableBufferPointer { buf in
            try ZvecError.check(zvec_collection_upsert(handle, buf.baseAddress, Int32(docs.count)))
        }
    }

    /// Delete documents by primary keys
    /// - Parameter pks: Array of primary key strings
    public func delete(pks: [String]) throws {
        var cStrings = pks.map { strdup($0) }
        defer { cStrings.forEach { free($0) } }
        try cStrings.withUnsafeMutableBufferPointer { buf in
            let ptr = UnsafeMutableRawPointer(buf.baseAddress!)
                .assumingMemoryBound(to: UnsafePointer<CChar>?.self)
            try ZvecError.check(zvec_collection_delete(handle, ptr, Int32(pks.count)))
        }
    }

    // MARK: - Query

    /// Query the collection with a vector
    /// - Parameters:
    ///   - fieldName: The vector field to search
    ///   - vector: The query vector
    ///   - topk: Number of results to return
    ///   - filter: Optional filter expression
    /// - Returns: Array of matching documents with scores
    public func query(fieldName: String, vector: [Float], topk: Int,
                      filter: String? = nil) throws -> [Doc] {
        var resultPtr: UnsafeMutablePointer<zvec_doc_t?>?
        var resultCount: Int32 = 0

        try vector.withUnsafeBufferPointer { vecBuf in
            try ZvecError.check(zvec_collection_query(
                handle, fieldName, vecBuf.baseAddress, UInt32(vector.count),
                Int32(topk), filter, &resultPtr, &resultCount))
        }

        guard let resultPtr = resultPtr, resultCount > 0 else { return [] }

        var docs: [Doc] = []
        for i in 0..<Int(resultCount) {
            if let docHandle = resultPtr[i] {
                docs.append(Doc(handle: docHandle, ownsHandle: true))
            }
        }
        // Free the array (but not the individual docs — they're owned by Doc objects now)
        resultPtr.deallocate()
        return docs
    }

    // MARK: - Fetch

    /// Fetch documents by primary keys
    /// - Parameter pks: Array of primary key strings
    /// - Returns: Array of matching documents
    public func fetch(pks: [String]) throws -> [Doc] {
        var cStrings = pks.map { strdup($0) }
        defer { cStrings.forEach { free($0) } }

        var resultPtr: UnsafeMutablePointer<zvec_doc_t?>?
        var resultCount: Int32 = 0

        try cStrings.withUnsafeMutableBufferPointer { buf in
            let ptr = UnsafeMutableRawPointer(buf.baseAddress!)
                .assumingMemoryBound(to: UnsafePointer<CChar>?.self)
            try ZvecError.check(zvec_collection_fetch(
                handle, ptr, Int32(pks.count), &resultPtr, &resultCount))
        }

        guard let resultPtr = resultPtr, resultCount > 0 else { return [] }

        var docs: [Doc] = []
        for i in 0..<Int(resultCount) {
            if let docHandle = resultPtr[i] {
                docs.append(Doc(handle: docHandle, ownsHandle: true))
            }
        }
        resultPtr.deallocate()
        return docs
    }

    // MARK: - Index

    /// Create an HNSW index on a vector field
    /// - Parameters:
    ///   - fieldName: The vector field name
    ///   - metric: Distance metric type
    ///   - m: HNSW M parameter (default: 50)
    ///   - efConstruction: HNSW ef_construction parameter (default: 500)
    public func createHnswIndex(fieldName: String, metric: MetricType,
                                 m: Int32 = 50, efConstruction: Int32 = 500) throws {
        try ZvecError.check(zvec_collection_create_hnsw_index(
            handle, fieldName, metric.cValue, m, efConstruction))
    }

    /// Create an HNSW index on a vector field with progress reporting
    /// - Parameters:
    ///   - fieldName: The vector field name
    ///   - metric: Distance metric type
    ///   - m: HNSW M parameter (default: 50)
    ///   - efConstruction: HNSW ef_construction parameter (default: 500)
    ///   - progress: Callback receiving (currentCount, totalCount). Called from a background thread — dispatch to main queue for UI updates.
    public func createHnswIndex(fieldName: String, metric: MetricType,
                                 m: Int32 = 50, efConstruction: Int32 = 500,
                                 progress: @escaping (UInt32, UInt32) -> Void) throws {
        // Box the closure so we can pass it through a C void* context
        class ProgressBox {
            let callback: (UInt32, UInt32) -> Void
            init(_ callback: @escaping (UInt32, UInt32) -> Void) { self.callback = callback }
        }
        let box = ProgressBox(progress)
        let context = Unmanaged.passRetained(box).toOpaque()
        defer { Unmanaged<ProgressBox>.fromOpaque(context).release() }

        let cCallback: zvec_progress_callback_t = { current, total, userData in
            guard let userData = userData else { return }
            let box = Unmanaged<ProgressBox>.fromOpaque(userData).takeUnretainedValue()
            box.callback(current, total)
        }

        try ZvecError.check(zvec_collection_create_hnsw_index_with_progress(
            handle, fieldName, metric.cValue, m, efConstruction, cCallback, context))
    }

    /// Create a flat (brute-force) index on a vector field
    /// - Parameters:
    ///   - fieldName: The vector field name
    ///   - metric: Distance metric type
    public func createFlatIndex(fieldName: String, metric: MetricType) throws {
        try ZvecError.check(zvec_collection_create_flat_index(
            handle, fieldName, metric.cValue))
    }
}

