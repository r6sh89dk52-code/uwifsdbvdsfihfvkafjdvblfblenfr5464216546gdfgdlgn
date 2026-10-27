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
    func testFastDashboardCountersMatchProjectedHistoryWithoutRosterSorting()throws {
        let source=try fixture("n1e-clinical-stock.json")
        let folder=try directory()
        let journal=try N2EncryptedClinicalJournal(directory:folder,
            secret:Data(repeating:0x77,count:32))
        _=try journal.commit(source,expectedRevision:0)
        let store=N2ProtectedClinicalVaultCore(testJournal:journal,directory:folder)
        let full=try store.readDashboard()
        let visits=try XCTUnwrap(full.history).visits
        let date="2026-10-14",weekStart="2026-10-12"
        let fast=try XCTUnwrap(store.dashboardCounters(today:date,weekStart:weekStart))
        XCTAssertEqual(fast.today,visits.filter{
            $0.status=="saved" && $0.date==date
        }.count)
        XCTAssertEqual(fast.week,visits.filter{
            $0.status=="saved" && $0.date>=weekStart && $0.date<=date
        }.count)
        XCTAssertEqual(fast.month,visits.filter{
            $0.status=="saved" && $0.date>="2026-10-01" && $0.date<=date
        }.count)
        XCTAssertEqual(fast.drafts,full.drafts.count)
        XCTAssertEqual(try journal.recover()?.snapshot,source)
    }

    func testFasterFormWorkerVisibilityMatchesOriginalIndex()throws {
        let source=try fixture("n1e-clinical-stock.json")
        let (products,nursing,mappings)=try catalogs()
        let catalog=try N2NativeCatalogLoader.load(
            products:products,nursing:nursing,approvedMappings:mappings)
        let direct=try N2NativeFormContextReader.read(
            snapshot:source,revision:7,products:catalog)
        let previous=try N2NativeSnapshotReader.read(source)
        XCTAssertEqual(direct.workers.map(\.dni),
                       previous.searchableRoster.map(\.dni))
        XCTAssertEqual(direct.workers.map(\.name),
                       previous.searchableRoster.map(\.name))
    }

    func testDashboardCountDoesNotCreateMissingClinicalSource()throws {
        let folder=try directory()
        let journal=try N2EncryptedClinicalJournal(directory:folder,
            secret:Data(repeating:0x78,count:32))
        let store=N2ProtectedClinicalVaultCore(testJournal:journal,directory:folder)
        XCTAssertNil(try store.dashboardCounters(
            today:"2026-10-25",weekStart:"2026-10-19"))
        XCTAssertNil(try journal.recover())
    }

    func testDraftListOneRevisionMatchesStrictReaderAndDeleteKeepsStock()throws {
        let original=try fixture("n1e-clinical-stock.json")
        let patch=try JSONSerialization.data(withJSONObject:[
            "worker":["dni":"00000001","name":"TRABAJADOR FICTICIO"],
            "date":"2026-10-25","time":"10:00","items":[]] as [String:Any])
        let seed=try N2SnapshotEditor.upsertDraft(
            snapshot:original,id:"DRAFT-FAST-LIST",changes:patch,
            at:1700000000000)
        let folder=try directory()
        let journal=try N2EncryptedClinicalJournal(directory:folder,
            secret:Data(repeating:0x79,count:32))
        XCTAssertEqual(try journal.commit(seed,expectedRevision:0),1)
        let store=N2ProtectedClinicalVaultCore(testJournal:journal,directory:folder)
        XCTAssertEqual(try store.currentRevision(),1)

        let strict=try N2NativeDraftRecovery.read(seed)
        let authenticated=try N2NativeDraftRecovery.readVerified(seed)
        let fast=try store.readDraftsWithRevision()
        XCTAssertEqual(fast.revision,1)
        XCTAssertEqual(fast.drafts.map(\.id),strict.map(\.id))
        XCTAssertEqual(fast.drafts.map(\.id),authenticated.map(\.id))
        XCTAssertEqual(fast.drafts.map(\.form.date),strict.map(\.form.date))
        XCTAssertTrue(fast.drafts.contains{$0.id=="DRAFT-FAST-LIST"})

        let deleted=try store.removeDraft(
            id:"DRAFT-FAST-LIST",expectedRevision:fast.revision)
        XCTAssertEqual(deleted.revision,2)
        XCTAssertEqual(try store.currentRevision(),2)
        let latest=try store.readDraftsWithRevision()
        XCTAssertEqual(latest.revision,2)
        XCTAssertFalse(latest.drafts.contains{$0.id=="DRAFT-FAST-LIST"})
        let before=try XCTUnwrap(JSONSerialization.jsonObject(
            with:original) as? [String:Any])
        let after=try XCTUnwrap(JSONSerialization.jsonObject(
            with:try XCTUnwrap(journal.recover()).snapshot) as? [String:Any])
        for collection in ["workers","stockLots","stockMovements","allergies"] {
            XCTAssertEqual(try JSONSerialization.data(
                withJSONObject:before[collection]!,options:[.sortedKeys]),
                try JSONSerialization.data(
                withJSONObject:after[collection]!,options:[.sortedKeys]))
        }
        XCTAssertThrowsError(try store.removeDraft(
            id:"fundo-unit",expectedRevision:latest.revision)) {
            XCTAssertEqual($0 as? N2SnapshotEditError,.savedIsImmutable)
        }
        XCTAssertEqual(try journal.recover()?.revision,2)
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
