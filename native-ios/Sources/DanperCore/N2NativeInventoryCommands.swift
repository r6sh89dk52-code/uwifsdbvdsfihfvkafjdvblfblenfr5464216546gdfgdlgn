import Foundation
import CoreFoundation

/// Verified physical stock ledger commands for the native store. Opening a
/// sealed container is NOT a receipt; clinical FEFO dispenses use N2 clinical.
public enum N2InventoryError:Error,Equatable {
    case invalidSnapshot,invalidLot,duplicateLot,unrecognizedMaterial
    case invalidMovement,duplicatedMovement,insufficientEvidence,limitReached
}
public enum N2NativeInventoryCommands {
    private static func num(_ x:Any?)->Double? {
        guard let n=x as? NSNumber,CFGetTypeID(n) != CFBooleanGetTypeID(),
              n.doubleValue.isFinite else {return nil}
        return n.doubleValue
    }
    private static func positive(_ n:Double)->Bool {n>0 && n<=10_000_000}
    private static func triple(_ v:Double)->Double {(v*1000).rounded()/1000}
    private static func day(_ at:Int64)->String {
        var cal=Calendar(identifier:.gregorian)
        cal.timeZone=TimeZone(identifier:"America/Lima")!
        let d=cal.dateComponents([.year,.month,.day],
                from:Date(timeIntervalSince1970:Double(at)/1000))
        return String(format:"%04d-%02d-%02d",d.year!,d.month!,d.day!)
    }
    private static func balance(_ x:[String:Any])->Double {
        let sealed=num(x["sealedContainers"]) ?? 0
        let capacity=num(x["unitsPerContainer"]) ?? 0
        let loose=num(x["looseUnits"]) ?? 0
        let opened=num(x["openedRemaining"]) ?? 0
        return triple(sealed * capacity + loose + opened)
    }
    static func validLot(_ l:[String:Any])->Bool {
        guard let id=l["id"] as? String,!id.isEmpty,
              let code=l["code"] as? String,!code.isEmpty,
              let name=l["name"] as? String,!name.isEmpty,
              let _ = l["lot"] as? String,
              let _ = l["catalogUnit"] as? String,
              let expiry=l["expires"] as? String,
              let container=l["container"] as? String,
              ["unidad","caja","frasco","paquete","blister","otro"].contains(container),
              let cap=num(l["unitsPerContainer"]),cap>=1,cap.rounded()==cap,
              let sealed=num(l["sealedContainers"]),sealed>=0,sealed.rounded()==sealed,
              let loose=num(l["looseUnits"]),loose>=0,
              let opened=num(l["openedRemaining"]),opened>=0,opened<=cap,
              let at=num(l["updatedAt"]),at>=0,at.rounded()==at,
              balance(l)<=10_000_000_000 else{return false}
        if let site=l["site"], !["LA VENTUROSA","PLVENTUROSA"].contains(site as? String ?? "") {return false}
        if !expiry.isEmpty {
            guard expiry.range(of:#"^\d{4}-\d{2}-\d{2}$"#,
                options:.regularExpression) != nil else{return false}
        }
        return true
    }
    private static func root(_ snapshot:Data)throws->[String:Any] {
        guard (try? N2VersionedSnapshotAudit.inspect(snapshot)) != nil,
              (try? N1fLosslessFieldGate.inspect(snapshot)) != nil,
              let source=try? JSONSerialization.jsonObject(with:snapshot) as? [String:Any]
        else{throw N2InventoryError.invalidSnapshot}
        return source
    }
    private static func done(_ next:[String:Any])throws->Data {
        guard let raw=try? JSONSerialization.data(withJSONObject:next,
                options:[.sortedKeys]),
              (try? N2VersionedSnapshotAudit.inspect(raw)) != nil,
              (try? N1fLosslessFieldGate.inspect(raw)) != nil else {
            throw N2InventoryError.invalidSnapshot
        }
        return raw
    }
    private static func catalog(_ raw:Data)throws->[String:String] {
        guard let items=try? JSONSerialization.jsonObject(with:raw)
            as? [[String:Any]],items.count==98 else {
            throw N2InventoryError.unrecognizedMaterial
        }
        var found=[String:String]()
        for (i,row) in items.enumerated() {
            guard let id=row["id"] as? String,id=="E-\(i+1)",
                  let name=row["name"] as? String,!name.isEmpty,
                  row["donated"] as? Bool == false else{
                throw N2InventoryError.unrecognizedMaterial
            }
            found[id]=name
        }
        return found
    }
    /// Explicit verification of a legacy lot's original location. Never a transfer,
    /// count adjustment, or inferred assignment. Existing quantities and ledger stay exact.
    public static func verifyOriginalSite(snapshot:Data,eventID:String,lotID:String,
        site:String,reason:String,operatorName:String,at:Int64)throws->Data {
        guard !eventID.isEmpty,eventID.count<=200,at>0,at<=9_007_199_254_740_991,
              ["LA VENTUROSA","PLVENTUROSA"].contains(site),
              (8...250).contains(reason.trimmingCharacters(in:.whitespacesAndNewlines).count),
              (3...200).contains(operatorName.trimmingCharacters(in:.whitespacesAndNewlines).count)
        else{throw N2InventoryError.insufficientEvidence}
        var state=try root(snapshot)
        var events=state["nativeStockSiteVerifications"] as? [[String:Any]] ?? []
        let event:[String:Any]=["id":eventID,"lotId":lotID,"site":site,"reason":reason,
                                "operatorName":operatorName,"at":at,"scope":"original-location"]
        if let previous=events.first(where:{$0["id"] as? String==eventID}) {
            guard try JSONSerialization.data(withJSONObject:previous,options:[.sortedKeys]) == JSONSerialization.data(withJSONObject:event,options:[.sortedKeys]) else{throw N2InventoryError.duplicatedMovement}
            return snapshot
        }
        let sites=try N2StockSiteEvidence.resolve(state)
        guard events.count<10000,let lots=state["stockLots"] as? [[String:Any]],
              let lot=lots.first(where:{$0["id"] as? String==lotID}),
              sites[lotID]==nil,(lot["site"] as? String ?? "").isEmpty,
              validLot(lot) else{throw N2InventoryError.invalidLot}
        // Ledger before/after snapshots are canonical and immutable. Keep the
        // original lot byte-for-byte and attach location evidence separately.
        events.append(event);state["nativeStockSiteVerifications"]=events
        return try done(state)
    }

