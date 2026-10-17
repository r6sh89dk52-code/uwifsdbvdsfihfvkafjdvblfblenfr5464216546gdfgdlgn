import SwiftUI
import DanperCore

/// First-class encrypted N2 draft tab, never uses N1g demo drafts.
struct N2NativeDraftsDashboard:View {
    @State private var records=[N2RecoverableDraft]()
    @State private var loading=true
    @State private var failed=false
    @State private var message="Leyendo borradores cifrados…"

    var body:some View {
        ScrollView {
          VStack(alignment:.leading,spacing:16) {
            DanperPanel {
                Label("Datos protegidos",systemImage:"lock.shield")
                Text("Los borradores están guardados dentro de la misma bóveda cifrada. Reabrir no crea otra atención ni descuenta inventario.")
                    .font(.footnote).foregroundStyle(.secondary)
                if failed {
                    Label(message,systemImage:"exclamationmark.triangle")
                        .foregroundStyle(.orange)
                }else{
                    Text(message).font(.footnote).foregroundStyle(.secondary)
                }
            }
            DanperPanel("Registros pendientes") {
                if records.isEmpty && !loading {
                    Text("No hay borradores para recuperar.")
                        .foregroundStyle(.secondary)
                }
                ForEach(records) { draft in
                    NavigationLink {
                        N2NativeClinicalFormView(requestedDraftID:draft.id)
                    } label: {
                        VStack(alignment:.leading,spacing:5) {
                            Text(draft.workerName.isEmpty ?
                                "Trabajador por seleccionar":draft.workerName)
                                .font(.headline).foregroundStyle(.primary)
                            Text(DanperDatePresentation.displayDateTime(draft.form.date,draft.form.time))
                                .font(.caption).foregroundStyle(.secondary)
                            Text("Materiales: \(draft.form.items.count) · Procedimientos: \(draft.form.procedures.count)")
                                .font(.caption2).foregroundStyle(.secondary)
                        }.frame(maxWidth:.infinity,alignment:.leading)
                            .padding(14).background(DanperStyle.canvas,in:RoundedRectangle(cornerRadius:14))
                    }.buttonStyle(.plain)
                }
            }
            DanperPanel {
                NavigationLink {
                    N2NativeClinicalFormView()
                } label: {
                    Label("Nueva atención",systemImage:"cross.case.fill")
                }
                Text("Para borrar un borrador, ábrelo y utiliza la acción de eliminación confirmada desde la lista de borradores del formulario.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
          }.padding(16)
        }
        .navigationTitle("Borradores")
        .danperFormChrome()
        .refreshable {await load()}
        .task {await load()}
    }
    @MainActor
    private func load() async {
        loading=true
        defer {loading=false}
        do {
            records=try await N2SyntheticTrialIOSVault.shared.readDrafts()
            failed=false
            message="Borradores recuperables: \(records.count). Desliza para actualizar."
        }catch{
            records=[]
            failed=true
            message="No se pudo verificar la bóveda N2. No se ha borrado ningún registro."
        }
    }
}

