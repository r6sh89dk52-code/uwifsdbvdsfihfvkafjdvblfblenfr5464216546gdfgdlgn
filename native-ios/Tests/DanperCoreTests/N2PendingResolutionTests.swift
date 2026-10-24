import Foundation
import XCTest
@testable import DanperCore

final class N2PendingResolutionTests:XCTestCase {
    func testSuccessfulConsumptionOffersNoResolution() {
        XCTAssertEqual(N2PendingResolution.forReason("Descontado"),.completed)
    }
    func testMissingStockDoesNotAskForMappingOrOpening() {
        XCTAssertEqual(N2PendingResolution.forReason(
            "Sin existencias FEFO disponibles en el inventario único."),.registerStock)
        XCTAssertEqual(N2PendingResolution.forReason("Saldo FEFO insuficiente."),.registerStock)
    }
    func testMissingLinkRequiresOnlyCorrespondence() {
        XCTAssertEqual(N2PendingResolution.forReason("Sin correspondencia aprobada."),.verifyCorrespondence)
    }
    func testPhysicalEvidenceOnlyWhenRelevant() {
        for reason in [
            "Presentación Kardex ambigua: exige lote seleccionado.",
            "Presentaciones de stock incompatibles: selecciona y verifica el lote físico.",
            "Cantidad física no verificada.",
            "No hay envase abierto verificable: confirma Abrir nuevo envase. No se descontó stock.",
            "Confirma la cantidad de envases realmente abiertos.",
            "Apertura declarada o volumen no verificable en el lote seleccionado. No se descontó stock."
        ] {
            XCTAssertEqual(N2PendingResolution.forReason(reason),.verifyPhysicalUse,reason)
        }
    }
    func testHistoricalSafetyDoesNotInviteNewStockOrOpening() {
        for reason in [
            "Fecha clínica futura o inválida: el consumo queda registrado sin modificar el inventario.",
            "El lote fue registrado después de la atención o posee movimientos posteriores: reconstruir el saldo del corte sin restarlo otra vez del conteo actual.",
            "Correspondencia verificada después de la atención: requiere conciliación histórica."
        ] {
            XCTAssertEqual(N2PendingResolution.forReason(reason),.reviewChronology,reason)
        }
    }
    func testUnrecognizedReasonIsNotTreatedAsMissingStock() {
        XCTAssertEqual(N2PendingResolution.forReason("Pendiente de conciliar"),.reviewPending)
    }
}
