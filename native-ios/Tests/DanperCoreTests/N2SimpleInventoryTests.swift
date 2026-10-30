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
        for key in ["workers","attentions","allergies","catalogMappings"] {
            XCTAssertEqual(try JSONSerialization.data(withJSONObject:a[key]!,options:.sortedKeys),
                           try JSONSerialization.data(withJSONObject:b[key]!,options:.sortedKeys),key)
        }
        XCTAssertTrue((b["stockLots"] as! [Any]).isEmpty)
        XCTAssertTrue((b["stockMovements"] as! [Any]).isEmpty)
        XCTAssertTrue((b["ambulatoryReconciliation"] as! [Any]).isEmpty)
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
        let values=try N2VersionedSnapshotAudit.inspect(second.snapshot).consumptionR
        XCTAssertEqual(try XCTUnwrap(values.last ?? nil).sign,.plus,"R=0 nunca debe mostrarse como -0")
        XCTAssertEqual(N2SimpleInventory.round(-0.0).sign,.plus)
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
    func testNinthDayFormulaUsesVerifiedEventsAndNeverChangesCount()throws {
        let old=try source(empty:true)
        var raw=try N2SimpleInventory.activate(snapshot:old,backup:proof(old),request:N2SimpleActivation(
            id:regimeID,at:at("2026-11-08"),operatorName:"OPERADOR FICTICIO",confirmed:true,
            backupAvailable:true,initialProducts:[product(quantity:72)]),catalog:catalog())
        raw=try N2SimpleInventory.apply(command(.receipt,quantity:2,time:at("2026-11-10")),to:raw,catalog:catalog())
        raw=try N2SimpleInventory.saveVisit(snapshot:raw,visit:visit(raw,quantity:4,day:"2026-11-11"),at:at("2026-11-11")).snapshot
        raw=try N2SimpleInventory.apply(command(.count,quantity:70,time:at("2026-11-15")),to:raw,catalog:catalog())
        let original=raw,cut=try N2SimpleInventory.cutPreview(snapshot:raw,code:"16000182",through:"2026-11-15",catalog:catalog())
        XCTAssertEqual(cut.period.start,"2026-11-09");XCTAssertEqual(cut.period.end,"2026-12-08")
        XCTAssertEqual(cut.counted,70);XCTAssertEqual(cut.verifiedOutflows,4);XCTAssertEqual(cut.receipts,2)
        XCTAssertEqual(cut.estimatedOpening,72);XCTAssertEqual(cut.confirmedOpening,72)
        XCTAssertFalse(cut.requiresVerification);XCTAssertEqual(cut.currentStock,70);XCTAssertEqual(raw,original)
    }
    func testUnknownOpeningIsNeverCertifiedAndInvalidDatesFailClosed()throws {
        let raw=try active(source:source(empty:true))
        let cut=try N2SimpleInventory.cutPreview(snapshot:raw,code:"16000182",through:"2026-11-16",catalog:catalog())
        XCTAssertTrue(cut.requiresVerification);XCTAssertNil(cut.confirmedOpening);XCTAssertNil(cut.estimatedOpening)
        XCTAssertEqual(cut.currentStock,70)
        for date in ["2026-02-30","2026-13-01","2026-11-08"] {
            XCTAssertThrowsError(try N2SimpleInventory.cutPreview(snapshot:raw,code:"16000182",through:date,catalog:catalog()))
        }
    }
    func testClinicalOnlyBeforeActivationDoesNotMutateLegacyStock()throws {
        let old=try source(),before=try object(old)
        let next=try N2PreSimpleClinicalTransaction.save(snapshot:old,visit:visit(old),at:at("2026-11-16")).snapshot
        let after=try object(next)
        for key in ["stockLots","stockMovements"] {
            XCTAssertEqual(try bytes([key:before[key]!]),try bytes([key:after[key]!]))
        }
        XCTAssertEqual((after["attentions"] as? [Any])?.count,(before["attentions"] as? [Any])!.count+1)
    }
    func testNursingExportLeavesUnknownBalancesWithoutZeroFormulas()throws {
        let raw=try active(source:source(empty:true)),n=try object(fixture("n2-nursing-parity.json"))
        let result=try N2VerifiedNursingWorkbook.exportRange(snapshot:raw,catalog:JSONSerialization.data(withJSONObject:n["catalog"]!),
            template:fixture("n1s-nursing-template-store.zip"),start:"2026-11-09",end:"2026-11-16",responsible:"OPERADOR FICTICIO",mappings:fixture("n2-reviewed-approved.json"))
        XCTAssertEqual(result.stockKnownRows,0);XCTAssertEqual(result.stockUnknownRows,98)
        let entries=try N1rStoredZip.unpack(result.xlsx)
        let sheet=String(data:try XCTUnwrap(entries.first{$0.name=="xl/worksheets/sheet1.xml" || $0.name=="xl/worksheets/sheet2.xml"}).data,encoding:.utf8)!
        XCTAssertTrue(sheet.contains("NO VERIFICADO"));XCTAssertFalse(sheet.contains("<f>D7+E7</f>"))
        XCTAssertEqual(try N2SimpleInventory.read(raw).products.first?.quantity,70)
    }
    private func nursingSheet(_ raw:Data,start:String,end:String)throws->String {
        let n=try object(fixture("n2-nursing-parity.json"))
        let result=try N2VerifiedNursingWorkbook.exportRange(
            snapshot:raw,catalog:JSONSerialization.data(withJSONObject:n["catalog"]!),
            template:fixture("n1s-nursing-template-store.zip"),start:start,end:end,
            responsible:"OPERADOR FICTICIO",mappings:fixture("n2-reviewed-approved.json"))
        let entries=try N1rStoredZip.unpack(result.xlsx)
        return try XCTUnwrap(String(data:XCTUnwrap(entries.first{$0.name=="xl/worksheets/sheet2.xml"}).data,encoding:.utf8))
    }
    private func cell(_ sheet:String,_ address:String)throws->String {
        let regex=try NSRegularExpression(pattern:"<c\\b[^>]*\\br=\""+address+"\"[^>]*(?:/>|>.*?</c>)")
        let match=try XCTUnwrap(regex.firstMatch(in:sheet,range:NSRange(sheet.startIndex..<sheet.endIndex,in:sheet)))
        return String(sheet[try XCTUnwrap(Range(match.range,in:sheet))])
    }
    func testEditedHistoricalContainerRChangesCutOnlyNotPhysicalStock()throws {
        let old=try source()
        let verified=try proof(old)
        let raw=try N2SimpleInventory.activate(
            snapshot:old,backup:verified,
            request:N2SimpleActivation(
                id:regimeID,at:at("2026-10-29"),
                operatorName:"OPERADOR FICTICIO",confirmed:true,
                backupAvailable:true,initialProducts:[
                    product("16000013",quantity:5)
                ]),
            catalog:catalog())
        let prior=try N2SimpleInventory.read(raw)
        let detail=try N2ClinicalCorrections.detail(
            snapshot:raw,visitID:"planta-open")
        let med=try XCTUnwrap(detail.medications.first{$0.id=="box-2"})
        XCTAssertTrue(med.historicalOpeningEditable)
        XCTAssertEqual(med.historicalOpeningR,1)
        let before=try N2SimpleInventory.cutPreview(
            snapshot:raw,code:"16000013",through:"2026-10-29",
            catalog:catalog(),archive:verified)
        let patch=try bytes(["itemHistoricalOpenings":["box-2":0]])
        let edited=try N2ClinicalCorrections.append(
            snapshot:raw,eventID:"A40B0C2F-A1D4-42D1-AF31-A1D87DF065E9",
            visitID:"planta-open",changes:patch,
            reason:"Corrección histórica sin sustento escrito del usuario",
            operatorName:"OPERADOR FICTICIO",medicationDiscrepancy:"",
            expectedEffectiveSHA:detail.effectiveSHA256,at:at("2026-11-01"))
        XCTAssertEqual(try N2SimpleInventory.read(edited),prior,
            "A historical R override must not create any new stock movement")
        let effective=try N2ClinicalCorrections.detail(
            snapshot:edited,visitID:"planta-open")
        XCTAssertEqual(effective.medications.first(where:{$0.id=="box-2"})?.historicalOpeningR,0)
        XCTAssertFalse(try N2ClinicalCorrections.pendingDiscrepancies(edited).contains("planta-open"))
        let after=try N2SimpleInventory.cutPreview(
            snapshot:edited,code:"16000013",through:"2026-10-29",
            catalog:catalog(),archive:verified)
        XCTAssertEqual(before.currentStock,after.currentStock)
        XCTAssertEqual(after.verifiedOutflows,before.verifiedOutflows-1)
        XCTAssertNoThrow(try N2SimpleInventory.audit(edited))
        XCTAssertEqual(try N2NativeSnapshotReader.read(edited).visits.filter{$0.id=="planta-open"}.count,1)
        let oldSheet=try nursingSheet(raw,start:"2026-10-09",end:"2026-11-08")
        let newSheet=try nursingSheet(edited,start:"2026-10-09",end:"2026-11-08")
        // E-57 is row 63: the clinical R changes, while the counted final
        // balance remains 5 and the unproven opening stays NO VERIFICADO.
        XCTAssertTrue(try cell(oldSheet,"G63").contains("<v>1</v>"))
        XCTAssertTrue(try cell(newSheet,"G63").contains("<v>0</v>"))
        XCTAssertTrue(try cell(newSheet,"D63").contains("NO VERIFICADO"))
        XCTAssertTrue(try cell(newSheet,"H63").contains("<v>5</v>"))
        XCTAssertEqual(try cell(oldSheet,"H63"),try cell(newSheet,"H63"))
        XCTAssertFalse(try cell(newSheet,"H63").contains("<f>"))
        let plan=try object(fixture("n1s-indicator-plan.json"))
        for (snapshot,expectedR) in [(raw,1),(edited,0)] {
            let indicator=try N2VerifiedIndicatorWorkbook.export(snapshot:snapshot,
                products:JSONSerialization.data(withJSONObject:plan["catalog"]!),
                mappings:fixture("n2-reviewed-approved.json"),template:fixture("n1s-indicator-template-store.zip"),
                start:"2026-10-09",end:"2026-11-08",subdivision:"PLVENTUROSA",
                selectedVisitIDs:["planta-open"],allowPending:true)
            XCTAssertEqual(indicator.visits,1);XCTAssertEqual(indicator.rows,1)
            let parts=try N1rStoredZip.unpack(indicator.xlsx)
            let consumption=try XCTUnwrap(String(data:XCTUnwrap(parts.first{$0.name=="xl/worksheets/sheet5.xml"}).data,encoding:.utf8))
            XCTAssertTrue(try cell(consumption,"R2").contains("<v>\(expectedR)</v>"))
        }
        XCTAssertEqual(try N2SimpleInventory.read(edited),prior)
        let unallowed=try bytes(["itemHistoricalOpenings":["unit-5":0]])
        XCTAssertThrowsError(try N2ClinicalCorrections.append(
            snapshot:edited,eventID:"1923B0DE-1FAD-4D78-B983-909E62F31235",
            visitID:"planta-open",changes:unallowed,
            reason:"Cambio histórico de unidad no permitido",
            operatorName:"OPERADOR FICTICIO",medicationDiscrepancy:"",
            expectedEffectiveSHA:effective.effectiveSHA256,at:at("2026-11-02")))
    }

    func testNextPeriodNursingOpeningSurvivesOlderHistoricalClinicalUses()throws {
        // Historical visits occur in October. The physical count is 15 Nov.
        // It cannot prove the opening of 9 Nov, but it establishes a reliable
        // balance for a later period starting 9 Dec (without intervening moves).
        let raw=try active()
        let n=try object(fixture("n2-nursing-parity.json"))
        let template=try fixture("n1s-nursing-template-store.zip")
        let catalogData=try JSONSerialization.data(withJSONObject:n["catalog"]!)
        let mapping=try fixture("n2-reviewed-approved.json")
        let before=try N2SimpleInventory.read(raw)
        let first=try N2VerifiedNursingWorkbook.exportRange(
            snapshot:raw,catalog:catalogData,template:template,
            start:"2026-11-09",end:"2026-11-16",
            responsible:"OPERADOR FICTICIO",mappings:mapping)
        XCTAssertEqual(first.stockKnownRows,0,
            "A late-November count must not certify November 9 retroactively")
        let next=try N2VerifiedNursingWorkbook.exportRange(
            snapshot:raw,catalog:catalogData,template:template,
            start:"2026-12-09",end:"2026-12-16",
            responsible:"OPERADOR FICTICIO",mappings:mapping)
        XCTAssertGreaterThan(next.stockKnownRows,0,
            "October clinical evidence must not block verified December openings")
        XCTAssertEqual(try N2SimpleInventory.read(raw),before,
            "Export must never change physical inventory")
    }

    func testUnknownHistoricalOpeningDoesNotInventConsumptionOrOpeningInExcel()throws {
        let empty=try source(empty:true)
        let old=try N2PreSimpleClinicalTransaction.save(snapshot:empty,
            visit:visit(empty,code:"16000013",day:"2026-10-14"),at:at("2026-10-14")).snapshot
        let raw=try N2SimpleInventory.activate(snapshot:old,backup:proof(old),
            request:N2SimpleActivation(id:regimeID,at:at("2026-10-29"),
                operatorName:"OPERADOR FICTICIO",confirmed:true,backupAvailable:true,
                initialProducts:[product("16000013",quantity:5)]),catalog:catalog())
        XCTAssertNil(try N2SimpleInventory.read(raw).historicalUses.first?.verifiedR)
        let sheet=try nursingSheet(raw,start:"2026-10-09",end:"2026-11-08")
        XCTAssertTrue(try cell(sheet,"D63").contains("NO VERIFICADO"))
        XCTAssertFalse(try cell(sheet,"G63").contains("<v>"))
        XCTAssertTrue(try cell(sheet,"H63").contains("<v>5</v>"))
        XCTAssertEqual(try N2SimpleInventory.read(raw).products.first?.quantity,5)
    }

    func testNursingBalancesContinueAcrossNinthDayWithReceiptsAndOutflows()throws {
        let old=try source()
        var raw=try N2SimpleInventory.activate(snapshot:old,backup:proof(old),
            request:N2SimpleActivation(id:regimeID,at:at("2026-10-29"),
                operatorName:"OPERADOR FICTICIO",confirmed:true,backupAvailable:true,
                initialProducts:[product()]),catalog:catalog())
        raw=try N2SimpleInventory.saveVisit(snapshot:raw,
            visit:visit(raw,id:"BEFORE-CUT",quantity:3,day:"2026-12-08"),at:at("2026-12-08")).snapshot
        raw=try N2SimpleInventory.apply(command(.receipt,quantity:5,time:at("2026-12-09")),to:raw,catalog:catalog())
        raw=try N2SimpleInventory.saveVisit(snapshot:raw,
            visit:visit(raw,id:"AFTER-CUT",quantity:2,day:"2026-12-09"),at:at("2026-12-09","19:00:00")).snapshot
        let before=try N2SimpleInventory.read(raw)
        let first=try nursingSheet(raw,start:"2026-11-09",end:"2026-12-08")
        let second=try nursingSheet(raw,start:"2026-12-09",end:"2027-01-08")
        // E-22 / row 28. The 8th closes at 67; the 9th opens at 67.
        XCTAssertTrue(try cell(first,"D28").contains("<v>70</v>"))
        XCTAssertTrue(try cell(first,"G28").contains("<v>3</v>"))
        XCTAssertTrue(try cell(first,"H28").contains("<v>67</v>"))
        XCTAssertTrue(try cell(second,"D28").contains("<v>67</v>"))
        XCTAssertTrue(try cell(second,"E28").contains("<v>5</v>"))
        XCTAssertTrue(try cell(second,"G28").contains("<v>2</v>"))
        XCTAssertTrue(try cell(second,"H28").contains("<v>70</v>"))
        XCTAssertEqual(try N2SimpleInventory.read(raw),before)
    }

    func testFormDraftRecoversExplicitRWithoutAnyLegacyPhysicalSelection()throws {
        let raw=try active(source:source(empty:true)),context=try N2NativeFormContextReader.read(snapshot:raw,revision:1,products:catalog())
        XCTAssertEqual(context.inventorySchemaVersion,2)
        var draft=N2NativeFormDraft(id:"draft-r-ficticio")
        var med=N2FormMedication(code:"16000025",procedure:"CURACION DE HERIDA")
        med.simpleR=0;med.selectedLotID="NO-DEBE-SERIALIZARSE";med.physicalQuantity=99
        draft.items=[med]
        let patch=try object(draft.makeDraftPatch(context:context)),item=try XCTUnwrap((patch["items"] as? [[String:Any]])?.first)
        XCTAssertEqual(item["simpleR"] as? Int,0);XCTAssertNil(item["physicalUse"]);XCTAssertNil(item["confirmNewContainer"])
    }

    func testVaultResetRevisionAndSelectiveRestoreNeverAllowFullOverwrite()throws {
        let folder=FileManager.default.temporaryDirectory.appendingPathComponent("danper-n2-synthetic-v2-api-"+UUID().uuidString)
        defer {try? FileManager.default.removeItem(at:folder)}
        let journal=try N2EncryptedClinicalJournal(directory:folder,secret:Data(repeating:81,count:32))
        let old=try source(),verified=try proof(old)
        _=try journal.commit(old,expectedRevision:0)
        let store=N2ProtectedClinicalVaultCore(testJournal:journal,directory:folder)
        let created=try store.activateSimpleInventory(backup:verified,request:activation(products:[product()]),catalog:catalog(),expectedRevision:1)
        XCTAssertEqual(created.revision,2)
        let before=try XCTUnwrap(journal.recover()).snapshot
        XCTAssertThrowsError(try store.applySimpleInventoryCommand(command(.receipt,quantity:2),catalog:catalog(),expectedRevision:1))
        XCTAssertThrowsError(try store.recoverPortableSource(backup:verified,confirmed:true))
        XCTAssertEqual(try journal.recover()?.snapshot,before)
        let merged=try store.restoreSimpleClinical(backup:verified,eventID:UUID().uuidString,operatorName:"OPERADOR FICTICIO",at:at("2026-11-17"),confirmed:true,expectedRevision:2)
        let repeatImport=try store.restoreSimpleClinical(backup:verified,eventID:UUID().uuidString,operatorName:"OPERADOR FICTICIO",at:at("2026-11-18"),confirmed:true,expectedRevision:merged.revision)
        XCTAssertEqual(repeatImport.revision,merged.revision)
        let reopened=try XCTUnwrap(journal.recover()).snapshot
        XCTAssertEqual(try N2SimpleInventory.read(reopened).products.first?.quantity,70)
        XCTAssertEqual((try object(reopened)["attentions"] as? [Any])?.count,(try object(old)["attentions"] as? [Any])?.count)
    }
    func testEmptyTargetRecoveryRequiresConsentAndPreservesExactEncryptedPayload()throws {
        let folder=FileManager.default.temporaryDirectory.appendingPathComponent("danper-n2-synthetic-v2-recovery-"+UUID().uuidString)
        defer {try? FileManager.default.removeItem(at:folder)}
        let journal=try N2EncryptedClinicalJournal(directory:folder,secret:Data(repeating:82,count:32))
        let store=N2ProtectedClinicalVaultCore(testJournal:journal,directory:folder),old=try source(),verified=try proof(old)
        XCTAssertThrowsError(try store.recoverPortableSource(backup:verified,confirmed:false))
        XCTAssertNil(try journal.recover())
        _=try store.recoverPortableSource(backup:verified,confirmed:true)
        XCTAssertEqual(try journal.recover()?.snapshot,verified.snapshot)
        XCTAssertEqual(try N2SimpleInventory.fingerprint(XCTUnwrap(journal.recover()).snapshot),verified.sourceSHA256)
        XCTAssertThrowsError(try store.recoverPortableSource(backup:verified,confirmed:true))
    }

    func testCountCoveredConsumptionIsNotAlsoAnUnexplainedAdjustmentAndExportsVerifiedR()throws {
        let old=try source(empty:true)
        var raw=try N2SimpleInventory.activate(snapshot:old,backup:proof(old),request:N2SimpleActivation(id:regimeID,
            at:at("2026-11-08"),operatorName:"OPERADOR FICTICIO",confirmed:true,backupAvailable:true,
            initialProducts:[product(quantity:10)]),catalog:catalog())
        raw=try N2SimpleInventory.apply(command(.count,quantity:9,time:at("2026-11-11")),to:raw,catalog:catalog())
        raw=try N2SimpleInventory.saveVisit(snapshot:raw,visit:visit(raw,quantity:1,day:"2026-11-10"),at:at("2026-11-12")).snapshot
        let incident=try XCTUnwrap(N2SimpleInventory.read(raw).incidents.first)
        raw=try N2SimpleInventory.apply(command(.resolveIncident,time:at("2026-11-13"),incident:incident.id),to:raw,catalog:catalog())
        let state=try N2SimpleInventory.read(raw),cut=try N2SimpleInventory.cutPreview(snapshot:raw,code:"16000182",through:"2026-11-13",catalog:catalog())
        XCTAssertEqual(state.movements.count,2);XCTAssertEqual(state.products.first?.quantity,9)
        XCTAssertEqual(cut.verifiedOutflows,1);XCTAssertEqual(cut.netAdjustments,0);XCTAssertEqual(cut.confirmedOpening,10)
        XCTAssertEqual(try N2VersionedSnapshotAudit.inspect(raw).consumptionR,[1])
        let nursing=try object(fixture("n2-nursing-parity.json"))
        let result=try N2VerifiedNursingWorkbook.exportRange(snapshot:raw,catalog:JSONSerialization.data(withJSONObject:nursing["catalog"]!),
            template:fixture("n1s-nursing-template-store.zip"),start:"2026-11-09",end:"2026-11-13",responsible:"OPERADOR FICTICIO",mappings:fixture("n2-reviewed-approved.json"))
        XCTAssertEqual(result.stockKnownRows,1)
        let sheet=String(data:try XCTUnwrap(N1rStoredZip.unpack(result.xlsx).first{$0.name=="xl/worksheets/sheet2.xml"}).data,encoding:.utf8)!
        XCTAssertNotNil(sheet.range(of:#"<c r="G28"[^>]*><v>1</v></c>"#,options:.regularExpression))
        XCTAssertNotNil(sheet.range(of:#"<c r="J28"[^>]*><v>0</v></c>"#,options:.regularExpression))
    }
    func testAmbulatoryV2KeepsVerifiedRAndDoesNotGuessMissingPresentationR()throws {
        var raw=try active(source:source(empty:true))
        raw=try N2SimpleInventory.saveVisit(snapshot:raw,visit:visit(raw,id:"VERIFICADO",code:"16000025",r:1),at:at("2026-11-16")).snapshot
        raw=try N2SimpleInventory.saveVisit(snapshot:raw,visit:visit(raw,id:"SIN-R",code:"16000025",day:"2026-11-17"),at:at("2026-11-17")).snapshot
        let plan=try object(fixture("n1s-indicator-plan.json"))
        let result=try N2VerifiedIndicatorWorkbook.export(snapshot:raw,products:JSONSerialization.data(withJSONObject:plan["catalog"]!),
            mappings:fixture("n2-reviewed-approved.json"),template:fixture("n1s-indicator-template-store.zip"),
            start:"2026-11-09",end:"2026-12-08",subdivision:"LA VENTUROSA",selectedVisitIDs:["VERIFICADO","SIN-R"],allowPending:true)
        XCTAssertTrue(result.provisional);XCTAssertEqual(result.pendingLines,1);XCTAssertEqual(result.rows,2)
        let sheet=String(data:try XCTUnwrap(N1rStoredZip.unpack(result.xlsx).first{$0.name=="xl/worksheets/sheet5.xml"}).data,encoding:.utf8)!
        XCTAssertNotNil(sheet.range(of:#"<c r="R2"[^>]*><v>1</v></c>"#,options:.regularExpression))
        XCTAssertNotNil(sheet.range(of:#"<c r="R3"[^>]*/>"#,options:.regularExpression))
        XCTAssertEqual(try N2SimpleInventory.read(raw).products.first{$0.code=="16000025"}?.quantity,11)
    }

    func testOfficialExportsNeverLabelCalculatedStockAsPhysicalCountOrUseFutureExpiry()throws {
        let old=try source(empty:true)
        var raw=try N2SimpleInventory.activate(snapshot:old,backup:proof(old),request:N2SimpleActivation(id:regimeID,
            at:at("2026-11-08"),operatorName:"OPERADOR FICTICIO",confirmed:true,backupAvailable:true,
            initialProducts:[product(quantity:10)]),catalog:catalog())
        raw=try N2SimpleInventory.saveVisit(snapshot:raw,visit:visit(raw,quantity:1,day:"2026-11-10"),at:at("2026-11-10")).snapshot
        raw=try N2SimpleInventory.apply(command(.expiry,time:at("2026-11-18"),expiry:"2028-01-01",verified:true),to:raw,catalog:catalog())
        let nursing=try object(fixture("n2-nursing-parity.json"))
        let report=try N2VerifiedNursingWorkbook.exportRange(snapshot:raw,catalog:JSONSerialization.data(withJSONObject:nursing["catalog"]!),
            template:fixture("n1s-nursing-template-store.zip"),start:"2026-11-09",end:"2026-11-16",responsible:"OPERADOR FICTICIO",mappings:fixture("n2-reviewed-approved.json"))
        let nurseSheet=String(data:try XCTUnwrap(N1rStoredZip.unpack(report.xlsx).first{$0.name=="xl/worksheets/sheet2.xml"}).data,encoding:.utf8)!
        XCTAssertEqual(report.stockKnownRows,1)
        XCTAssertNotNil(nurseSheet.range(of:#"<c r="J28"[^>]*/>"#,options:.regularExpression),"Sin conteo no se certifica F/S=0")
        let expiry=try XCTUnwrap(DanperDatePresentation.numericExcelDate("2027-02-10"))
        XCTAssertTrue(nurseSheet.contains("<v>\(Int(expiry))</v>"))
        let plan=try object(fixture("n1s-indicator-plan.json"))
        let result=try N2VerifiedIndicatorWorkbook.export(snapshot:raw,products:JSONSerialization.data(withJSONObject:plan["catalog"]!),
            mappings:fixture("n2-reviewed-approved.json"),template:fixture("n1s-indicator-template-store.zip"),start:"2026-11-09",end:"2026-11-16",
            subdivision:"LA VENTUROSA",selectedVisitIDs:["SIMPLE-FICTICIO"],allowPending:true)
        let countSheet=String(data:try XCTUnwrap(N1rStoredZip.unpack(result.xlsx).first{$0.name=="xl/worksheets/sheet2.xml"}).data,encoding:.utf8)!
        let row=try XCTUnwrap(countSheet.components(separatedBy:"</row>").first{$0.contains("16000182")})
        XCTAssertNotNil(row.range(of:#"<c r="D[0-9]+"[^>]*/>"#,options:.regularExpression),"Saldo calculado 9 no equivale a un conteo realizado al cierre")
        XCTAssertEqual(try N2SimpleInventory.read(raw).products.first?.quantity,9)
    }

    func testOneArchiveCannotCertifyEvidenceImportedFromAnotherSource()throws {
        let old=try source(empty:true),originalProof=try proof(old)
        let importedBase=try N2SimpleInventory.activate(snapshot:old,backup:originalProof,request:N2SimpleActivation(id:UUID().uuidString,
            at:at("2026-11-08"),operatorName:"OPERADOR FICTICIO",confirmed:true,backupAvailable:true,initialProducts:[product(quantity:10)]),catalog:catalog())
        let incoming=try N2SimpleInventory.saveVisit(snapshot:importedBase,visit:visit(importedBase,quantity:1,day:"2026-11-10"),at:at("2026-11-10")).snapshot
        let importedProof=try proof(incoming)
        let current=try active(source:old)
        let restored=try N2SimpleInventory.restoreClinical(snapshot:current,backup:importedProof,eventID:UUID().uuidString,
            operatorName:"OPERADOR FICTICIO",at:at("2026-11-16"),confirmed:true)
        let cut=try N2SimpleInventory.cutPreview(snapshot:restored,code:"16000182",through:"2026-11-16",catalog:catalog(),archive:originalProof)
        XCTAssertTrue(cut.requiresVerification);XCTAssertNil(cut.estimatedOpening);XCTAssertNil(cut.confirmedOpening)
        XCTAssertEqual(cut.currentStock,70);XCTAssertEqual(try N2SimpleInventory.read(restored).products.first?.quantity,70)
    }

}
