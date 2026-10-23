import XCTest
@testable import DanperCore

final class N2PendingDispensingEvidenceTests:XCTestCase {
    private func source()throws->Data {
        let directory=try XCTUnwrap(ProcessInfo.processInfo.environment["DANPER_N1_FIXTURE_DIR"])
        return try Data(contentsOf:URL(fileURLWithPath:directory).appendingPathComponent("n1e-clinical-stock.json"))
    }
    private var timestamp:Int64 {Int64(ISO8601DateFormatter().date(from:"2026-10-14T18:00:00Z")!.timeIntervalSince1970*1000)}
    func testInvalidAmountsConsentAndTargetsAreRejected()throws {
        let source=try source()
        for quantity in [0,-1,Double.nan,Double.infinity,10_000_001] {
            let evidence=N2PendingDispensingEvidence(visitID:"missing",itemID:"missing",lotID:"missing",quantity:quantity,
                confirmNewContainer:true,operatorName:"OPERADOR FICTICIO",reason:"Evidencia física de prueba",at:timestamp)
            XCTAssertThrowsError(try evidence.append(snapshot:source,explicitConsent:true))
        }
        let evidence=N2PendingDispensingEvidence(visitID:"missing",itemID:"missing",lotID:"missing",quantity:1,
            confirmNewContainer:true,operatorName:"OPERADOR FICTICIO",reason:"Evidencia física de prueba",at:timestamp)
        XCTAssertThrowsError(try evidence.append(snapshot:source,explicitConsent:false))
        XCTAssertThrowsError(try evidence.append(snapshot:source,explicitConsent:true))
    }
    func testNewEvidenceCannotDebitALotRegisteredAfterTheClinicalDate()throws {
        try rejectsLaterLot(on:"2026-10-01")
        try rejectsLaterLot(on:"2026-10-14")
    }
    private func rejectsLaterLot(on clinicalDate:String)throws {
        let original=try source()
        let root=try JSONSerialization.jsonObject(with:original) as! [String:Any]
        var visit=try XCTUnwrap((root["attentions"] as! [[String:Any]]).first{$0["id"] as? String=="fundo-unit"})
        visit["id"]="historical-physical-evidence";visit["date"]=clinicalDate
        var item=(visit["items"] as! [[String:Any]])[0]
        item["physicalUse"]=["lotId":"unverified-lot","quantity":5,"confirmNewContainer":true]
        visit["items"]=[item]
        let lot=try XCTUnwrap((root["stockLots"] as! [[String:Any]]).first{$0["id"] as? String=="tablet-carton"})
        let directory=try XCTUnwrap(ProcessInfo.processInfo.environment["DANPER_N1_FIXTURE_DIR"])
        let mappings=try Data(contentsOf:URL(fileURLWithPath:directory).appendingPathComponent("n2-reviewed-approved.json"))
        let pending=try N2NativeClinicalTransaction.appendSavedVisit(snapshot:original,
            visit:JSONSerialization.data(withJSONObject:visit),approvedCatalog:mappings,at:timestamp)
        XCTAssertEqual(pending.pending,1)
        let evidence=N2PendingDispensingEvidence(visitID:"historical-physical-evidence",itemID:item["id"] as! String,
            lotID:lot["id"] as! String,quantity:(item["quantity"] as! NSNumber).doubleValue,
            confirmNewContainer:true,operatorName:"OPERADOR FICTICIO",reason:"Evidencia no permite alterar un conteo posterior",at:timestamp+1)
        let authorized=try evidence.append(snapshot:pending.snapshot,explicitConsent:true)
        let result=try N2NativeClinicalTransaction.retryCurrentSavedVisit(snapshot:authorized,
            visitID:"historical-physical-evidence",approvedCatalog:mappings,at:timestamp+1)
        XCTAssertEqual(result.pending,1);XCTAssertEqual(result.physicalMovementsAdded,0)
        let folder=FileManager.default.temporaryDirectory.appendingPathComponent("danper-n2-synthetic-pending-"+UUID().uuidString,isDirectory:true)
        defer {try? FileManager.default.removeItem(at:folder)}
        let journal=try N2EncryptedClinicalJournal(directory:folder,secret:Data(repeating:0x53,count:32))
        XCTAssertEqual(try journal.commit(pending.snapshot,expectedRevision:0),1)
        let vault=N2ProtectedClinicalVaultCore(testJournal:journal,directory:folder)
        XCTAssertEqual(try vault.confirmPendingDispensing(evidence,approvedCatalog:mappings,expectedRevision:1).revision,2)
        XCTAssertThrowsError(try vault.confirmPendingDispensing(evidence,approvedCatalog:mappings,expectedRevision:1))
        let recovered=try XCTUnwrap(journal.recover())
        XCTAssertEqual(recovered.revision,2)
        XCTAssertEqual(try N2PendingDispensingEvidence.read(snapshot:recovered.snapshot),[evidence])
        for file in try FileManager.default.contentsOfDirectory(at:folder,includingPropertiesForKeys:nil) {
            XCTAssertNil(try Data(contentsOf:file).range(of:Data(evidence.reason.utf8)))
        }
    }
}
