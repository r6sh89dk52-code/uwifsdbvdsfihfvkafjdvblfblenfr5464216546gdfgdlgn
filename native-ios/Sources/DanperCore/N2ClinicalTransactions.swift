import Foundation
import CoreFoundation

/// N2: pure, memory-only operation against the exact build222 JSON shape.
/// Never touches the legacy Keychain, source archive, current IPA or live vault.
public enum N2ClinicalError: Error, Equatable {
    case invalidSnapshot, invalidVisit, wrongWorker, duplicateVisit
    case invalidApprovedCatalog, inconsistentHistory, invalidTime
}
public struct N2ClinicalResult {
    public let snapshot: Data
    public let linked: Int
    public let pending: Int
    public let alreadyLinked: Int
    public let pendingReasons: [String]
    public let physicalMovementsAdded: Int
}
public enum N2NativeClinicalTransaction {
    private struct Material {
        let clinicalCode:String
        let clinicalName:String
        let clinicalUnit:String
        let kardexCode:String
        let kardexName:String
    }
    private static let approvedPairs = Set(("1:16000007;2:16000029;3:16000037;4:16000039;5:16016685;6:16000055;7:16011903;8:16000057;9:16000061;10:16015455;11:16000065;12:16000086;13:16000089;14:16000105;15:16000132;16:16000137;17:16000152;18:16000158;19:16000174;21:16011905;22:16000182;23:16000191;24:16000196;26:16000035;27:16000040;28:16000064;29:16000080;30:16000081;31:16000082;32:16000084;33:16000088;34:16000006;35:16024392;36:16000131;37:16000150;38:16000156;39:16011904;40:16019736;41:16000148;42:16000149;43:16000146;44:16000147;45:16011898;46:16000133;47:16000171;48:16000195;49:16000213;50:16011872;51:16000172;52:16017902;53:16000207;54:16000000;55:16000001;56:16000002;57:16000013;58:16000014;59:16010672;60:16000077;61:16000094;62:16024400;63:16024400;64:16000130;65:16000128;66:16000135;67:16000136;69:16000210;70:16000209;71:16000227;72:16000231;73:16000235;74:16000236;75:16000237;76:16000238;77:16000054;78:16000165;79:16000164;80:10000575;83:16013532;87:16000025;88:16000009;89:16000010;90:16000066;91:16024399;92:16000143;93:16000142;96:16019966").split(separator:";").map(String.init))
    private static func number(_ x:Any?) -> Double? {
        guard let n=x as? NSNumber,CFGetTypeID(n) != CFBooleanGetTypeID(),
              n.doubleValue.isFinite else {return nil}
        return n.doubleValue
    }
    private static func str(_ x:Any?) -> String? {
        guard let s=x as? String,!s.isEmpty else{return nil}
        return s
    }
    private static func triple(_ x:Double) -> Double {(x*1000).rounded()/1000}
    private static func total(_ l:[String:Any]) -> Double? {
        guard let sealed=number(l["sealedContainers"]),
              let capacity=number(l["unitsPerContainer"]),
              let loose=number(l["looseUnits"]),let open=number(l["openedRemaining"])
        else {return nil}
        return triple(sealed*capacity+loose+open)
    }
    private static func limaDay(_ millis:Int64) -> String {
        let date=Date(timeIntervalSince1970:Double(millis)/1000)
        var calendar=Calendar(identifier:.gregorian)
        calendar.timeZone=TimeZone(identifier:"America/Lima")!
        let parts=calendar.dateComponents([.year,.month,.day],from:date)
        return String(format:"%04d-%02d-%02d",parts.year!,parts.month!,parts.day!)
    }
    private static func mappings(_ data:Data) throws -> [Material] {
        guard let raw=try? JSONSerialization.jsonObject(with:data) as? [[String:Any]],
              raw.count==86 else {throw N2ClinicalError.invalidApprovedCatalog}
        var keys=Set<String>(),seen=Set<String>(),result:[Material]=[]
        for row in raw {
            guard let clinicalCode=str(row["clinicalCode"]),
                  let clinicalName=str(row["clinicalName"]),
                  let clinicalUnit=str(row["clinicalUnit"]),
                  let code=str(row["kardexCode"]),let name=str(row["kardexName"]),
                  code.hasPrefix("E-"),let index=Int(code.dropFirst(2)),
                  let key = Optional(String(index)+":"+clinicalCode),
                  approvedPairs.contains(key),keys.insert(key).inserted,
                  seen.insert(code).inserted else {
                throw N2ClinicalError.invalidApprovedCatalog
            }
            result.append(Material(clinicalCode:clinicalCode,clinicalName:clinicalName,
                                   clinicalUnit:clinicalUnit,kardexCode:code,kardexName:name))
        }
        guard keys==approvedPairs else {throw N2ClinicalError.invalidApprovedCatalog}
        return result
    }

