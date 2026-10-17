import Foundation

public struct N2ProcedureProposal:Equatable,Sendable {
    public let procedure:String
    public let source:String
    public var needsConfirmation:Bool { procedure.isEmpty }
}

/// Literal port of build222 procedureRules.ts. A proposal never establishes
/// administration, dose or diagnosis. Context is limited to confirmed choices
/// and unambiguous presentation proposals, never other contextual suggestions.
public enum N2ProcedureRules {
    public static let procedures=[
        "OBSERVACION","TRATAMIENTO ORAL","INYECTABLE","CURACION DE HERIDA",
        "APLICACION DE CREMA","APLICACION DE GOTAS OFTALMICAS","LAVADO OCULAR",
        "CONTROL","RETIRO DE PUNTOS DE SUTURA","SUTURAS",
        "EXTRACCION DE CUERPO EXTRAÑO","TOMA DE PETAR"
    ]
    public static func infer(name:String,context:[String]=[])->N2ProcedureProposal {
        let n=name.folding(options:.diacriticInsensitive,locale:Locale(identifier:"en_US_POSIX")).uppercased()
        func matches(_ pattern:String)->Bool { n.range(of:pattern,options:.regularExpression) != nil }
        func proposal(_ p:String,_ source:String)->N2ProcedureProposal {
            N2ProcedureProposal(procedure:p,source:source)
        }
        if matches(#"\b(TABLETA|TABLETAS|PASTILLA|PASTILLAS|CAPSULA|CAPSULAS|GRAGEA|GRAGEAS|COMPRIMIDO|COMPRIMIDOS)\b"#) {return proposal("TRATAMIENTO ORAL","presentation")}
        if matches(#"\b(AMPOLLA|AMPOLLAS|AMP|INYECTABLE)\b"#) {return proposal("INYECTABLE","presentation")}
        if matches("OFTALM|GOTAS OCULARES|GOTA OCULAR") {return proposal("APLICACION DE GOTAS OFTALMICAS","presentation")}
        if matches(#"\b(CREMA|CREMAS|UNGUENTO|POMADA)\b"#) {return proposal("APLICACION DE CREMA","presentation")}
        let specialized=matches("ACUPUNTURA|ODONTOLOG|NYLON.*AGUJA|SEDA.*AGUJA|CAJA PARA DESCARTAR|ACIDO ORTOFOSFORICO")
        let pending=proposal("","review")
        if matches(#"\b(AGUJA|AGUJAS|JERINGA|JERINGAS)\b"#) && !specialized {
            return context.contains("INYECTABLE") ? proposal("INYECTABLE","context") : pending
        }
        if matches(#"\b(GASA|GASAS|ALGODON|CURITA|CURITAS|APOSITO|APOSITOS|GUANTE|GUANTES|ALCOHOL|VENDA|VENDAS)\b"#) || matches("AGUA OXIGENADA") {
            let valid=Set(["INYECTABLE","CURACION DE HERIDA","SUTURAS","EXTRACCION DE CUERPO EXTRAÑO","RETIRO DE PUNTOS DE SUTURA"])
            let plausible=Set(context.filter{valid.contains($0)})
            if plausible.count==1 {return proposal(plausible.first!,"context")}
        }
        return pending
    }
    public static func detail(_ procedure:String)->String {
        ["INYECTABLE","CURACION DE HERIDA","SUTURAS","EXTRACCION DE CUERPO EXTRAÑO","RETIRO DE PUNTOS DE SUTURA"].contains(procedure) ? "INSUMOS" : "-"
    }
}

extension N2NativeFormDraft {
    public var hasWound:Bool {
        (procedures+items.map(\.procedure)).contains{$0.contains("HERIDA") || $0.contains("SUTUR")}
    }
    public mutating func refreshProcedureSuggestions(catalog:N2NativeCatalogIndex) {
        // Rebuild from independent evidence each time. Removing an ampoule
        // must invalidate a syringe suggestion; suggestions cannot self-sustain.
        let names=Dictionary(uniqueKeysWithValues:catalog.clinical.map{($0.code,$0.name)})
        let presentations=items.filter{!$0.procedureConfirmed}.map {
            N2ProcedureRules.infer(name:names[$0.code] ?? "").procedure
        }.filter{!$0.isEmpty}
        let evidence=procedures+items.filter(\.procedureConfirmed).map(\.procedure)+presentations
        for i in items.indices where !items[i].procedureConfirmed {
            let proposal=N2ProcedureRules.infer(name:names[items[i].code] ?? "",context:evidence)
            items[i].procedure=proposal.procedure
            items[i].procedureSource=proposal.source
        }
    }
}
