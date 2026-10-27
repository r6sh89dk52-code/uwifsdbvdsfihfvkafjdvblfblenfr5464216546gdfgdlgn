import Foundation

public struct N2SimpleInventoryCommand:Codable,Equatable,Sendable {
    public enum Operation:String,Codable,Sendable {case register,receipt,outflow,count,expiry,resolveIncident}
    public let id:String
    public let operation:Operation
    public let code:String
    public let quantity:Double
    public let at:Int64
    public let operatorName:String
    public let reason:String
    public var product:N2SimpleProduct?
    public var expiry:String?
    public var expiryVerified:Bool?
    public var incidentID:String?
    public var declaredR:Int?
    public init(id:String=UUID().uuidString,operation:Operation,code:String,quantity:Double=0,
                at:Int64,operatorName:String,reason:String,product:N2SimpleProduct?=nil,
                expiry:String?=nil,expiryVerified:Bool?=nil,incidentID:String?=nil,declaredR:Int?=nil) {
        self.id=id;self.operation=operation;self.code=code;self.quantity=quantity;self.at=at
        self.operatorName=operatorName;self.reason=reason;self.product=product;self.expiry=expiry
        self.expiryVerified=expiryVerified;self.incidentID=incidentID;self.declaredR=declaredR
    }
}
extension N2SimpleInventory {
    public static func suggestedMode(unit:String)->N2SimpleCountMode? {
        let u=unit.trimmingCharacters(in:.whitespacesAndNewlines).uppercased()
        if ["UND","TBL","TAB","PAR","UN"].contains(u) {return .units}
        if ["FCO","CJA","PAQ","BLISTER","ENV","FRASCO","CAJA","PAQUETE"].contains(u) {return .presentation}
        return nil
    }
    static func metadata(id:String,code:String,at:Int64,op:String,reason:String,
                         previous:String,next:String,verified:Bool)->N2SimpleMetadataEvent {
        N2SimpleMetadataEvent(id:id,code:code,at:at,operatorName:op,reason:reason,
                              previous:previous,next:next,verified:verified)
    }
    static func movement(id:String,p:N2SimpleProduct,kind:String,at:Int64,after:Double,
                         op:String,reason:String,visit:String?=nil,item:String?=nil,
                         r:Int?=nil,clinicalQuantity:Double?=nil)->N2SimpleMovement {
        N2SimpleMovement(id:id,code:p.code,unit:p.unit,kind:kind,at:at,before:p.quantity,
            after:round(after),delta:round(after-p.quantity),operatorName:op,reason:reason,
            visitID:visit,itemID:item,declaredR:r,clinicalQuantity:clinicalQuantity)
    }
    public static func apply(_ command:N2SimpleInventoryCommand,to snapshot:Data,
                             catalog:N2NativeCatalogIndex)throws->Data {
        _=try audit(snapshot)
        let root=try object(snapshot);var s=try state(root)
        guard text(command.id),validTime(command.at),command.at>=s.regime.activatedAt,
              text(command.operatorName),text(command.reason),validQuantity(command.quantity) else {
            throw N2SimpleInventoryError.invalidEvent
        }
        let fingerprint=try self.fingerprint(JSONEncoder().encode(command))
        if let prior=s.appliedCommands[command.id] {
            guard prior==fingerprint else{throw N2SimpleInventoryError.duplicateChangedEvent}
            return snapshot
        }
        // User commands share the same namespace as clinical and activation events.
        guard !s.movements.contains(where:{$0.id==command.id}),
              !s.metadataEvents.contains(where:{$0.id==command.id}) else {
            throw N2SimpleInventoryError.duplicateChangedEvent
        }
        if command.operation == .register {
            guard var p=command.product,p.code==command.code,
                  !s.products.contains(where:{$0.code==p.code}),
                  let official=catalog.clinical.first(where:{$0.code==p.code}),
                  p.name==official.name,p.unit==official.unit,
                  suggestedMode(unit:p.unit).map({$0==p.mode}) ?? true else {
                throw N2SimpleInventoryError.invalidProduct
            }
            p.quantity=command.quantity;p.lastCountAt=command.at
            guard validProduct(p) else{throw N2SimpleInventoryError.invalidProduct}
            var empty=p;empty.quantity=0
            s.products.append(p)
            s.movements.append(movement(id:command.id,p:empty,kind:"initial",at:command.at,
                after:p.quantity,op:command.operatorName,reason:command.reason))
            s.metadataEvents.append(metadata(id:command.id+":expiry",code:p.code,at:command.at,
                op:command.operatorName,reason:command.reason,previous:"",next:p.expiry,verified:p.expiryVerified))
        }else {
            guard let idx=s.products.firstIndex(where:{$0.code==command.code}) else {
                throw N2SimpleInventoryError.invalidProduct
            }
            var p=s.products[idx]
            guard command.at >= (s.movements.last(where:{$0.code==p.code})?.at ?? p.lastCountAt),
                  p.mode != .presentation || command.quantity.rounded()==command.quantity else {
                throw N2SimpleInventoryError.invalidQuantity
            }
            switch command.operation {
            case .register:break
            case .receipt,.outflow,.count:
                guard command.operation == .count || command.quantity>0 else {
                    throw N2SimpleInventoryError.invalidQuantity
                }
                let after=command.operation == .count ? command.quantity :
                    round(p.quantity+(command.operation == .receipt ? command.quantity:-command.quantity))
                guard validQuantity(after) else{throw N2SimpleInventoryError.insufficientStock}
                let kind=command.operation == .receipt ? "receipt" : (command.operation == .count ? "count":"outflow")
                s.movements.append(movement(id:command.id,p:p,kind:kind,at:command.at,after:after,
                    op:command.operatorName,reason:command.reason))
                p.quantity=after
                if command.operation == .count {p.lastCountAt=command.at}
            case .expiry:break
            case .resolveIncident:
                guard let incidentID=command.incidentID,
                      let i=s.incidents.firstIndex(where:{$0.id==incidentID && $0.code==p.code}),
                      s.incidents[i].resolutionEventID==nil else{throw N2SimpleInventoryError.invalidEvent}
                let incident=s.incidents[i]
                let r=p.mode == .presentation ? (command.declaredR ?? incident.declaredR) : nil
                guard p.mode != .presentation || r.map({[0,1].contains($0)})==true else {
                    throw N2SimpleInventoryError.invalidDeclaration
                }
                let debit=p.mode == .presentation ? Double(r!):incident.clinicalQuantity
                if incident.clinicalAt<p.lastCountAt,
                   let count=s.movements.last(where:{$0.code==p.code && ["initial","count"].contains($0.kind) && $0.at>incident.clinicalAt}) {
                    // A later authoritative count already includes this use. Explicit
                    // resolution records its declaration, never debits the count twice.
                    s.incidents[i].resolutionEventID=count.id
                }else {
                    guard p.quantity>=debit else{throw N2SimpleInventoryError.insufficientStock}
                    let m=movement(id:command.id,p:p,kind:"outflow",at:command.at,after:p.quantity-debit,
                        op:command.operatorName,reason:command.reason,visit:incident.visitID,item:incident.itemID,
                        r:r,clinicalQuantity:incident.clinicalQuantity)
                    s.movements.append(m);p.quantity=m.after;s.incidents[i].resolutionEventID=m.id
                }
                s.incidents[i].resolvedAt=command.at;s.incidents[i].resolvedBy=command.operatorName
                s.incidents[i].resolutionReason=command.reason;s.incidents[i].resolvedR=r
            }
            if command.operation == .expiry || command.expiry != nil {
                guard let next=command.expiry,let verified=command.expiryVerified,
                      next.isEmpty || validDay(next),!verified || !next.isEmpty else {
                    throw N2SimpleInventoryError.invalidDate
                }
                s.metadataEvents.append(metadata(id:command.operation == .expiry ? command.id:command.id+":expiry",
                    code:p.code,at:command.at,op:command.operatorName,reason:command.reason,
                    previous:p.expiry,next:next,verified:verified))
                p.expiry=next;p.expiryVerified=verified
            }
            s.products[idx]=p
        }
        s.appliedCommands[command.id]=fingerprint
        return try putting(s,in:root)
    }
}
