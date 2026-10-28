import XCTest
import DanperCore
@testable import DANPERNative

/// Explicit synthetic-only fixture for v2 UI journeys. The production clinical
/// source is never read, activated or changed by this test.
final class N2SimpleInventoryNativeTests:XCTestCase {
    func testPrepareConsolidatedDemoAndVerifyEncryptedRecovery() async throws {
        #if !targetEnvironment(simulator)
        throw XCTSkip("Requires isolated Simulator with fictional DEMO data")
        #endif
        let vault=N2SyntheticTrialIOSVault.shared
        if try await vault.inspect()==nil {_=try await vault.startEmptyDemo()}
        let form=try await vault.clinicalFormContext()
        if !form.workers.contains(where:{$0.dni=="00000031"}) {
            let worker:[String:Any]=["dni":"00000031","name":"PERSONA FICTICIA KARDEX V2","sex":"F","age":"30","area":"PRUEBA","labor":"PRUEBA","ubigeo":"","site":"LA VENTUROSA"]
            _=try await vault.registerWorker(JSONSerialization.data(withJSONObject:worker),at:Int64(Date().timeIntervalSince1970*1000),expectedRevision:form.revision)
        }
        var context=try await vault.simpleInventoryContext()
        if context.state==nil {
            let password="SOLO-FICTICIO-Kardex-2026"
            let backup=try await vault.exportPortableEncryptedBackup(password:password)
            let destination=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString+".danperbackup")
            defer{try? FileManager.default.removeItem(at:destination)}
            try backup.write(to:destination,options:.atomic)
            let available=try Data(contentsOf:destination)
            let review=try await vault.inspectSimpleBackup(available,password:password)
            XCTAssertEqual(review.domain,.demo)
            let products=try [("16000182",70.0),("16000025",12.0)].map {code,quantity in
                let source=try XCTUnwrap(context.catalog.clinical.first{$0.code==code})
                return N2SimpleProduct(code:code,name:source.name,unit:source.unit,
                    mode:N2SimpleInventory.suggestedMode(unit:source.unit)!,quantity:quantity,expiry:"2027-02-10",expiryVerified:true)
            }
            _=try await vault.activateSimpleInventory(archive:available,password:password,request:N2SimpleActivation(
                id:UUID().uuidString,at:Int64(Date().timeIntervalSince1970*1000),operatorName:"OPERADOR FICTICIO",
                confirmed:true,backupAvailable:true,initialProducts:products),expectedRevision:context.revision)
            context=try await vault.simpleInventoryContext()
        }
        if let existing=context.state {
            for (code,target) in [("16000182",70.0),("16000025",12.0)] where existing.products.first(where:{$0.code==code})?.quantity != target {
                _=try await vault.applySimpleInventoryCommand(N2SimpleInventoryCommand(id:UUID().uuidString,operation:.count,code:code,quantity:target,
                    at:Int64(Date().timeIntervalSince1970*1000),operatorName:"OPERADOR FICTICIO",reason:"Preparación explícita del conteo DEMO para repetición de prueba"),expectedRevision:context.revision)
                context=try await vault.simpleInventoryContext()
            }
        }
        let state=try XCTUnwrap(context.state)
        XCTAssertEqual(state.products.count,2)
        XCTAssertEqual(state.products.first{$0.code=="16000182"}?.quantity,70)
        XCTAssertEqual(state.products.first{$0.code=="16000025"}?.quantity,12)
        let password="SOLO-FICTICIO-Kardex-2026"
        let archive=try await vault.exportPortableEncryptedBackup(password:password)
        let review=try await vault.inspectSimpleBackup(archive,password:password)
        XCTAssertEqual(review.schemaVersion,2)
        let reopened=try await vault.simpleInventoryContext()
        XCTAssertEqual(reopened.state?.regime.id,state.regime.id)
    }
}
