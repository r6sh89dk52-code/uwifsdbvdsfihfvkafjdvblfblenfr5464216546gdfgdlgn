import Foundation
import XCTest
@testable import DanperCore

final class N2NativeCatalogIndexTests:XCTestCase {
    private func fixture(_ name:String)throws->Data {
        let folder=try XCTUnwrap(ProcessInfo.processInfo.environment["DANPER_N1_FIXTURE_DIR"])
        return try Data(contentsOf:URL(fileURLWithPath:folder)
            .appendingPathComponent(name))
    }
    private func sources()throws->(Data,Data,Data) {
        let original=try XCTUnwrap(JSONSerialization.jsonObject(
            with:fixture("n1s-indicator-plan.json")) as? [String:Any])
        let cases=try XCTUnwrap(JSONSerialization.jsonObject(
            with:fixture("n2-nursing-parity.json")) as? [String:Any])
        return (try JSONSerialization.data(withJSONObject:original["catalog"]!),
                try JSONSerialization.data(withJSONObject:cases["catalog"]!),
                try fixture("n2-reviewed-approved.json"))
    }
    func testExact432ClinicalAnd98NursingAnd86ApprovedIdentityLinks()throws {
        let (clinical,nursing,mappings)=try sources()
        let index=try N2NativeCatalogLoader.load(products:clinical,nursing:nursing,
                                                   approvedMappings:mappings)
        XCTAssertEqual(index.clinical.count,432)
        XCTAssertEqual(index.nursing.count,98)
        XCTAssertEqual(index.approvals.count,86)
        XCTAssertEqual(index.authorizedNursingOptions(for:"16024400").count,2)
        XCTAssertTrue(index.authorizedNursingOptions(for:"99999999").isEmpty)
        XCTAssertEqual(index.clinicalMatches("16000182").first?.code,"16000182")
        XCTAssertEqual(index.nursingMatches("E-68").first?.id,"E-68")
        XCTAssertFalse(index.approvals.contains{$0.kardexID=="E-68"})
    }
    func testModifiedMappingOrClinicalCatalogIsRejected()throws {
        let (clinical,nursing,mappings)=try sources()
        var corrupt=try XCTUnwrap(JSONSerialization.jsonObject(with:mappings)
                                  as? [[String:Any]])
        corrupt[0]["clinicalName"]="NAME REPLACED"
        let tampered=try JSONSerialization.data(withJSONObject:corrupt)
        XCTAssertThrowsError(try N2NativeCatalogLoader.load(
            products:clinical,nursing:nursing,approvedMappings:tampered)) {
            XCTAssertEqual($0 as? N2CatalogError,.invalidApprovals)
        }
        var products=try XCTUnwrap(JSONSerialization.jsonObject(with:clinical)
                                   as? [[String:Any]])
        products[1]["code"]=products[0]["code"]
        let duplicate=try JSONSerialization.data(withJSONObject:products)
        XCTAssertThrowsError(try N2NativeCatalogLoader.load(
            products:duplicate,nursing:nursing,approvedMappings:mappings)) {
            XCTAssertEqual($0 as? N2CatalogError,.invalidClinicalCatalog)
        }
    }
}
