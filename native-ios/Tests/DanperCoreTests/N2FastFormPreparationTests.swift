import Foundation
import XCTest
@testable import DanperCore

/// Ensures the faster iOS new-attention bootstrap changes neither validation
/// nor the decrypted clinical source. Uses synthetic fixture data ONLY.
final class N2FastFormPreparationTests:XCTestCase {
    private func fixture(_ name:String)throws->Data {
        guard let dir=ProcessInfo.processInfo.environment["DANPER_N1_FIXTURE_DIR"] else {
            throw XCTSkip("Synthetic fixtures must be generated before this test")
        }
        return try Data(contentsOf:URL(fileURLWithPath:dir).appendingPathComponent(name))
    }
    private func directory()throws->URL {
        let url=FileManager.default.temporaryDirectory.appendingPathComponent(
            "danper-n2-synthetic-"+UUID().uuidString,isDirectory:true)
        try FileManager.default.createDirectory(at:url,withIntermediateDirectories:false)
        addTeardownBlock{try? FileManager.default.removeItem(at:url)}
        return url
    }
    private func catalogs()throws->(Data,Data,Data) {
        let plan=try XCTUnwrap(JSONSerialization.jsonObject(
            with:fixture("n1s-indicator-plan.json")) as? [String:Any])
        let nurse=try XCTUnwrap(JSONSerialization.jsonObject(
            with:fixture("n2-nursing-parity.json")) as? [String:Any])
        return (
            try JSONSerialization.data(withJSONObject:plan["catalog"]!),
            try JSONSerialization.data(withJSONObject:nurse["catalog"]!),
            try fixture("n2-reviewed-approved.json")
        )
    }

    func testUnifiedReadEqualsTwoOriginalAuthenticatedReads()throws {
        let source=try fixture("n1e-clinical-stock.json")
        let folder=try directory()
        let journal=try N2EncryptedClinicalJournal(directory:folder,
            secret:Data(repeating:0x74,count:32))
        XCTAssertEqual(try journal.commit(source,expectedRevision:0),1)
        let store=N2ProtectedClinicalVaultCore(testJournal:journal,directory:folder)
        let (products,nursing,mappings)=try catalogs()

        // The separate readers provide the reference behavior.
        let oldContext=try store.clinicalFormContext(
            products:products,nursing:nursing,mappings:mappings)
        let oldDrafts=try store.readDrafts()
        let prepared=try store.prepareClinicalForm(
            products:products,nursing:nursing,mappings:mappings)

        XCTAssertEqual(prepared.context.revision,oldContext.revision)
        XCTAssertEqual(prepared.context.workers,oldContext.workers)
        XCTAssertEqual(prepared.context.allergies,oldContext.allergies)
        XCTAssertEqual(prepared.context.lots,oldContext.lots)
        XCTAssertEqual(prepared.context.products.clinical.count,
                       oldContext.products.clinical.count)
        XCTAssertEqual(prepared.context.products.nursing.count,
                       oldContext.products.nursing.count)
        XCTAssertEqual(prepared.context.operationalMappings,
                       oldContext.operationalMappings)
        XCTAssertEqual(prepared.drafts.map(\.id),oldDrafts.map(\.id))
        XCTAssertEqual(try journal.recover()?.revision,1)
        XCTAssertEqual(try journal.recover()?.snapshot,source)
    }

    func testUnifiedDashboardMatchesSeparateHistoryAndDraftReads()throws {
        let source=try fixture("n1e-clinical-stock.json")
        let folder=try directory()
        let journal=try N2EncryptedClinicalJournal(directory:folder,
            secret:Data(repeating:0x76,count:32))
        _=try journal.commit(source,expectedRevision:0)
        let store=N2ProtectedClinicalVaultCore(testJournal:journal,directory:folder)
        let baseline=try XCTUnwrap(store.readIndex())
        let previousDrafts=try store.readDrafts()
        let prepared=try store.readDashboard()
        let history=try XCTUnwrap(prepared.history)
        XCTAssertEqual(history.roster,baseline.roster)
        XCTAssertEqual(history.searchableRoster,baseline.searchableRoster)
        XCTAssertEqual(history.visits,baseline.visits)
        XCTAssertEqual(history.pendingClinicalLines,baseline.pendingClinicalLines)
        XCTAssertEqual(prepared.drafts.map(\.id),previousDrafts.map(\.id))
        XCTAssertEqual(try journal.recover()?.snapshot,source)
    }
    func testUnifiedReadDoesNotCreateMissingClinicalSource()throws {
        let folder=try directory()
        let journal=try N2EncryptedClinicalJournal(directory:folder,
            secret:Data(repeating:0x75,count:32))
        let store=N2ProtectedClinicalVaultCore(testJournal:journal,directory:folder)
        let (products,nursing,mappings)=try catalogs()
        XCTAssertThrowsError(try store.prepareClinicalForm(
            products:products,nursing:nursing,mappings:mappings)) {
            XCTAssertEqual($0 as? N2ProtectedStoreError,.absentSource)
        }
        XCTAssertNil(try journal.recover())
    }
}
