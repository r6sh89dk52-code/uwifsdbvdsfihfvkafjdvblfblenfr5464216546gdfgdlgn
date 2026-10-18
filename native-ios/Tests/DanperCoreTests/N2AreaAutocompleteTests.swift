import Foundation
import XCTest
@testable import DanperCore

final class N2AreaAutocompleteTests:XCTestCase {
    private let official=[
        N2OfficialArea(site:"LA VENTUROSA",
                       area:"Seguridad y Salud en el Trabajo",code:"12345678"),
        N2OfficialArea(site:"PLVENTUROSA",
                       area:"Gestión de Talento Humano",code:"87654321")
    ]
    func testAllRequestedLabelsSuggestEvenWithoutOfficialResource() {
        let examples:[String:String]=[
            "fito":"Fitosanidad",
            "salu":"Servicio de Salud",
            "operaciones":"Departamento de Operaciones",
            "riego":"Mantenimiento de Sistema de Riego",
            "palto":"Producción Agrícola Palto"
        ]
        for (term,expected) in examples {
            let suggestions=N2AreaAutocomplete.suggestions(
                query:term,site:"LA VENTUROSA",official:[],known:[])
            XCTAssertTrue(suggestions.contains(expected),
                          "Missing suggestion for \(term)")
        }
    }
    func testOfficialSuggestionsWorkAcrossBothSites() {
        XCTAssertTrue(N2AreaAutocomplete.suggestions(
            query:"talento",site:"LA VENTUROSA",
            official:official,known:[]).contains("Gestión de Talento Humano"))
        XCTAssertTrue(N2AreaAutocomplete.suggestions(
            query:"seguridad",site:"PLVENTUROSA",
            official:official,known:[]).contains("Seguridad y Salud en el Trabajo"))
    }
    func testDiacriticsPartialWordsAndNoDuplicates() {
        let found=N2AreaAutocomplete.suggestions(query:"PRODUCCION",
            site:"LA VENTUROSA",official:[],
            known:["PRODUCCIÓN AGRÍCOLA PALTO","Producción Agrícola Palto"])
        XCTAssertEqual(found.count,1)
        XCTAssertEqual(N2AreaAutocomplete.normalize(found[0]),
                       N2AreaAutocomplete.normalize("Producción Agrícola Palto"))
        XCTAssertEqual(N2AreaAutocomplete.suggestions(query:"   ",
            site:"LA VENTUROSA",official:[],known:[]),[])
    }
    func testCodeIsNotFabricatedBySuggestedFreeText() {
        let matches=N2AreaAutocomplete.suggestions(
            query:"servicio de salud",site:"LA VENTUROSA",
            official:[],known:[])
        XCTAssertEqual(matches,["Servicio de Salud"])
        XCTAssertTrue(official.allSatisfy{$0.code.count==8})
    }
}
