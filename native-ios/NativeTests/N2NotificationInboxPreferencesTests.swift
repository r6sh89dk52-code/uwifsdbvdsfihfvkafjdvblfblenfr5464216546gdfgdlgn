import Foundation
import XCTest
@testable import DANPERNative

final class N2NotificationInboxPreferencesTests:XCTestCase {
    func testIndividualDismissalPersistsAndModesRemainSeparate()throws {
        let suite="DANPER-FICTICIO-"+UUID().uuidString
        let defaults=try XCTUnwrap(UserDefaults(suiteName:suite))
        defer{defaults.removePersistentDomain(forName:suite)}
        XCTAssertEqual(N2NotificationInboxPreferences.dismiss("draft.ficticio-A",mode:.clinical,defaults:defaults),["draft.ficticio-A"])
        XCTAssertEqual(N2NotificationInboxPreferences.dismiss("stock.ficticio-B",mode:.clinical,defaults:defaults),["draft.ficticio-A","stock.ficticio-B"])
        XCTAssertEqual(N2NotificationInboxPreferences.read(.clinical,defaults:try XCTUnwrap(UserDefaults(suiteName:suite))),["draft.ficticio-A","stock.ficticio-B"])
        XCTAssertTrue(N2NotificationInboxPreferences.read(.demo,defaults:defaults).isEmpty)
    }
    func testRestoringPresentationPreferencesDoesNotRemoveOtherStoredData()throws {
        let suite="DANPER-FICTICIO-"+UUID().uuidString
        let defaults=try XCTUnwrap(UserDefaults(suiteName:suite))
        defer{defaults.removePersistentDomain(forName:suite)}
        let data=Data("MARCADOR FICTICIO DE DATOS AJENOS".utf8)
        defaults.set(data,forKey:"unrelated-data")
        _=N2NotificationInboxPreferences.dismiss("ficticio",mode:.clinical,defaults:defaults)
        _=N2NotificationInboxPreferences.dismiss("otro",mode:.demo,defaults:defaults)
        XCTAssertTrue(N2NotificationInboxPreferences.restore(.clinical,defaults:defaults).isEmpty)
        XCTAssertTrue(N2NotificationInboxPreferences.read(.clinical,defaults:defaults).isEmpty)
        XCTAssertEqual(N2NotificationInboxPreferences.read(.demo,defaults:defaults),["otro"])
        XCTAssertEqual(defaults.data(forKey:"unrelated-data"),data)
    }
}
