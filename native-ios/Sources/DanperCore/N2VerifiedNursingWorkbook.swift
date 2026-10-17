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
                              date:String,shift:String,responsible:String)throws->Result {
        let report=try N2NursingReportBuilder.daily(
            snapshot:snapshot,catalog:catalog,date:date)
        guard report.rows.count==98 else{throw Failure.incompleteOrUnreconciled}
        let known=report.rows.filter{$0.stockKnown}.count
        guard known>0 else{throw Failure.noPhysicalHistory}
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
}
