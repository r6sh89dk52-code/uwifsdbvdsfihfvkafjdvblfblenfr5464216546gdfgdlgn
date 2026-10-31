import Foundation
#if canImport(os)
import os
#endif

/// Fixed operation names only: no patient fields, DNI, query, password or key.
/// Instruments Points of Interest can correlate these spans with CPU/time.
struct N2PerformanceSpan {
    #if canImport(os)
    private static let log=OSLog(subsystem:"pe.danper.saludmovil.performance",category:.pointsOfInterest)
    private let id:OSSignpostID
    private let name:StaticString
    #endif
    init(_ name:StaticString) {
        #if canImport(os)
        self.name=name;id=OSSignpostID(log:Self.log)
        os_signpost(.begin,log:Self.log,name:name,signpostID:id)
        #endif
    }
    func end() {
        #if canImport(os)
        os_signpost(.end,log:Self.log,name:name,signpostID:id)
        #endif
    }
}
