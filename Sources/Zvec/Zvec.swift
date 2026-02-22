import Foundation
import CZvec

/// Top-level namespace for zvec operations
public enum Zvec {
    /// Initialize the zvec library. Call this once before using any other zvec functions.
    public static func initialize() throws {
        try ZvecError.check(zvec_init())
    }
}

