import Foundation
import CoreFoundation

public enum N2ContainerAccounting {
    public enum Failure:Error {case invalidDeclaration}
    struct Part {
        let before:[String:Any]
        let after:[String:Any]
        let openings:Int
        let volume:Double
    }
    static func allocate(lots:[[String:Any]],selected:String?,openings:Int,volume:Double,at:Int64)->[Part]? {
        if openings==0 {
            let before=selected.flatMap {identifier in lots.first{$0["id"] as? String==identifier}} ??
                lots.first{openCount($0)>0}
            guard let before,let after=plan(lot:before,openings:0,volume:volume,at:at) else{return nil}
            return [Part(before:before,after:after,openings:0,volume:volume)]
        }
        let compatible=selected.map {identifier in lots.filter{$0["id"] as? String==identifier}} ?? lots
        var remainingOpenings=openings,remainingVolume=volume,parts=[Part]()
        for before in compatible where remainingOpenings>0 {
            let count=min(remainingOpenings,before["sealedContainers"] as? Int ?? 0)
            guard count>0 else{continue}
            let capacity=(before["unitsPerContainer"] as? NSNumber)?.doubleValue ?? 0
            let opened=(before["openedRemaining"] as? NSNumber)?.doubleValue ?? 0
            let loose=(before["looseUnits"] as? NSNumber)?.doubleValue ?? 0
            let available=Double(count)*capacity+opened+loose
            let used=before["volumeTrackingEnabled"] as? Bool == false ? 0:min(remainingVolume,available)
            guard let after=plan(lot:before,openings:count,volume:used,at:at) else{return nil}
            parts.append(Part(before:before,after:after,openings:count,volume:used))
            remainingOpenings-=count;remainingVolume-=used
        }
        guard remainingOpenings==0,abs(remainingVolume)<0.000001,parts.count<=490 else{return nil}
        return parts
    }
    private static func integer(_ value:Any?)->Int? {
        guard let number=value as? NSNumber,CFGetTypeID(number) != CFBooleanGetTypeID(),
              number.doubleValue.isFinite,number.doubleValue>=0,number.doubleValue<=10_000_000,
              number.doubleValue.rounded()==number.doubleValue else{return nil}
        return number.intValue
    }
    public static func isContainer(unit:String)->Bool {
        !["UND","TBL","PAR","ML","LT"].contains(unit.uppercased()) && !unit.isEmpty
    }
    public static func openCount(_ lot:[String:Any])->Int {
        if let count=lot["declaredOpenContainers"] as? Int {return count}
        return ((lot["openedRemaining"] as? NSNumber)?.doubleValue ?? 0)>0 ? 1:0
    }
    static func plan(lot:[String:Any],openings:Int,volume:Double,at:Int64)->[String:Any]? {
        guard isContainer(unit:lot["catalogUnit"] as? String ?? ""),
              openings>=0,openings<=10_000,volume.isFinite,volume>=0,
              let sealed=lot["sealedContainers"] as? Int,sealed>=openings,
              let capacity=(lot["unitsPerContainer"] as? NSNumber)?.doubleValue,
              let opened=(lot["openedRemaining"] as? NSNumber)?.doubleValue,
              let loose=(lot["looseUnits"] as? NSNumber)?.doubleValue,
              openCount(lot)+openings>0 else{return nil}
        if lot["volumeTrackingEnabled"] as? Bool == false && volume>0 {return nil}
        let available=opened+loose+Double(openings)*capacity
        guard volume<=available else{return nil}
        var after=lot
        let remainder=available-volume
        after["sealedContainers"]=sealed-openings
        after["openedRemaining"]=min(capacity,remainder)
        after["looseUnits"]=max(0,remainder-capacity)
        after["declaredOpenContainers"]=openCount(lot)+openings
        after["updatedAt"]=at
        return after
    }
    static func validMovement(_ movement:[String:Any])->Bool {
        if movement["kind"] as? String == "containerState" {
            guard let before=movement["before"] as? [String:Any],
                  var after=movement["after"] as? [String:Any],
                  let count=integer(movement["closedContainers"]),count>0,count<=openCount(before),
                  ["agotado","cerrado","descartado"].contains(movement["containerDisposition"] as? String ?? ""),
                  let reason=movement["description"] as? String,reason.count>=10,
                  let operatorName=movement["operatorName"] as? String,operatorName.count>=3,
                  (movement["quantity"] as? NSNumber)?.doubleValue==0,
                  (movement["excelQuantity"] as? NSNumber)?.doubleValue==0,
                  movement["openedNewContainer"] as? Bool == false,
                  after["volumeTrackingEnabled"] as? Bool == false,
                  after["declaredOpenContainers"] as? Int==openCount(before)-count,
                  integer(movement["containerAccountingVersion"])==1,
                  (after["updatedAt"] as? NSNumber)==(movement["at"] as? NSNumber),
                  N2ContainerAccounting.isContainer(unit:before["catalogUnit"] as? String ?? "") else{return false}
            let exhausted=movement["declaredExhaustedByNewOpening"] as? Bool == true
            if exhausted {
                guard count==1,
                      movement["containerDisposition"] as? String=="agotado",
                      before["volumeTrackingEnabled"] as? Bool != true,
                      (after["openedRemaining"] as? NSNumber)?.doubleValue==0,
                      (after["looseUnits"] as? NSNumber)?.doubleValue==0 else{
                    return false
                }
                after["openedRemaining"]=before["openedRemaining"]
                after["looseUnits"]=before["looseUnits"]
            }
            after["declaredOpenContainers"]=before["declaredOpenContainers"]
            after["updatedAt"]=before["updatedAt"]
            after["volumeTrackingEnabled"]=before["volumeTrackingEnabled"]
            return NSDictionary(dictionary:after).isEqual(to:before)
        }
        guard movement["kind"] as? String=="use",integer(movement["containerAccountingVersion"]) == 1,
              let before=movement["before"] as? [String:Any],
              let after=movement["after"] as? [String:Any],
              let unit=before["catalogUnit"] as? String,isContainer(unit:unit),
              let openings=integer(movement["declaredOpenings"]),
              let quantity=(movement["quantity"] as? NSNumber)?.doubleValue,
              let at=movement["at"] as? Int64,
              let expected=plan(lot:before,openings:openings,volume:quantity,at:at),
              let expectedData=try? JSONSerialization.data(withJSONObject:expected,options:.sortedKeys),
              let afterData=try? JSONSerialization.data(withJSONObject:after,options:.sortedKeys),
              expectedData==afterData,
              (movement["excelQuantity"] as? NSNumber)?.doubleValue==Double(openings),
              movement["openedNewContainer"] as? Bool == (openings>0)
        else{return false}
        return true
    }
    /// A save-time confirmation may explicitly attest that ONE previously
    /// open container was exhausted before opening the next. The closure
    /// is an auditable containerState event (Kardex R=0), not another use.
    /// Never infer a closure while tracking a measured internal remainder.
    static func exhaustedByNextOpening(lot:[String:Any],attentionID:String,
                                       itemID:String,operatorName:String,
                                       at:Int64)->(after:[String:Any],event:[String:Any])? {
        guard let lotID=lot["id"] as? String,!lotID.isEmpty,
              let code=lot["code"] as? String,
              let name=lot["name"] as? String,
              let unit=lot["catalogUnit"] as? String,isContainer(unit:unit),
              openCount(lot)==1,
              lot["volumeTrackingEnabled"] as? Bool != true,
              at>=(lot["updatedAt"] as? Int64 ?? Int64.max),
              operatorName.count>=3 else{return nil}
        var after=lot
        after["declaredOpenContainers"]=0
        // A verified exhaustion declaration is stronger than a placeholder
        // openedRemaining used when internal volumes are not tracked.
        after["openedRemaining"]=0
        after["looseUnits"]=0
        after["updatedAt"]=at
        after["volumeTrackingEnabled"]=false
        let event:[String:Any]=[
            "id":"ATT:\(attentionID):ITEM:\(itemID):PREVIOUS-EXHAUSTED:\(lotID)",
            "lotId":lotID,"code":code,"name":name,"unit":unit,
            "kind":"containerState","at":at,
            "containerAccountingVersion":1,"closedContainers":1,
            "containerDisposition":"agotado",
            "declaredExhaustedByNewOpening":true,
            "operatorName":operatorName,
            "description":"Agotamiento del envase anterior confirmado al abrir uno nuevo",
            "quantity":0,"excelQuantity":0,"physicalChange":0,
            "openedNewContainer":false,"sealedAdded":0,"looseAdded":0,
            "before":lot,"after":after]
        guard validMovement(event) else{return nil}
        return (after,event)
    }

