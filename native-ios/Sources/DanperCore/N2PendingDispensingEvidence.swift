import Foundation

public struct N2PendingDispensingEvidence:Codable,Sendable,Equatable {
    public let id:String
    public let visitID:String
    public let itemID:String
    public let lotID:String
    public let quantity:Double
    public let confirmNewContainer:Bool
    public let operatorName:String
    /// Optional in older encrypted declarations; required by the current single-user UI.
    public let operatorDni:String?
    public let reason:String
    public let at:Int64
    public let version:Int
    public var newContainers:Int?
    public init(visitID:String,itemID:String,lotID:String,quantity:Double,
                confirmNewContainer:Bool,operatorName:String,reason:String,at:Int64,newContainers:Int?=nil,operatorDni:String?=nil) {
        id=UUID().uuidString;self.visitID=visitID;self.itemID=itemID;self.lotID=lotID
        self.quantity=quantity;self.confirmNewContainer=confirmNewContainer
        self.operatorName=operatorName;self.operatorDni=operatorDni
        self.reason=reason;self.at=at;version=1
        self.newContainers=newContainers ?? (confirmNewContainer ? 1:0)
    }
    /// A factual, machine-generated audit description. It records the
    /// operator's explicit declaration, not independent proof of past stock.
    /// The user never needs to type an arbitrary motive for a routine use.
    public static func automaticAuditDescription(
        clinicalDate:String,lotReference:String,historical:Bool,
        container:Bool,newContainers:Int,physicalQuantity:Double
    )->String {
        let operation:String
        if container {
            operation=newContainers>0
                ? "apertura declarada de \(newContainers) envase(s), Kardex R=\(newContainers)"
                : "reutilización declarada de envase abierto, Kardex R=0"
        } else {
            operation="consumo físico declarado de \(physicalQuantity.formatted()) unidad(es)"
        }
        let scope=historical
            ? "Conciliación histórica: sin movimiento físico retroactivo ni modificación del conteo actual."
            : "Conciliación del consumo; sujeto a verificación de stock FEFO."
        return "Declaración explícita del profesional en DANPER: \(operation). Atención \(clinicalDate); lote \(lotReference). \(scope)"
    }
    public enum Failure:Error {case invalidEvidence,invalidTarget}
    public static func read(snapshot:Data)throws->[Self] {
        guard let root=try JSONSerialization.jsonObject(with:snapshot) as? [String:Any] else{throw Failure.invalidTarget}
        guard let value=root["nativePendingDispensingEvidence"] else{return []}
        let records=try JSONDecoder().decode([Self].self,from:JSONSerialization.data(withJSONObject:value))
        guard records.count<=500,Set(records.map(\.id)).count==records.count else{throw Failure.invalidEvidence}
        for record in records {try record.validate()}
        return records
    }
    private func validate()throws {
        guard version==1,UUID(uuidString:id) != nil,!visitID.isEmpty,!itemID.isEmpty,!lotID.isEmpty,
              quantity.isFinite,quantity>=0,quantity<=10_000_000,at>0,
              newContainers == nil || ((0...10_000).contains(newContainers!) && (newContainers==0 || confirmNewContainer)),
              operatorName.trimmingCharacters(in:.whitespacesAndNewlines).count>=3,
              operatorDni == nil || operatorDni!.range(of:#"^\d{8}$"#,
                  options:.regularExpression) != nil,
              reason.trimmingCharacters(in:.whitespacesAndNewlines).count>=10 else{throw Failure.invalidEvidence}
    }
    public func append(snapshot:Data,explicitConsent:Bool)throws->Data {
        try validate()
        guard explicitConsent else{throw Failure.invalidEvidence}
        _=try N2VersionedSnapshotAudit.inspect(snapshot)
        guard var root=try JSONSerialization.jsonObject(with:snapshot) as? [String:Any],
              let visits=root["attentions"] as? [[String:Any]],
              let visit=visits.first(where:{$0["id"] as? String==visitID && $0["status"] as? String=="saved"}),
              let items=visit["items"] as? [[String:Any]],items.contains(where:{$0["id"] as? String==itemID}),
              let lots=root["stockLots"] as? [[String:Any]],lots.contains(where:{$0["id"] as? String==lotID}),
              let movements=root["stockMovements"] as? [[String:Any]] else{throw Failure.invalidTarget}
        if movements.contains(where:{ movement in
            let ref=movement["dispenseRef"] as? [String:Any]
            return ref?["attentionId"] as? String==visitID && ref?["itemId"] as? String==itemID
        }) {return snapshot}
        var records=try Self.read(snapshot:snapshot)
        if records.contains(self){return snapshot}
        guard records.count<500,!records.contains(where:{$0.id==id}) else{throw Failure.invalidEvidence}
        records.append(self)
        root["nativePendingDispensingEvidence"]=try JSONSerialization.jsonObject(with:JSONEncoder().encode(records))
        return try JSONSerialization.data(withJSONObject:root,options:.sortedKeys)
    }
}