    public static func registerLot(snapshot:Data,lot:Data,
                                   catalogData:Data)throws->Data {
        var state=try root(snapshot)
        let official=try catalog(catalogData)
        guard var lots=state["stockLots"] as? [[String:Any]],
              let item=try? JSONSerialization.jsonObject(with:lot) as? [String:Any],
              validLot(item),let id=item["id"] as? String,
              let code=item["code"] as? String,
              item["name"] as? String == official[code],
              lots.count<500 else {throw N2InventoryError.invalidLot}
        guard !lots.contains(where:{$0["id"] as? String == id}) else {
            throw N2InventoryError.duplicateLot
        }
        lots.append(item)
        state["stockLots"]=lots
        return try done(state)
    }
    /// Only unused lots can have their label/expiry corrected in place.
    /// Any lot with previous movements requires a separate audited inventory
    /// action; never rewrite immutable before/after snapshots.
    public static func correctUnusedLot(snapshot:Data,lotID:String,
        reference:String,expires:String,reason:String,operatorName:String,
        at:Int64)throws->Data {
        let ref=reference.trimmingCharacters(in:.whitespacesAndNewlines)
        let why=reason.trimmingCharacters(in:.whitespacesAndNewlines)
        let op=operatorName.trimmingCharacters(in:.whitespacesAndNewlines)
        guard !lotID.isEmpty,(1...120).contains(ref.utf8.count),
              (8...250).contains(why.utf8.count),
              (3...120).contains(op.utf8.count),at>0,
              expires.isEmpty || (
                 expires.range(of:#"^\d{4}-\d{2}-\d{2}$"#,
                     options:.regularExpression) != nil &&
                 ISO8601DateFormatter().date(from:expires+"T12:00:00Z") != nil
              ) else{throw N2InventoryError.insufficientEvidence}
        var root=try self.root(snapshot)
        guard var lots=root["stockLots"] as? [[String:Any]],
              let movements=root["stockMovements"] as? [[String:Any]],
              let idx=lots.firstIndex(where:{$0["id"] as? String==lotID}),
              !movements.contains(where:{$0["lotId"] as? String==lotID}),
              validLot(lots[idx]) else{
            throw N2InventoryError.invalidLot
        }
        var current=lots[idx]
        let oldRef=current["lot"] as? String ?? ""
        let oldExpiry=current["expires"] as? String ?? ""
        guard oldRef != ref || oldExpiry != expires else{
            throw N2InventoryError.invalidMovement
        }
        current["lot"]=ref
        current["expires"]=expires
        guard validLot(current) else{throw N2InventoryError.invalidLot}
        var events=root["nativeLotMetadataCorrections"] as? [[String:Any]] ?? []
        guard events.count<10000 else{throw N2InventoryError.limitReached}
        events.append([
            "id":UUID().uuidString,"lotId":lotID,"at":at,
            "operator":op,"reason":why,
            "oldReference":oldRef,"newReference":ref,
            "oldExpires":oldExpiry,"newExpires":expires,
            "scope":"metadata-only-no-stock-debit"
        ])
        lots[idx]=current
        root["stockLots"]=lots
        root["nativeLotMetadataCorrections"]=events
        return try done(root)
    }

