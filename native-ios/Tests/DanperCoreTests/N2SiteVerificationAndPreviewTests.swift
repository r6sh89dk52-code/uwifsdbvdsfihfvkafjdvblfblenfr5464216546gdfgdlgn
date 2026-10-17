import Foundation
import XCTest
@testable import DanperCore

final class N2SiteVerificationAndPreviewTests:XCTestCase {
    private func fixture(_ name:String)throws->Data {
        let dir=try XCTUnwrap(ProcessInfo.processInfo.environment["DANPER_N1_FIXTURE_DIR"])
        return try Data(contentsOf:URL(fileURLWithPath:dir).appendingPathComponent(name))
    }
    private func dict(_ data:Data)throws->[String:Any] {try XCTUnwrap(JSONSerialization.jsonObject(with:data) as? [String:Any])}
    private func bytes(_ value:Any)throws->Data {try JSONSerialization.data(withJSONObject:value,options:[.sortedKeys])}
    private let at:Int64=1_791_999_600_000 // 14/10/2026 in Lima
    private func sourceAndVisit()throws->(Data,Data) {
        let source=try fixture("n1e-clinical-stock.json")
        let root=try dict(source)
        var visit=try XCTUnwrap((root["attentions"] as? [[String:Any]])?.first{$0["id"] as? String=="fundo-unit"})
        visit["id"]="PREVIEW-FICTICIO"
        var items=visit["items"] as! [[String:Any]]
        items[0]["id"]="PREVIEW-ITEM";items[0]["quantity"]=1
        visit["items"]=items
        return (source,try bytes(visit))
    }
    func testExplicitSiteVerificationPreservesAllQuantitiesClinicalDataAndMovements()throws {
        let source=try fixture("n1e-clinical-stock.json"),before=try dict(source)
        let lots=before["stockLots"] as! [[String:Any]],id=lots[0]["id"] as! String
        let result=try N2NativeInventoryCommands.verifyOriginalSite(snapshot:source,eventID:"VERIFY-1",lotID:id,
            site:"LA VENTUROSA",reason:"Ubicación original verificada con conteo ficticio",operatorName:"OPERADOR FICTICIO",at:at)
        let after=try dict(result)
        for key in ["workers","attentions","allergies","stockMovements"] {
            XCTAssertEqual(try bytes(before[key]!),try bytes(after[key]!))
        }
        XCTAssertEqual(try bytes(lots),try bytes(after["stockLots"]!))
        XCTAssertEqual(try N2StockSiteEvidence.resolve(after)[id],"LA VENTUROSA")
        XCTAssertEqual((after["nativeStockSiteVerifications"] as? [[String:Any]])?.count,1)
        XCTAssertEqual(try N2NativeInventoryCommands.verifyOriginalSite(snapshot:result,eventID:"VERIFY-1",lotID:id,
            site:"LA VENTUROSA",reason:"Ubicación original verificada con conteo ficticio",operatorName:"OPERADOR FICTICIO",at:at),result)
        XCTAssertThrowsError(try N2NativeInventoryCommands.verifyOriginalSite(snapshot:result,eventID:"VERIFY-2",lotID:id,
            site:"PLVENTUROSA",reason:"Intento de traslado no permitido",operatorName:"OPERADOR FICTICIO",at:at))
        XCTAssertThrowsError(try N2NativeInventoryCommands.verifyOriginalSite(snapshot:result,eventID:"VERIFY-1",lotID:id,
            site:"PLVENTUROSA",reason:"Otro contenido para mismo identificador",operatorName:"OPERADOR FICTICIO",at:at))
    }
    func testUnverifiedSiteDoesNotDebitButExplicitVerificationEnablesAutomaticUse()throws {
        let (source,visitData)=try sourceAndVisit()
        var visit=try dict(visitData);visit["dispensingSite"]="LA VENTUROSA"
        let data=try bytes(visit),catalog=try fixture("n2-reviewed-approved.json")
        let blocked=try N2NativeClinicalTransaction.appendSavedVisit(snapshot:source,visit:data,approvedCatalog:catalog,at:at)
        XCTAssertEqual(blocked.pending,1);XCTAssertEqual(blocked.physicalMovementsAdded,0)
        var verified=source
        for (index,lot) in (try dict(source)["stockLots"] as! [[String:Any]]).enumerated() {
            verified=try N2NativeInventoryCommands.verifyOriginalSite(snapshot:verified,eventID:"V-\(index)",lotID:lot["id"] as! String,
                site:"LA VENTUROSA",reason:"Sede original confirmada con información ficticia",operatorName:"OPERADOR FICTICIO",at:at)
        }
        let result=try N2NativeClinicalTransaction.appendSavedVisit(snapshot:verified,visit:data,approvedCatalog:catalog,at:at)
        XCTAssertEqual(result.pending,0);XCTAssertEqual(result.linked,1);XCTAssertGreaterThan(result.physicalMovementsAdded,0)
    }
    func testPreviewNeverWritesAndPredictsActualAutomaticMovementExactly()throws {
        let (source,visit)=try sourceAndVisit(),catalog=try fixture("n2-reviewed-approved.json")
        let dir=FileManager.default.temporaryDirectory.appendingPathComponent("danper-n2-synthetic-preview-"+UUID().uuidString)
        defer{try? FileManager.default.removeItem(at:dir)}
        let journal=try N2EncryptedClinicalJournal(directory:dir,secret:Data(repeating:0x43,count:32))
        _=try N2AtomicClinicalCoordinator(journal:journal).bootstrapFromVerifiedSingleSource(source)
        let core=N2ProtectedClinicalVaultCore(testJournal:journal,directory:dir)
        let preview=try core.previewAttention(visit,approvedCatalog:catalog,at:at,expectedRevision:1)
        XCTAssertEqual(preview.pending,0);XCTAssertEqual(preview.linked,1)
        XCTAssertEqual(try core.inspect()?.revision,1)
        XCTAssertEqual(try core.sourceForEncryptedBackup(),source)
        _=try core.saveAttention(visit,approvedCatalog:catalog,at:at,expectedRevision:1)
        XCTAssertEqual(try core.sourceForEncryptedBackup(),preview.snapshot)
        let committed=try core.sourceForEncryptedBackup()
        _=try core.saveAttention(visit,approvedCatalog:catalog,at:at,expectedRevision:2)
        XCTAssertEqual(try core.sourceForEncryptedBackup(),committed)
        XCTAssertThrowsError(try core.previewAttention(visit,approvedCatalog:catalog,at:at,expectedRevision:1))
    }
}
