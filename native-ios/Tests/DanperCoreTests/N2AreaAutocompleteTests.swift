import Foundation
import XCTest
@testable import DanperCore

final class N2AreaAutocompleteTests:XCTestCase {
    private let official=[
        N2OfficialArea(site:"LA VENTUROSA",area:"Fitosanidad",code:"10000001"),
        N2OfficialArea(site:"LA VENTUROSA",area:"Seguridad y Salud en el Trabajo",code:"10000002"),
        N2OfficialArea(site:"PLVENTUROSA",area:"Empaque",code:"20000001"),
        N2OfficialArea(site:"PLVENTUROSA",area:"Operaciones Fresco",code:"20000002"),
        N2OfficialArea(site:"PLVENTUROSA",area:"Gestión de Talento Humano",code:"20000003")
    ]

    func testSuggestionsFollowSelectedSiteNotOtherSite() {
        let plant=N2AreaAutocomplete.suggestions(
            query:"",site:"PLVENTUROSA",official:official,known:[])
        XCTAssertTrue(plant.contains("Empaque"))
        XCTAssertTrue(plant.contains("Operaciones Fresco"))
        XCTAssertTrue(plant.contains("Gestión de Talento Humano"))
        XCTAssertFalse(plant.contains("Fitosanidad"))
        let fundo=N2AreaAutocomplete.suggestions(
            query:"",site:"LA VENTUROSA",official:official,known:[])
        XCTAssertTrue(fundo.contains("Fitosanidad"))
        XCTAssertFalse(fundo.contains("Gestión de Talento Humano"))
    }
    func testFullOfficialCatalogHasNoEightResultCap() {
        let fundo=(0..<31).map{
            N2OfficialArea(site:"LA VENTUROSA",
                           area:"Fundo \($0)",code:String(format:"%08d",$0))
        }
        let planta=(0..<124).map{
            N2OfficialArea(site:"PLVENTUROSA",
                           area:"Planta \($0)",code:String(format:"%08d",1000+$0))
        }
        let entire=fundo+planta
        XCTAssertTrue(N2AreaAutocomplete.isComplete(official:entire))
        XCTAssertEqual(N2AreaAutocomplete.officialCount(site:"LA VENTUROSA",official:entire),31)
        XCTAssertEqual(N2AreaAutocomplete.officialCount(site:"PLVENTUROSA",official:entire),124)
        let results=N2AreaAutocomplete.suggestions(
            query:"planta",site:"PLVENTUROSA",official:entire,known:[])
        XCTAssertEqual(results.filter{$0.hasPrefix("Planta ")}.count,124)
        XCTAssertFalse(results.contains(where:{$0.hasPrefix("Fundo ")}))
        XCTAssertFalse(N2AreaAutocomplete.isComplete(official:Array(entire.dropLast())))
    }
    func testPlantCommonAliasesAreFreeTextNotInventedCodes() {
        let plant=N2AreaAutocomplete.suggestions(
            query:"empaque",site:"PLVENTUROSA",official:[],known:[])
        XCTAssertEqual(plant,["Empaque"])
        let fresh=N2AreaAutocomplete.suggestions(
            query:"opera",site:"PLVENTUROSA",official:[],known:[])
        XCTAssertEqual(fresh,["Operaciones Fresco"])
        XCTAssertFalse(N2AreaAutocomplete.suggestions(
            query:"operaciones fresco",site:"LA VENTUROSA",
            official:[],known:[]).contains("Operaciones Fresco"))
    }
    func testAccentInsensitiveAndFullDirectoryBrowsing() {
        let result=N2AreaAutocomplete.suggestions(query:"gestion",
            site:"PLVENTUROSA",official:official,known:[])
        XCTAssertEqual(result,["Gestión de Talento Humano"])
        XCTAssertEqual(N2AreaAutocomplete.suggestions(query:"palto",
            site:"LA VENTUROSA",official:[],known:[]),["Producción Agrícola Palto"])
        XCTAssertEqual(N2AreaAutocomplete.suggestions(query:"salud",
            site:"LA VENTUROSA",official:[],known:[]),["Servicio de Salud"])
        XCTAssertEqual(N2AreaAutocomplete.suggestions(query:"fito",
            site:"LA VENTUROSA",official:[],known:[]),["Fitosanidad"])
    }
}
