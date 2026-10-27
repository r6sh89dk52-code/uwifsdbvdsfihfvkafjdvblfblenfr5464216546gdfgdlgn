import Foundation
import XCTest
@testable import DanperCore

final class N2SimpleInventoryTests:XCTestCase {
    private let password="FICTICIO-Respaldo-Seguro-2026"
    private let regimeID="7D4F6357-162A-411E-99B9-E071963E3221"
    private func fixture(_ name:String)throws->Data {
        let folder=try XCTUnwrap(ProcessInfo.processInfo.environment["DANPER_N1_FIXTURE_DIR"])
        return try Data(contentsOf:URL(fileURLWithPath:folder).appendingPathComponent(name))
    }
    private func object(_ data:Data)throws->[String:Any] {try N2SimpleInventory.object(data)}
    private func bytes(_ object:[String:Any])throws->Data {try N2SimpleInventory.bytes(object)}
    private func at(_ day:String="2026-11-15",_ hour:String="18:00:00")->Int64 {
        Int64(ISO8601DateFormatter().date(from:day+"T"+hour+"Z")!.timeIntervalSince1970*1000)
    }
    private func catalog()throws->N2NativeCatalogIndex {
        let p=try object(fixture("n1s-indicator-plan.json")),n=try object(fixture("n2-nursing-parity.json"))
        return try N2NativeCatalogLoader.load(products:JSONSerialization.data(withJSONObject:p["catalog"]!),
            nursing:JSONSerialization.data(withJSONObject:n["catalog"]!),approvedMappings:fixture("n2-reviewed-approved.json"))
    }
    private func source(empty:Bool=false)throws->Data {
        if !empty {return try fixture("n1e-clinical-stock.json")}
        var root=try object(fixture("n1e-clinical-stock.json"))
        root["attentions"]=[Any]();root["stockLots"]=[Any]();root["stockMovements"]=[Any]()
        root["deliveryIncidents"]=[Any]();return try bytes(root)
    }
    private func product(_ code:String="16000182",quantity:Double=70)throws->N2SimpleProduct {
        let p=try XCTUnwrap(catalog().clinical.first{$0.code==code})
        return N2SimpleProduct(code:p.code,name:p.name,unit:p.unit,
            mode:N2SimpleInventory.suggestedMode(unit:p.unit) ?? .units,
            quantity:quantity,expiry:"2027-02-10",expiryVerified:true)
    }
    private func proof(_ raw:Data)throws->N2VerifiedInventoryBackup {
        try N2InventoryBackupCodec.verify(archive:N2InventoryBackupCodec.createVerified(snapshot:raw,password:password),password:password)
    }
    private func activation(products:[N2SimpleProduct],confirmed:Bool=true,available:Bool=true)->N2SimpleActivation {
        N2SimpleActivation(id:regimeID,at:at(),operatorName:"OPERADOR FICTICIO",confirmed:confirmed,
            backupAvailable:available,initialProducts:products)
    }
    private func active(source raw:Data?=nil,quantity:Double=70)throws->Data {
        let original=try raw ?? source()
        return try N2SimpleInventory.activate(snapshot:original,backup:proof(original),
            request:activation(products:[product(quantity:quantity),product("16000025",quantity:12)]),catalog:catalog())
    }
    private func visit(_ raw:Data,id:String="SIMPLE-FICTICIO",code:String="16000182",quantity:Int=2,
                       r:Int?=nil,day:String="2026-11-16")throws->Data {
        let root=try object(raw),worker=try XCTUnwrap((root["workers"] as? [[String:Any]])?.first),p=try product(code)
        var item:[String:Any]=["id":"linea-ficticia","code":p.code,"name":p.name,"unit":p.unit,
            "quantity":quantity,"procedure":"PROCEDIMIENTO FICTICIO"]
        if let r {item["simpleR"]=r}
        return try bytes(["id":id,"status":"saved","worker":worker,"date":day,"time":"13:00",
            "diagnosis":"DIAGNÓSTICO FICTICIO","category":"ENFERMEDAD","system":"RESPIRATORIO",
            "responsible":"OPERADOR FICTICIO","responsibleDni":"00000031","items":[item]])
    }
    private func command(_ kind:N2SimpleInventoryCommand.Operation,code:String="16000182",quantity:Double=0,
                         id:String=UUID().uuidString,time:Int64?=nil,expiry:String?=nil,
                         verified:Bool?=nil,incident:String?=nil,r:Int?=nil)->N2SimpleInventoryCommand {
        N2SimpleInventoryCommand(id:id,operation:kind,code:code,quantity:quantity,at:time ?? at("2026-11-17"),
            operatorName:"OPERADOR FICTICIO",reason:"Operación ficticia verificada",expiry:expiry,
            expiryVerified:verified,incidentID:incident,declaredR:r)
    }
    func testActivationPreservesEveryClinicalDictionaryAndRetiresOldOperations()throws {
        let old=try source(),next=try active(),a=try object(old),b=try object(next)
        for key in ["workers","attentions","allergies","catalogMappings","ambulatoryReconciliation"] {
            XCTAssertEqual(try JSONSerialization.data(withJSONObject:a[key]!,options:.sortedKeys),
                           try JSONSerialization.data(withJSONObject:b[key]!,options:.sortedKeys),key)
        }
        XCTAssertTrue((b["stockLots"] as! [Any]).isEmpty)
        XCTAssertTrue((b["stockMovements"] as! [Any]).isEmpty)
        XCTAssertEqual(try N2SimpleInventory.read(next).products.first?.quantity,70)
        XCTAssertEqual(try N2SimpleInventory.read(next).incidents.count,0)
        XCTAssertEqual(try N2VersionedSnapshotAudit.inspect(next).pendingClinicalItems,0)
    }
    func testActivationRequiresVerifiedMatchingBackupAndExplicitAvailabilityAndConsent()throws {
        let raw=try source(),backup=try proof(raw),products=try [product()]
        for request in [activation(products:products,confirmed:false),activation(products:products,available:false)] {
            XCTAssertThrowsError(try N2SimpleInventory.activate(snapshot:raw,backup:backup,request:request,catalog:catalog()))
        }
        XCTAssertThrowsError(try N2SimpleInventory.activate(snapshot:source(empty:true),backup:backup,
            request:activation(products:products),catalog:catalog()))
        XCTAssertEqual(try N1eLegacyClinicalAudit.inspect(raw).sourceSHA256,
                       try N1eLegacyClinicalAudit.inspect(source()).sourceSHA256)
    }
    func testActivationIsIdempotentButCannotRestartOrChangeInitialCount()throws {
        let raw=try source(),backup=try proof(raw),request=try activation(products:[product()])
        let next=try N2SimpleInventory.activate(snapshot:raw,backup:backup,request:request,catalog:catalog())
        XCTAssertEqual(try N2SimpleInventory.activate(snapshot:next,backup:backup,request:request,catalog:catalog()),next)
        XCTAssertThrowsError(try N2SimpleInventory.activate(snapshot:next,backup:backup,
            request:activation(products:[product(quantity:99)]),catalog:catalog()))
        XCTAssertThrowsError(try N2SimpleInventory.activate(snapshot:next,backup:backup,
            request:N2SimpleActivation(at:at(),operatorName:"OPERADOR FICTICIO",confirmed:true,
                backupAvailable:true,initialProducts:[]),catalog:catalog()))
    }
    func testUnitsDeductExactlyOnceAndRetriedVisitDoesNotDuplicate()throws {
        let raw=try active(),v=try visit(raw)
        let saved=try N2SimpleInventory.saveVisit(snapshot:raw,visit:v,at:at("2026-11-16"))
        XCTAssertEqual(try N2SimpleInventory.read(saved.snapshot).products.first?.quantity,68)
        XCTAssertEqual(saved.physicalMovementsAdded,1)
        XCTAssertEqual(try N2SimpleInventory.saveVisit(snapshot:saved.snapshot,visit:v,at:at("2026-11-16")).snapshot,saved.snapshot)
        var changed=try object(v);changed["diagnosis"]="OTRO DIAGNÓSTICO FICTICIO"
        XCTAssertThrowsError(try N2SimpleInventory.saveVisit(snapshot:saved.snapshot,visit:bytes(changed),at:at("2026-11-16")))
    }
    func testManualR1AndR0DoNotTrackInternalVolumesOrCloseContainers()throws {
        let raw=try active(),first=try N2SimpleInventory.saveVisit(snapshot:raw,
            visit:visit(raw,id:"FCO-1",code:"16000025",quantity:10,r:1),at:at("2026-11-16"))
        let second=try N2SimpleInventory.saveVisit(snapshot:first.snapshot,
            visit:visit(first.snapshot,id:"FCO-0",code:"16000025",quantity:300,r:0),at:at("2026-11-16","19:00:00"))
        let s=try N2SimpleInventory.read(second.snapshot)
        XCTAssertEqual(s.products.first{$0.code=="16000025"}?.quantity,11)
        XCTAssertEqual(s.movements.filter{$0.visitID != nil}.compactMap(\.declaredR),[1,0])
        XCTAssertTrue((try object(second.snapshot)["stockLots"] as! [Any]).isEmpty)
        XCTAssertEqual(s.movements.filter{$0.kind=="containerState"}.count,0)
    }
    func testUnknownCatalogUnitRequiresExplicitPresentationModeWithoutConversion()throws {
        let old=try source(),backup=try proof(old)
        var p=try product("16000019",quantity:12)
        XCTAssertNil(N2SimpleInventory.suggestedMode(unit:p.unit))
        XCTAssertEqual(p.unit,"LT")
        p.mode = .presentation
        let raw=try N2SimpleInventory.activate(snapshot:old,backup:backup,
            request:activation(products:[p]),catalog:catalog())
        let saved=try N2SimpleInventory.saveVisit(snapshot:raw,
            visit:visit(raw,code:"16000019",quantity:300,r:1),at:at("2026-11-16"))
        XCTAssertEqual(try N2SimpleInventory.read(saved.snapshot).products.first?.quantity,11)
        XCTAssertEqual(try N2SimpleInventory.read(saved.snapshot).products.first?.unit,"LT")
    }
    func testMissingRPreservesClinicalVisitAndCreatesOnlySeparateIncident()throws {
        let raw=try active(),result=try N2SimpleInventory.saveVisit(snapshot:raw,
            visit:visit(raw,code:"16000025"),at:at("2026-11-16"))
        let state=try N2SimpleInventory.read(result.snapshot)
        XCTAssertEqual(result.pending,1);XCTAssertEqual(result.physicalMovementsAdded,0)
        XCTAssertEqual(state.products.first{$0.code=="16000025"}?.quantity,12)
        XCTAssertEqual(state.incidents.count,1)
        XCTAssertEqual((try object(result.snapshot)["attentions"] as! [Any]).count,
                       (try object(raw)["attentions"] as! [Any]).count+1)
    }
    func testInsufficientStockThenReceiptCanResolveExactlyOnce()throws {
        let raw=try active(),saved=try N2SimpleInventory.saveVisit(snapshot:raw,
            visit:visit(raw,quantity:90),at:at("2026-11-16"))
        let received=try N2SimpleInventory.apply(command(.receipt,quantity:30),to:saved.snapshot,catalog:catalog())
        let incident=try XCTUnwrap(N2SimpleInventory.read(received).incidents.first)
        let resolve=command(.resolveIncident,id:"RESOLVER-UNA-VEZ",time:at("2026-11-18"),incident:incident.id)
        let resolved=try N2SimpleInventory.apply(resolve,to:received,catalog:catalog())
        XCTAssertEqual(try N2SimpleInventory.read(resolved).products.first?.quantity,10)
        XCTAssertEqual(try N2SimpleInventory.apply(resolve,to:resolved,catalog:catalog()),resolved)
        XCTAssertEqual(try N2SimpleInventory.audit(resolved).pendingClinicalItems,0)
    }
    func testLaterAuthoritativeCountCoversOlderIncidentWithoutAnotherDebit()throws {
        let raw=try active(),saved=try N2SimpleInventory.saveVisit(snapshot:raw,
            visit:visit(raw,quantity:90),at:at("2026-11-16"))
        let counted=try N2SimpleInventory.apply(command(.count,quantity:80),to:saved.snapshot,catalog:catalog())
        let incident=try XCTUnwrap(N2SimpleInventory.read(counted).incidents.first)
        let resolved=try N2SimpleInventory.apply(command(.resolveIncident,time:at("2026-11-18"),incident:incident.id),to:counted,catalog:catalog())
        XCTAssertEqual(try N2SimpleInventory.read(resolved).products.first?.quantity,80)
        XCTAssertEqual(try N2SimpleInventory.read(resolved).movements.count,try N2SimpleInventory.read(counted).movements.count)
        XCTAssertEqual(try N2SimpleInventory.audit(resolved).pendingClinicalItems,0)
    }
    func testExpiryReferenceChangeDoesNotChangeStockOrMovements()throws {
        let raw=try active(),s=try N2SimpleInventory.read(raw)
        let next=try N2SimpleInventory.apply(command(.expiry,expiry:"2028-03-12",verified:true),to:raw,catalog:catalog())
        let after=try N2SimpleInventory.read(next)
        XCTAssertEqual(after.products.first?.quantity,s.products.first?.quantity)
        XCTAssertEqual(after.movements,s.movements)
        XCTAssertEqual(after.products.first?.expiry,"2028-03-12")
        XCTAssertThrowsError(try N2SimpleInventory.apply(command(.expiry,expiry:"2027-02-30",verified:true),to:raw,catalog:catalog()))
    }
    func testNegativeOutflowAndChangedEventReplayFailWithoutMutation()throws {
        let raw=try active()
        XCTAssertThrowsError(try N2SimpleInventory.apply(command(.outflow,quantity:71),to:raw,catalog:catalog()))
        let next=try N2SimpleInventory.apply(command(.receipt,quantity:2,id:"EVENTO"),to:raw,catalog:catalog())
        XCTAssertThrowsError(try N2SimpleInventory.apply(command(.receipt,quantity:3,id:"EVENTO"),to:next,catalog:catalog()))
        XCTAssertEqual(try N2SimpleInventory.read(next).products.first?.quantity,72)
    }
    func testHistoricalVisitBeforeCountIsNotDebitedAgain()throws {
        let raw=try active(),saved=try N2SimpleInventory.saveVisit(snapshot:raw,
            visit:visit(raw,day:"2026-11-10"),at:at("2026-11-16"))
        XCTAssertEqual(try N2SimpleInventory.read(saved.snapshot).products.first?.quantity,70)
        XCTAssertEqual(saved.pending,1);XCTAssertEqual(saved.physicalMovementsAdded,0)
    }
    func testSelectiveRestoreKeepsNewInventoryAndDeduplicatesClinicalRecords()throws {
        let old=try source(),raw=try active(source:source(empty:true)),backup=try proof(old)
        let restored=try N2SimpleInventory.restoreClinical(snapshot:raw,backup:backup,eventID:"IMPORTACION-FICTICIA",
            operatorName:"OPERADOR FICTICIO",at:at("2026-11-16"),confirmed:true)
        let before=try N2SimpleInventory.read(raw),after=try N2SimpleInventory.read(restored)
        XCTAssertEqual(before.products,after.products);XCTAssertEqual(before.movements,after.movements)
        XCTAssertEqual(after.incidents.count,0)
        XCTAssertEqual((try object(restored)["attentions"] as! [Any]).count,(try object(old)["attentions"] as! [Any]).count)
        XCTAssertTrue((try object(restored)["stockMovements"] as! [Any]).isEmpty)
        XCTAssertEqual(try N2SimpleInventory.restoreClinical(snapshot:restored,backup:backup,eventID:"OTRA-SOLICITUD",
            operatorName:"OPERADOR FICTICIO",at:at("2026-11-17"),confirmed:true),restored)
    }
    func testCorruptArchiveAndWrongPasswordDoNotYieldMigrationProof()throws {
        let archive=try N2InventoryBackupCodec.createVerified(snapshot:source(),password:password)
        XCTAssertThrowsError(try N2InventoryBackupCodec.verify(archive:archive,password:"OTRA-CLAVE-FICTICIA-2026"))
        var root=try object(archive);var ciphertext=Data(base64Encoded:root["data"] as! String)!
        ciphertext[0] ^= 1;root["data"]=ciphertext.base64EncodedString()
        XCTAssertThrowsError(try N2InventoryBackupCodec.verify(archive:bytes(root),password:password))
    }
    func testV2ArchiveRoundTripIsExplicitlyUnsupportedByOldV1Reader()throws {
        let raw=try active(),archive=try N2InventoryBackupCodec.createVerified(snapshot:raw,password:password)
        let verified=try N2InventoryBackupCodec.verify(archive:archive,password:password)
        XCTAssertEqual(verified.schemaVersion,2)
        XCTAssertEqual(verified.sourceSHA256,try N2SimpleInventory.fingerprint(raw))
        XCTAssertThrowsError(try N1PortableArchiveReader.inspect(archive:archive,password:password))
    }
    func testStrictV2AuditRejectsReactivatedLotsForgedBalanceAndExpiryWithoutHistory()throws {
        let raw=try active()
        var r=try object(raw);r["stockLots"]=try object(source())["stockLots"]!
        XCTAssertThrowsError(try N2VersionedSnapshotAudit.inspect(bytes(r)))
        r=try object(raw);var s=try N2SimpleInventory.read(raw);s.products[0].quantity=999
        r["simpleInventory"]=try JSONSerialization.jsonObject(with:JSONEncoder().encode(s))
        XCTAssertThrowsError(try N2VersionedSnapshotAudit.inspect(bytes(r)))
        s=try N2SimpleInventory.read(raw);s.products[0].expiry="2030-01-01"
        r["simpleInventory"]=try JSONSerialization.jsonObject(with:JSONEncoder().encode(s))
        XCTAssertThrowsError(try N2VersionedSnapshotAudit.inspect(bytes(r)))
        r=try object(raw);r["inventorySchemaVersion"]=3
        XCTAssertThrowsError(try N2VersionedSnapshotAudit.inspect(bytes(r)))
    }
    func testEncryptedJournalMigrationInterruptionRecoversOriginalThenCommitsV2()throws {
        let dir=FileManager.default.temporaryDirectory.appendingPathComponent("danper-n2-synthetic-"+UUID().uuidString)
        defer{try? FileManager.default.removeItem(at:dir)}
        let secret=Data(repeating:33,count:32),journal=try N2EncryptedClinicalJournal(directory:dir,secret:secret)
        let old=try source(),next=try active(source:old)
        _=try journal.commit(old,expectedRevision:0)
        XCTAssertThrowsError(try journal.commit(next,expectedRevision:1,fault:{point in
            if point == .pendingJournalWritten {throw N2EncryptedClinicalJournal.Failure.interrupted}
        }))
        XCTAssertEqual(try journal.recover()?.snapshot,old)
        _=try journal.commit(next,expectedRevision:1)
        let recovered=try N2EncryptedClinicalJournal(directory:dir,secret:secret).recover()
        XCTAssertEqual(recovered?.revision,2);XCTAssertEqual(recovered?.snapshot,next)
        XCTAssertEqual(try N2SimpleInventory.read(XCTUnwrap(recovered).snapshot).products.first?.quantity,70)
    }
}
