import Foundation
import XCTest
@testable import DanperCore

final class N2ReconciliationEditorTests:XCTestCase {
    private func source(_ name:String)throws->Data {
        let folder=try XCTUnwrap(ProcessInfo.processInfo.environment["DANPER_N1_FIXTURE_DIR"])
        return try Data(contentsOf:URL(fileURLWithPath:folder).appendingPathComponent(name))
    }
    private func catalog()throws->Data {
        let reference=try XCTUnwrap(JSONSerialization.jsonObject(
            with:source("n1q-reviewed-expected.json")) as? [String:Any])
        return try JSONSerialization.data(withJSONObject:reference["catalog"]!)
    }
    private func event(_ kind:String,id:String,code:String="",qty:Int=0,
                       until:String="",voidOf:String="")->Data {
        let value:[String:Any]=[
            "id":id,"kind":kind,"subdivision":"LA VENTUROSA",
            "code":code,"date":"2026-10-09","at":1791600000000,
            "quantity":qty,"reason":"Evidencia verificada",
            "document":"","expires":"","periodEnd":until,"voidOf":voidOf]
        return try! JSONSerialization.data(withJSONObject:value)
    }
    func testAppendVoidAndKeepClinicalSourceUnchanged()throws {
        let original=try source("n1e-clinical-stock.json")
        let p=try catalog()
        let opening=event("opening",id:"audit-a",code:"16000182",qty:10)
        let first=try N2NativeReconciliationEditor.append(
            snapshot:original,event:opening,catalog:p)
        let result=try N2NativeReconciliationEditor.list(snapshot:first)
        XCTAssertEqual(result.count,1)
        XCTAssertEqual(result[0].quantity,10)
        XCTAssertThrowsError(try N2NativeReconciliationEditor.append(
            snapshot:first,event:opening,catalog:p)){
            XCTAssertEqual($0 as? N2ReconciliationEditError,.invalidEvent)
        }
        let cancelled=try N2NativeReconciliationEditor.append(
            snapshot:first,event:event("void",id:"audit-void",voidOf:"audit-a"),
            catalog:p)
        let rows=try N2NativeReconciliationEditor.list(snapshot:cancelled)
        XCTAssertEqual(rows.count,2)
        XCTAssertTrue(rows.first{$0.id=="audit-a"}!.voided)
        let source1=try XCTUnwrap(JSONSerialization.jsonObject(
            with:original) as? [String:Any])
        let source2=try XCTUnwrap(JSONSerialization.jsonObject(
            with:cancelled) as? [String:Any])
        XCTAssertEqual((source1["stockMovements"] as? [[String:Any]])?.count,
                       (source2["stockMovements"] as? [[String:Any]])?.count)
        XCTAssertEqual((source1["attentions"] as? [[String:Any]])?.count,
                       (source2["attentions"] as? [[String:Any]])?.count)
    }
}
