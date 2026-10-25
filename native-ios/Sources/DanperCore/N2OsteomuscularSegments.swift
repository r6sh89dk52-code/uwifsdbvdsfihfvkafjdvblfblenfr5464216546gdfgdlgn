import Foundation

/// Descriptions appearing in column O (SEGMENTO OSTEOMUSCULAR) of the
/// user-provided 2026 ten-sheet ambulatory workbook. The original historical
/// strings remain exactly selectable for backwards compatibility.
public enum N2OsteomuscularSegments {
    public static let historical:[String] = [
        "ZONA CERVICAL,DORSAL,LUMBAR Y SACRA",
        "PRIMERO, SEGUNDO ,TERCERO, CUARTO Y QUINTO DEDO DERECHO E IZQUIERDO",
        "TOBILLO",
        "ZONA INGUINAL",
        "PARTE POSTERIOR DEL TORAX (ESPALDA)",
        "MANO",
        "PRIMER, SEGUNDO, TERCERO, CUARTO Y QUINTO ORTEJO DERECHO E IZQUIERDO",
        "RODILLA",
        "CUELLO",
        "CABEZA"
    ]

    /// Individual sites clarify the combined original lumbar/cervical item.
    /// PIE and PIERNA are explicit user-requested selectable sites.
    public static let specific:[String] = [
        "ZONA CERVICAL",
        "ZONA DORSAL",
        "ZONA LUMBAR",
        "ZONA SACRA",
        "HOMBRO",
        "BRAZO",
        "CODO",
        "ANTEBRAZO",
        "MUÑECA",
        "MANO",
        "DEDOS DE LA MANO",
        "ZONA INGUINAL",
        "CADERA",
        "MUSLO",
        "RODILLA",
        "PIERNA",
        "TOBILLO",
        "PIE",
        "DEDOS DEL PIE",
        "CUELLO",
        "CABEZA"
    ]

    public static let custom="OTRO (ESPECIFICAR)"
    public static let options:[String] = {
        var unique=Set<String>()
        return (specific+historical).filter{unique.insert($0).inserted}
    }()
    /// Legacy typed draft descriptions remain usable through the custom
    /// field; no changes to storage, visit schema, autosave or exports.
    public static func isKnown(_ text:String)->Bool {
        options.contains(text)
    }
}
