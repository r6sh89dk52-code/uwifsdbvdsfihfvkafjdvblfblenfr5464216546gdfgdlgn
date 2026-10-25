import Foundation

/// A single validated native clinical generation yields one unchanged nursing
/// workbook. No demo manifests or guessed stock values are permitted.
public enum N2VerifiedNursingWorkbook {
    public enum Failure:Error,Equatable {
        case noPhysicalHistory, incompleteOrUnreconciled
    }
    public struct Result:Sendable {
        public let xlsx:Data
        public let stockKnownRows:Int
        public let stockUnknownRows:Int
        public let day:String
    }
    public static func export(snapshot:Data,catalog:Data,template:Data,
                              date:String,shift:String,responsible:String,site:String="")throws->Result {
        let report=try N2NursingReportBuilder.daily(
            snapshot:snapshot,catalog:catalog,date:date,site:site)
        guard report.rows.count==98 else{throw Failure.incompleteOrUnreconciled}
        let known=report.rows.filter{$0.stockKnown}.count
        // Export each absent-lot stock cell as recorded 0, without creating a physical lot.
        // The stockKnown flag remains false for unverified physical counts.
        guard report.exportable else{throw Failure.incompleteOrUnreconciled}
        let manifest=try report.manifest(shift:shift,responsible:responsible)
        let book=try N1sNursingExcelWriter.export(base:template,manifest:manifest)
        guard book.sheetCount==1,book.writtenRows==98,book.xlsx.count>20_000,
              book.xlsx.starts(with:[0x50,0x4B,0x03,0x04]) else{
            throw Failure.incompleteOrUnreconciled
        }
        return Result(xlsx:book.xlsx,stockKnownRows:known,
                      stockUnknownRows:98-known,day:date)
    }
    /// Verified multi-day report, explicitly labeled CONSOLIDADO with start/end.
    public static func exportRange(snapshot:Data,catalog:Data,template:Data,
                                   start:String,end:String,responsible:String,
                                   site:String="",mappings:Data?=nil,
                                   reconstructFromCount:Bool=false)throws->Result {
        // Retrospective count-based reconstruction is opt-in for the 9th-day
        // export only; arbitrary date ranges keep the original physical ledger.
        let report:N2NursingReport
        if reconstructFromCount {
            guard let mappings else{throw Failure.incompleteOrUnreconciled}
            report=try N2NursingReportBuilder.reconstructedCut(
                snapshot:snapshot,catalog:catalog,mappings:mappings,
                start:start,end:end,site:site)
        } else {
            report=try N2NursingReportBuilder.range(
                snapshot:snapshot,catalog:catalog,start:start,end:end,site:site)
        }
        guard report.rows.count==98,report.exportable else{
            throw Failure.incompleteOrUnreconciled
        }
        let known=report.rows.filter(\.stockKnown).count
        // Export each absent-lot stock cell as recorded 0, without creating a physical lot.
        // The stockKnown flag remains false for unverified physical counts.
        let manifest=try report.manifest(shift:"CONSOLIDADO",responsible:responsible)
        let book=try N1sNursingExcelWriter.export(base:template,manifest:manifest)
        guard book.sheetCount==1,book.writtenRows==98,book.xlsx.count>20_000,
              book.xlsx.starts(with:[0x50,0x4B,0x03,0x04]) else{
            throw Failure.incompleteOrUnreconciled
        }
        return Result(xlsx:book.xlsx,stockKnownRows:known,
                      stockUnknownRows:98-known,day:start)
    }
}

