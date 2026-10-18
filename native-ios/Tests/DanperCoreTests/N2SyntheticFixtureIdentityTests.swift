import Foundation
import XCTest
@testable import DanperCore

final class N2SyntheticFixtureIdentityTests:XCTestCase {
    private func workers()->[[String:Any]] {
        N2SyntheticFixtureIdentity.names.keys.sorted().map {
            ["dni":$0,"name":N2SyntheticFixtureIdentity.names[$0]!]
        }
    }
    func testGeneratedNaturalNamesAdmittedButGenericOrModifiedRecordsRejected() {
        let registered=workers()
        let visits:[[String:Any]]=[
            ["worker":["dni":"00000001","name":"Mariana Torres Salazar"]],
            ["worker":["dni":"00000005","name":"Valeria Ríos Medina"]]
        ]
        XCTAssertTrue(N2SyntheticFixtureIdentity.matches(workers:registered,visits:visits))
        var changed=registered
        changed[0]["name"]="PERSONA FICTICIA UNO"
        XCTAssertFalse(N2SyntheticFixtureIdentity.matches(workers:changed,visits:visits))
        changed=registered
        changed[0]["dni"]="41728463"
        XCTAssertFalse(N2SyntheticFixtureIdentity.matches(workers:changed,visits:visits))
        XCTAssertFalse(N2SyntheticFixtureIdentity.matches(
            workers:registered,visits:[["worker":["dni":"00000001","name":"Distinto"]]]))
        XCTAssertFalse(N2SyntheticFixtureIdentity.matches(
            workers:registered+registered.prefix(1),visits:[]))
        XCTAssertFalse(N2SyntheticFixtureIdentity.matches(workers:registered,visits:[
            ["worker":["dni":"12345678","name":"Mariana Torres Salazar"]]
        ]))
    }
}
