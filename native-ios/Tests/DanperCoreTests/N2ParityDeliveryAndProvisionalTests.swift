import XCTest
@testable import DanperCore

final class N2ParityDeliveryAndProvisionalTests:XCTestCase {
    private func fixture(_ name:String)throws->Data {
        let root=try XCTUnwrap(ProcessInfo.processInfo.environment["DANPER_N1_FIXTURE_DIR"])
        return try Data(contentsOf:URL(fileURLWithPath:root).appendingPathComponent(name))
    }
    private func bytes(_ value:Any)throws->Data {try JSONSerialization.data(withJSONObject:value)}
    func testCareSiteUsesSingleInventoryAcrossLegacyAndBothLotSites()throws {
        var root=try XCTUnwrap(JSONSerialization.jsonObject(with:fixture("n1e-clinical-stock.json")) as? [String:Any])
        let visits=try XCTUnwrap(root["attentions"] as? [[String:Any]])
        var visit=try XCTUnwrap(visits.first{$0["id"] as? String=="fundo-unit"})
        visit["id"]="site-parity"
        visit["dispensingSite"]="PLVENTUROSA"
        var items=try XCTUnwrap(visit["items"] as? [[String:Any]])
        items[0]["id"]="site-item";items[0]["quantity"]=1
        visit["items"]=items
        let timestamp=Int64(ISO8601DateFormatter().date(from:"2026-10-14T18:00:00Z")!.timeIntervalSince1970*1000)
        root["stockMovements"]=[[String:Any]]()
        var initial=root["stockLots"] as! [[String:Any]]
        initial[0]["looseUnits"]=10
        root["stockLots"]=initial
        let unknown=try N2NativeClinicalTransaction.appendSavedVisit(snapshot:bytes(root),visit:bytes(visit),approvedCatalog:fixture("n2-reviewed-approved.json"),at:timestamp)
        XCTAssertEqual(unknown.pending,0)
        XCTAssertEqual(unknown.linked,1)
        XCTAssertEqual(unknown.physicalMovementsAdded,1)
        var lots=try XCTUnwrap(root["stockLots"] as? [[String:Any]])
        for i in lots.indices {lots[i]["site"]="LA VENTUROSA"}
        root["stockLots"]=lots
        let mismatch=try N2NativeClinicalTransaction.appendSavedVisit(snapshot:bytes(root),visit:bytes(visit),approvedCatalog:fixture("n2-reviewed-approved.json"),at:timestamp)
        XCTAssertEqual(mismatch.pending,0)
        XCTAssertEqual(mismatch.linked,1)
        XCTAssertEqual(mismatch.physicalMovementsAdded,1)
        for i in lots.indices {lots[i]["site"]="PLVENTUROSA"}
        root["stockLots"]=lots
        let matching=try N2NativeClinicalTransaction.appendSavedVisit(snapshot:bytes(root),visit:bytes(visit),approvedCatalog:fixture("n2-reviewed-approved.json"),at:timestamp)
        XCTAssertEqual(matching.linked,1)
        XCTAssertEqual(matching.pending,0)
        XCTAssertEqual(matching.physicalMovementsAdded,1)
        let snapshot=try XCTUnwrap(JSONSerialization.jsonObject(with:matching.snapshot) as? [String:Any])
        let saved=try XCTUnwrap((snapshot["attentions"] as? [[String:Any]])?.first{$0["id"] as? String=="site-parity"})
        XCTAssertEqual((saved["nativeDispensing"] as? [String:String])?["site-item"],"Descontado")
    }
    func testPendingClinicalQuantityExportsOnlyAsMarkedProvisionalTenSheetWorkbook()throws {
        let snapshot=try fixture("n1e-clinical-stock.json")
        let plan=try XCTUnwrap(JSONSerialization.jsonObject(with:fixture("n1s-indicator-plan.json")) as? [String:Any])
        let products=try bytes(plan["catalog"]!)
        let mappings=try fixture("n2-reviewed-approved.json")
        let template=try fixture("n1s-indicator-template-store.zip")
        XCTAssertThrowsError(try N2VerifiedIndicatorWorkbook.export(snapshot:snapshot,products:products,mappings:mappings,template:template,start:"2026-10-09",end:"2026-11-08",subdivision:"LA VENTUROSA",selectedVisitIDs:["pending-stock"]))
        let result=try N2VerifiedIndicatorWorkbook.export(snapshot:snapshot,products:products,mappings:mappings,template:template,start:"2026-10-09",end:"2026-11-08",subdivision:"LA VENTUROSA",selectedVisitIDs:["pending-stock"],allowPending:true)
        XCTAssertTrue(result.provisional)
        XCTAssertEqual(result.pendingLines,1)
        let parts=try N1rStoredZip.unpack(result.xlsx)
        let book=String(decoding:try XCTUnwrap(parts.first{$0.name=="xl/workbook.xml"}).data,as:UTF8.self)
        XCTAssertEqual(book.components(separatedBy:"<sheet ").count-1,10)
        let consumos=String(decoding:try XCTUnwrap(parts.first{$0.name=="xl/worksheets/sheet5.xml"}).data,as:UTF8.self)
        XCTAssertTrue(consumos.contains("1000"))
        let notes=String(decoding:try XCTUnwrap(parts.first{$0.name=="xl/worksheets/sheet6.xml"}).data,as:UTF8.self)
        XCTAssertTrue(notes.contains("BORRADOR PROVISIONAL"))
        XCTAssertTrue(notes.contains("pending-stock"))
        XCTAssertTrue(notes.contains("sin salida física"))
        // Export is pure and cannot change a single physical movement.
        XCTAssertEqual(snapshot,try fixture("n1e-clinical-stock.json"))
    }
    func testBothNursingReportsIncludeTheSingleSharedInventory()throws {
        let plan=try XCTUnwrap(JSONSerialization.jsonObject(with:fixture("n2-nursing-parity.json")) as? [String:Any])
        let catalog=try XCTUnwrap(plan["catalog"] as? [[String:Any]])
        let lot:[String:Any]=["id":"SITE-TEST","code":"E-1","name":catalog[0]["name"]!,
            "catalogUnit":"UND","lot":"FICTICIO","expires":"2028-01-01",
            "container":"unidad","unitsPerContainer":1,"sealedContainers":0,
            "looseUnits":10,"openedRemaining":0,"updatedAt":1791982800000,
            "site":"LA VENTUROSA"]
        let snapshot=try N2NativeInventoryCommands.registerLot(snapshot:fixture("n1e-clinical-stock.json"),
            lot:bytes(lot),catalogData:bytes(catalog))
        let fundo=try N2NursingReportBuilder.daily(snapshot:snapshot,catalog:bytes(catalog),date:"2026-10-14",site:"LA VENTUROSA")
        let planta=try N2NursingReportBuilder.daily(snapshot:snapshot,catalog:bytes(catalog),date:"2026-10-14",site:"PLVENTUROSA")
        XCTAssertEqual(fundo.rows.filter(\.stockKnown).count,3)
        XCTAssertEqual(planta.rows.filter(\.stockKnown).count,3)
    }
    func testFrequencyPreservesEarlierVisitWhenExportingOnlyLaterSelection()throws {
        var root=try XCTUnwrap(JSONSerialization.jsonObject(with:fixture("n1e-clinical-stock.json")) as? [String:Any])
        var visits=root["attentions"] as! [[String:Any]]
        var later=visits.first{$0["id"] as? String=="pending-stock"}!
        later["id"]="later-same-day";later["time"]="23:50"
        var items=later["items"] as! [[String:Any]]
        items[0]["id"]="later-pending-item";later["items"]=items
        visits.append(later);root["attentions"]=visits
        let plan=try XCTUnwrap(JSONSerialization.jsonObject(with:fixture("n1s-indicator-plan.json")) as? [String:Any])
        let result=try N2VerifiedIndicatorWorkbook.export(snapshot:bytes(root),products:bytes(plan["catalog"]!),
            mappings:fixture("n2-reviewed-approved.json"),template:fixture("n1s-indicator-template-store.zip"),
            start:"2026-10-09",end:"2026-11-08",subdivision:"LA VENTUROSA",
            selectedVisitIDs:["later-same-day"],allowPending:true)
        let parts=try N1rStoredZip.unpack(result.xlsx)
        let xml=String(decoding:parts.first{$0.name=="xl/worksheets/sheet5.xml"}!.data,as:UTF8.self)
        XCTAssertTrue(xml.contains("SEGUNDA"))
        XCTAssertFalse(xml.contains("PRIMERA"))
    }

}
