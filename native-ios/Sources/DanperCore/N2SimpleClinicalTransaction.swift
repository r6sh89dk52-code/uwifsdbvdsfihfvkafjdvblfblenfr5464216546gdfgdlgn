import Foundation
import CoreFoundation

extension N2SimpleInventory {
    private static func clinicalMoment(_ visit:[String:Any],at:Int64)throws->Int64 {
        guard let date=visit["date"] as? String,validDay(date),let time=visit["time"] as? String,
              time.range(of:#"^([01]\d|2[0-3]):[0-5]\d$"#,options:.regularExpression) != nil else {
            throw N2ClinicalError.invalidVisit
        }
        let f=DateFormatter();f.locale=Locale(identifier:"en_US_POSIX");f.timeZone=TimeZone(identifier:"America/Lima")
        f.dateFormat="yyyy-MM-dd HH:mm";f.isLenient=false
        let text=date+" "+time
        guard let moment=f.date(from:text),f.string(from:moment)==text else{throw N2ClinicalError.invalidVisit}
        let value=Int64(moment.timeIntervalSince1970*1000)
        guard value<=at else{throw N2ClinicalError.invalidTime}
        // A record entered in the current minute represents the explicit
        // dispensing being confirmed now, not an inferred historical debit.
        return text==f.string(from:Date(timeIntervalSince1970:Double(at)/1000)) ? at:value
    }
    public static func saveVisit(snapshot:Data,visit:Data,at:Int64)throws->N2ClinicalResult {
        _=try audit(snapshot)
        guard validTime(at) else{throw N2ClinicalError.invalidTime}
        var root=try object(snapshot),s=try state(root)
        let request=try object(visit)
        guard var visits=root["attentions"] as? [[String:Any]],let workers=root["workers"] as? [[String:Any]],
              let id=request["id"] as? String,text(id),id.count<=120,request["status"] as? String=="saved",
              let worker=request["worker"] as? [String:Any],let dni=worker["dni"] as? String,
              let name=worker["name"] as? String,
              workers.contains(where:{$0["dni"] as? String==dni && $0["name"] as? String==name}),
              let items=request["items"] as? [[String:Any]],items.count<=100,
              let operatorName=request["responsible"] as? String,text(operatorName),
              ["diagnosis","category","system"].allSatisfy({(request[$0] as? String).map(text) ?? false}),
              let clinician=request["responsibleDni"] as? String,clinician.count==8,
              clinician.allSatisfy({$0.isASCII && $0.isNumber}),at>=s.regime.activatedAt else {
            throw N2ClinicalError.invalidVisit
        }
        let clinicalAt=try clinicalMoment(request,at:at)
        if let previous=visits.first(where:{$0["id"] as? String==id}),previous["status"] as? String=="saved" {
            guard request.allSatisfy({k,v in
                guard let old=previous[k],let a=try? JSONSerialization.data(withJSONObject:old,options:[.sortedKeys,.fragmentsAllowed]),
                      let b=try? JSONSerialization.data(withJSONObject:v,options:[.sortedKeys,.fragmentsAllowed]) else{return false}
                return a==b
            }) else{throw N2ClinicalError.duplicateVisit}
            return N2ClinicalResult(snapshot:snapshot,linked:0,pending:0,alreadyLinked:items.count,
                pendingReasons:[],physicalMovementsAdded:0)
        }
        var saved=request
        if let draft=visits.first(where:{$0["id"] as? String==id}) {
            guard draft["status"] as? String=="draft",draft["originId"]==nil else{throw N2ClinicalError.duplicateVisit}
            saved=draft.merging(request,uniquingKeysWith:{_,new in new})
        }
        var linked=0,pending=0,reasons=[String](),outcomes=[String:String](),lineIDs=Set<String>()
        for item in items {
            guard let iid=item["id"] as? String,text(iid),iid.count<=120,lineIDs.insert(iid).inserted,
                  let code=item["code"] as? String,let unit=item["unit"] as? String,
                  let itemName=item["name"] as? String,text(itemName),
                  let quantity=item["quantity"] as? NSNumber,CFGetTypeID(quantity) != CFBooleanGetTypeID(),
                  quantity.doubleValue>0,quantity.doubleValue.rounded()==quantity.doubleValue,
                  validQuantity(quantity.doubleValue) else {throw N2ClinicalError.invalidVisit}
            let eventID="V2:"+id+":"+iid
            let index=s.products.firstIndex(where:{$0.code==code && $0.unit==unit && $0.name==itemName})
            let p=index.map{s.products[$0]}
            let declaration=(item["simpleR"] as? NSNumber).flatMap {n->Int? in
                guard CFGetTypeID(n) != CFBooleanGetTypeID(),n.doubleValue==0 || n.doubleValue==1 else{return nil}
                return n.intValue
            }
            let debit:Double?=p.map{$0.mode == .units ? quantity.doubleValue:declaration.map(Double.init)} ?? nil
            var problem:String?
            if p==nil {problem="Producto sin conteo físico en el inventario nuevo"}
            else if p?.mode == .presentation && declaration==nil {problem="Falta declaración manual R=1 o R=0"}
            else if clinicalAt < p!.lastCountAt {problem="Atención anterior al último conteo físico; no se vuelve a descontar"}
            else if at < (s.movements.last(where:{$0.code==code})?.at ?? 0) {problem="Revisar cronología del inventario nuevo"}
            else if let debit,p!.quantity<debit {problem="Existencias insuficientes; atención clínica conservada"}
            if let problem {
                pending+=1;reasons.append(problem);outcomes[iid]=problem
                s.incidents.append(N2SimpleIncident(id:eventID+":incident",visitID:id,itemID:iid,code:code,unit:unit,
                    clinicalQuantity:quantity.doubleValue,requestedDebit:debit,declaredR:p?.mode == .presentation ? declaration:nil,
                    at:at,reason:problem,resolutionEventID:nil,operatorName:operatorName,clinicalAt:clinicalAt))
            }else if let index,let debit {
                let original=s.products[index]
                let m=movement(id:eventID,p:original,kind:"outflow",at:at,after:original.quantity-debit,
                    op:operatorName,reason:original.mode == .presentation ? "Declaración manual R=\(declaration!)":"Cantidad clínica dispensada",
                    visit:id,item:iid,r:original.mode == .presentation ? declaration:nil,clinicalQuantity:quantity.doubleValue)
                s.movements.append(m);s.products[index].quantity=m.after
                outcomes[iid]="Descontado";linked+=1
            }
        }
        saved["nativeDispensing"]=outcomes;saved["simpleInventoryRegimeID"]=s.regime.id
        if let index=visits.firstIndex(where:{$0["id"] as? String==id}) {visits[index]=saved}
        else {visits.append(saved)}
        root["attentions"]=visits
        let next=try putting(s,in:root)
        return N2ClinicalResult(snapshot:next,linked:linked,pending:pending,alreadyLinked:0,
            pendingReasons:reasons,physicalMovementsAdded:linked)
    }
}

