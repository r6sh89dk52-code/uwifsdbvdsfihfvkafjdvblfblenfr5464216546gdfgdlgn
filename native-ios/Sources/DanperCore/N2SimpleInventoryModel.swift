import Foundation
import CoreFoundation
import Crypto

public enum N2SimpleInventoryError:Error,Equatable {
    case invalidSnapshot,unsupportedSchema,invalidProduct,invalidQuantity,invalidDate
    case missingBackup,sourceChanged,alreadyActive,confirmationRequired,invalidEvent
    case insufficientStock,duplicateChangedEvent,invalidDeclaration,invalidClinicalLink
    case conflictingClinicalRecord,legacyOperation,limitReached
}
public enum N2SimpleCountMode:String,Codable,Sendable {case units,presentation}
public struct N2SimpleProduct:Codable,Equatable,Sendable,Identifiable {
    public var id:String {code}
    public var code:String
    public var name:String
    public var unit:String
    public var mode:N2SimpleCountMode
    public var quantity:Double
    public var expiry:String
    public var expiryVerified:Bool
    public var lastCountAt:Int64
    public init(code:String,name:String,unit:String,mode:N2SimpleCountMode,quantity:Double,
                expiry:String="",expiryVerified:Bool=false,lastCountAt:Int64=0) {
        self.code=code;self.name=name;self.unit=unit;self.mode=mode;self.quantity=quantity
        self.expiry=expiry;self.expiryVerified=expiryVerified;self.lastCountAt=lastCountAt
    }
}
public struct N2SimpleRegime:Codable,Equatable,Sendable {
    public let id:String
    public let activatedAt:Int64
    public let timeZone:String
    public let schemaVersion:Int
    public let sourceSHA256:String
    public let activationSHA256:String
    public let backupSHA256:String
    public let operatorName:String
    public let confirmationID:String
    public let auditID:String
    public let migrationStatus:String
}
public struct N2SimpleMovement:Codable,Equatable,Sendable,Identifiable {
    public let id:String
    public let code:String
    public let unit:String
    public let kind:String
    public let at:Int64
    public let before:Double
    public let after:Double
    public let delta:Double
    public let operatorName:String
    public let reason:String
    public let visitID:String?
    public let itemID:String?
    public let declaredR:Int?
    public let clinicalQuantity:Double?
}
public struct N2SimpleMetadataEvent:Codable,Equatable,Sendable,Identifiable {
    public let id:String
    public let code:String
    public let at:Int64
    public let operatorName:String
    public let reason:String
    public let previous:String
    public let next:String
    public let verified:Bool
}
public struct N2SimpleIncident:Codable,Equatable,Sendable,Identifiable {
    public let id:String
    public let visitID:String
    public let itemID:String
    public let code:String
    public let unit:String
    public let clinicalQuantity:Double
    public let requestedDebit:Double?
    public let declaredR:Int?
    public let at:Int64
    public let reason:String
    public var resolutionEventID:String?
    public var operatorName:String
    public let clinicalAt:Int64
    public var resolvedAt:Int64?=nil
    public var resolvedBy:String?=nil
    public var resolutionReason:String?=nil
    public var resolvedR:Int?=nil
}
public struct N2SimpleClinicalImport:Codable,Equatable,Sendable {
    public let id:String
    public let sourceSHA256:String
    public let at:Int64
    public let operatorName:String
    public let workersAdded:Int
    public let visitsAdded:Int
}
public struct N2SimpleHistoricalUse:Codable,Equatable,Sendable {
    public let visitID:String
    public let itemID:String
    public let code:String
    public let unit:String
    public let quantity:Double
    public let verifiedR:Double?
    public let sourceSHA256:String
}
public struct N2SimpleInventoryState:Codable,Equatable,Sendable {
    public let regime:N2SimpleRegime
    public var products:[N2SimpleProduct]
    public var movements:[N2SimpleMovement]
    public var metadataEvents:[N2SimpleMetadataEvent]
    public var incidents:[N2SimpleIncident]
    public var clinicalImports:[N2SimpleClinicalImport]
    public var historicalUses:[N2SimpleHistoricalUse]
    public var openingIsExtraordinary:Bool
    public var appliedCommands:[String:String]
}

