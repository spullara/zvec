import Foundation
import CZvec

/// Defines the schema for a zvec collection
public class CollectionSchema {
    internal let handle: zvec_schema_t

    /// Create a new collection schema
    /// - Parameter name: The name of the collection
    public init(name: String) {
        self.handle = zvec_schema_create(name)
    }

    deinit {
        zvec_schema_destroy(handle)
    }

    /// Add a scalar field to the schema
    /// - Parameters:
    ///   - name: Field name
    ///   - dataType: The data type of the field
    ///   - nullable: Whether the field can be null
    @discardableResult
    public func addField(_ name: String, dataType: DataType, nullable: Bool = false) throws -> CollectionSchema {
        let status = zvec_schema_add_field(handle, name, dataType.cValue, nullable)
        try ZvecError.check(status)
        return self
    }

    /// Add a vector field to the schema
    /// - Parameters:
    ///   - name: Field name
    ///   - dataType: The vector data type (e.g., .vectorFP32)
    ///   - dimension: The dimension of the vector
    ///   - nullable: Whether the field can be null
    ///   - metric: Distance metric type (default: inner product)
    @discardableResult
    public func addVectorField(_ name: String, dataType: DataType = .vectorFP32,
                                dimension: UInt32, nullable: Bool = false,
                                metric: MetricType = .ip) throws -> CollectionSchema {
        let status = zvec_schema_add_vector_field(handle, name, dataType.cValue, dimension, nullable, metric.cValue)
        try ZvecError.check(status)
        return self
    }
}