    public static func close(snapshot:Data,lotID:String,count:Int,disposition:String,
                             operatorName:String,reason:String,at:Int64)throws->Data {
        _=try N1eLegacyClinicalAudit.inspect(snapshot)
        guard var root=try JSONSerialization.jsonObject(with:snapshot) as? [String:Any],
              var lots=root["stockLots"] as? [[String:Any]],
              var movements=root["stockMovements"] as? [[String:Any]],
              let index=lots.firstIndex(where:{$0["id"] as? String==lotID}),
              at>=(lots[index]["updatedAt"] as? Int64 ?? Int64.max) else{throw Failure.invalidDeclaration}
        let before=lots[index]
        guard count>0,count<=openCount(before) else{throw Failure.invalidDeclaration}
        var after=before
        after["declaredOpenContainers"]=openCount(before)-count
        after["updatedAt"]=at
        after["volumeTrackingEnabled"]=false
        let movement:[String:Any]=[
            "id":UUID().uuidString,"lotId":lotID,"code":before["code"]!,"name":before["name"]!,
            "unit":before["catalogUnit"]!,"kind":"containerState","at":at,
            "containerAccountingVersion":1,"closedContainers":count,"containerDisposition":disposition,
            "operatorName":operatorName,"description":reason,"quantity":0,"excelQuantity":0,
            "physicalChange":0,"openedNewContainer":false,"sealedAdded":0,"looseAdded":0,
            "before":before,"after":after]
        guard validMovement(movement) else{throw Failure.invalidDeclaration}
        lots[index]=after;movements.append(movement)
        root["stockLots"]=lots;root["stockMovements"]=movements
        let result=try JSONSerialization.data(withJSONObject:root,options:.sortedKeys)
        _=try N1eLegacyClinicalAudit.inspect(result)
        _=try N1fLosslessFieldGate.inspect(result)
        return result
    }
}
