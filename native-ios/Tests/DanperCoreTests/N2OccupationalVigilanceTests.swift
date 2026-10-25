import Foundation
import XCTest
@testable import DanperCore

final class N2OccupationalVigilanceTests:XCTestCase {
    private func snapshot(_ visits:[[String:Any]])throws->Data {
        var root=try XCTUnwrap(JSONSerialization.jsonObject(
            with:N2EmptyDemoSnapshot.make()) as? [String:Any])
        root["workers"]=[[
            "dni":"12345678","name":"TRABAJADORA SINTETICA",
            "sex":"F","age":"30","site":"LA VENTUROSA",
            "area":"PRODUCCION AGRICOLA PALTO","labor":"COSECHA",
            "source":"manual"
        ]]
        root["attentions"]=visits
        return try JSONSerialization.data(withJSONObject:root,options:.sortedKeys)
    }
    private func visit(_ id:String,_ system:String,_ date:String="2026-10-19")
        ->[String:Any] {
        [
            "id":id,"status":"saved","date":date,"time":"09:30",
            "system":system,"category":"ENFERMEDAD COMUN",
            "worker":[
                "dni":"12345678","name":"TRABAJADORA SINTETICA",
                "sex":"F","age":"30","site":"LA VENTUROSA",
                "area":"PRODUCCION AGRICOLA PALTO",
                "labor":"COSECHA"
            ],
            "responsibleDni":"87654321",
            "responsible":"ENFERMERA SINTETICA",
            "items":[[String:Any]]()
        ]
    }
    private func sheet(_ result:N2OccupationalVigilanceWorkbook.Result)throws->String {
        let entries=try N1rStoredZip.unpack(result.xlsx)
        let sheets=entries.filter{$0.name.hasPrefix("xl/worksheets/sheet")}
        XCTAssertEqual(sheets.count,1,"El modelo no debe generar hojas ocultas")
        let source=try XCTUnwrap(sheets.first)
        return try XCTUnwrap(String(data:source.data,encoding:.utf8))
    }
    func testOnlyOsteomuscularSavedVisitsAndOneSheet()throws {
        let source=try snapshot([
            visit("O-1","OSTEOMUSCULAR"),
            visit("R-1","RESPIRATORIO"),
            visit("O-2","OSTEOMUSCULAR","2026-10-21")
        ])
        let result=try N2OccupationalVigilanceWorkbook.export(
            snapshot:source,start:"2026-10-09",end:"2026-10-24")
        XCTAssertEqual(result.rows,2)
        XCTAssertEqual(result.sheetName,"VIGILACIA OCUPACIONAL")
        let xml=try sheet(result)
        XCTAssertEqual(xml.components(separatedBy:"<row r=").count-1,3)
        for text in ["DSUBDIVISION","APELLIDOS Y NOMBRES",
                     "Posturas inadecuadas",
                     "Capacitacion y ejecucion de pausas activas",
                     "TRABAJADORA SINTETICA"] {
            XCTAssertTrue(xml.contains(text),"Campo faltante: \(text)")
        }
        XCTAssertFalse(xml.contains("RESPIRATORIO"))
        XCTAssertTrue(xml.contains("r=\"G2\" s=\"5\""),
                      "La fecha debe ser un valor numérico de Excel")
        XCTAssertTrue(xml.contains("r=\"I2\" s=\"6\""),
                      "El DNI se conserva como texto de ocho dígitos")
        let names=try N1rStoredZip.unpack(result.xlsx).map(\.name)
        XCTAssertFalse(names.contains(where:{$0.contains("sheet2.xml")}))
    }
    func testOnlySelectedDateAndNoDuplicateClinicalRows()throws {
        let source=try snapshot([
            visit("OLD","OSTEOMUSCULAR","2026-10-08"),
            visit("IN","OSTEOMUSCULAR","2026-10-09"),
            visit("LATE","OSTEOMUSCULAR","2026-11-09")
        ])
        let result=try N2OccupationalVigilanceWorkbook.export(
            snapshot:source,start:"2026-10-09",end:"2026-11-08")
        XCTAssertEqual(result.rows,1)
        XCTAssertEqual(try sheet(result).components(separatedBy:"<row r=").count-1,2)
        XCTAssertThrowsError(try N2OccupationalVigilanceWorkbook.export(
            snapshot:source,start:"2026-10-24",end:"2026-10-09"))
    }
    func testOfficialOrganizationCodesDependOnSocietyAndArea()throws {
        let fundo=N2VigilanceOrganizationCodes.resolve(
            site:"La Venturosa",unit:"SERVICIOS DE SALUD")
        XCTAssertEqual(fundo.subdivision,"A071")
        XCTAssertEqual(fundo.organizationalUnit,"20000136")
        let planta=N2VigilanceOrganizationCodes.resolve(
            site:"PL Aventurosa",unit:"SERVICIOS DE SALUD")
        XCTAssertEqual(planta.subdivision,"I031")
        XCTAssertEqual(planta.organizationalUnit,"20000066")
        XCTAssertEqual(N2VigilanceOrganizationCodes.resolve(
            site:"LA VENTUROSA",unit:"PRODUCCION AGRICOLA PALTO"
        ).organizationalUnit,"20000126")
        XCTAssertEqual(N2VigilanceOrganizationCodes.resolve(
            site:"PLVENTUROSA",unit:"ASEGURAMIENTO DE LA CALIDAD FRESCO"
        ).organizationalUnit,"20000101")
        XCTAssertNotEqual(fundo.organizationalUnit,planta.organizationalUnit)
    }

