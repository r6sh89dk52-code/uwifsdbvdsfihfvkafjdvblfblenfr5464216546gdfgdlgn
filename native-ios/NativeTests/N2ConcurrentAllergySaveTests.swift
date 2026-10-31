import XCTest
import DanperCore
@testable import DANPERNative

final class N2ConcurrentAllergySaveTests:XCTestCase {
    private var ownsDemo=false
    override func tearDown() async throws {
        #if targetEnvironment(simulator)
        if ownsDemo {
            // Only erase the fictional source this case created on the
            // workflow's fresh Simulator. Never adopt/delete an existing one.
            try await N2SyntheticTrialIOSVault.shared.eraseEntireDemo(
                confirmation:N2SyntheticResetScope.confirmation)
            let remaining=try await N2SyntheticTrialIOSVault.shared.inspect()
            XCTAssertNil(remaining)
            ownsDemo=false
        }
        #endif
        try await super.tearDown()
    }
    func testConcurrentWritesAcceptOneRevisionAndPreserveVisitsAndStock() async throws {
        #if !targetEnvironment(simulator)
        XCTFail("Requires the isolated synthetic Simulator");return
        #endif
        let vault=N2SyntheticTrialIOSVault.shared
        let existing=try await vault.inspect()
        guard existing==nil else {
            XCTFail("Requires a fresh synthetic namespace; existing data is not changed");return
        }
        _=try await vault.startEmptyDemo()
        ownsDemo=true
        var context=try await vault.clinicalFormContext()
        let dni="00009400"
        if !context.workers.contains(where:{$0.dni==dni}) {
            let worker:[String:String]=["dni":dni,"name":"PERSONA FICTICIA CONCURRENCIA",
                "site":"LA VENTUROSA","area":"PRUEBA","labor":"PRUEBA","sex":"F","age":"30","ubigeo":""]
            _=try await vault.registerWorker(JSONSerialization.data(withJSONObject:worker),
                at:1793370000000,expectedRevision:context.revision)
            context=try await vault.clinicalFormContext()
        }
        // Nonzero physical stock makes the no-debit assertion meaningful.
        let emptyInventory=try await vault.simpleInventoryContext()
        let archive=try await vault.exportPortableEncryptedBackup(password:"SOLO-FICTICIO-Concurrencia-2026")
        let product=try XCTUnwrap(emptyInventory.catalog.clinical.first{$0.code=="16000182"})
        _=try await vault.activateSimpleInventory(archive:archive,password:"SOLO-FICTICIO-Concurrencia-2026",
            request:N2SimpleActivation(id:UUID().uuidString,at:1793370000001,
                operatorName:"OPERADOR FICTICIO",confirmed:true,backupAvailable:true,
                initialProducts:[N2SimpleProduct(code:product.code,name:product.name,unit:product.unit,
                    mode:try XCTUnwrap(N2SimpleInventory.suggestedMode(unit:product.unit)),quantity:70,
                    expiry:"2027-02-10",expiryVerified:true)]),expectedRevision:emptyInventory.revision)
        context=try await vault.clinicalFormContext()
        let revision=context.revision
        let before=try await vault.readHistory()
        let inventory=try await vault.simpleInventoryContext()
        XCTAssertEqual(try XCTUnwrap(inventory.state).products.first{$0.code==product.code}?.quantity,70)
        let results=await withTaskGroup(of:Int.self,returning:[Int].self) {group in
            for i in 0..<16 {
                group.addTask {
                    do {
                        _=try await vault.reviewAllergiesRevision(dni:dni,status:"none",substances:"",
                            at:1793370000100+Int64(i),expectedRevision:revision)
                        return 1
                    } catch N2ProtectedStoreError.staleRevision {return 0}
                    catch {return -1}
                }
            }
            var all=[Int]();for await value in group {all.append(value)};return all
        }
        XCTAssertEqual(results.filter{$0==1}.count,1)
        XCTAssertEqual(results.filter{$0==0}.count,15)
        XCTAssertFalse(results.contains(-1))
        let after=try await vault.clinicalFormContext()
        XCTAssertEqual(after.revision,revision+1)
        XCTAssertEqual(after.workers,context.workers)
        XCTAssertEqual(after.lots,context.lots)
        XCTAssertEqual(after.allergies[dni]?.status,"none")
        let history=try await vault.readHistory()
        XCTAssertEqual(history?.visits,before?.visits)
        let stock=try await vault.simpleInventoryContext()
        let encoder=JSONEncoder();encoder.outputFormatting = .sortedKeys
        XCTAssertEqual(try encoder.encode(stock.state),try encoder.encode(inventory.state))
        await vault.clearSessionCaches()
        let reopened=try await vault.clinicalFormContext()
        XCTAssertEqual(reopened.revision,revision+1)
        XCTAssertEqual(reopened.allergies[dni]?.status,"none")
        XCTAssertEqual(reopened.workers,context.workers)
    }
}
