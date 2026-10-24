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

    /// Short, user-facing explanation; the clinical record keeps the original reason.
    public var summary:String {
        switch self {
        case .completed:return "Consumo vinculado al Kardex"
        case .registerStock:return "No hay stock disponible para descontar"
        case .verifyCorrespondence:return "Falta vincular el producto al inventario"
        case .verifyPhysicalUse:return "Falta comprobar lote o apertura"
        case .reviewChronology:return "Pendiente por revisión de fecha e historial"
        case .reviewPending:return "Consumo pendiente de revisión"
        }
    }

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
           text.hasPrefix("Correspondencia verificada después de la atención") ||
           text.hasPrefix("Correspondencia vinculada después de la atención") {
            return .reviewChronology
        }
        let physicalReasons=[
            "Presentación Kardex ambigua",
            "Diferencia de presentación",
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
