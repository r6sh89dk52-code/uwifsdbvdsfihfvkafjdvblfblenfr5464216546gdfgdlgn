import Foundation
import XCTest
@testable import DanperCore

final class N2InventoryCommandsTests:XCTestCase {
    private func fixture(_ name:String)throws->Data {
        let dir=try XCTUnwrap(ProcessInfo.processInfo.environment["DANPER_N1_FIXTURE_DIR"])
        return try Data(contentsOf:URL(fileURLWithPath:dir)
            .appendingPathComponent(name))
    }
    private func dictionary(_ bytes:Data)throws->[String:Any] {
        try XCTUnwrap(JSONSerialization.jsonObject(with:bytes) as? [String:Any])
    }
    private func canonical(_ object:Any)throws->Data {
        try JSONSerialization.data(withJSONObject:object,options:[.sortedKeys])
    }
    func testStockReceiptAdjustmentAndIdempotencyMatchLegacyMovementEngine()throws {
        let source=try fixture("n1e-clinical-stock.json")
        let reference=try dictionary(fixture("n2-stock-parity.json"))
        let events=try XCTUnwrap(reference["events"] as? [[String:Any]])
        let first=events[0],second=events[1]
        let receipt=try N2NativeInventoryCommands.extraordinary(
            snapshot:source,movementID:first["id"] as! String,
            lotID:first["lotId"] as! String,
            at:Int64((first["at"] as! NSNumber).doubleValue),
            sealedAdded:first["sealedAdded"] as! Int,
            looseAdded:(first["looseAdded"] as! NSNumber).doubleValue,
            reason:first["description"] as! String)
        let expected1=reference["afterFirst"] as! [String:Any]
        let firstRoot=try dictionary(receipt)
        XCTAssertEqual(try canonical(firstRoot["stockLots"]!),
                       try canonical(expected1["lots"]!))
        XCTAssertEqual(try canonical(firstRoot["stockMovements"]!),
                       try canonical(expected1["movements"]!))
        let adjusted=try N2NativeInventoryCommands.adjustment(
            snapshot:receipt,movementID:second["id"] as! String,
            lotID:second["lotId"] as! String,
            at:Int64((second["at"] as! NSNumber).doubleValue),
            newSealed:second["newSealed"] as! Int,
            newLoose:(second["newLoose"] as! NSNumber).doubleValue,
            newOpened:(second["newOpened"] as! NSNumber).doubleValue,
            reason:second["description"] as! String)
        let expected2=reference["afterSecond"] as! [String:Any]
        let secondRoot=try dictionary(adjusted)
        XCTAssertEqual(try canonical(secondRoot["stockLots"]!),
                       try canonical(expected2["lots"]!))
        XCTAssertEqual(try canonical(secondRoot["stockMovements"]!),
                       try canonical(expected2["movements"]!))
        _=try N1eLegacyClinicalAudit.inspect(adjusted)
        XCTAssertEqual(try N2NativeInventoryCommands.adjustment(
            snapshot:adjusted,movementID:second["id"] as! String,
            lotID:second["lotId"] as! String,
            at:Int64((second["at"] as! NSNumber).doubleValue),
            newSealed:second["newSealed"] as! Int,
            newLoose:(second["newLoose"] as! NSNumber).doubleValue,
            newOpened:(second["newOpened"] as! NSNumber).doubleValue,
            reason:second["description"] as! String),adjusted)
    }
    func testInventoryRejectsUndocumentedAndDuplicateStock()throws {
        let source=try fixture("n1e-clinical-stock.json")
        XCTAssertThrowsError(try N2NativeInventoryCommands.extraordinary(
            snapshot:source,movementID:"X",lotID:"early-unit",at:1_760_530_000_000,
            sealedAdded:0,looseAdded:0,reason:"Motivo documentado")) {
            XCTAssertEqual($0 as? N2InventoryError,.invalidMovement)
        }
        let parity=try dictionary(fixture("n2-nursing-parity.json"))
        let catalog=try canonical(parity["catalog"]!)
        let existing=try dictionary(source)["stockLots"] as! [[String:Any]]
        var candidate=existing[0]
        candidate["id"]="N2:NEW-LOT-001"
        candidate["lot"]="TEST-NEW-LOT"
        candidate["sealedContainers"]=1
        candidate["looseUnits"]=0
        candidate["openedRemaining"]=0
        let updated=try N2NativeInventoryCommands.registerLot(
            snapshot:source,lot:canonical(candidate),catalogData:catalog)
        XCTAssertEqual((try dictionary(updated)["stockLots"] as! [[String:Any]]).count,6)
        XCTAssertThrowsError(try N2NativeInventoryCommands.registerLot(
            snapshot:updated,lot:canonical(candidate),catalogData:catalog)) {
            XCTAssertEqual($0 as? N2InventoryError,.duplicateLot)
        }
    }

    func testMetadataCorrectionOnlyOnUnusedLotAndDoesNotRewriteMovements()throws {
        let source=try fixture("n1e-clinical-stock.json")
        let sourceRoot=try dictionary(source)
        let parity=try dictionary(fixture("n2-nursing-parity.json"))
        let catalog=try canonical(parity["catalog"]!)
        var candidate=try XCTUnwrap((sourceRoot["stockLots"] as? [[String:Any]])?.first)
        candidate["id"]="N2-UNUSED-METADATA-LOT"
        candidate["lot"]="ANTES-123"
        candidate["expires"]="2027-11-02"
        candidate["sealedContainers"]=0
        candidate["looseUnits"]=2
        candidate["openedRemaining"]=0
        let registered=try N2NativeInventoryCommands.registerLot(
            snapshot:source,lot:canonical(candidate),catalogData:catalog)
        let before=try dictionary(registered)
        let result=try N2NativeInventoryCommands.correctUnusedLot(
            snapshot:registered,lotID:"N2-UNUSED-METADATA-LOT",
            reference:"DESPUES-456",expires:"2027-12-03",
            reason:"Número de lote corregido con etiqueta física",
            operatorName:"ENFERMERIA RESPONSABLE",at:1793000000000)
        let updated=try dictionary(result)
        XCTAssertEqual(try canonical(updated["stockMovements"]!),
                       try canonical(before["stockMovements"]!))
        let changed=try XCTUnwrap((updated["stockLots"] as? [[String:Any]])?
            .first(where:{$0["id"] as? String=="N2-UNUSED-METADATA-LOT"}))
        XCTAssertEqual(changed["lot"] as? String,"DESPUES-456")
        XCTAssertEqual(changed["expires"] as? String,"2027-12-03")
        XCTAssertEqual(changed["looseUnits"] as? Int,2)
        XCTAssertEqual((updated["nativeLotMetadataCorrections"] as? [[String:Any]])?.count,1)
        XCTAssertThrowsError(try N2NativeInventoryCommands.correctUnusedLot(
            snapshot:registered,lotID:"early-unit",reference:"NO-ALTERAR",
            expires:"2027-12-03",reason:"Cambio prohibido de lote ya usado",
            operatorName:"ENFERMERIA RESPONSABLE",at:1793000000001)){
            XCTAssertEqual($0 as? N2InventoryError,.invalidLot)
        }
    }

}