    /// Use an explicitly verified roster record and a complete saved visit.
    /// A pending physical line is kept in the clinical record; there is never
    /// a fabricated R=0 or an unconfirmed opening.
    public static func appendSavedVisit(snapshot:Data, visit:Data,
                                        approvedCatalog:Data, at:Int64) throws -> N2ClinicalResult {
        try execute(snapshot:snapshot,visit:visit,approvedCatalog:approvedCatalog,
                    at:at,append:true)
    }

    /// Resolve historical saved lines only with explicit non-retroactive evidence.
    /// Never silently reconstruct historical physical movements.
    public static func retryCurrentSavedVisit(snapshot:Data, visitID:String,
                                              approvedCatalog:Data, at:Int64) throws -> N2ClinicalResult {
        guard let root=try? JSONSerialization.jsonObject(with:snapshot) as? [String:Any],
              let visits=root["attentions"] as? [[String:Any]],
              let visit=visits.first(where:{$0["id"] as? String == visitID}),
              let source=try? JSONSerialization.data(withJSONObject:visit)
        else{throw N2ClinicalError.invalidVisit}
        return try execute(snapshot:snapshot,visit:source,approvedCatalog:approvedCatalog,
                           at:at,append:false)
    }

    private static func execute(snapshot:Data,visit:Data,approvedCatalog:Data,
                                at:Int64,append:Bool) throws -> N2ClinicalResult {
        guard at>0,at<9_007_199_254_740_991 else{throw N2ClinicalError.invalidTime}
        // Validate original AND derived ledger before making it eligible for a write.
        _=try N1eLegacyClinicalAudit.inspect(snapshot)
        _=try N1fLosslessFieldGate.inspect(snapshot)
        let approved=try mappings(approvedCatalog)
        guard var root=try? JSONSerialization.jsonObject(with:snapshot) as? [String:Any],
              var visits=root["attentions"] as? [[String:Any]],
              var lots=root["stockLots"] as? [[String:Any]],
              var movements=root["stockMovements"] as? [[String:Any]],
              let workers=root["workers"] as? [[String:Any]],
              let new=try? JSONSerialization.jsonObject(with:visit) as? [String:Any],
              let id=str(new["id"]),new["status"] as? String == "saved",
              let date=str(new["date"]),let worker=new["worker"] as? [String:Any],
              let dni=str(worker["dni"]),let name=str(worker["name"]),
              let items=new["items"] as? [[String:Any]],
              !items.isEmpty,items.count<=100,visits.count<100_000
        else {throw N2ClinicalError.invalidVisit}
        guard workers.contains(where:{$0["dni"] as? String == dni &&
            $0["name"] as? String == name}) else {throw N2ClinicalError.wrongWorker}
        if append {
            guard !visits.contains(where:{$0["id"] as? String == id}) else {
                throw N2ClinicalError.duplicateVisit
            }
            visits.append(new)
        }else {
            guard let old=visits.first(where:{$0["id"] as? String == id}),
                  let previous=try? JSONSerialization.data(withJSONObject:old,options:[.sortedKeys]),
                  let candidate=try? JSONSerialization.data(withJSONObject:new,options:[.sortedKeys]),
                  previous==candidate else {throw N2ClinicalError.invalidVisit}
        }
        // No edits to an existing saved attention or its clinical quantities.
        var ids=Set<String>()
        for item in items {
            guard let key=str(item["id"]),ids.insert(key).inserted,
                  let code=str(item["code"]),let text=str(item["name"]),
                  let unit=str(item["unit"]),!code.isEmpty,!text.isEmpty,!unit.isEmpty,
                  let count=number(item["quantity"]),count>0,count.rounded()==count else{
                throw N2ClinicalError.invalidVisit
            }
        }
        let today=limaDay(at)
        var linked=0,pending=0,already=0,reasons:[String]=[],added=0
        func mark(_ reason:String) {pending+=1;reasons.append(reason)}
        for item in items {
            let itemID=item["id"] as! String,code=item["code"] as! String
            let existing=movements.filter{
                guard let ref=$0["dispenseRef"] as? [String:Any] else{return false}
                return ref["attentionId"] as? String == id && ref["itemId"] as? String == itemID
            }
            if !existing.isEmpty {
                // Existing delivery is immutable and must still match the item.
                already+=1;continue
            }
            if date != today {
                mark("Fecha clínica histórica: no se reconstruye consumo físico.")
                continue
            }
            let candidates=approved.filter{$0.clinicalCode==code &&
                $0.clinicalName==item["name"] as? String &&
                $0.clinicalUnit==item["unit"] as? String}
            if candidates.isEmpty {mark("Sin correspondencia aprobada.");continue}
            let individual=["UND","TBL","PAR"].contains((item["unit"] as! String).uppercased())
            let explicit=item["physicalUse"] as? [String:Any]
            if candidates.count>1 && explicit==nil {
                mark("Presentación Kardex ambigua: exige lote seleccionado.");continue
            }
            if !individual && explicit==nil {
                mark("Envase: falta cantidad interna verificada.");continue
            }
            let selected=explicit.flatMap{str($0["lotId"])}
            let useQuantity=explicit.flatMap{number($0["quantity"])} ??
                (individual ? number(item["quantity"]) : nil)
            guard let quantity=useQuantity,quantity>0,quantity<=10_000_000,
                  (!individual || quantity==number(item["quantity"])) else {
                mark("Cantidad física no verificada.");continue
            }
            let allowable=Set(candidates.map{$0.kardexCode})
            let eligible=lots.filter {l in
                guard let lc=str(l["code"]),let ln=str(l["name"]),
                      allowable.contains(lc),
                      candidates.contains(where:{$0.kardexCode==lc && $0.kardexName==ln}),
                      let t=total(l),t>0,
                      let expiry=l["expires"] as? String,
                      expiry.isEmpty || expiry>=today else{return false}
                if individual {
                    let stock=(l["catalogUnit"] as? String ?? "").uppercased()
                    return (item["unit"] as? String)?.uppercased()=="PAR" ?
                        stock=="PAR" : ["UND","TBL"].contains(stock)
                }
                return true
            }
            let chosen=eligible.first(where:{$0["id"] as? String == selected})
            if explicit != nil && (selected==nil || chosen==nil) {
                mark("Existencia seleccionada no verificable.");continue
            }
            guard let kardex=chosen?["code"] as? String ?? (candidates.count==1 ?
                         candidates[0].kardexCode : nil) else {
                mark("Presentación no seleccionada.");continue
            }
            if !individual && eligible.contains(where:{$0["code"] as? String == kardex &&
                (($0["container"] as? String)=="unidad" ||
                 (number($0["unitsPerContainer"]) ?? 0)<=1)}) {
                mark("Capacidad del envase no verificada.");continue
            }
            let stock=eligible.filter{$0["code"] as? String == kardex}
                .sorted { a,b in
                    let da=(a["expires"] as? String).flatMap{$0.isEmpty ? nil:$0} ?? "9999-12-31"
                    let db=(b["expires"] as? String).flatMap{$0.isEmpty ? nil:$0} ?? "9999-12-31"
                    return da==db ? (a["id"] as! String)<(b["id"] as! String) : da<db
                }
            if stock.reduce(0.0,{$0+(total($1) ?? 0)})+0.00001<quantity {
                mark("Saldo FEFO insuficiente.");continue
            }
            var probe=lots,parts:[([String:Any],[String:Any],Double,Bool,Double)]=[]
            var rest=triple(quantity),canPlan=true
            while rest>0.00001 {
                if parts.count>=490 {canPlan=false;break}
                // Re-sort by FEFO among the chosen compatible presentation.
                let available=stock.compactMap{entry -> [String:Any]? in
                    probe.first(where:{$0["id"] as? String == entry["id"] as? String})
                }.filter{(total($0) ?? 0)>0}
                guard let before=available.first else{canPlan=false;break}
                let pack=(before["container"] as? String)!="unidad" ||
                         number(before["unitsPerContainer"]) != 1 ||
                         (before["catalogUnit"] as? String)!="UND"
                let opened=number(before["openedRemaining"]) ?? 0
                let loose=number(before["looseUnits"]) ?? 0
                let sealed=number(before["sealedContainers"]) ?? 0
                let cap=number(before["unitsPerContainer"]) ?? 1
                let room=pack ? (opened>0 ? opened : loose>0 ? loose : sealed>0 ? cap:0) :
                    (total(before) ?? 0)
                let take=triple(min(rest,individual ? floor(room+0.000001):room))
                if take<=0 {canPlan=false;break}
                var after=before
                var open=false
                var r=individual ? take : 0.0
                if !pack {
                    var left=take
                    let looseTake=min(loose,left)
                    after["looseUnits"]=triple(loose-looseTake);left=triple(left-looseTake)
                    let sealedTake=min(sealed,left)
                    after["sealedContainers"]=Int(sealed-sealedTake);left=triple(left-sealedTake)
                    if left>0 {after["openedRemaining"]=triple(opened-left)}
                }else if opened>0 {
                    after["openedRemaining"]=triple(opened-take)
                }else if loose>0 {
                    after["looseUnits"]=triple(loose-take)
                }else if sealed>0 {
                    after["sealedContainers"]=Int(sealed-1)
                    after["openedRemaining"]=triple(cap-take)
                    open=true
                    if !individual {r=1}
                }else {canPlan=false;break}
                after["updatedAt"]=at
                guard (total(after) ?? -1)>=0,
                      triple((total(after) ?? 0)-(total(before) ?? 0)) == -take else {
                    canPlan=false;break
                }
                if let idx=probe.firstIndex(where:{$0["id"] as? String == before["id"] as? String}) {
                    probe[idx]=after
                }
                parts.append((before,after,take,open,r))
                rest=triple(rest-take)
            }
            if !canPlan || rest>0.00001 {
                mark("Plan FEFO incompleto. No se descontó stock.");continue
            }
            if parts.contains(where:{$0.3}) &&
               explicit?["confirmNewContainer"] as? Bool != true {
                mark("Falta autorizar apertura del nuevo envase.");continue
            }
            let refCommon:[String:Any]=[
                "attentionId":id,"itemId":itemID,"clinicalCode":code,
                "clinicalName":item["name"]!,"clinicalUnit":item["unit"]!,
                "clinicalQuantity":item["quantity"]!,"confirmedAt":at
            ]
            let beforeCount=movements.count
            for (i,part) in parts.enumerated() {
                let before=part.0,after=part.1,qty=part.2
                var ref=refCommon
                if parts.count>1 {
                    ref["partIndex"]=i+1
                    ref["partCount"]=parts.count
                    ref["physicalTotal"]=quantity
                }
                let suffix=parts.count==1 ? "" : ":PART:\(i+1)"
                let movement:[String:Any]=[
                    "id":"ATT:\(id):ITEM:\(itemID)\(suffix)",
                    "lotId":before["id"]!,
                    "code":before["code"]!,"name":before["name"]!,
                    "unit":before["catalogUnit"]!,"at":at,
                    "kind":"use","description":"Consumo FEFO vinculado a atención",
                    "quantity":qty,"sealedAdded":0,"looseAdded":0,
                    "openedNewContainer":part.3,"excelQuantity":part.4,
                    "physicalChange":-qty,"before":before,"after":after,
                    "dispenseRef":ref
                ]
                movements.append(movement)
            }
            lots=probe
            added+=movements.count-beforeCount
            linked+=1
        }
        root["attentions"]=visits
        root["stockLots"]=lots
        root["stockMovements"]=movements
        guard JSONSerialization.isValidJSONObject(root),
              let candidate=try? JSONSerialization.data(withJSONObject:root),
              (try? N1eLegacyClinicalAudit.inspect(candidate)) != nil,
              (try? N1fLosslessFieldGate.inspect(candidate)) != nil else {
            throw N2ClinicalError.inconsistentHistory
        }
        return N2ClinicalResult(snapshot:candidate,linked:linked,pending:pending,
                                alreadyLinked:already,pendingReasons:reasons,
                                physicalMovementsAdded:added)
    }
}
