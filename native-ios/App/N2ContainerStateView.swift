import SwiftUI
import DanperCore

struct N2ContainerStateView:View {
    let lot:N2FormLot
    let revision:Int
    let onSaved:()->Void
    @Environment(\.n2WorkspaceVault) private var vault
    @Environment(\.dismiss) private var dismiss
    @State private var count=1
    @State private var disposition="agotado"
    @State private var operatorName=""
    @State private var reason=""
    @State private var consent=false
    @State private var busy=false
    @State private var message=""
    var body:some View {
        NavigationStack {
            Form {
                Text(lot.name+" · "+lot.reference)
                Text("Solo declara el estado del envase ya abierto. No descuenta envases cerrados ni modifica atenciones previas o estima volumen descartado.")
                Text("El volumen restante queda sin seguimiento verificado, porque no se estima cuánto contenía cada envase retirado.").font(.caption)
                Stepper("Envases: \(count)",value:$count,in:1...max(1,lot.openContainers))
                Picker("Estado declarado",selection:$disposition) {
                    Text("Agotado").tag("agotado")
                    Text("Cerrado / retirado de uso").tag("cerrado")
                    Text("Descartado").tag("descartado")
                }
                TextField("Responsable",text:$operatorName)
                TextField("Motivo y evidencia",text:$reason,axis:.vertical)
                Toggle("Confirmo el estado real del envase",isOn:$consent)
                Button("Registrar declaración") {Task {await save()}}
                    .disabled(!consent || busy || operatorName.count<3 || reason.count<10)
                if !message.isEmpty {Text(message).foregroundStyle(.orange)}
            }
            .navigationTitle("Estado de envases")
            .danperFormChrome()
            .toolbar {Button("Cancelar"){dismiss()}}
        }
    }
    @MainActor private func save() async {
        guard consent,!busy else{return}
        busy=true;defer {busy=false}
        do {
            _=try await vault.closeContainers(lotID:lot.id,count:count,disposition:disposition,
                operatorName:operatorName,reason:reason,at:Int64(Date().timeIntervalSince1970*1000),expectedRevision:revision)
            onSaved();dismiss()
        } catch {message="No se registró la declaración. Actualiza el inventario y revisa la evidencia."}
    }
}
