import Foundation
import CoreFoundation
import Crypto

/// Cross-checks synthetic TypeScript reconciliation + actual exported OOXML.
/// No XLSX parser, patient import, inventory writer or production integration.
internal enum N1qAuditError: Error, Equatable {
    case invalidReference, alteredSource, invalidCatalog, invalidEvents
    case invalidPhysicalLedger, invalidReconciliation, invalidFormula
    case invalidWorkbookCell, incompleteCutoff
}
internal struct N1qParityReport: Equatable {
    let sourceSHA256:String
    let workbookSHA256:String
    let products:Int
    let verifiedOpenings:Int
    let verifiedCounts:Int
    let receipts:Int
    let rowsWithFormulas:Int
    let reviewed:Bool
    let physicalClinicalLines:Int
    let canActivate:Bool
    let isNativeWorkbookExporter:Bool
}
internal enum N1qReconciliationParityAudit {
    private static let sheets=["BD MATERIALES","CONTEO","INGRESOS","RESU",
             "CONSUMOS","JUSTIFICACIONES","GUIA","@subuo","BASE TRU","@uo"]
    private static let sampleFormulaColumns:[String:[String]]=[
        "conteo":["H"],"ingresos":["D","E","F","G","X"],
        "resu":["E","F","G","H","I","J","L"]]
    private static func string(_ x:Any?) -> String? { x as? String }
    private static func number(_ x:Any?) -> Double? {
        guard let n=x as? NSNumber,
              CFGetTypeID(n) != CFBooleanGetTypeID(),n.doubleValue.isFinite else {return nil}
        return n.doubleValue
    }
    private static func integer(_ x:Any?) -> Int? {
        guard let n=number(x),n>=0,n<=10_000_000,
              n.rounded()==n else {return nil}
        return Int(n)
    }
    private static func instant(_ x:Any?) -> Int64? {
        guard let n=number(x),n>=1,n<=9_007_199_254_740_991,
              n.rounded()==n else {return nil}
        return Int64(n)
    }
    private static func boolean(_ x:Any?) -> Bool? {
        guard let n=x as? NSNumber,CFGetTypeID(n)==CFBooleanGetTypeID() else {return nil}
        return n.boolValue
    }
    private static func digest(_ text:String) -> Bool {
        text.count==64 && text.utf8.allSatisfy{
            (48...57).contains($0)||(97...102).contains($0)}
    }
    private static func sha(_ data:Data)->String {
        SHA256.hash(data:data).map{String(format:"%02x",$0)}.joined()
    }
    private static func encoded(_ value:Any) throws -> Data {
        try JSONSerialization.data(withJSONObject:value,options:[.sortedKeys,.fragmentsAllowed])
    }
    private static func equalJSON(_ lhs:Any,_ rhs:Any) throws -> Bool {
        try encoded(lhs)==encoded(rhs)
    }
    private static func isoDate(_ value:String) -> Bool {
        guard value.range(of:#"^\d{4}-\d{2}-\d{2}$"#,options:.regularExpression) != nil,
              let year=Int(value.prefix(4)),let month=Int(value.dropFirst(5).prefix(2)),
              let day=Int(value.suffix(2)),year>=1900 else {return false}
        var cal=Calendar(identifier:.gregorian)
        cal.timeZone=TimeZone(secondsFromGMT:0)!
        guard let date=cal.date(from:DateComponents(year:year,month:month,day:day))
        else{return false}
        return cal.component(.year,from:date)==year &&
               cal.component(.month,from:date)==month &&
               cal.component(.day,from:date)==day
    }
    private static func excelDate(_ value:String) throws -> String {
        guard isoDate(value) else {throw N1qAuditError.invalidEvents}
        var cal=Calendar(identifier:.gregorian)
        cal.timeZone=TimeZone(secondsFromGMT:0)!
        let year=Int(value.prefix(4))!,month=Int(value.dropFirst(5).prefix(2))!,
            day=Int(value.suffix(2))!
        let dayDate=cal.date(from:DateComponents(year:year,month:month,day:day))!
        return String(Int(dayDate.timeIntervalSince1970/86400.0)+25569)
    }
    private static func expectedFormula(_ sheet:String,_ column:String,_ row:Int,
                                        reviewed:Bool)->String {
        let n=String(row)
        switch sheet {
        case "conteo":
            if column=="H" {return "IF(COUNTA(D"+n+":G"+n+")=0,\"\",SUM(D"+n+":G"+n+"))"}
        case "ingresos":
            let source=["D":"J","E":"N","F":"R","G":"V"]
            if let letter=source[column] {
                return "IF("+letter+n+"=\"\",\"\",IF("+letter+n+"-TODAY()<=90,1,0))"
            }
            if column=="X" && reviewed {
                return "IF(COUNTA(H"+n+",L"+n+",P"+n+",T"+n+")=0,0,SUM(H"+n+",L"+n+",P"+n+",T"+n+"))"
            }
        case "resu":
            switch column {
            case "E": return "IF(COUNT(INGRESOS!X"+n+")=0,\"\",INGRESOS!X"+n+")"
            case "F": return "SUMIF(TB_CONSUMOS[CÓDIGO],A"+n+",TB_CONSUMOS[CANTIDAD])"
            case "G": return "IF(OR(D"+n+"=\"\",E"+n+"=\"\"),\"\",SUM(D"+n+":E"+n+")-F"+n+")"
            case "H": return "IF(COUNT(CONTEO!D"+n+")=0,\"\",CONTEO!D"+n+")"
            case "I": return "IF(OR(G"+n+"=\"\",H"+n+"=\"\"),\"\",G"+n+"-H"+n+")"
            case "J": return "IF(I"+n+"=\"\",\"\",IF(I"+n+"<0,\"SOBRANTE\",IF(I"+n+"=0,\"-\",\"FALTANTE\")))"
            case "L": return "IF(OR(K"+n+"=\"\",G"+n+"=\"\"),\"\",K"+n+"-G"+n+")"
            default: break
            }
        default: break
        }
        return ""
    }

    private struct Event {
        let raw:[String:Any]
        let id:String
        let kind:String
        let code:String
        let date:String
        let at:Int64
        let quantity:Int
        let document:String
        let expires:String
        let periodEnd:String
        let voidOf:String
        let subdivision:String
    }
    private static func parseEvents(_ input:[[String:Any]],catalog:Set<String>) throws -> [Event] {
        guard input.count<=1200 else {throw N1qAuditError.invalidEvents}
        var ids=Set<String>(),usedVoids=Set<String>()
        var previous:[String:Event]=[:]
        var records:[Event]=[]
        for raw in input {
            guard let id=string(raw["id"]),!id.isEmpty,id.count<=120,
                  ids.insert(id).inserted,
                  let kind=string(raw["kind"]),
                  ["opening","receipt","count","review","void"].contains(kind),
                  let location=string(raw["subdivision"]),!location.isEmpty,
                  let date=string(raw["date"]),isoDate(date),
                  let at=instant(raw["at"]),let quantity=integer(raw["quantity"]),
                  let reason=string(raw["reason"]),reason.count>=8,reason.count<=240,
                  let code=string(raw["code"]),let document=string(raw["document"]),
                  let expires=string(raw["expires"]),let periodEnd=string(raw["periodEnd"]),
                  let voidOf=string(raw["voidOf"]) else {
                throw N1qAuditError.invalidEvents
            }
            if ["opening","receipt","count"].contains(kind) {
                guard catalog.contains(code),periodEnd.isEmpty,voidOf.isEmpty else {
                    throw N1qAuditError.invalidEvents
                }
                if kind=="receipt" {
                    guard quantity>0,(3...100).contains(document.count),
                          expires.isEmpty || isoDate(expires) else {
                        throw N1qAuditError.invalidEvents
                    }
                }else if !document.isEmpty || !expires.isEmpty {
                    throw N1qAuditError.invalidEvents
                }
            }else if kind=="review" {
                guard code.isEmpty,document.isEmpty,expires.isEmpty,voidOf.isEmpty,
                      quantity==0,isoDate(periodEnd),periodEnd>=date else {
                    throw N1qAuditError.invalidEvents
                }
            }else{
                guard code.isEmpty,document.isEmpty,expires.isEmpty,
                      periodEnd.isEmpty,quantity==0,!voidOf.isEmpty,
                      let prior=previous[voidOf],prior.kind != "void",
                      !usedVoids.contains(voidOf),prior.subdivision==location,
                      at>=prior.at else {throw N1qAuditError.invalidEvents}
                usedVoids.insert(voidOf)
            }
            let row=Event(raw:raw,id:id,kind:kind,code:code,date:date,at:at,
                    quantity:quantity,document:document,expires:expires,
                    periodEnd:periodEnd,voidOf:voidOf,subdivision:location)
            previous[id]=row
            records.append(row)
        }
        let live=records.filter{$0.kind != "void" && !usedVoids.contains($0.id)}
        var unique=Set<String>()
        for row in live {
            let key:String
            if row.kind=="opening" || row.kind=="count" {
                key=[row.subdivision,row.kind,row.date,row.code].joined(separator:"|")
            }else if row.kind=="review" {
                key=[row.subdivision,"review",row.date,row.periodEnd].joined(separator:"|")
            }else if row.kind=="receipt" {
                key=[row.subdivision,"receipt",row.date,row.code,
                     row.document.uppercased()].joined(separator:"|")
            }else {continue}
            guard unique.insert(key).inserted else {throw N1qAuditError.invalidEvents}
        }
        for r in live where r.kind=="receipt" {
            if live.contains(where:{
                $0.kind=="review" && $0.subdivision==r.subdivision &&
                r.date >= $0.date && r.date <= $0.periodEnd && r.at>$0.at
            }) {throw N1qAuditError.invalidEvents}
        }
        return live
    }
    /// Compare TypeScript's workbook-derived sample cells and 432 material
    /// balances without ever persisting original clinical input.
    static func inspect(snapshot:Data,reference:Data) throws -> N1qParityReport {
        guard let expected=try? JSONSerialization.jsonObject(with:reference) as? [String:Any],
              integer(expected["schema"])==1,
              let mode=string(expected["mode"]),["reviewed","unreviewed","voided"].contains(mode),
              let sourceSHA=string(expected["sourceSHA256"]),
              digest(sourceSHA),sha(snapshot)==sourceSHA else {
            throw N1qAuditError.alteredSource
        }
        guard let start=string(expected["periodStart"]),isoDate(start),
              let end=string(expected["periodEnd"]),isoDate(end),start<=end,
              let site=string(expected["subdivision"]),site=="LA VENTUROSA",
              let selectedIDs=expected["selectedVisitIDs"] as? [String],
              let catalog=expected["catalog"] as? [[String:Any]],catalog.count==432,
              let rawEvents=expected["events"] as? [[String:Any]],
              let reported=expected["byCode"] as? [String:[String:Any]],
              let expectedSummary=expected["summary"] as? [String:Any],
              let workbook=expected["workbook"] as? [String:Any] else {
            throw N1qAuditError.invalidReference
        }
        var codes=Set<String>(),catalogCodes:[String]=[]
        for p in catalog {
            guard let code=string(p["code"]),code.range(of:#"^\d+$"#,
                  options:.regularExpression) != nil,
                  let name=string(p["name"]),!name.isEmpty,
                  let unit=string(p["unit"]),!unit.isEmpty,codes.insert(code).inserted
            else {throw N1qAuditError.invalidCatalog}
            catalogCodes.append(code)
        }
        guard Set(reported.keys)==codes else {throw N1qAuditError.invalidCatalog}
        let events=try parseEvents(rawEvents,catalog:codes).filter{$0.subdivision==site}
        let review=events.contains{$0.kind=="review" && $0.date==start && $0.periodEnd==end}
        guard (mode=="reviewed")==review else {throw N1qAuditError.invalidReconciliation}
        let physical=try N1eLegacyClinicalAudit.inspect(snapshot)
        guard let raw=try? JSONSerialization.jsonObject(with:snapshot) as? [String:Any],
              let visits=raw["attentions"] as? [[String:Any]] else {
            throw N1qAuditError.invalidPhysicalLedger
        }
        var linked:[String:Double?]=[:],pointer=0
        for visit in visits where string(visit["status"])=="saved" {
            guard let id=string(visit["id"]),let items=visit["items"] as? [[String:Any]]
            else {throw N1qAuditError.invalidPhysicalLedger}
            for item in items {
                guard let iid=string(item["id"]),pointer<physical.consumptionR.count else {
                    throw N1qAuditError.invalidPhysicalLedger
                }
                linked[id+"\u{001F}"+iid]=physical.consumptionR[pointer]
                pointer+=1
            }
        }
        guard pointer==physical.consumptionR.count else {
            throw N1qAuditError.invalidPhysicalLedger
        }
        var eligibleIDs:[String]=[],consumption:[String:Int]=[:],clinicalLines=0
        for v in visits where string(v["status"])=="saved" {
            guard let id=string(v["id"]),let day=string(v["date"]),
                  let worker=v["worker"] as? [String:Any],
                  let items=v["items"] as? [[String:Any]] else {
                throw N1qAuditError.invalidPhysicalLedger
            }
            if day<start || day>end || string(worker["site"]) != site {continue}
            var completed=true
            for item in items {
                guard let itemID=string(item["id"]),
                      let value=linked[id+"\u{001F}"+itemID] ?? nil,
                      value>=0,value.rounded()==value,
                      let code=string(item["code"]),codes.contains(code) else {
                    completed=false
                    break
                }
            }
            if !completed {continue}
            eligibleIDs.append(id)
            for item in items {
                let code=string(item["code"])!,itemID=string(item["id"])!
                let value=linked[id+"\u{001F}"+itemID]!!
                consumption[code,default:0]+=Int(value)
                clinicalLines+=1
            }
        }
        guard eligibleIDs==selectedIDs else {throw N1qAuditError.invalidPhysicalLedger}
        let openings=events.filter{$0.kind=="opening" && $0.date==start}
        let counts=events.filter{$0.kind=="count" && $0.date==end}
        let receipts=events.filter{$0.kind=="receipt" && $0.date>=start && $0.date<=end}
        let countOpening=openings.count,countCount=counts.count,countReceipts=receipts.count
        let expectedWarnings:[String]=[
            ...(review ? [] : ["Ingresos no cerrados para el período: ninguna ausencia puede interpretarse como cero."]),
            ...(countOpening < 432 ? ["Stock inicial pendiente para "+String(432-countOpening)+" materiales."]:[]),
            ...(countCount < 432 ? ["Recuento final pendiente para "+String(432-countCount)+" materiales."]:[])
        ]
        guard integer(expectedSummary["openingConfirmed"])==countOpening,
              integer(expectedSummary["countConfirmed"])==countCount,
              integer(expectedSummary["receiptsConfirmed"])==countReceipts,
              boolean(expectedSummary["reviewed"])==review,
              (expectedSummary["warnings"] as? [String])==expectedWarnings else {
            throw N1qAuditError.invalidReconciliation
        }
        var computed:[String:[String:Any]]=[:]
        var receiptsPerCode:[String:[Event]]=[:]
        for code in catalogCodes {
            let opening=openings.first{$0.code==code}
            let count=counts.first{$0.code==code}
            let entries=receipts.filter{$0.code==code}.sorted{
                if $0.date != $1.date{return $0.date<$1.date}
                if $0.at != $1.at{return $0.at<$1.at}
                return $0.id<$1.id
            }
            guard entries.count<=4 else {throw N1qAuditError.invalidEvents}
            receiptsPerCode[code]=entries
            let consumed=consumption[code] ?? 0
            var record:[String:Any]=["code":code,"consumed":consumed,
                                     "receiptDetails":entries.map{$0.raw}]
            if let opening {record["opening"]=opening.quantity}
            if review {record["receipts"]=entries.reduce(0){$0+$1.quantity}}
            if let opening,review {
                let closing=opening.quantity+entries.reduce(0){$0+$1.quantity}-consumed
                guard closing>=0 else {throw N1qAuditError.incompleteCutoff}
                record["closing"]=closing
                if let count {record["difference"]=closing-count.quantity}
            }
            if let count {record["count"]=count.quantity}
            computed[code]=record
            guard let actual=reported[code],try equalJSON(actual,record) else {
                throw N1qAuditError.invalidReconciliation
            }
        }
        guard let workbookHash=string(workbook["sha256"]),digest(workbookHash),
              workbook["sheets"] as? [String]==sheets,
              integer(workbook["materials"])==432,
              integer(workbook["tables"])==19,
              integer(workbook["formulaRows"])==432,
              boolean(workbook["fullCalcOnLoad"])==true,
              boolean(workbook["forceFullCalc"])==true,
              let formulaSamples=workbook["formulaSamples"] as? [[String:Any]],
              formulaSamples.count==4 else {
            throw N1qAuditError.invalidReference
        }
        var uniqueRows=Set<Int>()
        for sample in formulaSamples {
            guard let row=integer(sample["row"]),(3...434).contains(row),
                  uniqueRows.insert(row).inserted else {throw N1qAuditError.invalidFormula}
            for (sheet,columns) in sampleFormulaColumns {
                guard let actual=sample[sheet] as? [String:String],
                      Set(actual.keys)==Set(columns) else {
                    throw N1qAuditError.invalidFormula
                }
                for column in columns {
                    guard actual[column]==expectedFormula(sheet,column,row,reviewed:review) else {
                        throw N1qAuditError.invalidFormula
                    }
                }
            }
        }
        guard let observed=workbook["physicalCells"] as? [[String:Any]],observed.count==4
        else {throw N1qAuditError.invalidWorkbookCell}
        for cell in observed {
            guard let code=string(cell["code"]),codes.contains(code),
                  let row=integer(cell["row"]),
                  catalogCodes[row-3]==code,
                  let detail=computed[code],
                  let income=cell["income"] as? [String:String],
                  let comment=string(cell["comment"]),comment.isEmpty,
                  let countD=string(cell["count"]),let openingD=string(cell["opening"])
            else {throw N1qAuditError.invalidWorkbookCell}
            let expectedCount=detail["count"].map{String(describing:$0)} ?? ""
            let expectedOpening=detail["opening"].map{String(describing:$0)} ?? ""
            guard countD==expectedCount,openingD==expectedOpening else {
                throw N1qAuditError.invalidWorkbookCell
            }
            let cols=["H","I","J","K","L","M","N","O","P","Q","R","S","T","U","V","W","X"]
            guard Set(income.keys)==Set(cols),income["X"]=="" else {
                throw N1qAuditError.invalidWorkbookCell
            }
            let positions=[["H","I","J","K"],["L","M","N","O"],
                           ["P","Q","R","S"],["T","U","V","W"]]
            var expectedIncome=Dictionary(uniqueKeysWithValues:cols.map{($0,"")})
            for (i,event) in (receiptsPerCode[code] ?? []).enumerated() {
                expectedIncome[positions[i][0]]=String(event.quantity)
                expectedIncome[positions[i][1]]=try excelDate(event.date)
                expectedIncome[positions[i][2]]=event.expires.isEmpty ?
                    "" : try excelDate(event.expires)
                expectedIncome[positions[i][3]]=event.document
            }
            guard income==expectedIncome else {throw N1qAuditError.invalidWorkbookCell}
        }
        return N1qParityReport(sourceSHA256:sourceSHA,workbookSHA256:workbookHash,
              products:catalogCodes.count,verifiedOpenings:countOpening,
              verifiedCounts:countCount,receipts:countReceipts,
              rowsWithFormulas:432,reviewed:review,physicalClinicalLines:clinicalLines,
              canActivate:false,isNativeWorkbookExporter:false)
    }
}