/// Until the user authorizes the new regime, clinical recording remains usable
/// but this app never executes another operation in the retired FEFO inventory.
public enum N2PreSimpleClinicalTransaction {
    public static func save(snapshot:Data,visit:Data,at:Int64)throws->N2ClinicalResult {
        guard !N2SimpleInventory.isActive(snapshot) else{throw N2SimpleInventoryError.legacyOperation}
        _=try N2VersionedSnapshotAudit.inspect(snapshot,allowEmptySynthetic:true)
        _=try N1fLosslessFieldGate.inspect(snapshot)
        var root=try N2SimpleInventory.object(snapshot)
        let request=try N2SimpleInventory.object(visit)
        guard N2SimpleInventory.validTime(at),var visits=root["attentions"] as? [[String:Any]],
              let workers=root["workers"] as? [[String:Any]],let id=request["id"] as? String,
              N2SimpleInventory.text(id),request["status"] as? String=="saved",
              let worker=request["worker"] as? [String:Any],let dni=worker["dni"] as? String,
              workers.contains(where:{$0["dni"] as? String==dni && $0["name"] as? String==worker["name"] as? String}),
              let date=request["date"] as? String,N2SimpleInventory.validDay(date),
              let time=request["time"] as? String,time.range(of:#"^([01]\d|2[0-3]):[0-5]\d$"#,options:.regularExpression) != nil,
              ["diagnosis","category","system","responsible"].allSatisfy({(request[$0] as? String).map(N2SimpleInventory.text) ?? false}),
              let items=request["items"] as? [[String:Any]] else{throw N2ClinicalError.invalidVisit}
        if let previous=visits.first(where:{$0["id"] as? String==id}),previous["status"] as? String=="saved" {
            guard request.allSatisfy({key,value in
                guard let old=previous[key],let a=try? JSONSerialization.data(withJSONObject:old,options:[.sortedKeys,.fragmentsAllowed]),
                      let b=try? JSONSerialization.data(withJSONObject:value,options:[.sortedKeys,.fragmentsAllowed]) else{return false}
                return a==b
            }) else{throw N2ClinicalError.duplicateVisit}
            return N2ClinicalResult(snapshot:snapshot,linked:0,pending:0,alreadyLinked:items.count,pendingReasons:[],physicalMovementsAdded:0)
        }
        var saved=request
        if let draft=visits.first(where:{$0["id"] as? String==id}) {
            guard draft["status"] as? String=="draft",draft["originId"]==nil else{throw N2ClinicalError.duplicateVisit}
            saved=draft.merging(request,uniquingKeysWith:{_,new in new})
        }
        var outcomes=[String:String]()
        for item in items {
            guard let iid=item["id"] as? String else{throw N2ClinicalError.invalidVisit}
            outcomes[iid]="Inventario nuevo pendiente de activar; sin movimiento físico"
        }
        saved["nativeDispensing"]=outcomes;saved["recordedBeforeSimpleInventory"]=true
        if let i=visits.firstIndex(where:{$0["id"] as? String==id}) {visits[i]=saved}else{visits.append(saved)}
        root["attentions"]=visits
        let next=try N2SimpleInventory.bytes(root)
        _=try N2VersionedSnapshotAudit.inspect(next,allowEmptySynthetic:true)
        _=try N1fLosslessFieldGate.inspect(next)
        return N2ClinicalResult(snapshot:next,linked:0,pending:items.count,alreadyLinked:0,
            pendingReasons:items.map{_ in "Inventario nuevo pendiente de activar; sin movimiento físico"},physicalMovementsAdded:0)
    }
}