    public static func extraordinary(snapshot:Data,movementID:String,
                                     lotID:String,at:Int64,
                                     sealedAdded:Int,looseAdded:Double,
                                     reason:String)throws->Data {
        guard sealedAdded>=0,sealedAdded<=10_000_000,
              looseAdded>=0,looseAdded.isFinite,looseAdded<=10_000_000,
              sealedAdded>0 || looseAdded>0 else {
            throw N2InventoryError.invalidMovement
        }
        return try record(snapshot:snapshot,id:movementID,lotID:lotID,
                          at:at,reason:reason,kind:"extraordinary",
                          sealed:sealedAdded,loose:looseAdded,opened:0)
    }
    public static func adjustment(snapshot:Data,movementID:String,lotID:String,
                                  at:Int64,newSealed:Int,newLoose:Double,
                                  newOpened:Double,reason:String)throws->Data {
        guard newSealed>=0,newSealed<=10_000_000,newLoose>=0,
              newLoose<=10_000_000,newLoose.isFinite,
              newOpened>=0,newOpened<=10_000_000,newOpened.isFinite else{
            throw N2InventoryError.invalidMovement
        }
        return try record(snapshot:snapshot,id:movementID,lotID:lotID,
                          at:at,reason:reason,kind:"adjustment",
                          sealed:newSealed,loose:newLoose,opened:newOpened)
    }
    private static func record(snapshot:Data,id:String,lotID:String,
                               at:Int64,reason:String,kind:String,
                               sealed:Int,loose:Double,opened:Double)throws->Data {
        guard !id.isEmpty,id.utf8.count<=200,at>0,
              at<=9_007_199_254_740_991,
              reason.trimmingCharacters(in:.whitespaces).count>=8,
              reason.count<=250 else{throw N2InventoryError.insufficientEvidence}
        var state=try root(snapshot)
        guard var lots=state["stockLots"] as? [[String:Any]],
              var movements=state["stockMovements"] as? [[String:Any]],
              let idx=lots.firstIndex(where:{$0["id"] as? String == lotID})
        else{throw N2InventoryError.invalidLot}
        if let previous=movements.first(where:{$0["id"] as? String == id}) {
            guard previous["lotId"] as? String == lotID,
                  previous["kind"] as? String == kind,
                  num(previous["at"])==Double(at),
                  previous["description"] as? String == reason,
                  (kind=="extraordinary"
                    ? num(previous["sealedAdded"])==Double(sealed) &&
                      num(previous["looseAdded"])==loose
                    : num((previous["after"] as? [String:Any])?["sealedContainers"])==Double(sealed) &&
                      num((previous["after"] as? [String:Any])?["looseUnits"])==loose &&
                      num((previous["after"] as? [String:Any])?["openedRemaining"])==opened)
            else{throw N2InventoryError.duplicatedMovement}
            return snapshot
        }
        guard movements.count<1000 else{throw N2InventoryError.limitReached}
        let before=lots[idx]
        guard validLot(before) else{throw N2InventoryError.invalidLot}
        var after=before
        let quantity:Double,delta:Double
        if kind=="extraordinary" {
            after["sealedContainers"]=Int(num(before["sealedContainers"])!)+sealed
            after["looseUnits"]=triple((num(before["looseUnits"]) ?? 0)+loose)
            quantity=triple(Double(sealed)*(num(before["unitsPerContainer"]) ?? 0)+loose)
            guard positive(quantity) else {throw N2InventoryError.invalidMovement}
        }else {
            guard opened<=(num(before["unitsPerContainer"]) ?? 0),
                  num(before["sealedContainers"]) != Double(sealed) ||
                  num(before["looseUnits"]) != loose ||
                  num(before["openedRemaining"]) != opened else{
                throw N2InventoryError.invalidMovement
            }
            after["sealedContainers"]=sealed
            after["looseUnits"]=loose
            after["openedRemaining"]=opened
            quantity=0
        }
        after["updatedAt"]=at
        guard validLot(after) else{throw N2InventoryError.invalidLot}
        delta=triple(balance(after)-balance(before))
        if kind=="extraordinary" && delta<=0{
            throw N2InventoryError.invalidMovement
        }
        if kind=="adjustment" && delta==0{
            throw N2InventoryError.invalidMovement
        }
        let m:[String:Any]=[
            "id":id,"lotId":lotID,"code":before["code"]!,
            "name":before["name"]!,"unit":before["catalogUnit"]!,
            "at":at,"kind":kind,"description":reason,
            "quantity":quantity,
            "sealedAdded":kind=="extraordinary" ? sealed:0,
            "looseAdded":kind=="extraordinary" ? loose:0,
            "openedNewContainer":false,"excelQuantity":0,
            "physicalChange":delta,"before":before,"after":after
        ]
        lots[idx]=after
        movements.append(m)
        state["stockLots"]=lots
        state["stockMovements"]=movements
        return try done(state)
    }
}


