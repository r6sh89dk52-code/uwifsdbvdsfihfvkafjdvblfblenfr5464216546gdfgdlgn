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
    func testHistoricStatusDescribesActualCauseWithoutSuggestingFalseDebit() {
        let lateLot="El lote fue registrado después de la atención o posee movimientos posteriores: reconstruir el saldo del corte sin restarlo otra vez del conteo actual."
        let lateMapping="Correspondencia vinculada después de la atención: requiere conciliación histórica."
        let invalid="Fecha clínica futura o inválida: el consumo queda registrado sin modificar el inventario."
        XCTAssertEqual(N2PendingResolution.forReason(lateLot),.reviewChronology)
        XCTAssertEqual(N2PendingResolution.historicalTitle(forReason:lateLot),
                       "Lote posterior a la atención")
        XCTAssertTrue(N2PendingResolution.historicalGuidance(forReason:lateLot)
                      .contains("no vuelvas a descontarlo"))
        XCTAssertEqual(N2PendingResolution.forReason(lateMapping),.reviewChronology)
        XCTAssertEqual(N2PendingResolution.historicalTitle(forReason:lateMapping),
                       "Vínculo confirmado después de la atención")
        XCTAssertTrue(N2PendingResolution.historicalGuidance(forReason:lateMapping)
                      .contains("no demuestra una salida física antigua"))
        XCTAssertEqual(N2PendingResolution.historicalTitle(forReason:invalid),
                       "Revisar fecha de la atención")
        XCTAssertTrue(N2PendingResolution.historicalGuidance(forReason:invalid)
                      .contains("Revisa la fecha original"))
    }
    func testUserFacingMessagesDoNotConfuseStockAndCorrespondence() {
        XCTAssertEqual(N2PendingResolution.registerStock.summary,
                       "No hay stock disponible para descontar")
        XCTAssertEqual(N2PendingResolution.verifyCorrespondence.summary,
                       "Falta vincular el producto al inventario")
        XCTAssertEqual(N2PendingResolution.verifyPhysicalUse.summary,
                       "Falta comprobar lote o apertura")
        XCTAssertEqual(N2PendingResolution.reviewChronology.summary,
                       "Pendiente por revisión de fecha e historial")
    }
    func testUnrecognizedReasonIsNotTreatedAsMissingStock() {
        XCTAssertEqual(N2PendingResolution.forReason("Pendiente de conciliar"),.reviewPending)
    }
}
