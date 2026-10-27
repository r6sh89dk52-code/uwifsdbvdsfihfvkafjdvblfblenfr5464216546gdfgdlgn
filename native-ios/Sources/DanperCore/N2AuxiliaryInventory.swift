import Foundation

public enum N2AuxiliaryInventory {
    public static func accounting(snapshot:Data)throws->String {
        guard let root=try JSONSerialization.jsonObject(with:snapshot) as? [String:Any],
              let lots=root["stockLots"] as? [[String:Any]],
              let movements=root["stockMovements"] as? [[String:Any]] else{throw Failure.invalidProduct}
        let auxiliary=lots.filter{($0["code"] as? String)?.hasPrefix("AUX:")==true}
        let ids=Set(auxiliary.compactMap{$0["id"] as? String})
        let history=movements.filter{ids.contains($0["lotId"] as? String ?? "")}.map { movement in
            movement.filter{["id","lotId","code","at","kind","quantity","physicalChange","excelQuantity","openedNewContainer","operationalMappingID","operationalMappingVersion"].contains($0.key)}
        }
        let report:[String:Any]=["schema":1,"scope":"native-auxiliary-not-official-98","lots":auxiliary,"movements":history]
        return String(decoding:try JSONSerialization.data(withJSONObject:report,options:[.prettyPrinted,.sortedKeys]),as:UTF8.self)
    }
    public enum Failure:Error {case invalidEvidence,invalidProduct,invalidLot}
    public static func products(snapshot:Data)throws->[N2NursingCatalogProduct] {
        guard let root=try JSONSerialization.jsonObject(with:snapshot) as? [String:Any] else{throw Failure.invalidProduct}
        guard let value=root["nativeAuxiliaryCatalog"] else{return []}
        guard let entries=value as? [[String:Any]],entries.count<=432 else{throw Failure.invalidProduct}
        return try entries.map { row in
            guard let code=row["clinicalCode"] as? String,
                  let name=row["name"] as? String,
                  let id=row["id"] as? String,id=="AUX:"+code,
                  let unit=row["unit"] as? String,!unit.isEmpty else{throw Failure.invalidProduct}
            return N2NursingCatalogProduct(id:id,name:name,group:"Contabilidad auxiliar",unit:unit)
        }
    }
    public static func register(snapshot:Data,clinicalCode:String,lot:Data,
                                catalog:N2NativeCatalogIndex,operatorName:String,
                                evidence:String,at:Int64,explicitConsent:Bool)throws->Data {
        guard explicitConsent,operatorName.trimmingCharacters(in:.whitespacesAndNewlines).count>=3,
              evidence.trimmingCharacters(in:.whitespacesAndNewlines).count>=10,at>0 else{throw Failure.invalidEvidence}
        guard let product=catalog.clinical.first(where:{$0.code==clinicalCode}),
              let physical=try JSONSerialization.jsonObject(with:lot) as? [String:Any],
              physical["code"] as? String=="AUX:"+clinicalCode,
              physical["name"] as? String==product.name,
              N2NativeInventoryCommands.validLot(physical) else{throw Failure.invalidLot}
        guard var root=try JSONSerialization.jsonObject(with:snapshot) as? [String:Any],
              var lots=root["stockLots"] as? [[String:Any]] else{throw Failure.invalidProduct}
        guard lots.count<500,!lots.contains(where:{$0["id"] as? String==physical["id"] as? String}) else{throw Failure.invalidLot}
        _=try products(snapshot:snapshot)
        var entries=root["nativeAuxiliaryCatalog"] as? [[String:Any]] ?? []
        let unit=physical["catalogUnit"] as! String
        if let existing=entries.first(where:{$0["id"] as? String=="AUX:"+clinicalCode}) {
            guard existing["name"] as? String==product.name,existing["unit"] as? String==unit else{throw Failure.invalidProduct}
        } else {
            entries.append(["id":"AUX:"+clinicalCode,"clinicalCode":clinicalCode,"name":product.name,
                "unit":unit,"operatorName":operatorName,"evidence":evidence,"confirmedAt":at,"version":1])
        }
        lots.append(physical)
        root["nativeAuxiliaryCatalog"]=entries;root["stockLots"]=lots
        let result=try JSONSerialization.data(withJSONObject:root,options:.sortedKeys)
        _=try N2VersionedSnapshotAudit.inspect(result,allowEmptySynthetic:true)
        _=try N1fLosslessFieldGate.inspect(result)
        return result
    }
}
