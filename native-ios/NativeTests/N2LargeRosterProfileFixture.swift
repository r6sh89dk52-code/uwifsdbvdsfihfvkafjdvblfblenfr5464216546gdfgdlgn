import XCTest
import Foundation
@testable import DanperCore
@testable import DANPERNative

/// Diagnostic fixture only. A workflow-created, empty Simulator DEMO is the
/// sole target. No access to the independent clinical namespace or phone data.
final class N2LargeRosterProfileFixture:XCTestCase {
    private enum Failure:Error {case simulatorRequired,existingDemo}
    private let password="SOLO-FICTICIO-Load9648-2026"
    private var baseline:URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("danper-load-physical-and-history-baseline.json")
    }
    private func requireSimulator()throws {
        #if !targetEnvironment(simulator)
        throw Failure.simulatorRequired
        #endif
    }
    func testSeed9648WorkersAnd1005VisitsInEmptyDemo() async throws {
        try requireSimulator();continueAfterFailure=false
        let vault=N2SyntheticTrialIOSVault.shared
        guard try await vault.inspect()==nil else{throw Failure.existingDemo}
        let file=try XCTUnwrap(Bundle(for:Self.self).url(forResource:"n2-synthetic-clinical",withExtension:"json",subdirectory:"SyntheticFixtures"))
        var root=try XCTUnwrap(JSONSerialization.jsonObject(with:Data(contentsOf:file)) as? [String:Any])
        var workers=try XCTUnwrap(root["workers"] as? [[String:Any]])
        XCTAssertLessThan(workers.count,9648)
        for i in (workers.count+1)...9648 {
            workers.append(["dni":String(format:"%08d",i),"name":String(format:"PERSONA FICTICIA PERF %05d",i),
              "area":"AREA FICTICIA","labor":"LABOR FICTICIA","sex":"F","age":"30","ubigeo":"","site":"LA VENTUROSA"])
        }
        root["workers"]=workers
        var visits=try XCTUnwrap(root["attentions"] as? [[String:Any]])
        let example=try XCTUnwrap(visits.first{$0["id"] as? String=="fundo-unit"})
        for i in 0..<1000 {
            var visit=example
            visit["id"]="PERF-FICTICIO-\(i)";visit["worker"]=workers[i+5]
            visit["items"]=[[String:Any]]();visit["nativeDispensing"]=[String:String]()
            visit["diagnosis"]="DIAGNOSTICO FICTICIO DE RENDIMIENTO"
            visit["standaloneProcedures"]=["OBSERVACION"]
            visits.append(visit)
        }
        root["attentions"]=visits
        let source=try JSONSerialization.data(withJSONObject:root,options:.sortedKeys)
        let report=try N2VersionedSnapshotAudit.inspect(source)
        XCTAssertEqual(report.workers,9648);XCTAssertEqual(report.attentions,1005)
        print("DANPER_LARGE_SOURCE_SHA256 "+report.sourceSHA256)
        let archive=try N2InventoryBackupCodec.createVerified(snapshot:source,password:password,domain:.demo)
        let restored=try await vault.recoverPortableSource(archive:archive,password:password,confirmed:true)
        XCTAssertEqual(restored.workers,9648);XCTAssertEqual(restored.attentions,1005)
        // Existing fixture helpers subsequently activate the SAME v2 physical
        // counts70/12 and retain their original draft. Never bulk-register
        // thousands of separate worker transactions or replay old consumptions.
    }
    private func invariantData() async throws -> Data {
        let vault=N2SyntheticTrialIOSVault.shared
        let archive=try await vault.exportPortableEncryptedBackup(password:password)
        let checked=try N2InventoryBackupCodec.verify(archive:archive,password:password)
        XCTAssertEqual(checked.domain,.demo);XCTAssertEqual(checked.schemaVersion,2)
        let root=try XCTUnwrap(JSONSerialization.jsonObject(with:checked.snapshot) as? [String:Any])
        let workers=try XCTUnwrap(root["workers"] as? [[String:Any]])
        let rows=try XCTUnwrap(root["attentions"] as? [[String:Any]])
        let visits=rows.filter{$0["status"] as? String != "draft"}
        let originalDraft=try XCTUnwrap(rows.first{$0["id"] as? String=="premium-ui-draft"})
        XCTAssertEqual(originalDraft["status"] as? String,"draft")
        XCTAssertEqual(workers.count,9648);XCTAssertEqual(visits.count,1005)
        XCTAssertTrue(visits.allSatisfy{$0["status"] as? String=="saved"})
        let physical=try XCTUnwrap(root["simpleInventory"])
        return try JSONSerialization.data(withJSONObject:["workers":workers,"attentions":visits,"simpleInventory":physical,"originalDraft":originalDraft],options:.sortedKeys)
    }
    func testCaptureCompletePhysicalWorkersAndHistoryBeforeReview() async throws {
        try requireSimulator();continueAfterFailure=false
        XCTAssertFalse(FileManager.default.fileExists(atPath:baseline.path),"Refuse to replace a prior baseline")
        let data=try await invariantData()
        try data.write(to:baseline,options:.atomic)
    }
    func testMeasureNativeAllergyAndSearchOnLargeDemo() async throws {
        try requireSimulator();continueAfterFailure=false
        let vault=N2SyntheticTrialIOSVault.shared
        let contextStart=ProcessInfo.processInfo.systemUptime
        let context=try await vault.clinicalFormContext()
        let contextMS=(ProcessInfo.processInfo.systemUptime-contextStart)*1000
        XCTAssertEqual(context.workers.count,9648)
        var revision=context.revision
        var saves=[Double]()
        let at=Int64(Date().timeIntervalSince1970*1000)
        for i in 0..<7 {
            let start=ProcessInfo.processInfo.systemUptime
            revision=try await vault.reviewAllergiesRevision(dni:"00000031",
                status:i%2==0 ? "none":"known",substances:i%2==0 ? "":"SUSTANCIA FICTICIA PERF",
                at:at+Int64(i),expectedRevision:revision)
            saves.append((ProcessInfo.processInfo.systemUptime-start)*1000)
        }
        let indexStart=ProcessInfo.processInfo.systemUptime
        let index=N2SearchIndex(rows:context.workers,fields:{$0.dni+"\u{1f}"+$0.name})
        let indexMS=(ProcessInfo.processInfo.systemUptime-indexStart)*1000
        XCTAssertTrue(index.matches("").isEmpty)
        var last=[Double](),common=[Double]()
        for _ in 0..<100 {
            var start=ProcessInfo.processInfo.systemUptime
            let end=index.matches("PERF 09648",limit:25)
            last.append((ProcessInfo.processInfo.systemUptime-start)*1000)
            XCTAssertEqual(end.last?.dni,"00009648")
            start=ProcessInfo.processInfo.systemUptime
            let page=index.matches("PERSONA FICTICIA PERF",limit:25)
            common.append((ProcessInfo.processInfo.systemUptime-start)*1000)
            XCTAssertEqual(page.count,25)
        }
        let inspected=try await vault.inspect()
        let summary=try XCTUnwrap(inspected)
        XCTAssertEqual(summary.workers,9648);XCTAssertEqual(summary.saved,1005)
        XCTAssertGreaterThanOrEqual(summary.drafts,1)
        XCTAssertEqual(summary.attentions,summary.saved+summary.drafts)
        let report:[String:Any]=["scope":"iPhone16 Simulator native DEMO API, not UI tap latency or physical iPhone",
            "workers":summary.workers,"visits":summary.saved,"drafts":summary.drafts,"confirmedAllergySaveMS":saves,
            "lastWorkerSearchMS":last,"commonFirstPageSearchMS":common,"contextLoadOneSampleMS":contextMS,
            "searchIndexBuildOneSampleMS":indexMS,"uiMeasured":false,"IPA":false]
        let json=try JSONSerialization.data(withJSONObject:report,options:.sortedKeys)
        print("DANPER_LARGE_NATIVE_BENCHMARK "+String(decoding:json,as:UTF8.self))
    }
    func testVerifyLargeReviewPreservedPhysicalWorkersHistoryAndDraft() async throws {
        try requireSimulator();continueAfterFailure=false
        let expected=try Data(contentsOf:baseline)
        let actual=try await invariantData()
        XCTAssertTrue(actual==expected,"The complete physical state, all workers and original visits must remain identical")
        let vault=N2SyntheticTrialIOSVault.shared
        let context=try await vault.clinicalFormContext()
        XCTAssertEqual(context.workers.count,9648)
        XCTAssertEqual(context.allergies["00000031"]?.status,"none")
        XCTAssertEqual(context.allergies["00000031"]?.reviewed,true)
        let drafts=try await vault.readDrafts()
        XCTAssertTrue(drafts.contains{$0.id=="premium-ui-draft"},"Preserve the original encrypted draft")
        print("DANPER_LARGE_UI_INTEGRITY workers=9648 visits=1005 fullPhysicalWorkersHistory=unchanged allergy=confirmed originalDraft=preserved")
    }
}
