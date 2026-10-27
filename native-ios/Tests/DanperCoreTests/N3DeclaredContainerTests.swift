import Foundation
import XCTest
@testable import DanperCore

final class N3DeclaredContainerTests:XCTestCase {
    private func fixture(_ name:String)throws->Data {
        let folder=try XCTUnwrap(ProcessInfo.processInfo.environment["DANPER_N1_FIXTURE_DIR"])
        return try Data(contentsOf:URL(fileURLWithPath:folder).appendingPathComponent(name))
    }
    private func bytes(_ value:Any)throws->Data {try JSONSerialization.data(withJSONObject:value,options:.sortedKeys)}
    private func object(_ data:Data)throws->[String:Any] {try XCTUnwrap(JSONSerialization.jsonObject(with:data) as? [String:Any])}
    private func time(_ day:String)->Int64 {
        Int64(ISO8601DateFormatter().date(from:day+"T18:00:00Z")!.timeIntervalSince1970*1000)
    }
    private func source(capacity:Int=1,sealed:Int=2)throws->Data {
        var root=try object(fixture("n1e-clinical-stock.json"))
        root["attentions"]=[[String:Any]]();root["stockMovements"]=[[String:Any]]()
        let maps=try JSONSerialization.jsonObject(with:fixture("n2-reviewed-approved.json")) as! [[String:Any]]
        let product=try XCTUnwrap(maps.first{$0["kardexCode"] as? String=="E-87"})
        root["stockLots"]=[["id":"declared-bottles","code":"E-87","name":product["kardexName"]!,
            "catalogUnit":"FCO","lot":"SYNTHETIC-DECLARATION","expires":"2027-12-31","container":"frasco",
            "unitsPerContainer":capacity,"sealedContainers":sealed,"looseUnits":0,"openedRemaining":0,
            "declaredOpenContainers":0,"volumeTrackingEnabled":capacity>1,"updatedAt":time("2026-11-07")]]
        return try bytes(root)
    }
    private func visit(_ snapshot:Data,id:String,day:String,openings:Int=0,volume:Double=0)throws->Data {
        let root=try object(snapshot)
        let maps=try JSONSerialization.jsonObject(with:fixture("n2-reviewed-approved.json")) as! [[String:Any]]
        let product=try XCTUnwrap(maps.first{$0["kardexCode"] as? String=="E-87"})
        let original=try object(fixture("n1e-clinical-stock.json"))
        var visit=(original["attentions"] as! [[String:Any]])[0]
        visit["id"]=id;visit["date"]=day;visit["time"]="13:00"
        visit["worker"]=(root["workers"] as! [[String:Any]])[0]
        visit["items"]=[["id":id+"-item","code":product["clinicalCode"]!,"name":product["clinicalName"]!,
            "unit":product["clinicalUnit"]!,"quantity":1,"procedure":"OBSERVACION",
            "physicalUse":["lotId":"declared-bottles","quantity":volume,
                "confirmNewContainer":openings>0,"newContainers":openings]]]
        return try bytes(visit)
    }
    private func save(_ source:Data,id:String,day:String,openings:Int=0,volume:Double=0)throws->N2ClinicalResult {
        try N2NativeClinicalTransaction.appendSavedVisit(snapshot:source,
            visit:visit(source,id:id,day:day,openings:openings,volume:volume),
            approvedCatalog:fixture("n2-reviewed-approved.json"),at:time(day))
    }
    private func lot(_ source:Data)throws->[String:Any] {try XCTUnwrap((object(source)["stockLots"] as? [[String:Any]])?.first)}
    private func catalog()throws->Data {
        try bytes(object(fixture("n2-nursing-parity.json"))["catalog"]!)
    }
    func testMandatoryOneZeroZeroOneZeroAcrossDaysSessionsMonthlyCutAndExcel()throws {
        var snapshot=try source()
        let folder=FileManager.default.temporaryDirectory.appendingPathComponent("danper-n2-synthetic-"+UUID().uuidString,isDirectory:true)
        defer {try? FileManager.default.removeItem(at:folder)}
        let key=Data(repeating:0x53,count:32)
        var revision=try N2EncryptedClinicalJournal(directory:folder,secret:key).commit(snapshot,expectedRevision:0)
        let expected=[1,0,0,1,0]
        for index in expected.indices {
            let journal=try N2EncryptedClinicalJournal(directory:folder,secret:key)
            snapshot=try XCTUnwrap(journal.recover()).snapshot
            let day=String(format:"2026-11-%02d",8+index)
            let result=try save(snapshot,id:"declared-\(index)",day:day,openings:expected[index])
            XCTAssertEqual(result.linked,1,result.pendingReasons.joined(separator:";"))
            XCTAssertEqual(result.pending,0)
            snapshot=result.snapshot
            revision=try journal.commit(snapshot,expectedRevision:revision)
            let report=try N2NursingReportBuilder.daily(snapshot:snapshot,catalog:catalog(),date:day)
            XCTAssertTrue(report.exportable,report.warnings.joined(separator:";"))
            XCTAssertEqual(report.rows.first{$0.code=="E-87"}?.consumed,Double(expected[index]))
        }
        XCTAssertEqual(try N1eLegacyClinicalAudit.inspect(snapshot).consumptionR.compactMap{$0},expected.map(Double.init))
        XCTAssertEqual(try lot(snapshot)["sealedContainers"] as? Int,0)
        XCTAssertEqual(try lot(snapshot)["declaredOpenContainers"] as? Int,2)
        let period=try N2NursingReportBuilder.range(snapshot:snapshot,catalog:catalog(),start:"2026-11-08",end:"2026-11-12")
        XCTAssertTrue(period.exportable,period.warnings.joined(separator:";"))
        XCTAssertEqual(period.rows.first{$0.code=="E-87"}?.consumed,2)
        XCTAssertEqual(period.rows.first{$0.code=="E-87"}?.closing,0)
        let cutBefore=try N2AutomaticCutAccounting.calculate(snapshot:snapshot,mappings:fixture("n2-reviewed-approved.json"),through:"2026-11-08")
        let cutAfter=try N2AutomaticCutAccounting.calculate(snapshot:snapshot,mappings:fixture("n2-reviewed-approved.json"),through:"2026-11-12")
        XCTAssertEqual(cutBefore.rows.first{$0.code=="E-87"}?.reportedUse,1)
        XCTAssertEqual(cutBefore.rows.first{$0.code=="E-87"}?.currentCount,1)
        XCTAssertEqual(cutBefore.rows.first{$0.code=="E-87"}?.opening,2)
        XCTAssertEqual(cutAfter.start,"2026-11-09")
        XCTAssertEqual(cutAfter.rows.first{$0.code=="E-87"}?.reportedUse,1)
        XCTAssertEqual(cutAfter.rows.first{$0.code=="E-87"}?.currentCount,0)
        XCTAssertEqual(cutAfter.rows.first{$0.code=="E-87"}?.opening,1)
        let workbook=try N2VerifiedNursingWorkbook.exportRange(snapshot:snapshot,catalog:catalog(),
            template:fixture("n1s-nursing-template-store.zip"),start:"2026-11-08",end:"2026-11-12",responsible:"OPERADOR FICTICIO")
        let entries=try N1rStoredZip.unpack(workbook.xlsx)
        let sheet=try XCTUnwrap(entries.first{$0.name=="xl/worksheets/sheet2.xml"})
        let xml=try XCTUnwrap(String(data:sheet.data,encoding:.utf8))
        XCTAssertTrue(xml.contains("PERÍODO CONSOLIDADO"))
        XCTAssertNotNil(xml.range(of:#"<c r="G93"[^>]*><v>2(?:\.0)?</v></c>"#,options:.regularExpression))
        XCTAssertNotNil(xml.range(of:#"<c r="H93"[^>]*>.*?<v>0(?:\.0)?</v></c>"#,options:.regularExpression))
        let products=try bytes(object(fixture("n1s-indicator-plan.json"))["catalog"]!)
        let indicator=try N2VerifiedIndicatorWorkbook.export(snapshot:snapshot,products:products,
            mappings:fixture("n2-reviewed-approved.json"),template:fixture("n1s-indicator-template-store.zip"),
            start:"2026-11-09",end:"2026-12-08",subdivision:"LA VENTUROSA",
            selectedVisitIDs:Set((1...4).map{"declared-\($0)"}),allowPending:true)
        XCTAssertEqual(indicator.pendingLines,0)
        XCTAssertEqual(indicator.rows,4)
        let indicatorParts=try N1rStoredZip.unpack(indicator.xlsx)
        XCTAssertEqual(indicatorParts.filter{$0.name.hasPrefix("xl/worksheets/sheet")}.count,10)
        let consumos=String(decoding:try XCTUnwrap(indicatorParts.first{$0.name=="xl/worksheets/sheet5.xml"}).data,as:UTF8.self)
        for (index,value) in [0,0,1,0].enumerated() {
            XCTAssertNotNil(consumos.range(of:"<c r=\"R\(index+2)\"[^>]*><v>\(value)(?:\\.0)?</v></c>",options:.regularExpression))
        }
        let repeated=try N2NativeClinicalTransaction.retryCurrentSavedVisit(snapshot:snapshot,visitID:"declared-4",
            approvedCatalog:fixture("n2-reviewed-approved.json"),at:time("2026-11-13"))
        XCTAssertEqual(repeated.physicalMovementsAdded,0)
        XCTAssertEqual(try N1eLegacyClinicalAudit.inspect(repeated.snapshot).consumptionR.compactMap{$0},expected.map(Double.init))
    }
    func testExplicitReuseR0WithoutInventingEarlierOpeningOrChangingPhysicalStock()throws {
        let original=try source(capacity:1,sealed:2)
        var visitData=try object(visit(original,id:"reused-from-stock",
                                      day:"2026-11-08"))
        var items=visitData["items"] as! [[String:Any]]
        items[0]["reusePreviouslyOpened"]=true
        visitData["items"]=items
        let saved=try N2NativeClinicalTransaction.appendSavedVisit(
            snapshot:original,visit:bytes(visitData),
            approvedCatalog:fixture("n2-reviewed-approved.json"),
            at:time("2026-11-08"))
        XCTAssertEqual(saved.linked,1,saved.pendingReasons.joined(separator:";"))
        XCTAssertEqual(saved.pending,0)
        XCTAssertEqual(try N1eLegacyClinicalAudit.inspect(saved.snapshot)
                       .consumptionR.compactMap{$0},[0])
        let all=try object(saved.snapshot)
        let moves=all["stockMovements"] as! [[String:Any]]
        XCTAssertEqual(moves.count,1)
        XCTAssertEqual(moves[0]["kind"] as? String,"use")
        XCTAssertEqual(moves[0]["reuseWithoutRecordedOpening"] as? Bool,true)
        XCTAssertEqual((moves[0]["physicalChange"] as? NSNumber)?.doubleValue,0)
        XCTAssertEqual((moves[0]["excelQuantity"] as? NSNumber)?.doubleValue,0)
        XCTAssertEqual(try lot(saved.snapshot)["declaredOpenContainers"] as? Int,0)
        XCTAssertEqual(try lot(saved.snapshot)["sealedContainers"] as? Int,2)
        let repeated=try N2NativeClinicalTransaction.retryCurrentSavedVisit(
            snapshot:saved.snapshot,visitID:"reused-from-stock",
            approvedCatalog:fixture("n2-reviewed-approved.json"),
            at:time("2026-11-09"))
        XCTAssertEqual(repeated.physicalMovementsAdded,0)
        XCTAssertEqual((try object(repeated.snapshot)["stockMovements"] as? [[String:Any]])?.count,1)
        var tampered=all
        var altered=moves
        altered[0]["reuseWithoutRecordedOpening"]=false
        tampered["stockMovements"]=altered
        XCTAssertThrowsError(try N1eLegacyClinicalAudit.inspect(bytes(tampered)))
    }
    func testReuseWithoutConfirmationRemainsPendingButExplicitReuseDoesNot()throws {
        let original=try source(capacity:100,sealed:2)
        XCTAssertEqual(try save(original,id:"no-attestation",day:"2026-11-08").pending,1)
        var proposed=try object(visit(original,id:"attested-reuse",day:"2026-11-08"))
        var items=proposed["items"] as! [[String:Any]]
        items[0]["reusePreviouslyOpened"]=true
        proposed["items"]=items
        let saved=try N2NativeClinicalTransaction.appendSavedVisit(
            snapshot:original,visit:bytes(proposed),
            approvedCatalog:fixture("n2-reviewed-approved.json"),
            at:time("2026-11-08"))
        XCTAssertEqual(saved.pending,0)
        XCTAssertEqual(saved.linked,1)
        XCTAssertEqual(try lot(saved.snapshot)["sealedContainers"] as? Int,2)
        XCTAssertEqual(try lot(saved.snapshot)["openedRemaining"] as? Int,0)
        XCTAssertEqual(try N1eLegacyClinicalAudit.inspect(saved.snapshot).consumptionR.compactMap{$0},[0])
    }
    func testStaleSelectedSealedLotDoesNotOverrideEarlierFEFOOpenLot()throws {
        var raw=try object(source(capacity:1,sealed:1))
        var lots=raw["stockLots"] as! [[String:Any]]
        var later=lots[0]
        later["id"]="later-unopened-box"
        later["lot"]="LATER-EXPIRY"
        later["expires"]="2028-12-31"
        later["sealedContainers"]=2
        lots.append(later)
        raw["stockLots"]=lots
        let first=try save(bytes(raw),id:"first-open",day:"2026-11-08",openings:1)
        var second=try object(visit(first.snapshot,id:"reuse-with-stale-lot",
                                    day:"2026-11-09"))
        var rows=second["items"] as! [[String:Any]]
        rows[0]["reusePreviouslyOpened"]=true
        var physical=rows[0]["physicalUse"] as! [String:Any]
        physical["reusePreviouslyOpened"]=true
        physical["lotId"]="later-unopened-box"
        rows[0]["physicalUse"]=physical
        second["items"]=rows
        let result=try N2NativeClinicalTransaction.appendSavedVisit(
            snapshot:first.snapshot,visit:bytes(second),
            approvedCatalog:fixture("n2-reviewed-approved.json"),
            at:time("2026-11-09"))
        XCTAssertEqual(result.linked,1,result.pendingReasons.joined(separator:";"))
        XCTAssertEqual(result.pending,0)
        XCTAssertEqual(try N1eLegacyClinicalAudit.inspect(result.snapshot).consumptionR.compactMap{$0},[1,0])
        let events=try XCTUnwrap(object(result.snapshot)["stockMovements"] as? [[String:Any]])
        XCTAssertEqual(events.last?["lotId"] as? String,"declared-bottles")
        XCTAssertEqual((events.last?["excelQuantity"] as? NSNumber)?.doubleValue,0)
        XCTAssertFalse(events.contains{$0["reuseWithoutRecordedOpening"] as? Bool == true})
    }
    func testAttestedReuseOfBoxOfOneHundredDoesNotReclassifyStock()throws {
        var original=try object(source(capacity:100,sealed:2))
        var lots=original["stockLots"] as! [[String:Any]]
        lots[0]["catalogUnit"]="CJA"
        lots[0]["container"]="caja"
        original["stockLots"]=lots
        var clinical=try object(visit(bytes(original),id:"box-of-100",day:"2026-11-08"))
        var lines=clinical["items"] as! [[String:Any]]
        lines[0]["reusePreviouslyOpened"]=true
        clinical["items"]=lines
        let saved=try N2NativeClinicalTransaction.appendSavedVisit(
            snapshot:bytes(original),visit:bytes(clinical),
            approvedCatalog:fixture("n2-reviewed-approved.json"),at:time("2026-11-08"))
        XCTAssertEqual(saved.pending,0,saved.pendingReasons.joined(separator:";"))
        XCTAssertEqual(saved.linked,1)
        let changed=try lot(saved.snapshot)
        XCTAssertEqual(changed["sealedContainers"] as? Int,2)
        XCTAssertEqual(changed["openedRemaining"] as? Int,0)
        XCTAssertEqual(changed["declaredOpenContainers"] as? Int,0)
        XCTAssertEqual(try N1eLegacyClinicalAudit.inspect(saved.snapshot).consumptionR.compactMap{$0},[0])
        let movement=try XCTUnwrap((object(saved.snapshot)["stockMovements"] as? [[String:Any]])?.first)
        XCTAssertEqual(movement["reuseWithoutRecordedOpening"] as? Bool,true)
        XCTAssertEqual((movement["physicalChange"] as? NSNumber)?.doubleValue,0)
    }

    func testSaveTimeExplicitNewOpeningClosesOneVerifiedPreviousWithoutSecondDebit()throws {
        let first=try save(source(sealed:3),id:"popup-first",day:"2026-11-08",openings:1)
        XCTAssertEqual(first.linked,1)
        var next=try object(visit(first.snapshot,id:"popup-next",day:"2026-11-09",openings:1))
        var items=try XCTUnwrap(next["items"] as? [[String:Any]])
        var use=try XCTUnwrap(items[0]["physicalUse"] as? [String:Any])
        use["previousContainerExhausted"]=true
        items[0]["physicalUse"]=use
        next["items"]=items
        let saved=try N2NativeClinicalTransaction.appendSavedVisit(snapshot:first.snapshot,
            visit:bytes(next),approvedCatalog:fixture("n2-reviewed-approved.json"),
            at:time("2026-11-09"))
        XCTAssertEqual(saved.linked,1,saved.pendingReasons.joined(separator:";"))
        XCTAssertEqual(saved.pending,0)
        let all=try object(saved.snapshot)
        let moves=try XCTUnwrap(all["stockMovements"] as? [[String:Any]])
        let closings=moves.filter{$0["kind"] as? String=="containerState"}
        XCTAssertEqual(closings.count,1)
        XCTAssertEqual(closings[0]["containerDisposition"] as? String,"agotado")
        XCTAssertEqual((closings[0]["excelQuantity"] as? NSNumber)?.doubleValue,0)
        // The emptied prior bottle removes its residual physical contents
        // once, while only the NEW opening produces Kardex R=1.
        XCTAssertEqual((closings[0]["physicalChange"] as? NSNumber)?.doubleValue,-1)
        XCTAssertEqual((closings[0]["quantity"] as? NSNumber)?.doubleValue,0)
        var corrupted=all
        var forged=try XCTUnwrap(corrupted["stockMovements"] as? [[String:Any]])
        guard let closingIndex=forged.firstIndex(where:{
            $0["kind"] as? String=="containerState"
        }) else {return XCTFail("Falta movimiento de agotamiento")}
        forged[closingIndex]["physicalChange"]=0
        corrupted["stockMovements"]=forged
        XCTAssertThrowsError(try N1eLegacyClinicalAudit.inspect(bytes(corrupted)),
                             "Un remanente agotado no puede falsificar cambio físico 0")
        XCTAssertEqual(try lot(saved.snapshot)["declaredOpenContainers"] as? Int,1)
        XCTAssertEqual(try lot(saved.snapshot)["sealedContainers"] as? Int,1)
        XCTAssertEqual(try N1eLegacyClinicalAudit.inspect(saved.snapshot)
                        .consumptionR.compactMap{$0},[1,1])
        let retried=try N2NativeClinicalTransaction.retryCurrentSavedVisit(
            snapshot:saved.snapshot,visitID:"popup-next",
            approvedCatalog:fixture("n2-reviewed-approved.json"),
            at:time("2026-11-10"))
        XCTAssertEqual(retried.physicalMovementsAdded,0)
        let again=try object(retried.snapshot)
        XCTAssertEqual((again["stockMovements"] as? [[String:Any]])?.count,moves.count)
    }
    func testNextOpeningCannotSilentlyExhaustTwoPreviouslyOpenedContainers()throws {
        let first=try save(source(sealed:4),id:"two-open",day:"2026-11-08",openings:2)
        var next=try object(visit(first.snapshot,id:"next-after-two",day:"2026-11-09",openings:1))
        var rows=next["items"] as! [[String:Any]]
        var use=rows[0]["physicalUse"] as! [String:Any]
        use["previousContainerExhausted"]=true
        rows[0]["physicalUse"]=use
        next["items"]=rows
        let pending=try N2NativeClinicalTransaction.appendSavedVisit(snapshot:first.snapshot,
            visit:bytes(next),approvedCatalog:fixture("n2-reviewed-approved.json"),
            at:time("2026-11-09"))
        XCTAssertEqual(pending.linked,0)
        XCTAssertEqual(pending.pending,1)
        XCTAssertEqual(try lot(pending.snapshot)["declaredOpenContainers"] as? Int,2)
        XCTAssertEqual(try lot(pending.snapshot)["sealedContainers"] as? Int,2)
        let m=try object(pending.snapshot)["stockMovements"] as! [[String:Any]]
        XCTAssertFalse(m.contains{$0["kind"] as? String=="containerState"})
    }
    func testMeasuredRemainderPreventsAutomaticExhaustion()throws {
        let first=try save(source(capacity:10,sealed:3),id:"measured-open",
                             day:"2026-11-08",openings:1,volume:2)
        var next=try object(visit(first.snapshot,id:"new-while-measured",
                                  day:"2026-11-09",openings:1))
        var items=next["items"] as! [[String:Any]]
        var evidence=items[0]["physicalUse"] as! [String:Any]
        evidence["previousContainerExhausted"]=true
        items[0]["physicalUse"]=evidence
        next["items"]=items
        let result=try N2NativeClinicalTransaction.appendSavedVisit(
            snapshot:first.snapshot,visit:bytes(next),
            approvedCatalog:fixture("n2-reviewed-approved.json"),at:time("2026-11-09"))
        XCTAssertEqual(result.pending,1)
        XCTAssertEqual(try lot(result.snapshot)["openedRemaining"] as? Int,8)
    }

    func testVolumeCannotOpenOrExhaustContainerAndExplicitClosureDoesNotDebitAgain()throws {
        let first=try save(source(capacity:10,sealed:3),id:"first",day:"2026-11-08",openings:1,volume:10)
        XCTAssertEqual(first.linked,1)
        XCTAssertEqual(try lot(first.snapshot)["openedRemaining"] as? Int,0)
        XCTAssertEqual(try lot(first.snapshot)["declaredOpenContainers"] as? Int,1)
        let reuse=try save(first.snapshot,id:"reuse",day:"2026-11-09")
        XCTAssertEqual(reuse.linked,1)
        XCTAssertEqual(try N1eLegacyClinicalAudit.inspect(reuse.snapshot).consumptionR.compactMap{$0},[1,0])
        let tooMuch=try save(reuse.snapshot,id:"volume-alone",day:"2026-11-10",volume:11)
        XCTAssertEqual(tooMuch.pending,1)
        XCTAssertEqual(tooMuch.physicalMovementsAdded,0)
        XCTAssertEqual(try lot(tooMuch.snapshot)["sealedContainers"] as? Int,2)
        let additional=try save(reuse.snapshot,id:"two-more",day:"2026-11-10",openings:2)
        XCTAssertEqual(additional.linked,1)
        XCTAssertEqual(try N1eLegacyClinicalAudit.inspect(additional.snapshot).consumptionR.compactMap{$0},[1,0,2])
        let closed=try N2ContainerAccounting.close(snapshot:additional.snapshot,lotID:"declared-bottles",count:3,
            disposition:"agotado",operatorName:"OPERADOR FICTICIO",reason:"Agotamiento declarado manualmente en prueba",at:time("2026-11-11"))
        XCTAssertEqual(try lot(closed)["declaredOpenContainers"] as? Int,0)
        XCTAssertEqual(try lot(closed)["sealedContainers"] as? Int,0)
        XCTAssertEqual(try N1eLegacyClinicalAudit.inspect(closed).consumptionR.compactMap{$0},[1,0,2])
        XCTAssertEqual(try save(closed,id:"no-open",day:"2026-11-12").pending,1)
        let report=try N2NursingReportBuilder.daily(snapshot:closed,catalog:catalog(),date:"2026-11-11")
        XCTAssertTrue(report.exportable,report.warnings.joined(separator:";"))
        XCTAssertEqual(report.rows.first{$0.code=="E-87"}?.consumed,0)
    }
    func testNoOpeningWithoutDeclarationAndTamperingFailsAudit()throws {
        let original=try source()
        let pending=try save(original,id:"no-consent",day:"2026-11-08")
        XCTAssertEqual(pending.pending,1);XCTAssertEqual(pending.physicalMovementsAdded,0)
        XCTAssertEqual(try lot(pending.snapshot)["sealedContainers"] as? Int,2)
        var legacy=try object(visit(original,id:"legacy-permission",day:"2026-11-08",openings:1))
        var items=legacy["items"] as! [[String:Any]]
        items[0]["physicalUse"]=["lotId":"declared-bottles","quantity":0,"confirmNewContainer":true]
        legacy["items"]=items
        let legacyResult=try N2NativeClinicalTransaction.appendSavedVisit(snapshot:original,visit:bytes(legacy),
            approvedCatalog:fixture("n2-reviewed-approved.json"),at:time("2026-11-08"))
        XCTAssertEqual(legacyResult.pending,1)
        XCTAssertEqual(legacyResult.physicalMovementsAdded,0)
        let accepted=try save(original,id:"yes",day:"2026-11-08",openings:1)
        for key in ["excelQuantity","declaredOpenings"] {
            var root=try object(accepted.snapshot)
            var movements=root["stockMovements"] as! [[String:Any]]
            movements[0][key]=2;root["stockMovements"]=movements
            XCTAssertThrowsError(try N1eLegacyClinicalAudit.inspect(bytes(root)))
            movements[0][key]=true;root["stockMovements"]=movements
            XCTAssertThrowsError(try N1eLegacyClinicalAudit.inspect(bytes(root)))
        }
        XCTAssertThrowsError(try N2ContainerAccounting.close(snapshot:accepted.snapshot,lotID:"declared-bottles",count:2,
            disposition:"descartado",operatorName:"OPERADOR FICTICIO",reason:"Declaración inválida de prueba",at:time("2026-11-09")))
    }
    func testAllVerifiedContainerUnitsUseTheSameExplicitPlan()throws {
        let raw=try lot(source(capacity:100))
        for unit in ["FCO","CJA","PAQ","BLISTER","ENV"] {
            var lot=raw;lot["catalogUnit"]=unit
            XCTAssertTrue(N2ContainerAccounting.isContainer(unit:unit))
            XCTAssertNil(N2ContainerAccounting.plan(lot:lot,openings:0,volume:1,at:time("2026-11-08")))
            let opened=try XCTUnwrap(N2ContainerAccounting.plan(lot:lot,openings:1,volume:100,at:time("2026-11-08")))
            XCTAssertEqual(opened["declaredOpenContainers"] as? Int,1)
            XCTAssertNotNil(N2ContainerAccounting.plan(lot:opened,openings:0,volume:0,at:time("2026-11-09")))
        }
        for unit in ["UND","TBL","PAR","ML","LT"] {XCTAssertFalse(N2ContainerAccounting.isContainer(unit:unit))}
    }
    func testPendingContainerDoesNotInventOpeningInProvisionalIndicator()throws {
        let pending=try save(source(),id:"pending-container",day:"2026-11-09")
        XCTAssertEqual(pending.pending,1)
        let products=try bytes(object(fixture("n1s-indicator-plan.json"))["catalog"]!)
        XCTAssertThrowsError(try N2VerifiedIndicatorWorkbook.export(snapshot:pending.snapshot,products:products,
            mappings:fixture("n2-reviewed-approved.json"),template:fixture("n1s-indicator-template-store.zip"),
            start:"2026-11-09",end:"2026-12-08",subdivision:"LA VENTUROSA",
            selectedVisitIDs:["pending-container"])) {
            XCTAssertEqual($0 as? N2VerifiedIndicatorWorkbook.Failure,.unverifiedDelivery)
        }
        let provisional=try N2VerifiedIndicatorWorkbook.export(snapshot:pending.snapshot,products:products,
            mappings:fixture("n2-reviewed-approved.json"),template:fixture("n1s-indicator-template-store.zip"),
            start:"2026-11-09",end:"2026-12-08",subdivision:"LA VENTUROSA",
            selectedVisitIDs:["pending-container"],allowPending:true)
        XCTAssertTrue(provisional.provisional)
        XCTAssertEqual(provisional.pendingLines,1)
        let parts=try N1rStoredZip.unpack(provisional.xlsx)
        let consumos=String(decoding:try XCTUnwrap(parts.first{$0.name=="xl/worksheets/sheet5.xml"}).data,as:UTF8.self)
        XCTAssertNotNil(consumos.range(of:#"<c\b[^>]*\br="R2"[^>]*/>"#,options:.regularExpression))
        let notes=String(decoding:try XCTUnwrap(parts.first{$0.name=="xl/worksheets/sheet6.xml"}).data,as:UTF8.self)
        XCTAssertTrue(notes.contains("BORRADOR PROVISIONAL"))
        XCTAssertTrue(notes.contains("R PENDIENTE"))
        XCTAssertEqual(pending.physicalMovementsAdded,0)
    }
    func testDeclaredMultipleOpeningsSplitByFEFOWithoutInventingVolumeOrSkippingEarlierLot()throws {
        var root=try object(source(sealed:1))
        var lots=root["stockLots"] as! [[String:Any]]
        var later=lots[0]
        later["id"]="later-declared-bottles";later["lot"]="SYNTHETIC-LATER"
        later["expires"]="2028-12-31";later["sealedContainers"]=2
        lots.append(later);root["stockLots"]=lots
        let original=try bytes(root)
        var attention=try object(visit(original,id:"declared-split",day:"2026-11-08",openings:2))
        var items=attention["items"] as! [[String:Any]]
        items[0]["physicalUse"]=["quantity":0,"confirmNewContainer":true,"newContainers":2]
        attention["items"]=items
        let result=try N2NativeClinicalTransaction.appendSavedVisit(snapshot:original,visit:bytes(attention),
            approvedCatalog:fixture("n2-reviewed-approved.json"),at:time("2026-11-08"))
        XCTAssertEqual(result.linked,1,result.pendingReasons.joined(separator:";"))
        XCTAssertEqual(result.physicalMovementsAdded,2)
        let final=try object(result.snapshot)
        let after=final["stockLots"] as! [[String:Any]]
        XCTAssertEqual(after[0]["sealedContainers"] as? Int,0)
        XCTAssertEqual(after[1]["sealedContainers"] as? Int,1)
        let movements=final["stockMovements"] as! [[String:Any]]
        XCTAssertEqual(movements.compactMap{$0["excelQuantity"] as? Int},[1,1])
        XCTAssertTrue(movements.allSatisfy{($0["physicalChange"] as? NSNumber)?.doubleValue==0})
        XCTAssertEqual(try N1eLegacyClinicalAudit.inspect(result.snapshot).consumptionR.compactMap{$0},[2])
        let daily=try N2NursingReportBuilder.daily(snapshot:result.snapshot,catalog:catalog(),date:"2026-11-08")
        XCTAssertTrue(daily.exportable,daily.warnings.joined(separator:";"))
        XCTAssertEqual(daily.rows.first{$0.code=="E-87"}?.consumed,2)
        let repeated=try N2NativeClinicalTransaction.retryCurrentSavedVisit(snapshot:result.snapshot,
            visitID:"declared-split",approvedCatalog:fixture("n2-reviewed-approved.json"),at:time("2026-11-09"))
        XCTAssertEqual(repeated.physicalMovementsAdded,0)
        var corrupted=final
        var invalid=movements
        var ref=invalid[0]["dispenseRef"] as! [String:Any]
        ref["declaredOpeningTotal"]=3;invalid[0]["dispenseRef"]=ref
        corrupted["stockMovements"]=invalid
        XCTAssertThrowsError(try N1eLegacyClinicalAudit.inspect(bytes(corrupted)))
    }
}
