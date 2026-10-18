import XCTest
@testable import DanperCore

final class N2MedicationAllergyTextMatchTests:XCTestCase {
    func testAccentedNamesAndSeparatorConservativelyMatch() {
        XCTAssertEqual(N2MedicationAllergyTextMatch.matches(
            productName:"Paracetamól 500 mg comprimidos",
            substances:"ibuprofeno; PARACETAMOL"),["PARACETAMOL"])
        XCTAssertEqual(N2MedicationAllergyTextMatch.matches(
            productName:"Gentamicina gotas oftálmicas",
            substances:"gentamicina\namoxicilina"),["gentamicina"])
    }
    func testDoesNotInferCrossReactionsOrMissingDeclarations() {
        XCTAssertTrue(N2MedicationAllergyTextMatch.matches(
            productName:"Ampicilina tabletas",
            substances:"Penicilina").isEmpty)
        XCTAssertTrue(N2MedicationAllergyTextMatch.matches(
            productName:"Paracetamol",
            substances:"").isEmpty)
        XCTAssertTrue(N2MedicationAllergyTextMatch.matches(
            productName:"Paracetamol",
            substances:"A, B").isEmpty)
    }
}
