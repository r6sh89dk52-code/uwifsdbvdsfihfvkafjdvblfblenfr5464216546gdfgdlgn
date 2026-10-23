import XCTest
@testable import DanperCore

final class N2OperationalMappingTests:XCTestCase {
    private func fixture(_ name:String)throws->Data {
        let directory=try XCTUnwrap(ProcessInfo.processInfo.environment["DANPER_N1_FIXTURE_DIR"])
        return try Data(contentsOf:URL(fileURLWithPath:directory).appendingPathComponent(name))
    }
    private func bytes(_ value:Any)throws->Data {try JSONSerialization.data(withJSONObject:value)}
    private func catalog()throws->N2NativeCatalogIndex {
        let plan=try JSONSerialization.jsonObject(with:fixture("n1s-indicator-plan.json")) as! [String:Any]
        let nursing=try JSONSerialization.jsonObject(with:fixture("n2-nursing-parity.json")) as! [String:Any]
        return try N2NativeCatalogLoader.load(products:bytes(plan["catalog"]!),nursing:bytes(nursing["catalog"]!),
            approvedMappings:fixture("n2-reviewed-approved.json"))
    }
    private var now:Int64 {Int64(ISO8601DateFormatter().date(from:"2026-10-14T18:00:00Z")!.timeIntervalSince1970*1000)}
    private func rule(_ code:String,_ inventory:String,conversion:Double=1000)throws->N2OperationalMapping {
        let catalog=try catalog()
        return N2OperationalMapping(clinical:try XCTUnwrap(catalog.clinical.first{$0.code==code}),
            inventory:try XCTUnwrap(catalog.nursing.first{$0.id==inventory}),
            physicalUnit:code=="16000182" ? "UND":"mL",conversion:conversion,
            confirmedAt:now-1000,operatorName:"OPERADOR FICTICIO",
            evidence:"Etiqueta y concentración verificadas en prueba sintética")
    }
    func testExplicitConsentPersistenceAndConflict()throws {
        let original=try fixture("n1e-clinical-stock.json"),catalog=try catalog()
        let rule=try rule("16000019","E-86")
        XCTAssertThrowsError(try N2OperationalMappings.append(snapshot:original,rule:rule,catalog:catalog,explicitConsent:false))
        let saved=try N2OperationalMappings.append(snapshot:original,rule:rule,catalog:catalog,explicitConsent:true)
        XCTAssertEqual(try N2OperationalMappings.read(saved),[rule])
        XCTAssertEqual(try N2OperationalMappings.append(snapshot:saved,rule:rule,catalog:catalog,explicitConsent:true),saved)
        XCTAssertThrowsError(try N2OperationalMappings.append(snapshot:saved,rule:self.rule("16000019","E-87"),catalog:catalog,explicitConsent:true))
        XCTAssertEqual(catalog.approvals.count,86)
        XCTAssertEqual(catalog.clinical.count,432)
        XCTAssertEqual(catalog.nursing.count,98)
    }
    func testOperationalRulesPersistOnlyInsideEncryptedJournal()throws {
        let original=try fixture("n1e-clinical-stock.json")
        let rule=try rule("16000019","E-86")
        let mapped=try N2OperationalMappings.append(snapshot:original,rule:rule,catalog:catalog(),explicitConsent:true)
        let folder=FileManager.default.temporaryDirectory.appendingPathComponent("danper-n2-synthetic-"+UUID().uuidString,isDirectory:true)
        defer {try? FileManager.default.removeItem(at:folder)}
        let key=Data(repeating:0x61,count:32)
        let journal=try N2EncryptedClinicalJournal(directory:folder,secret:key)
        XCTAssertEqual(try journal.commit(mapped,expectedRevision:0),1)
        let reopened=try N2EncryptedClinicalJournal(directory:folder,secret:key)
        XCTAssertEqual(try N2OperationalMappings.read(XCTUnwrap(reopened.recover()).snapshot),[rule])
        for file in try FileManager.default.contentsOfDirectory(at:folder,includingPropertiesForKeys:nil) {
            XCTAssertNil(try Data(contentsOf:file).range(of:Data(rule.evidence.utf8)))
        }
    }
    func testIndividualConversionsCannotInventQuantities()throws {
        let original=try fixture("n1e-clinical-stock.json")
        XCTAssertThrowsError(try N2OperationalMappings.append(snapshot:original,rule:rule("16000182","E-22",conversion:2),catalog:catalog(),explicitConsent:true))
        let result=try N2OperationalMappings.append(snapshot:original,rule:rule("16000182","E-22",conversion:1),catalog:catalog(),explicitConsent:true)
        XCTAssertEqual(try N2OperationalMappings.read(result).first?.physicalUnitsPerClinicalUnit,1)
        var root=try JSONSerialization.jsonObject(with:original) as! [String:Any]
        var visit=(root["attentions"] as! [[String:Any]])[0]
        visit["id"]="operational-individual"
        let consumed=try N2NativeClinicalTransaction.appendSavedVisit(snapshot:result,visit:bytes(visit),
            approvedCatalog:fixture("n2-reviewed-approved.json"),at:now)
        XCTAssertEqual(consumed.linked,1);XCTAssertEqual(consumed.pending,0)
        root=try JSONSerialization.jsonObject(with:consumed.snapshot) as! [String:Any]
        XCTAssertEqual((root["attentions"] as? [[String:Any]])?.count,6)
    }
    func testNewRuleDoesNotBackfillHistoricalConsumption()throws {
        let original=try fixture("n1e-clinical-stock.json")
        let mapped=try N2OperationalMappings.append(snapshot:original,rule:rule("16000182","E-22",conversion:1),catalog:catalog(),explicitConsent:true)
        let root=try JSONSerialization.jsonObject(with:original) as! [String:Any]
        var visit=(root["attentions"] as! [[String:Any]])[0]
        visit["id"]="historic-operational";visit["date"]="2026-10-13"
        let result=try N2NativeClinicalTransaction.appendSavedVisit(snapshot:mapped,visit:bytes(visit),approvedCatalog:fixture("n2-reviewed-approved.json"),at:now)
        XCTAssertEqual(result.pending,1);XCTAssertEqual(result.physicalMovementsAdded,0)
        XCTAssertTrue(result.pendingReasons.first?.contains("conciliación histórica")==true)
    }
    func testAuxiliaryProductUsesSharedStockWithSeparateAccountingAnd98OfficialRows()throws {
        let catalog=try catalog(),source=try fixture("n1e-clinical-stock.json")
        let clinical=try XCTUnwrap(catalog.clinical.first{product in
            ["UND","TBL"].contains(product.unit) && !catalog.approvals.contains{$0.clinicalCode==product.code}
        })
        let lot:[String:Any]=["id":"auxiliary-synthetic-lot","code":"AUX:"+clinical.code,
            "name":clinical.name,"catalogUnit":"UND","lot":"AUX-SYNTHETIC","expires":"2027-01-01",
            "container":"unidad","unitsPerContainer":1,"sealedContainers":0,"looseUnits":3,
            "openedRemaining":0,"updatedAt":now-2000]
        XCTAssertThrowsError(try N2AuxiliaryInventory.register(snapshot:source,clinicalCode:clinical.code,
            lot:bytes(lot),catalog:catalog,operatorName:"OPERADOR FICTICIO",evidence:"Producto y conteo ficticios verificados",at:now-2000,explicitConsent:false))
        let stocked=try N2AuxiliaryInventory.register(snapshot:source,clinicalCode:clinical.code,
            lot:bytes(lot),catalog:catalog,operatorName:"OPERADOR FICTICIO",evidence:"Producto y conteo ficticios verificados",at:now-2000,explicitConsent:true)
        let inventory=try XCTUnwrap(N2AuxiliaryInventory.products(snapshot:stocked).first)
        let rule=N2OperationalMapping(clinical:clinical,inventory:inventory,physicalUnit:"UND",conversion:1,
            confirmedAt:now-1000,operatorName:"OPERADOR FICTICIO",evidence:"Equivalencia individual verificada en prueba")
        let mapped=try N2OperationalMappings.append(snapshot:stocked,rule:rule,catalog:catalog,explicitConsent:true)
        let root=try JSONSerialization.jsonObject(with:source) as! [String:Any]
        var visit=(root["attentions"] as! [[String:Any]])[0]
        visit["id"]="auxiliary-visit"
        visit["items"]=[["id":"auxiliary-item","code":clinical.code,"name":clinical.name,
                         "unit":clinical.unit,"quantity":1,"procedure":"OBSERVACION"]]
        let result=try N2NativeClinicalTransaction.appendSavedVisit(snapshot:mapped,visit:bytes(visit),
            approvedCatalog:fixture("n2-reviewed-approved.json"),at:now)
        XCTAssertEqual(result.linked,1);XCTAssertEqual(result.pending,0)
        let report=try XCTUnwrap(JSONSerialization.jsonObject(with:Data(N2AuxiliaryInventory.accounting(snapshot:result.snapshot).utf8)) as? [String:Any])
        XCTAssertEqual((report["movements"] as? [[String:Any]])?.count,1)
        XCTAssertEqual(((report["lots"] as? [[String:Any]])?.first?["looseUnits"] as? NSNumber)?.intValue,2)
        let nursing=try JSONSerialization.jsonObject(with:fixture("n2-nursing-parity.json")) as! [String:Any]
        let official=try N2NursingReportBuilder.daily(snapshot:result.snapshot,catalog:bytes(nursing["catalog"]!),date:"2026-10-14")
        XCTAssertEqual(official.rows.count,98)
        XCTAssertEqual(catalog.approvals.count,86)
    }
    func testAlcoholTwoBottlesReusesOpenedContentAndNeverDoubleDebits()throws {
        let catalog=try catalog()
        var root=try JSONSerialization.jsonObject(with:fixture("n1e-clinical-stock.json")) as! [String:Any]
        var lots=root["stockLots"] as! [[String:Any]]
        let nursing=try XCTUnwrap(catalog.nursing.first{$0.id=="E-86"})
        lots.append(["id":"operational-alcohol","code":"E-86","name":nursing.name,
            "catalogUnit":"FCO","lot":"SYNTHETIC","expires":"2027-01-01","container":"frasco",
            "unitsPerContainer":1000,"sealedContainers":2,"looseUnits":0,"openedRemaining":0,"updatedAt":now-2000])
        root["stockLots"]=lots
        let source=try bytes(root)
        let alcohol=try XCTUnwrap(catalog.clinical.first{$0.code=="16000019"})
        var visit=(root["attentions"] as! [[String:Any]])[0]
        visit["id"]="operational-first"
        visit["time"]="13:00"
        visit["items"]=[["id":"alcohol-item","code":alcohol.code,"name":alcohol.name,
            "unit":alcohol.unit,"quantity":1,"procedure":"OBSERVACION",
            "physicalUse":["quantity":5,"confirmNewContainer":false]]]
        let unmapped=try N2NativeClinicalTransaction.appendSavedVisit(snapshot:source,visit:bytes(visit),approvedCatalog:fixture("n2-reviewed-approved.json"),at:now)
        XCTAssertEqual(unmapped.pending,1);XCTAssertEqual(unmapped.physicalMovementsAdded,0)
        let mapped=try N2OperationalMappings.append(snapshot:source,rule:rule("16000019","E-86"),catalog:catalog,explicitConsent:true)
        let pending=try N2NativeClinicalTransaction.appendSavedVisit(snapshot:mapped,visit:bytes(visit),approvedCatalog:fixture("n2-reviewed-approved.json"),at:now)
        XCTAssertEqual(pending.pending,1);XCTAssertEqual(pending.physicalMovementsAdded,0)
        let evidence=N2PendingDispensingEvidence(visitID:"operational-first",itemID:"alcohol-item",lotID:"operational-alcohol",
            quantity:5,confirmNewContainer:true,operatorName:"OPERADOR FICTICIO",reason:"Apertura y consumo físicos verificados",at:now+1)
        XCTAssertThrowsError(try evidence.append(snapshot:pending.snapshot,explicitConsent:false))
        let authorized=try evidence.append(snapshot:pending.snapshot,explicitConsent:true)
        let first=try N2NativeClinicalTransaction.retryCurrentSavedVisit(snapshot:authorized,visitID:"operational-first",approvedCatalog:fixture("n2-reviewed-approved.json"),at:now+1)
        let firstRoot=try JSONSerialization.jsonObject(with:first.snapshot) as! [String:Any]
        let original=try XCTUnwrap((firstRoot["attentions"] as! [[String:Any]]).first{$0["id"] as? String=="operational-first"})
        let originalItems=original["items"] as! [[String:Any]]
        XCTAssertEqual((originalItems[0]["physicalUse"] as? [String:Any])?["confirmNewContainer"] as? Bool,false)
        XCTAssertEqual(try evidence.append(snapshot:first.snapshot,explicitConsent:true),first.snapshot)
        let physical=(firstRoot["stockMovements"] as! [[String:Any]]).last
        XCTAssertEqual(physical?["physicalEvidenceID"] as? String,evidence.id)
        XCTAssertEqual(first.linked,1);XCTAssertEqual(first.pending,0)
        visit["id"]="operational-second"
        var items=visit["items"] as! [[String:Any]]
        items[0]["physicalUse"]=["quantity":5,"confirmNewContainer":false]
        visit["items"]=items
        let second=try N2NativeClinicalTransaction.appendSavedVisit(snapshot:first.snapshot,visit:bytes(visit),approvedCatalog:fixture("n2-reviewed-approved.json"),at:now+1)
        XCTAssertEqual(second.linked,1);XCTAssertEqual(second.pending,0)
        let final=try JSONSerialization.jsonObject(with:second.snapshot) as! [String:Any]
        let lot=try XCTUnwrap((final["stockLots"] as! [[String:Any]]).first{$0["id"] as? String=="operational-alcohol"})
        XCTAssertEqual((lot["sealedContainers"] as? NSNumber)?.intValue,1)
        XCTAssertEqual((lot["openedRemaining"] as? NSNumber)?.intValue,990)
        let movements=(final["stockMovements"] as! [[String:Any]]).filter{$0["lotId"] as? String=="operational-alcohol"}
        XCTAssertEqual(movements.compactMap{($0["excelQuantity"] as? NSNumber)?.intValue},[1,0])
        XCTAssertTrue(movements.allSatisfy{$0["operationalMappingID"] != nil})
        let repeated=try N2NativeClinicalTransaction.retryCurrentSavedVisit(snapshot:second.snapshot,visitID:"operational-second",approvedCatalog:fixture("n2-reviewed-approved.json"),at:now+2)
        XCTAssertEqual(repeated.physicalMovementsAdded,0)
    }
}
