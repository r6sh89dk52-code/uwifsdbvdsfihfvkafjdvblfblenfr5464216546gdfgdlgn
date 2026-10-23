import SwiftUI
import DanperCore

struct N2PendingDispensingView:View {
    let visitID:String
    let medication:N2FormMedication
    let date:String
    let context:N2FormContext
    let onSaved:()->Void
    @Environment(\.n2WorkspaceVault) private var vault
    @Environment(\.dismiss) private var dismiss
    @State private var lotID=""
    @State private var quantity=""
    @State private var opening=false
    @State private var operatorName=""
    @State private var reason=""
    @State private var consent=false
    @State private var busy=false
    @State private var message=""
    var body:some View {
        NavigationStack {
            Form {
                Section("Verificar salida pendiente") {
                    Text(context.products.clinical.first{$0.code==medication.code}?.name ?? medication.code)
                    Text("Conserva la atención original. Solo se descontará si la correspondencia, el stock, la capacidad y la cronología permiten verificar la salida.").font(.footnote)
                    Picker("Lote compatible",selection:$lotID) {
                        Text("Seleccionar").tag("")
                        ForEach(context.options(for:medication.code,at:date)) { lot in
                            Text(lot.name+" · "+lot.reference+" · "+lot.total.formatted()).tag(lot.id)
                        }
                    }
                    TextField("Cantidad física realmente utilizada",text:$quantity).keyboardType(.decimalPad)
                    if let lot=context.lots.first(where:{$0.id==lotID}) {
                        Text("Capacidad verificada: \(lot.capacity.formatted()). Usa la misma unidad física que la capacidad y la regla operativa.").font(.caption)
                    }
                    Toggle("Autorizo abrir un nuevo envase si el plan lo requiere",isOn:$opening)
                    TextField("Responsable",text:$operatorName)
                    TextField("Evidencia y motivo",text:$reason,axis:.vertical).lineLimit(2...4)
                    Toggle("Confirmo la cantidad física y la evidencia",isOn:$consent)
                    Button("Verificar y conciliar sin duplicar atención") {Task {await save()}}
                        .disabled(busy || !consent || lotID.isEmpty)
                }
                if !message.isEmpty {Text(message).foregroundStyle(.orange)}
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("Conciliar consumo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {Button("Cancelar"){dismiss()}}
        }
    }
    @MainActor private func save() async {
        guard !busy,consent,let amount=Double(quantity.replacingOccurrences(of:",",with:".")),amount>0 else {
            message="Indica la cantidad física verificada.";return
        }
        busy=true;defer {busy=false}
        do {
            let evidence=N2PendingDispensingEvidence(visitID:visitID,itemID:medication.id,lotID:lotID,
                quantity:amount,confirmNewContainer:opening,operatorName:operatorName,reason:reason,
                at:Int64(Date().timeIntervalSince1970*1000))
            _=try await vault.confirmPendingDispensing(evidence,expectedRevision:context.revision)
            onSaved();dismiss()
        } catch {message="No se pudo verificar la operación. La atención permanece guardada. Actualiza el inventario y revisa la evidencia."}
    }
}
