import SwiftUI
import DanperCore

struct N2OperationalMappingView:View {
    let code:String
    let context:N2FormContext
    let onSaved:()->Void
    @Environment(\.n2WorkspaceVault) private var vault
    @Environment(\.dismiss) private var dismiss
    @State private var inventoryID=""
    @State private var inventoryQuery=""
    @State private var physicalUnit="mL"
    @State private var conversion=""
    @State private var operatorName=""
    @State private var evidence=""
    @State private var consent=false
    @State private var busy=false
    @State private var error=""
    @State private var showAuxiliary=false
    var body:some View {
        NavigationStack {
            Form {
                Section("Correspondencia operativa") {
                    Text(context.products.clinical.first{$0.code==code}?.name ?? code)
                    Text("No modifica las 86 asociaciones oficiales. Verifica producto, concentración y presentación antes de confirmar.")
                        .font(.footnote)
                    TextField("Buscar presentación física",text:$inventoryQuery)
                        .autocorrectionDisabled()
                    Picker("Presentación física",selection:$inventoryID) {
                        Text("Seleccionar").tag("")
                        ForEach((context.products.nursing+context.auxiliaryProducts).filter{
                            $0.unit != nil &&
                            !N2UserReviewedKardexLinks.unmatched.contains($0.id) &&
                            (inventoryQuery.isEmpty || $0.id==inventoryID ||
                                $0.name.localizedStandardContains(inventoryQuery))
                        }) { item in
                            Text(item.name+" · "+(item.unit ?? "")).tag(item.id)
                        }
                    }
                    Picker("Unidad física interna verificada",selection:$physicalUnit) {
                        ForEach(["mL","g","UND","PAR"],id:\.self){Text($0).tag($0)}
                    }
                    TextField("Unidades físicas por unidad clínica",text:$conversion).keyboardType(.decimalPad)
                    Text("Ejemplo: 1000 mL por LT solo si esa equivalencia y la capacidad del lote están verificadas. No equivale a un número de atenciones.").font(.caption)
                    TextField("Responsable de la verificación",text:$operatorName)
                    TextField("Evidencia: concentración, presentación y conversión",text:$evidence,axis:.vertical)
                    Toggle("Confirmo la equivalencia y conversión verificadas",isOn:$consent)
                    Button("Registrar producto fuera del Kardex de 98") {showAuxiliary=true}
                }
                if !error.isEmpty {Text(error).foregroundStyle(.orange)}
                Button("Guardar correspondencia operativa") {Task {await save()}}
                    .disabled(busy || !consent || inventoryID.isEmpty)
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("Vinculación operativa")
            .navigationBarTitleDisplayMode(.inline)
            .danperFormChrome()
            .toolbar {Button("Cancelar"){dismiss()}}
            .sheet(isPresented:$showAuxiliary) {
                N2AuxiliaryInventoryView(code:code,context:context,onSaved:{onSaved();dismiss()})
            }
        }
    }
    @MainActor private func save() async {
        guard !busy,consent,
              let product=context.products.clinical.first(where:{$0.code==code}),
              let inventory=(context.products.nursing+context.auxiliaryProducts).first(where:{$0.id==inventoryID}),
              let ratio=Double(conversion.replacingOccurrences(of:",",with:".")) else {
            error="Completa la presentación y la conversión verificadas.";return
        }
        busy=true
        defer {busy=false}
        do {
            let rule=N2OperationalMapping(clinical:product,inventory:inventory,
                physicalUnit:physicalUnit,conversion:ratio,
                confirmedAt:Int64(Date().timeIntervalSince1970*1000),
                operatorName:operatorName,evidence:evidence)
            _=try await vault.confirmOperationalMapping(rule,expectedRevision:context.revision)
            onSaved();dismiss()
        } catch {
            self.error="No se guardó la regla. Verifica los datos; si cambió el inventario, vuelve a abrir la atención. No se descontaron existencias."
        }
    }
}
