import Foundation
import CZvec

/// Data types for collection fields
public enum DataType: UInt32 {
    case undefined = 0
    case binary = 1
    case string = 2
    case bool = 3
    case int32 = 4
    case int64 = 5
    case uint32 = 6
    case uint64 = 7
    case float32 = 8
    case float64 = 9
    case vectorFP32 = 23
    case vectorFP16 = 22
    case vectorInt8 = 26

    internal var cValue: zvec_data_type_t {
        return zvec_data_type_t(rawValue: self.rawValue)
    }
}

/// Index types for vector fields
public enum IndexType: UInt32 {
    case undefined = 0
    case hnsw = 1
    case ivf = 3
    case flat = 4
    case invert = 10
}

/// Distance metric types
public enum MetricType: UInt32 {
    case undefined = 0
    case l2 = 1
    case ip = 2
    case cosine = 3

    internal var cValue: zvec_metric_type_t {
        return zvec_metric_type_t(rawValue: self.rawValue)
    }
}

/// Quantization types
public enum QuantizeType: UInt32 {
    case undefined = 0
    case fp16 = 1
    case int8 = 2
    case int4 = 3
}

