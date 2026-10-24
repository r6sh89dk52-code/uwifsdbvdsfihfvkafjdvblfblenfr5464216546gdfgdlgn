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
    @State private var newContainers=1
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
                    Text("Conserva la atención original. Solo se descontarán las aperturas declaradas verificables por correspondencia, stock y cronología. El volumen es opcional.").font(.footnote)
                    Picker("Lote compatible",selection:$lotID) {
                        Text("Seleccionar").tag("")
                        ForEach(context.options(for:medication.code,at:date)) { lot in
                            let balance=N2ContainerAccounting.isContainer(unit:lot.unit) ?
                                "\(lot.sealed) cerrados / \(lot.openContainers) abiertos":"\(lot.total.formatted()) \(lot.unit)"
                            Text("\(lot.name) · \(lot.reference) · \(balance)").tag(lot.id)
                        }
                    }
                    TextField("Cantidad física realmente utilizada",text:$quantity).keyboardType(.decimalPad)
                    if let lot=context.lots.first(where:{$0.id==lotID}) {
                        Text(N2ContainerAccounting.isContainer(unit:lot.unit) ?
                            "Envases cerrados: \(lot.sealed) · Abiertos declarados: \(lot.openContainers). El volumen solo se registra si existe seguimiento interno verificado." :
                            "Existencia individual: \(lot.total.formatted()) \(lot.unit).")
                            .font(.caption)
                    }
                    Toggle("Abrí un nuevo envase (declaración explícita)",isOn:$opening)
                    if opening {Stepper("Envases realmente abiertos: \(newContainers)",value:$newContainers,in:1...100)}
                    Text("Con envase abierto: Kardex 0. El volumen es opcional; no se inferirán aperturas.").font(.caption)
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
            .danperFormChrome()
            .toolbar {Button("Cancelar"){dismiss()}}
        }
    }
    @MainActor private func save() async {
        guard !busy,consent,let amount=Double(quantity.isEmpty ? "0":quantity.replacingOccurrences(of:",",with:".")),amount>=0 else {
            message="Indica la cantidad física verificada.";return
        }
        busy=true;defer {busy=false}
        do {
            let evidence=N2PendingDispensingEvidence(visitID:visitID,itemID:medication.id,lotID:lotID,
                quantity:amount,confirmNewContainer:opening,operatorName:operatorName,reason:reason,
                at:Int64(Date().timeIntervalSince1970*1000),newContainers:opening ? newContainers:0)
            _=try await vault.confirmPendingDispensing(evidence,expectedRevision:context.revision)
            onSaved();dismiss()
        } catch {message="No se pudo verificar la operación. La atención permanece guardada. Actualiza el inventario y revisa la evidencia."}
    }
}
