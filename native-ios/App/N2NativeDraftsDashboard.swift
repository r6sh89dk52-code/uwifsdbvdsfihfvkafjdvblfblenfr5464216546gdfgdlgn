import SwiftUI
import DanperCore

/// First-class encrypted N2 draft tab, never uses N1g demo drafts.
struct N2NativeDraftsDashboard:View {
    @Environment(\.n2WorkspaceVault) private var vault
    @State private var records=[N2RecoverableDraft]()
    @State private var loading=true
    @State private var failed=false
    @State private var message="Leyendo borradores cifrados…"
    @State private var selectedDeleteID:String?
    @State private var deletingID:String?

    var body:some View {
        ScrollView {
          VStack(alignment:.leading,spacing:16) {
            if failed {
                DanperPanel {
                    Label(message,systemImage:"exclamationmark.triangle")
                        .foregroundStyle(.orange)
                }
            }
            DanperPanel("Registros pendientes") {
                if records.isEmpty && !loading {
                    Text("No hay borradores para recuperar.")
                        .foregroundStyle(.secondary)
                }
                ForEach(records) { draft in
                    HStack(alignment:.center,spacing:8) {
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
                            }
                            .frame(maxWidth:.infinity,alignment:.leading)
                            .padding(14)
                            .background(DanperStyle.canvas,in:RoundedRectangle(cornerRadius:14))
                        }
                        .buttonStyle(.plain)
                        .disabled(deletingID != nil)
                        Button(role:.destructive) {
                            selectedDeleteID=draft.id
                        } label: {
                            Image(systemName:"trash")
                                .font(.body.weight(.semibold))
                                .frame(width:44,height:48)
                        }
                        .buttonStyle(DanperSecondaryButton())
                        .disabled(deletingID != nil)
                        .accessibilityLabel("Eliminar borrador de "+
                            (draft.workerName.isEmpty ? "trabajador sin seleccionar" : draft.workerName))
                        .accessibilityIdentifier("draft-dashboard-delete-"+draft.id)
                    }
                }
            }
            DanperPanel {
                NavigationLink {
                    N2NativeClinicalFormView()
                } label: {
                    Label("Nueva atención",systemImage:"cross.case.fill")
                }
                Text("Puedes eliminar cada borrador desde el icono de papelera, sin abrir la atención. Se solicitará confirmación y no se tocarán atenciones guardadas.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
          }.padding(16)
        }
        .navigationTitle("Borradores")
        .danperFormChrome()
        .refreshable {await load()}
        .task {await load()}
        .confirmationDialog("¿Eliminar este borrador?",
            isPresented:Binding(
                get:{selectedDeleteID != nil},
                set:{if !$0 {selectedDeleteID=nil}}
            ),titleVisibility:.visible) {
            Button("Eliminar borrador",role:.destructive) {
                guard let id=selectedDeleteID else{return}
                selectedDeleteID=nil
                Task {await deleteDraft(id)}
            }
            Button("Cancelar",role:.cancel) {selectedDeleteID=nil}
        } message: {
            Text("Solo se eliminará este borrador pendiente. Las atenciones confirmadas y los consumos del Kardex no se modificarán.")
        }
    }

    @MainActor private func deleteDraft(_ id:String) async {
        guard deletingID==nil,!loading,records.contains(where:{$0.id==id}) else{return}
        deletingID=id
        defer{deletingID=nil}
        do {
            guard let current=try await vault.inspect() else {
                failed=true
                message="La bóveda clínica no está disponible. No se eliminó ningún registro."
                return
            }
            // The core only deletes records that STILL have draft status.
            // Journal revision checking prevents silent concurrent overwrites.
            _=try await vault.deleteDraft(id:id,expectedRevision:current.revision)
            N2DraftReminder.cancel(id:id,mode:vault.mode)
            records.removeAll(where:{$0.id==id})
            failed=false
            message="Borrador eliminado correctamente. Ninguna atención guardada fue modificada."
            do {records=try await vault.readDrafts()}
            catch {
                failed=true
                message="Borrador eliminado, pero no se pudo actualizar la lista. Desliza para volver a cargar."
            }
        } catch {
            failed=true
            message="No se pudo eliminar el borrador. Es posible que haya cambiado; actualiza la lista antes de reintentar."
            if let latest=try? await vault.readDrafts() {records=latest}
        }
    }

    @MainActor
    private func load() async {
        guard deletingID==nil else{return}
        loading=true
        defer {loading=false}
        do {
            records=try await vault.readDrafts()
            failed=false
            message="Borradores recuperables: \(records.count). Desliza para actualizar."
        }catch{
            records=[]
            failed=true
            message="No se pudieron abrir los borradores. No se eliminó ningún registro."
        }
    }
}

