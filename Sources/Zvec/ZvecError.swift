import Foundation
import CZvec

/// Error type for zvec operations
public enum ZvecError: Error, LocalizedError {
    case ok
    case notFound(String)
    case alreadyExists(String)
    case invalidArgument(String)
    case permissionDenied(String)
    case failedPrecondition(String)
    case resourceExhausted(String)
    case unavailable(String)
    case internalError(String)
    case notSupported(String)
    case unknown(String)

    public var errorDescription: String? {
        switch self {
        case .ok: return "OK"
        case .notFound(let msg): return "Not found: \(msg)"
        case .alreadyExists(let msg): return "Already exists: \(msg)"
        case .invalidArgument(let msg): return "Invalid argument: \(msg)"
        case .permissionDenied(let msg): return "Permission denied: \(msg)"
        case .failedPrecondition(let msg): return "Failed precondition: \(msg)"
        case .resourceExhausted(let msg): return "Resource exhausted: \(msg)"
        case .unavailable(let msg): return "Unavailable: \(msg)"
        case .internalError(let msg): return "Internal error: \(msg)"
        case .notSupported(let msg): return "Not supported: \(msg)"
        case .unknown(let msg): return "Unknown error: \(msg)"
        }
    }

    internal static func check(_ status: zvec_status_t) throws {
        guard status.code != ZVEC_STATUS_OK else { return }
        let msg = withUnsafePointer(to: status.message) { ptr in
            ptr.withMemoryRebound(to: CChar.self, capacity: 512) { cstr in
                String(cString: cstr)
            }
        }
        switch status.code {
        case ZVEC_STATUS_NOT_FOUND: throw ZvecError.notFound(msg)
        case ZVEC_STATUS_ALREADY_EXISTS: throw ZvecError.alreadyExists(msg)
        case ZVEC_STATUS_INVALID_ARGUMENT: throw ZvecError.invalidArgument(msg)
        case ZVEC_STATUS_PERMISSION_DENIED: throw ZvecError.permissionDenied(msg)
        case ZVEC_STATUS_FAILED_PRECONDITION: throw ZvecError.failedPrecondition(msg)
        case ZVEC_STATUS_RESOURCE_EXHAUSTED: throw ZvecError.resourceExhausted(msg)
        case ZVEC_STATUS_UNAVAILABLE: throw ZvecError.unavailable(msg)
        case ZVEC_STATUS_INTERNAL_ERROR: throw ZvecError.internalError(msg)
        case ZVEC_STATUS_NOT_SUPPORTED: throw ZvecError.notSupported(msg)
        default: throw ZvecError.unknown(msg)
        }
    }
}

