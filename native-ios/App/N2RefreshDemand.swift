import Foundation

/// Coordinates view refresh requests, never authenticates or caches clinical
/// data. Revision hints only decide whether another authenticated read is needed.
struct N2RefreshDemand {
    enum Cause {case lifecycle,manual,verifiedWrite(Int)}
    private(set) var reading=false
    private var pendingManual=false
    private var minimumRevision:Int?

    mutating func begin(_ cause:Cause)->Bool {
        switch cause {
        case .lifecycle:break
        case .manual:if reading {pendingManual=true}
        case .verifiedWrite(let revision):minimumRevision=max(minimumRevision ?? 0,revision)
        }
        guard !reading else{return false}
        reading=true
        return true
    }
    func canPublish(_ revision:Int)->Bool {
        minimumRevision.map{revision >= $0} ?? true
    }
    mutating func finish(observedRevision:Int?)->Bool {
        let again=observedRevision.map{pendingManual || !canPublish($0)} ?? false
        reading=false;pendingManual=false;minimumRevision=nil
        return again
    }
}