/// Version dispatch does not relax v1. A v2 snapshot gets its own strict ledger
/// audit; v1 always passes through the unchanged legacy physical concordance.
public enum N2VersionedSnapshotAudit {
    public static func inspect(_ data:Data,allowEmptySynthetic:Bool=false)throws->N1eClinicalParityReport {
        guard let root=try? JSONSerialization.jsonObject(with:data) as? [String:Any] else {
            throw N2SimpleInventoryError.invalidSnapshot
        }
        if let version=root["inventorySchemaVersion"] {
            guard let n=version as? NSNumber,CFGetTypeID(n) != CFBooleanGetTypeID(),n.intValue==2,
                  n.doubleValue==2 else {throw N2SimpleInventoryError.unsupportedSchema}
            return try N2SimpleInventory.audit(data)
        }
        guard root["simpleInventory"] == nil else{throw N2SimpleInventoryError.unsupportedSchema}
        return try N1eLegacyClinicalAudit.inspect(data,allowEmptySynthetic:allowEmptySynthetic)
    }
}
public enum N2SimpleInventory {
    static func object(_ data:Data)throws->[String:Any] {
        guard data.count<=30*1024*1024,
              let root=try JSONSerialization.jsonObject(with:data) as? [String:Any] else {
            throw N2SimpleInventoryError.invalidSnapshot
        }
        return root
    }
    static func bytes(_ root:[String:Any])throws->Data {
        try JSONSerialization.data(withJSONObject:root,options:[.sortedKeys])
    }
    public static func fingerprint(_ data:Data)throws->String {
        SHA256.hash(data:try bytes(object(data))).map{String(format:"%02x",$0)}.joined()
    }
    static func digest(_ data:Data)->String {SHA256.hash(data:data).map{String(format:"%02x",$0)}.joined()}
    static func round(_ value:Double)->Double {(value*1000).rounded()/1000}
    static func validQuantity(_ q:Double)->Bool {
        q.isFinite && q>=0 && q<=10_000_000 && abs(round(q)-q)<0.0000001
    }
    static func validTime(_ at:Int64)->Bool {at>0 && at<9_007_199_254_740_991}
    static func text(_ text:String)->Bool {(1...200).contains(text.trimmingCharacters(in:.whitespacesAndNewlines).utf8.count)}
    static func sha(_ text:String)->Bool {text.count==64 && text.allSatisfy{"0123456789abcdef".contains($0)}}
    public static func validDay(_ day:String)->Bool {
        guard day.range(of:#"^\d{4}-\d{2}-\d{2}$"#,options:.regularExpression) != nil else{return false}
        let a=day.split(separator:"-").compactMap{Int($0)}
        guard a.count==3,(1900...2100).contains(a[0]) else{return false}
        var cal=Calendar(identifier:.gregorian);cal.timeZone=TimeZone(identifier:"America/Lima")!
        let c=DateComponents(year:a[0],month:a[1],day:a[2])
        guard let date=cal.date(from:c) else{return false}
        return cal.dateComponents([.year,.month,.day],from:date)==c
    }
    public static func day(_ at:Int64)->String {
        let f=DateFormatter();f.locale=Locale(identifier:"en_US_POSIX")
        f.timeZone=TimeZone(identifier:"America/Lima");f.dateFormat="yyyy-MM-dd"
        return f.string(from:Date(timeIntervalSince1970:Double(at)/1000))
    }
    public static func isActive(_ snapshot:Data)->Bool {
        guard let root=try? object(snapshot) else{return false}
        return (root["inventorySchemaVersion"] as? Int)==2
    }
    public static func read(_ snapshot:Data)throws->N2SimpleInventoryState {
        _=try N2VersionedSnapshotAudit.inspect(snapshot,allowEmptySynthetic:true)
        return try state(object(snapshot))
    }
    static func state(_ root:[String:Any])throws->N2SimpleInventoryState {
        guard root["inventorySchemaVersion"] as? Int == 2,let raw=root["simpleInventory"] as? [String:Any] else {
            throw N2SimpleInventoryError.unsupportedSchema
        }
        return try JSONDecoder().decode(N2SimpleInventoryState.self,from:bytes(raw))
    }
    static func putting(_ state:N2SimpleInventoryState,in root:[String:Any])throws->Data {
        var next=root
        next["inventorySchemaVersion"]=2
        next["simpleInventory"]=try JSONSerialization.jsonObject(with:JSONEncoder().encode(state))
        let raw=try bytes(next);_=try audit(raw);return raw
    }
    static func validProduct(_ p:N2SimpleProduct)->Bool {
        text(p.code) && p.code.allSatisfy{$0.isASCII && $0.isNumber} && text(p.name) && text(p.unit) &&
        validQuantity(p.quantity) && (suggestedMode(unit:p.unit).map({$0==p.mode}) ?? true) && (p.mode != .presentation || p.quantity.rounded()==p.quantity) &&
        (p.expiry.isEmpty || validDay(p.expiry)) && (!p.expiryVerified || !p.expiry.isEmpty) && validTime(p.lastCountAt)
    }
    static func clinicalRows(_ root:[String:Any])throws->[[String:Any]] {
        guard let visits=root["attentions"] as? [[String:Any]] else{throw N2SimpleInventoryError.invalidSnapshot}
        return visits
    }
    static func key(_ visit:String,_ item:String)->String {visit+"\u{001F}"+item}
    public static func audit(_ snapshot:Data)throws->N1eClinicalParityReport {
        let root=try object(snapshot)
        _=try N1fLosslessFieldGate.inspect(snapshot)
        if (try? N1BackupAdmission.preview(data:snapshot)) == nil {
            let baseKeys:Set<String>=["workers","attentions","allergies","stockLots","stockMovements",
                "catalogMappings","deliveryIncidents","ambulatoryReconciliation","notifications"]
            let base=root.filter{baseKeys.contains($0.key)}
            guard N2EmptyDemoSnapshot.matches(try bytes(base)) else{throw N2SimpleInventoryError.invalidSnapshot}
        }
        guard let lots=root["stockLots"] as? [Any],lots.isEmpty,
              let oldMoves=root["stockMovements"] as? [Any],oldMoves.isEmpty,
              ["nativePendingDispensingEvidence","nativeStockSiteVerifications","nativeLotMetadataCorrections","deliveryIncidents"].allSatisfy({
                  root[$0]==nil || (root[$0] as? [Any])?.isEmpty==true
              }) else {
            throw N2SimpleInventoryError.legacyOperation
        }
        let s=try state(root),r=s.regime
        guard UUID(uuidString:r.id) != nil,UUID(uuidString:r.confirmationID) != nil,
              UUID(uuidString:r.auditID) != nil,r.schemaVersion==2,r.timeZone=="America/Lima",
              r.migrationStatus=="active",validTime(r.activatedAt),sha(r.sourceSHA256),sha(r.activationSHA256),sha(r.backupSHA256),
              text(r.operatorName),s.products.count<=1000,s.movements.count<=50000,
              s.incidents.count<=50000,s.metadataEvents.count<=10000,s.clinicalImports.count<=1000,s.historicalUses.count<=100000,
              Set(s.products.map(\.code)).count==s.products.count,s.products.allSatisfy(validProduct) else {
            throw N2SimpleInventoryError.invalidSnapshot
        }
        let products=Dictionary(uniqueKeysWithValues:s.products.map{($0.code,$0)})
        var clinical=[String:[String:Any]](),ordered=[String]()
        let visits=try clinicalRows(root),workers=root["workers"] as? [[String:Any]] ?? []
        let dnis=Set(workers.compactMap{$0["dni"] as? String})
        for v in visits where v["status"] as? String=="saved" {
            guard let id=v["id"] as? String,let worker=v["worker"] as? [String:Any],
                  let dni=worker["dni"] as? String,dnis.contains(dni),
                  let items=v["items"] as? [[String:Any]] else{throw N2SimpleInventoryError.invalidClinicalLink}
            for item in items {
                guard let iid=item["id"] as? String else{throw N2SimpleInventoryError.invalidClinicalLink}
                let k=key(id,iid);clinical[k]=item;ordered.append(k)
            }
        }
        var ids=Set<String>(),balances=[String:Double](),lastAt=[String:Int64](),uses=[String:Double]()
        for m in s.movements {
            guard text(m.id),ids.insert(m.id).inserted,let p=products[m.code],m.unit==p.unit,
                  ["initial","receipt","outflow","count"].contains(m.kind),validTime(m.at),m.at>=r.activatedAt,
                  m.at >= (lastAt[m.code] ?? r.activatedAt),text(m.operatorName),text(m.reason),
                  validQuantity(m.before),validQuantity(m.after),m.delta.isFinite,
                  abs(round(m.before+m.delta)-m.after)<0.0000001,
                  m.before==(balances[m.code] ?? 0),
                  p.mode != .presentation || (m.before.rounded()==m.before && m.after.rounded()==m.after) else {
                throw N2SimpleInventoryError.invalidEvent
            }
            if balances[m.code]==nil {
                guard m.kind=="initial",m.before==0,m.delta>=0 else{throw N2SimpleInventoryError.invalidEvent}
            } else if m.kind=="initial" {throw N2SimpleInventoryError.invalidEvent}
            if m.kind=="receipt",m.delta<=0 {throw N2SimpleInventoryError.invalidEvent}
            if m.kind=="outflow",m.delta>0 {throw N2SimpleInventoryError.invalidEvent}
            if let visit=m.visitID,let item=m.itemID {
                let k=key(visit,item)
                guard m.kind=="outflow",let row=clinical[k],row["code"] as? String==m.code,
                      row["unit"] as? String==m.unit,let quantity=row["quantity"] as? NSNumber,
                      quantity.doubleValue==m.clinicalQuantity,uses[k]==nil else {
                    throw N2SimpleInventoryError.invalidClinicalLink
                }
                if p.mode == .presentation {
                    let original=(row["simpleR"] as? NSNumber).flatMap {n->Int? in
                        guard CFGetTypeID(n) != CFBooleanGetTypeID(),n.doubleValue==0 || n.doubleValue==1 else{return nil}
                        return n.intValue
                    }
                    let resolved=s.incidents.first{$0.visitID==visit && $0.itemID==item && $0.resolutionEventID==m.id}
                    guard let declared=m.declaredR,[0,1].contains(declared),m.delta == -Double(declared),
                          original==declared || resolved?.resolvedR==declared else {
                        throw N2SimpleInventoryError.invalidDeclaration
                    }
                } else {
                    guard m.declaredR==nil,m.delta == -quantity.doubleValue else{throw N2SimpleInventoryError.invalidDeclaration}
                }
                uses[k] = -m.delta
            } else if m.visitID != nil || m.itemID != nil || m.declaredR != nil || m.clinicalQuantity != nil {
                throw N2SimpleInventoryError.invalidClinicalLink
            }
            balances[m.code]=m.after;lastAt[m.code]=m.at
        }
        for p in s.products {
            guard balances[p.code]==p.quantity,let count=s.movements.last(where:{$0.code==p.code && ["initial","count"].contains($0.kind)}),
                  count.at==p.lastCountAt else {throw N2SimpleInventoryError.invalidEvent}
        }
        var incidenceKeys=Set<String>()
        for i in s.incidents {
            let k=key(i.visitID,i.itemID)
            guard text(i.id),ids.insert(i.id).inserted,incidenceKeys.insert(k).inserted,
                  let row=clinical[k],row["code"] as? String==i.code,row["unit"] as? String==i.unit,
                  (row["quantity"] as? NSNumber)?.doubleValue==i.clinicalQuantity,
                  validTime(i.at),i.at>=r.activatedAt,validTime(i.clinicalAt),i.clinicalAt<=i.at,text(i.reason),text(i.operatorName),
                  i.requestedDebit.map(validQuantity) ?? true,
                  i.declaredR.map({[0,1].contains($0)}) ?? true else{throw N2SimpleInventoryError.invalidClinicalLink}
            if let resolution=i.resolutionEventID {
                guard let resolvedAt=i.resolvedAt,validTime(resolvedAt),resolvedAt>=i.at,
                      let resolvedBy=i.resolvedBy,text(resolvedBy),let why=i.resolutionReason,text(why),
                      s.movements.contains(where:{$0.id==resolution && $0.code==i.code &&
                        (($0.visitID==i.visitID && $0.itemID==i.itemID) ||
                         (["initial","count"].contains($0.kind) && $0.at>i.clinicalAt))}) else {
                    throw N2SimpleInventoryError.invalidClinicalLink
                }
                if products[i.code]?.mode == .presentation {
                    guard let declared=i.resolvedR,[0,1].contains(declared) else {throw N2SimpleInventoryError.invalidDeclaration}
                }
            } else if uses[k] != nil || i.resolvedAt != nil || i.resolvedBy != nil || i.resolutionReason != nil || i.resolvedR != nil {
                throw N2SimpleInventoryError.invalidClinicalLink
            }
        }
        var expiryValues=[String:String](),expiryTimes=[String:Int64](),expiryChecks=[String:Bool]()
        for e in s.metadataEvents {
            guard ids.insert(e.id).inserted,products[e.code] != nil,validTime(e.at),e.at>=r.activatedAt,
                  text(e.operatorName),text(e.reason),(e.previous.isEmpty || validDay(e.previous)),
                  (e.next.isEmpty || validDay(e.next)),!e.verified || !e.next.isEmpty else{
                throw N2SimpleInventoryError.invalidEvent
            }
            guard e.previous==(expiryValues[e.code] ?? ""),e.at >= (expiryTimes[e.code] ?? r.activatedAt) else {
                throw N2SimpleInventoryError.invalidEvent
            }
            expiryValues[e.code]=e.next;expiryTimes[e.code]=e.at;expiryChecks[e.code]=e.verified
        }
        guard s.products.allSatisfy({expiryValues[$0.code]==$0.expiry && expiryChecks[$0.code]==$0.expiryVerified}),
              s.appliedCommands.count<=50000,s.appliedCommands.allSatisfy({text($0.key) && sha($0.value)}) else {
            throw N2SimpleInventoryError.invalidEvent
        }
        var imported=Set<String>()
        for i in s.clinicalImports {
            guard ids.insert(i.id).inserted,sha(i.sourceSHA256),imported.insert(i.sourceSHA256).inserted,
                  validTime(i.at),i.at>=r.activatedAt,text(i.operatorName),i.workersAdded>=0,i.visitsAdded>=0 else {
                throw N2SimpleInventoryError.invalidEvent
            }
        }
        var historicKeys=Set<String>()
        for h in s.historicalUses {
            let k=key(h.visitID,h.itemID)
            guard historicKeys.insert(k).inserted,let item=clinical[k],item["code"] as? String==h.code,
                  item["unit"] as? String==h.unit,(item["quantity"] as? NSNumber)?.doubleValue==h.quantity,
                  sha(h.sourceSHA256),h.verifiedR.map(validQuantity) ?? true,uses[k]==nil, !incidenceKeys.contains(k) else{
                throw N2SimpleInventoryError.invalidClinicalLink
            }
        }
        // Every saved line belongs to either the immutable clinical history,
        // exactly one new consumption, or a separate unresolved incident.
        guard ordered.allSatisfy({uses[$0] != nil || historicKeys.contains($0) || incidenceKeys.contains($0)}) else {
            throw N2SimpleInventoryError.invalidClinicalLink
        }
        let historical=Dictionary(uniqueKeysWithValues:s.historicalUses.map{(key($0.visitID,$0.itemID),$0.verifiedR)})
        let quantities:[Double?]=ordered.map{uses[$0] ?? historical[$0] ?? nil}
        return N1eClinicalParityReport(sourceSHA256:digest(snapshot),workers:workers.count,attentions:visits.count,
            savedClinicalItems:ordered.count,linkedClinicalItems:quantities.compactMap{$0}.count,
            pendingClinicalItems:s.incidents.filter{$0.resolutionEventID==nil}.count,splitDeliveries:0,
            physicalMovements:s.movements.count,stockLots:0,consumptionR:quantities)
    }
}
