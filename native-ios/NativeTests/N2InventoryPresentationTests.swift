import XCTest
import DanperCore
import UIKit
@testable import DANPERNative

final class N2InventoryPresentationTests:XCTestCase {
    private func catalog() throws->N2NativeCatalogIndex {
        func data(_ name:String)throws->Data {
            try Data(contentsOf:XCTUnwrap(Bundle.main.url(forResource:name,withExtension:"json",subdirectory:"N1sDemoResources")))
        }
        return try N2NativeCatalogLoader.load(products:data("n2-ambulatory-products"),nursing:data("n2-nursing-catalog"),approvedMappings:data("n2-approved-mappings"))
    }
    private func product(_ code:String="16000182",catalog:N2NativeCatalogIndex,expiry:String="",verified:Bool=false,quantity:Double=0)throws->N2SimpleProduct {
        let p=try XCTUnwrap(catalog.clinical.first{$0.code==code})
        return N2SimpleProduct(code:p.code,name:p.name,unit:p.unit,mode:.units,quantity:quantity,expiry:expiry,expiryVerified:verified)
    }
    func testCategoriesComeOnlyFromVerifiedGroupsAndUnknownsStayInAll() throws {
        let c=try catalog()
        XCTAssertEqual(N2InventoryPresentation.category(code:"16000182",catalog:c),.medications)
        XCTAssertEqual(N2InventoryPresentation.category(code:"16000025",catalog:c),.supplies)
        XCTAssertEqual(N2InventoryPresentation.category(code:"16000148",catalog:c),.supplies)
        XCTAssertNil(N2InventoryPresentation.category(code:"16025544",catalog:c))
        let products=try ["16000182","16000025","16025544"].map{try product($0,catalog:c)}
        XCTAssertEqual(N2InventoryPresentation.products(products,catalog:c,filter:.all,query:"").count,3)
        XCTAssertEqual(N2InventoryPresentation.products(products,catalog:c,filter:.medications,query:"").map(\.code),["16000182"])
        XCTAssertEqual(N2InventoryPresentation.products(products,catalog:c,filter:.supplies,query:"").map(\.code),["16000025"])
        // The same supplied catalog is unchanged; no unit normalization or mutation.
        XCTAssertEqual(c.clinical.first{$0.code=="16000025"}?.unit,"FCO")
    }
    func testAll432CatalogCodesRetain341UnclassifiedProductsInAll() throws {
        let c=try catalog()
        let products=try c.clinical.map { try product($0.code,catalog:c) }
        let all=N2InventoryPresentation.products(products,catalog:c,filter:.all,query:"")
        let medications=N2InventoryPresentation.products(products,catalog:c,filter:.medications,query:"")
        let supplies=N2InventoryPresentation.products(products,catalog:c,filter:.supplies,query:"")
        let unknown=products.filter { N2InventoryPresentation.category(code:$0.code,catalog:c)==nil }
        XCTAssertEqual(all.count,432)
        XCTAssertEqual(medications.count,38)
        XCTAssertEqual(supplies.count,53)
        XCTAssertEqual(unknown.count,341)
        XCTAssertEqual(Set(all.map(\.code)),Set(products.map(\.code)))
        XCTAssertTrue(Set(unknown.map(\.code)).isDisjoint(with:Set((medications+supplies).map(\.code))))
    }
    func testIntegratedSearchSupportsNameCodeAndOriginalPresentation() throws {
        let c=try catalog(),products=try ["16000182","16000025"].map{try product($0,catalog:c)}
        for q in [" paracetamol ","16000182","UND"] {
            XCTAssertEqual(N2InventoryPresentation.products(products,catalog:c,filter:.all,query:q).map(\.code),["16000182"])
        }
        XCTAssertEqual(N2InventoryPresentation.products(products,catalog:c,filter:.supplies,query:"fco").map(\.code),["16000025"])
        XCTAssertTrue(N2InventoryPresentation.products(products,catalog:c,filter:.medications,query:"fco").isEmpty)
    }
    func testExpiryBoundaryThirtyDaysAndZeroStockAreIndependent() throws {
        let c=try catalog(),now=ISO8601DateFormatter().date(from:"2026-10-27T17:00:00Z")!
        for (date,expected) in [("2026-10-26",N2InventoryPresentation.Expiry.expired),("2026-10-27",.near),("2026-11-26",.near),("2026-11-27",.valid)] {
            let p=try product(catalog:c,expiry:date,verified:true,quantity:0)
            XCTAssertEqual(N2InventoryPresentation.expiry(p,now:now),expected)
            XCTAssertEqual(p.quantity,0)
        }
        let pending=try product(catalog:c,expiry:"2025-01-01",verified:false,quantity:99)
        XCTAssertEqual(N2InventoryPresentation.expiry(pending,now:now),.unverified)
        XCTAssertEqual(N2InventoryPresentation.expiryText(pending,now:now),"Pendiente de verificar")
        XCTAssertFalse(N2InventoryPresentation.expiryText(pending,now:now).contains("2025"))
    }
    @MainActor func testExactSuppliedAssetsAreBundledAndSpecificSymbolsFollowGroups() throws {
        XCTAssertNotNil(UIImage(named:"ClinicalPortrait"));XCTAssertNotNil(UIImage(named:"ClinicalAvatar"))
        let c=try catalog()
        XCTAssertEqual(N2InventoryPresentation.symbol(try product(catalog:c),catalog:c),"pills.fill")
        XCTAssertEqual(N2InventoryPresentation.symbol(try product("16000025",catalog:c),catalog:c),"waterbottle.fill")
        XCTAssertEqual(N2InventoryPresentation.symbol(try product("16000148",catalog:c),catalog:c),"syringe.fill")
        XCTAssertEqual(N2InventoryPresentation.symbol(try product("16000235",catalog:c),catalog:c),"bandage.fill")
    }
}