    func testVigilanceWritesBothCodesIntoExistingColumnsWithoutNewSheets()throws {
        let fundo=try snapshot([visit("ORG-FUNDO","OSTEOMUSCULAR")])
        let first=try N2OccupationalVigilanceWorkbook.export(
            snapshot:fundo,start:"2026-10-09",end:"2026-10-24")
        let a=try sheet(first)
        XCTAssertEqual(first.unresolvedOrganizationalUnits,0)
        XCTAssertTrue(a.contains(#"r="C2" s="4" t="inlineStr""#))
        XCTAssertTrue(a.contains(">A071</t>"))
        XCTAssertTrue(a.contains(">20000126</t>"))
        let p=try XCTUnwrap(JSONSerialization.jsonObject(
            with:fundo) as? [String:Any])
        var cloned=p
        var visits=try XCTUnwrap(cloned["attentions"] as? [[String:Any]])
        var worker=try XCTUnwrap(visits[0]["worker"] as? [String:Any])
        worker["site"]="PLVENTUROSA"
        worker["area"]="ASEGURAMIENTO DE LA CALIDAD FRESCO"
        worker["subdivisionCode"]="A071" // Reject stale cross-society field.
        worker["organizationCode"]="20000126"
        visits[0]["worker"]=worker
        cloned["attentions"]=visits
        var roster=try XCTUnwrap(cloned["workers"] as? [[String:Any]])
        roster[0]["site"]="PLVENTUROSA"
        roster[0]["area"]="ASEGURAMIENTO DE LA CALIDAD FRESCO"
        cloned["workers"]=roster
        let plant=try JSONSerialization.data(withJSONObject:cloned,options:.sortedKeys)
        let second=try N2OccupationalVigilanceWorkbook.export(
            snapshot:plant,start:"2026-10-09",end:"2026-10-24")
        let xml=try sheet(second)
        XCTAssertEqual(second.unresolvedOrganizationalUnits,0)
        XCTAssertTrue(xml.contains(">I031</t>"))
        XCTAssertTrue(xml.contains(">20000101</t>"))
        XCTAssertFalse(xml.contains(">20000126</t>"))
        let names=try N1rStoredZip.unpack(second.xlsx).map(\.name)
        XCTAssertFalse(names.contains{$0.contains("sheet2.xml")})
    }

    func testUnknownOrganizationCannotInheritWrongSocietyCode()throws {
        let coded=N2VigilanceOrganizationCodes.resolve(
            site:"La Venturosa",unit:"AREA SIN REFERENCIA @UO",
            existingSubdivision:"I031",existingOrganization:"20000066")
        XCTAssertTrue(coded.recognizedSite)
        XCTAssertEqual(coded.subdivision,"A071")
        XCTAssertEqual(coded.organizationalUnit,"")
        let other=N2VigilanceOrganizationCodes.resolve(
            site:"OTRO FUNDO",unit:"SERVICIOS DE SALUD")
        XCTAssertFalse(other.recognizedSite)
        XCTAssertEqual(other.organizationalUnit,"")
    }

    func testUnmatchedUnitIsReportedWithoutInventingACode()throws {
        var medical=visit("ORG-UNKNOWN","OSTEOMUSCULAR")
        var worker=try XCTUnwrap(medical["worker"] as? [String:Any])
        worker["area"]="AREA DE EJEMPLO SIN CODIGO OFICIAL"
        worker["organizationCode"]="20000066" // Belongs to a different society.
        medical["worker"]=worker
        let result=try N2OccupationalVigilanceWorkbook.export(
            snapshot:snapshot([medical]),start:"2026-10-09",end:"2026-10-24")
        XCTAssertEqual(result.rows,1)
        XCTAssertEqual(result.unresolvedOrganizationalUnits,1)
        let xml=try sheet(result)
        XCTAssertTrue(xml.contains(">A071</t>"))
        XCTAssertFalse(xml.contains(">20000066</t>"))
    }

    func testNoOsteomuscularVisitsHasOnlyOriginalHeader()throws {
        let source=try snapshot([visit("NON","DIGESTIVO")])
        let result=try N2OccupationalVigilanceWorkbook.export(
            snapshot:source,start:"2026-10-09",end:"2026-10-24")
        XCTAssertEqual(result.rows,0)
        XCTAssertEqual(try sheet(result).components(separatedBy:"<row r=").count-1,1)
    }
}
