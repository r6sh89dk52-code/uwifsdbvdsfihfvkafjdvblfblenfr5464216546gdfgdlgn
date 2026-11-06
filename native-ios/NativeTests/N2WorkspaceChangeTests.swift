import XCTest
import Foundation
import DanperCore
@testable import DANPERNative

final class N2WorkspaceChangeTests:XCTestCase {
    private final class Recorder:@unchecked Sendable {
        private let lock=NSLock()
        private var values=[Int]()
        func append(_ value:Int){lock.lock();values.append(value);lock.unlock()}
        func snapshot()->[Int]{lock.lock();defer{lock.unlock()};return values}
    }
    func testWriteInvalidationFollowsVerifiedPersistenceAndRejectsFailedRevision() async throws {
        let demo=N2SyntheticTrialIOSVault.shared
        if try await demo.inspect()==nil {_=try await demo.startEmptyDemo()}
        var context=try await demo.clinicalFormContext()
        if context.workers.isEmpty {
            let worker:[String:String]=["dni":"00009402","name":"PERSONA FICTICIA REFRESCO",
                "site":"LA VENTUROSA","area":"PRUEBA","labor":"PRUEBA","sex":"F","age":"30","ubigeo":""]
            _=try await demo.registerWorker(JSONSerialization.data(withJSONObject:worker),at:1793370000000,expectedRevision:context.revision)
            context=try await demo.clinicalFormContext()
        }
        let recorder=Recorder()
        let token=NotificationCenter.default.addObserver(forName:N2WorkspaceChanges.notification,object:nil,queue:nil) { event in
            guard N2WorkspaceChanges.matches(event,.demo),let revision=event.userInfo?["revision"] as? Int else{return}
            XCTAssertEqual(Set(event.userInfo?.keys.compactMap{$0 as? String} ?? []),["revision","kind"])
            recorder.append(revision)
        }
        defer {NotificationCenter.default.removeObserver(token)}
        var form=N2NativeFormDraft(id:UUID().uuidString)
        form.dni=try XCTUnwrap(context.workers.first).dni
        form.date="2026-11-06";form.time="10:00"
        let patch=try form.makeDraftPatch(context:context,stage:0)
        let saved=try await N2WorkspaceVault.demo.saveDraft(id:form.id,changes:patch,at:1793370000100,expectedRevision:context.revision)
        XCTAssertEqual(recorder.snapshot(),[saved.revision])
        let persisted=try await demo.readDraftsWithRevision()
        XCTAssertEqual(persisted.revision,saved.revision)
        XCTAssertTrue(persisted.drafts.contains{$0.id==form.id})
        do {
            _=try await N2WorkspaceVault.demo.saveDraft(id:form.id,changes:patch,at:1793370000200,expectedRevision:context.revision)
            XCTFail("A stale write must fail before broadcasting")
        } catch N2ProtectedStoreError.staleRevision {}
        XCTAssertEqual(recorder.snapshot(),[saved.revision])
        _=try await demo.deleteDraft(id:form.id,expectedRevision:saved.revision)
    }
}
