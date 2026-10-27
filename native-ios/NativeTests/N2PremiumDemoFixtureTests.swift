import XCTest
import DanperCore
@testable import DANPERNative

/// Seed only this run's isolated simulator DEMO for recovery/deletion UI tests.
/// Never activates, reads or mutates the protected clinical source.
final class N2PremiumDemoFixtureTests:XCTestCase {
    func testPrepareSyntheticDraftForRedesignJourney() async throws {
        #if !targetEnvironment(simulator)
        throw XCTSkip("Synthetic UI fixtures run only in Simulator")
        #endif
        let vault=N2SyntheticTrialIOSVault.shared
        if try await vault.inspect()==nil {_=try await vault.startEmptyDemo()}
        var context=try await vault.clinicalFormContext()
        if !context.workers.contains(where:{$0.dni=="00000071"}) {
            let worker:[String:Any]=["dni":"00000071","name":"PERSONA FICTICIA REDISENO",
                "sex":"F","age":"36","area":"PRUEBA","labor":"PRUEBA","ubigeo":""]
            _=try await vault.registerWorker(JSONSerialization.data(withJSONObject:worker),
                at:Int64(Date().timeIntervalSince1970*1000),expectedRevision:context.revision)
            context=try await vault.clinicalFormContext()
        }
        let before=try await vault.inspect()
        var draft=N2NativeFormDraft(id:"premium-ui-draft")
        draft.dni="00000071";draft.date=N2HomeCalendarPeriod(now:Date()).today
        draft.time="09:30";draft.diagnosis="BORRADOR FICTICIO REDISENO"
        _=try await vault.saveDraft(id:draft.id,changes:draft.makeDraftPatch(context:context,stage:1),
            at:Int64(Date().timeIntervalSince1970*1000),expectedRevision:context.revision)
        let restored=try await vault.readDrafts()
        XCTAssertEqual(restored.first{$0.id==draft.id}?.form.diagnosis,draft.diagnosis)
        let after=try await vault.inspect()
        XCTAssertEqual(after?.physicalMovements,before?.physicalMovements)
        XCTAssertEqual(after?.saved,before?.saved)
    }
}
