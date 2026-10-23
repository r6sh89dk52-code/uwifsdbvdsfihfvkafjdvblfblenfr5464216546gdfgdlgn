import SwiftUI
import DanperCore

struct N2AuxiliaryInventoryView:View {
    let code:String
    let context:N2FormContext
    let onSaved:()->Void
    @Environment(\.n2WorkspaceVault) private var vault
    @Environment(\.dismiss) private var dismiss
    @State private var presentation="UND"
    @State private var capacity="1"
    @State private var sealed=""
    @State private var reference=""
    @State private var expiry=""
    @State private var operatorName=""
    @State private var evidence=""
    @State private var consent=false
    @State private var busy=false
    @State private var message=""
    @State private var accounting=""
    var body:some View {
        NavigationStack {
            Form {
                Section("Producto fuera del Kardex de 98") {
                    Text(context.products.clinical.first{$0.code==code}?.name ?? code)
                    Text("Stock compartido con contabilidad auxiliar. No agrega filas al Kardex oficial ni cambia sus fórmulas. Después verifica la correspondencia y la conversión.").font(.footnote)
                    Picker("Presentación verificada",selection:$presentation) {
                        ForEach(["UND","PAR","FCO","CJA","PAQ"],id:\.self){Text($0).tag($0)}
                    }
                    TextField("Capacidad interna verificada",text:$capacity).keyboardType(.numberPad)
                    TextField("Envases o unidades disponibles",text:$sealed).keyboardType(.numberPad)
                    TextField("Número de lote o referencia",text:$reference)
                    N2ExpiryTextField(text:$expiry).frame(minHeight:44)
                    Text("Vencimiento opcional. La capacidad debe usar la misma unidad física que confirmarás en la correspondencia.").font(.caption)
                    TextField("Responsable",text:$operatorName)
                    TextField("Evidencia de producto, presentación y capacidad",text:$evidence,axis:.vertical)
                    Toggle("Confirmo el conteo y los datos físicos verificados",isOn:$consent)
                    Button("Registrar lote auxiliar") {Task {await save()}}.disabled(!consent || busy)
                }
                Section("Existencias auxiliares registradas") {
                    ForEach(context.lots.filter{$0.kardexCode=="AUX:"+code}) { lot in
                        LabeledContent(lot.reference,value:lot.total.formatted())
                    }
                    if !accounting.isEmpty {
                        ShareLink(item:accounting) {Label("Compartir contabilidad auxiliar (JSON)",systemImage:"square.and.arrow.up")}
                    }
                }
                if !message.isEmpty {Text(message).foregroundStyle(.orange)}
            }
            .navigationTitle("Inventario auxiliar")
            .toolbar {Button("Cerrar"){dismiss()}}
            .task {
                do {accounting=try await vault.auxiliaryAccounting()}
                catch {message="No se pudo verificar la contabilidad auxiliar."}
            }
        }
    }
    @MainActor private func save() async {
        guard !busy,consent,let product=context.products.clinical.first(where:{$0.code==code}),
              let size=Int(capacity),size>0,let count=Int(sealed),count>0,
              !reference.trimmingCharacters(in:.whitespaces).isEmpty,
              expiry.isEmpty || N2ExpiryEntry.iso(expiry) != nil else {
            message="Completa el conteo, la capacidad, el lote y un vencimiento válido si corresponde.";return
        }
        busy=true;defer {busy=false}
        let timestamp=Int64(Date().timeIntervalSince1970*1000)
        let lot:[String:Any]=["id":UUID().uuidString,"code":"AUX:"+code,"name":product.name,
            "catalogUnit":presentation,"lot":reference,"expires":N2ExpiryEntry.iso(expiry) ?? "",
            "container":presentation=="FCO" ? "frasco":presentation=="CJA" ? "caja":"unidad",
            "unitsPerContainer":size,"sealedContainers":count,"looseUnits":0,"openedRemaining":0,"updatedAt":timestamp]
        do {
            _=try await vault.registerAuxiliaryLot(clinicalCode:code,lot:JSONSerialization.data(withJSONObject:lot),
                operatorName:operatorName,evidence:evidence,expectedRevision:context.revision)
            onSaved();dismiss()
        } catch {message="Lote rechazado. Verifica la evidencia y vuelve a cargar el inventario si cambió la revisión."}
    }
}
