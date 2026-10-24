import Foundation

/// Routes a saved clinical line to its next safe, relevant action.
/// This is presentation-only: it never authorizes mappings or writes stock.
public enum N2PendingResolution:Equatable,Sendable {
    case completed
    case registerStock
    case verifyCorrespondence
    case verifyPhysicalUse
    case reviewChronology
    case reviewPending

    public static func forReason(_ reason:String)->Self {
        let text=reason.trimmingCharacters(in:.whitespacesAndNewlines)
        if text=="Descontado" {return .completed}
        if text.hasPrefix("Sin correspondencia aprobada.") {
            return .verifyCorrespondence
        }
        if text.hasPrefix("Sin existencias FEFO disponibles") ||
           text.hasPrefix("Saldo FEFO insuficiente") {
            return .registerStock
        }
        if text.hasPrefix("Fecha clínica futura o inválida") ||
           text.hasPrefix("El lote fue registrado después de la atención") ||
           text.hasPrefix("Correspondencia verificada después de la atención") {
            return .reviewChronology
        }
        let physicalReasons=[
            "Presentación Kardex ambigua",
            "Presentaciones de stock incompatibles",
            "Presentación no seleccionada",
            "Existencia seleccionada no verificable",
            "Cantidad física no verificada",
            "Capacidad del envase no verificada",
            "Envase: falta cantidad interna verificada",
            "No hay envase abierto verificable",
            "Confirma la cantidad de envases realmente abiertos",
            "Apertura declarada o volumen no verificable",
            "Falta autorizar apertura",
            "Plan FEFO incompleto"
        ]
        if physicalReasons.contains(where:{text.hasPrefix($0)}) {
            return .verifyPhysicalUse
        }
        return .reviewPending
    }
}
