import Foundation
import CoreFoundation
import Crypto

/// N1p only COMPARES a source snapshot against a TS-produced synthetic
/// workbook contract. It NEVER creates a workbook, edits stock or enables
/// clinical records. The user-visible iOS app has no link to this auditor.
internal enum N1pExcelParityError: Error, Equatable {
    case invalidSource, invalidReference, alteredSource, invalidWorkbookContract
    case invalidRow, invalidRowOrder, invalidExcelValue, wrongClinicalQuantity
    case wrongFrequency, wrongLink, wrongColumn, wrongStatus
}

internal struct N1pExcelParityReport: Equatable {
    let sourceSHA256: String
    let workbookSHA256: String
    let visits: Int
    let rows: Int
    let linkedDeliveries: Int
    let pendingDeliveries: Int
    let confirmedZeroRows: Int
    let sheets: Int
    let columns: Int
    let canActivate: Bool
    let canClaimOfficialReconciledExport: Bool
}

internal enum N1pExcelParityAudit {
    private static let names = [
        "BD MATERIALES","CONTEO","INGRESOS","RESU","CONSUMOS",
        "JUSTIFICACIONES","GUIA","@subuo","BASE TRU","@uo"
    ]
    private static let frequency=["PRIMERA","SEGUNDA","TERCERA","CUARTA","QUINTA"]
    private static let detail:Set<String>=[
        "INYECTABLE","CURACION DE HERIDA","SUTURAS",
        "EXTRACCION DE CUERPO EXTRAÑO","RETIRO DE PUNTOS DE SUTURA"
    ]
    private static func text(_ value:Any?) -> String? { value as? String }
    private static func n(_ value:Any?) -> Double? {
        guard let x=value as? NSNumber,
              CFGetTypeID(x) != CFBooleanGetTypeID(),x.doubleValue.isFinite else {return nil}
        return x.doubleValue
    }
    private static func yes(_ value:Any?) -> Bool? {
        guard let x=value as? NSNumber,
              CFGetTypeID(x) == CFBooleanGetTypeID() else {return nil}
        return x.boolValue
    }
    private static func integer(_ value:Any?) -> Int? {
        guard let x=n(value),x.rounded()==x,x>=0,x<=Double(Int.max) else{return nil}
        return Int(x)
    }
    private static func hash(_ raw:Data) -> String {
        SHA256.hash(data:raw).map{String(format:"%02x",$0)}.joined()
    }
    private static func digest(_ x:String) -> Bool {
        x.count==64 && x.utf8.allSatisfy{(48...57).contains($0)||(97...102).contains($0)}
    }
    private static func jsonKey(_ strings:[Any]) throws -> String {
        let encoded=try JSONSerialization.data(withJSONObject:strings,options:[.fragmentsAllowed])
        guard let result=String(data:encoded,encoding:.utf8) else {
            throw N1pExcelParityError.invalidRow
        }
        return result
    }
    private static func dateSerial(_ str:String) throws -> Double {
        guard str.range(of: #"^\d{4}-\d{2}-\d{2}$"#,options:.regularExpression) != nil,
              let year=Int(str.prefix(4)),let month=Int(str.dropFirst(5).prefix(2)),
              let day=Int(str.suffix(2)) else { throw N1pExcelParityError.invalidRow }
        var cal=Calendar(identifier:.gregorian)
        cal.timeZone=TimeZone(secondsFromGMT:0)!
        guard let date=cal.date(from:DateComponents(year:year,month:month,day:day)),
              cal.component(.year,from:date)==year,
              cal.component(.month,from:date)==month,
              cal.component(.day,from:date)==day else {
            throw N1pExcelParityError.invalidRow
        }
        return date.timeIntervalSince1970/86400.0+25569.0
    }
    private static func time(_ string:String,optional:Bool=false) throws -> Any {
        if optional && string.isEmpty{return ""}
        guard string.range(of: #"^([01]\d|2[0-3]):[0-5]\d$"#,
                           options:.regularExpression) != nil,
              let hour=Int(string.prefix(2)),let minute=Int(string.suffix(2)) else {
            throw N1pExcelParityError.invalidRow
        }
        return Double(hour*60+minute)/1440.0
    }
    private static func same(_ a:Any,_ b:Any) -> Bool {
        if let left=n(a),let right=n(b) { return abs(left-right) < 0.000000001 }
        if let left=a as? String,let right=b as? String {return left==right}
        return false
    }
    private static func workerAge(_ raw:Any?) -> Any {
        let string=(raw as? String) ?? (raw as? NSNumber)?.stringValue ?? ""
        guard (1...3).contains(string.count),
              string.utf8.allSatisfy({(48...57).contains($0)}),
              let value=Int(string),value<=120 else {return ""}
        return value
    }
    private static func cells(_ visit:[String:Any],item:[String:Any]?,
                              quantity:Any,frequency:String) throws -> [Any] {
        guard let worker=visit["worker"] as? [String:Any],
              let dni=text(worker["dni"]),dni.count==8,
              let name=text(worker["name"]),
              let site=text(worker["site"]),
              ["LA VENTUROSA","PLVENTUROSA"].contains(site),
              let day=text(visit["date"]),
              let clock=text(visit["time"]),
              let diagnosis=text(visit["diagnosis"]),
              let blue=yes(visit["blueBandage"]),
              let returned=yes(visit["returned"]),
              let photo=yes(visit["photoSent"]) else {
            throw N1pExcelParityError.invalidRow
        }
        let proc:String
        if let item {
            guard let p=text(item["procedure"]) else {
                throw N1pExcelParityError.invalidRow
            }
            proc=p
        }else{
            proc=(visit["standaloneProcedures"] as? [String])?.joined(separator:" / ") ?? ""
        }
        let code:Any=item?["code"] ?? ""
        let material:Any=item?["name"] ?? ""
        return [
            site,text(worker["area"]) ?? "","","",text(worker["labor"]) ?? "",
            try dateSerial(day),try time(clock),dni,name,workerAge(worker["age"]),
            text(worker["sex"]) ?? "",text(worker["ubigeo"]) ?? "",
            text(visit["category"]) ?? "",text(visit["system"]) ?? "",
            text(visit["segment"]) ?? "",code,material,quantity,frequency,proc,
            item != nil ? (detail.contains(proc) ? "INSUMOS" : "-") : "",
            text(visit["permission"]) ?? "",text(visit["workStatus"]) ?? "",
            try time(text(visit["permissionTime"]) ?? "",optional:true),
            blue ? "SI" : "NO",returned ? "SI" : "NO",photo ? "SI" : "NO",
            text(visit["responsibleDni"]) ?? "",text(visit["responsible"]) ?? "",diagnosis
        ]
    }
    private static func parse(_ raw:Data) throws -> [String:Any] {
        guard let root=try? JSONSerialization.jsonObject(with:raw) as? [String:Any] else {
            throw N1pExcelParityError.invalidReference
        }
        return root
    }
    static func inspect(snapshot:Data, reference:Data) throws -> N1pExcelParityReport {
        let expected=try parse(reference)
        guard integer(expected["schema"])==1,
              let identifier=text(expected["id"]),["stock","frequency"].contains(identifier),
              let sha=text(expected["sourceSHA256"]),sha==hash(snapshot),
              let source=try? JSONSerialization.jsonObject(with:snapshot) as? [String:Any],
              let allVisits=source["attentions"] as? [[String:Any]],
              let metadata=expected["template"] as? [String:Any],
              let namesIn=metadata["sheets"] as? [String],namesIn==names,
              integer(metadata["materials"])==432,
              integer(metadata["tables"])==19,
              integer(metadata["columns"])==30,
              let zipHash=text(metadata["outputWorkbookSHA256"]),digest(zipHash),
              let plan=expected["plan"] as? [String:Any],
              yes(plan["provisional"])==true,
              let start=text(expected["start"]),let end=text(expected["end"]),
              start<=end,
              let reported=plan["lines"] as? [[String:Any]],
              let marked=plan["unverifiedLineIds"] as? [String] else {
            throw N1pExcelParityError.invalidReference
        }
        // Independent source-side FEFO, multilote, physical balance and R=1/0
        // verification. If this fails, no Excel row is trusted.
        let physical=try N1eLegacyClinicalAudit.inspect(snapshot)
        var physicalValues:[String:Double?]=[:],index=0
        for visit in allVisits where text(visit["status"])=="saved" {
            guard let id=text(visit["id"]),
                  let items=visit["items"] as? [[String:Any]] else {
                throw N1pExcelParityError.invalidSource
            }
            for item in items {
                guard let itemID=text(item["id"]),index<physical.consumptionR.count else {
                    throw N1pExcelParityError.invalidSource
                }
                physicalValues[id+"\u{001F}"+itemID]=physical.consumptionR[index]
                index+=1
            }
        }
        guard index==physical.consumptionR.count else {
            throw N1pExcelParityError.invalidSource
        }
        let saved=allVisits.filter{text($0["status"])=="saved"}
        var ids=Set<String>()
        for v in saved {
            guard let id=text(v["id"]),ids.insert(id).inserted,
                  let day=text(v["date"]) else {throw N1pExcelParityError.invalidSource}
            _=try dateSerial(day)
        }
        let ordered=saved.filter{
            guard let day=text($0["date"]) else {return false}
            return day>=start && day<=end
        }.sorted{
            let lhs=[text($0["date"]) ?? "",text($0["time"]) ?? "",text($0["id"]) ?? ""]
            let rhs=[text($1["date"]) ?? "",text($1["time"]) ?? "",text($1["id"]) ?? ""]
            return lhs.lexicographicallyPrecedes(rhs)
        }
        guard integer(plan["visits"])==ordered.count else {
            throw N1pExcelParityError.invalidRowOrder
        }
        var freq:[String:Int]=[:], projected:[[Any]]=[], rowIDs:[String]=[]
        var pending:[String]=[], linked=0,zeros=0
        for visit in ordered {
            guard let day=text(visit["date"]),let id=text(visit["id"]),
                  let worker=visit["worker"] as? [String:Any],
                  let dni=text(worker["dni"]),
                  let items=visit["items"] as? [[String:Any]] else {
                throw N1pExcelParityError.invalidSource
            }
            let frequencyKey=day+"\u{001F}"+dni
            let visitNo=(freq[frequencyKey] ?? 0)+1
            freq[frequencyKey]=visitNo
            let frequency=visitNo<=5 ? Self.frequency[visitNo-1] : "REVISAR"
            var itemIDs=Set<String>()
            for item in items {
                guard let itemID=text(item["id"]),itemIDs.insert(itemID).inserted,
                      let quantity=integer(item["quantity"]),quantity>0,
                      let code=text(item["code"]),!code.isEmpty,
                      text(item["name"]) != nil, text(item["unit"]) != nil else {
                    throw N1pExcelParityError.invalidRow
                }
                let physicalKey=id+"\u{001F}"+itemID
                let confirmed=physicalValues[physicalKey] ?? nil
                let excelR:Any
                if let confirmed {
                    excelR=confirmed
                    linked+=1
                    if confirmed == 0 {zeros+=1}
                }else{
                    excelR=quantity // provisional only; NEVER a physical movement
                    pending.append(try jsonKey([id,itemID]))
                }
                projected.append(try cells(visit,item:item,quantity:excelR,frequency:frequency))
                rowIDs.append(try jsonKey([id,itemID]))
            }
            if items.isEmpty {
                projected.append(try cells(visit,item:nil,quantity:"",frequency:frequency))
                rowIDs.append(try jsonKey([id,NSNull()]))
            }
        }
        guard reported.count==projected.count,
              integer(metadata["consumosRows"])==max(2,reported.count+1),
              integer(plan["linkedDeliveries"])==linked,
              integer(plan["pendingDeliveries"])==pending.count,
              marked==pending,
              (identifier != "stock" || zeros>0) else {
            throw N1pExcelParityError.wrongStatus
        }
        for i in projected.indices {
            guard let rowID=text(reported[i]["id"]) else {
                throw N1pExcelParityError.invalidRow
            }
            guard rowID==rowIDs[i] else {throw N1pExcelParityError.invalidRowOrder}
            guard let original=reported[i]["cells"] as? [Any],original.count==30,
                  projected[i].count==30 else {throw N1pExcelParityError.wrongColumn}
            for j in 0..<30 {
                guard same(original[j],projected[i][j]) else {
                    if j==17{throw N1pExcelParityError.wrongClinicalQuantity}
                    if j==18{throw N1pExcelParityError.wrongFrequency}
                    throw N1pExcelParityError.invalidExcelValue
                }
            }
        }
        return N1pExcelParityReport(sourceSHA256:sha,workbookSHA256:zipHash,
           visits:ordered.count,rows:reported.count,
           linkedDeliveries:linked,pendingDeliveries:pending.count,
           confirmedZeroRows:zeros,sheets:namesIn.count,columns:30,
           canActivate:false,canClaimOfficialReconciledExport:false)
    }
}
