import Foundation

/// Revision value is captured on the SwiftUI main actor before scheduling.
public struct N1jRevisionClock: Sendable, Equatable {
    public enum Failure: Error, Equatable { case exhausted }
    public private(set) var latest: Int64
    public init(recoveredRevision: Int64 = 0) {
        latest = max(0, recoveredRevision)
    }
    @discardableResult
    public mutating func capture() throws -> Int64 {
        guard latest < Int64.max else { throw Failure.exhausted }
        latest += 1
        return latest
    }
    public func isLatest(_ revision: Int64) -> Bool { revision == latest }
}
