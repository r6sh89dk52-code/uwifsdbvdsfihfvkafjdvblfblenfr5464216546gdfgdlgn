import Foundation
import XCTest
@testable import DanperCore

/// Copied into the test target only by run-core.sh. All records are fabricated.
/// Same harness and fixture sizes for initial HEAD and optimized HEAD.
final class N2PerformanceAuditTests:XCTestCase {
    private func fixture(_ name:String)throws->Data {
        let dir=try XCTUnwrap(ProcessInfo.processInfo.environment["DANPER_N1_FIXTURE_DIR"])
        return try Data(contentsOf:URL(fileURLWithPath:dir).appendingPathComponent(name))
    }
    func testMeasuredSyntheticActions()throws {
        let out=try XCTUnwrap(ProcessInfo.processInfo.environment["DANPER_PERF_OUTPUT"])
        var root=try XCTUnwrap(JSONSerialization.jsonObject(with:fixture("n1e-clinical-stock.json")) as? [String:Any])
        var workers=try XCTUnwrap(root["workers"] as? [[String:Any]])
        for i in (workers.count+1)...9_648 {
            workers.append(["dni":String(format:"%08d",i),"name":String(format:"PERSONA FICTICIA PERF %05d",i),
                "area":"AREA FICTICIA","labor":"LABOR FICTICIA","sex":"F","age":"30","ubigeo":"","site":"LA VENTUROSA"])
        }
        root["workers"]=workers
        var visits=try XCTUnwrap(root["attentions"] as? [[String:Any]])
        let example=try XCTUnwrap(visits.first{$0["id"] as? String=="fundo-unit"})
        for i in 0..<1_000 {
            var visit=example
            visit["id"]="PERF-FICTICIO-\(i)";visit["worker"]=workers[i+5]
            visit["items"]=[[String:Any]]();visit["nativeDispensing"]=[String:String]()
            visit["diagnosis"]="DIAGNOSTICO FICTICIO DE RENDIMIENTO"
            visit["standaloneProcedures"]=["OBSERVACION"]
            visits.append(visit)
        }
        root["attentions"]=visits
        let proof=try XCTUnwrap(JSONSerialization.jsonObject(with:fixture("n1q-reviewed-expected.json")) as? [String:Any])
        root["ambulatoryReconciliation"]=proof["events"]!
        let source=try JSONSerialization.data(withJSONObject:root,options:.sortedKeys)
        let validated=try N2VersionedSnapshotAudit.inspect(source)
        XCTAssertEqual(validated.workers,9_648)
        _=try N1fLosslessFieldGate.inspect(source)
        let directory=FileManager.default.temporaryDirectory.appendingPathComponent("danper-n2-synthetic-"+UUID().uuidString)
        try FileManager.default.createDirectory(at:directory,withIntermediateDirectories:false)
        defer{try? FileManager.default.removeItem(at:directory)}
        let secret=Data(repeating:0x48,count:32)
        func journal()throws->N2EncryptedClinicalJournal {try N2EncryptedClinicalJournal(directory:directory,secret:secret)}
        #if DANPER_PERF_OPTIMIZED
        var session:N2ProtectedClinicalVaultCore?
        func store()throws->N2ProtectedClinicalVaultCore {
            if let session {return session}
            let result=try N2ProtectedClinicalVaultCore(testJournal:journal(),directory:directory)
            session=result;return result
        }
        #else
        func store()throws->N2ProtectedClinicalVaultCore {try N2ProtectedClinicalVaultCore(testJournal:journal(),directory:directory)}
        #endif
        var revision=try journal().commit(source,expectedRevision:0)
        let indicator=try XCTUnwrap(JSONSerialization.jsonObject(with:fixture("n1s-indicator-plan.json")) as? [String:Any])
        let nursing=try XCTUnwrap(JSONSerialization.jsonObject(with:fixture("n2-nursing-parity.json")) as? [String:Any])
        let products=try JSONSerialization.data(withJSONObject:indicator["catalog"]!)
        let catalog=try JSONSerialization.data(withJSONObject:nursing["catalog"]!)
        let mappings=try fixture("n2-reviewed-approved.json")
        let context=try store().clinicalFormContext(products:products,nursing:catalog,mappings:mappings)
        XCTAssertEqual(context.workers.count,9_648)
        var results=[[String:Any]]()
        func measure(_ name:String,_ n:Int=7,_ work:()throws->Void)throws {
            var times=[Double]()
            for _ in 0..<n {
                let start=ProcessInfo.processInfo.systemUptime
                try work()
                times.append((ProcessInfo.processInfo.systemUptime-start)*1_000)
            }
            let ordered=times.sorted()
            var row:[String:Any]=["action":name,"samples":times,"n":n,"p50_ms":ordered[n/2],"max_ms":ordered.last!]
            // Small samples are not a credible tail estimate. Retain every raw value.
            if n>=20 {row["p95_ms"]=ordered[min(n-1,Int(ceil(Double(n)*0.95))-1)]}
            results.append(row)
            FileHandle.standardOutput.write(Data("PERF \(name) median_ms \(ordered[n/2])\n".utf8))
        }
        try measure("allergy_confirmed_encrypted_save") {
            revision=try store().reviewAllergiesRevision(dni:"00009648",status:"known",substances:"SUSTANCIA FICTICIA",
                at:1_793_370_000_000+Int64(revision),expectedRevision:revision)
        }
        try measure("draft_confirmed_encrypted_save") {
            let patch=try JSONSerialization.data(withJSONObject:["diagnosis":"BORRADOR FICTICIO","worker":workers[0],"date":"2026-10-30","time":"09:00","items":[[String:Any]]()])
            revision=try store().saveDraft(id:"PERF-DRAFT",changes:patch,at:1_793_370_100_000+Int64(revision),expectedRevision:revision).revision
        }
        try measure("form_prepare_9648") {
            XCTAssertEqual(try store().prepareClinicalForm(products:products,nursing:catalog,mappings:mappings).context.workers.count,9_648)
        }
        try measure("history_read_1005") {XCTAssertNotNil(try store().readIndex())}
        try measure("dashboard_refresh") {
            #if DANPER_PERF_OPTIMIZED
            XCTAssertNotNil(try store().dashboardSnapshot(today:"2026-10-30",weekStart:"2026-10-26"))
            #else
            _=try store().currentRevision()
            XCTAssertNotNil(try store().dashboardCounters(today:"2026-10-30",weekStart:"2026-10-26"))
            #endif
        }
        try measure("correction_editor_load",3) {
            #if DANPER_PERF_OPTIMIZED
            XCTAssertEqual(try store().prepareClinicalCorrection(visitID:"fundo-unit").detail.id,"fundo-unit")
            #else
            _=try store().clinicalFormContext(products:products,nursing:catalog,mappings:mappings)
            XCTAssertEqual(try store().readCorrectionDetail(visitID:"fundo-unit").id,"fundo-unit")
            _=try store().readCorrectionHistory(visitID:"fundo-unit")
            _=try store().readPendingClinicalCorrection(visitID:"fundo-unit")
            #endif
        }
        #if DANPER_PERF_OPTIMIZED
        let index=N2SearchIndex(rows:context.workers,fields:{$0.dni+"\u{1f}"+$0.name})
        #endif
        try measure("worker_search_last",100) {
            #if DANPER_PERF_OPTIMIZED
            XCTAssertEqual(index.matches("PERF 09648").last?.dni,"00009648")
            #else
            XCTAssertEqual(context.workers.filter{$0.dni.contains("PERF 09648") || $0.name.localizedStandardContains("PERF 09648")}.last?.dni,"00009648")
            #endif
        }
        try measure("worker_search_common",100) {
            #if DANPER_PERF_OPTIMIZED
            XCTAssertEqual(index.matches("PERSONA FICTICIA PERF").count,9_643)
            #else
            XCTAssertEqual(context.workers.filter{$0.dni.contains("PERSONA FICTICIA PERF") || $0.name.localizedStandardContains("PERSONA FICTICIA PERF")}.count,9_643)
            #endif
        }
        try measure("nursing_98_export",3) {
            let x=try store().exportVerifiedRangeNursingWorkbook(catalog:catalog,template:fixture("n1s-nursing-template-store.zip"),
                start:"2026-10-09",end:"2026-11-08",responsible:"OPERADOR FICTICIO",mappings:mappings)
            XCTAssertFalse(x.xlsx.isEmpty)
        }
        try measure("indicator_10_sheets_export",3) {
            let x=try store().exportVerifiedIndicatorWorkbook(products:products,mappings:mappings,template:fixture("n1s-indicator-template-store.zip"),
                start:"2026-10-09",end:"2026-11-08",subdivision:"LA VENTUROSA",ids:["fundo-unit","fundo-reuse"])
            XCTAssertEqual(x.visits,2);XCTAssertEqual(x.rows,2)
        }
        try measure("encrypted_backup_verified",3) {
            let x=try N2InventoryBackupCodec.createVerified(snapshot:try store().sourceForEncryptedBackup(),password:"FICTICIO-PERF-2026-ONLY",domain:.demo)
            XCTAssertFalse(x.isEmpty)
        }
        let after=try XCTUnwrap(journal().recover())
        let final=try XCTUnwrap(JSONSerialization.jsonObject(with:after.snapshot) as? [String:Any])
        for field in ["workers","stockLots","stockMovements"] {
            XCTAssertEqual(try JSONSerialization.data(withJSONObject:root[field]!,options:.sortedKeys),
                           try JSONSerialization.data(withJSONObject:final[field]!,options:.sortedKeys))
        }
        #if DANPER_PERF_OPTIMIZED
        let lifecycle="Session-owned journal/core; actual HMAC, AEAD, file reads and revision checks on every operation"
        #else
        let lifecycle="New journal/core per operation, matching the initial iOS adaptors"
        #endif
        let report:[String:Any]=["storeLifecycle":lifecycle,"workers":9_648,"initialVisits":visits.count,"snapshotBytes":source.count,
            "configuration":"SwiftPM Release; x86_64 Linux; fictitious v1 snapshot; same fabricated dataset; no UI/device latency claim",
            "host":ProcessInfo.processInfo.operatingSystemVersionString,"actions":results]
        try JSONSerialization.data(withJSONObject:report,options:[.prettyPrinted,.sortedKeys]).write(to:URL(fileURLWithPath:out),options:.atomic)
    }
}