/// Effective original site is derived from explicit, validated evidence. It never
/// edits legacy lot snapshots or rewrites their historical movement chain.
enum N2StockSiteEvidence {
    static func resolve(_ root:[String:Any])throws->[String:String] {
        guard let lots=root["stockLots"] as? [[String:Any]] else{throw N2InventoryError.invalidSnapshot}
        let known=["LA VENTUROSA","PLVENTUROSA"]
        var sites=[String:String]()
        for lot in lots {
            if let id=lot["id"] as? String,let site=lot["site"] as? String,known.contains(site) {sites[id]=site}
        }
        guard let raw=root["nativeStockSiteVerifications"] else{return sites}
        guard let events=raw as? [[String:Any]],events.count<=10000 else{throw N2InventoryError.invalidSnapshot}
        var ids=Set<String>()
        for event in events {
            guard let id=event["id"] as? String,!id.isEmpty,ids.insert(id).inserted,
                  let lotID=event["lotId"] as? String,
                  let lot=lots.first(where:{$0["id"] as? String==lotID}),
                  (lot["site"] as? String ?? "").isEmpty,sites[lotID]==nil,
                  let site=event["site"] as? String,known.contains(site),
                  event["scope"] as? String=="original-location",
                  let reason=event["reason"] as? String,(8...250).contains(reason.trimmingCharacters(in:.whitespacesAndNewlines).count),
                  let op=event["operatorName"] as? String,(3...200).contains(op.trimmingCharacters(in:.whitespacesAndNewlines).count),
                  let at=event["at"] as? NSNumber,CFGetTypeID(at) != CFBooleanGetTypeID(),
                  at.doubleValue>0,at.doubleValue<=9_007_199_254_740_991,at.doubleValue.rounded()==at.doubleValue
            else{throw N2InventoryError.invalidSnapshot}
            sites[lotID]=site
        }
        return sites
    }
}
