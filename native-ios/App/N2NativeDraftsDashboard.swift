import SwiftUI
import DanperCore

/// First-class encrypted N2 draft tab, never uses N1g demo drafts.
struct N2NativeDraftsDashboard:View {
    @Environment(\.n2WorkspaceVault) private var vault
    @State private var records=[N2RecoverableDraft]()
    @State private var loadedRevision:Int?
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
                        .accessibilityLabel("Eliminar borrador de " + (draft.workerName.isEmpty ? "trabajador sin seleccionar" : draft.workerName))
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
        guard deletingID==nil,!loading,
              let expectedRevision=loadedRevision,
              records.contains(where:{$0.id==id}) else{return}
        deletingID=id
        // Fast and reversible UI: hide the row before expensive encrypted
        // copy-on-write. No success is claimed until commit verifies.
        let prior=records
        records.removeAll(where:{$0.id==id})
        defer{deletingID=nil}
        do {
            // The core checks BOTH the exact revision and status=="draft".
            // A saved attention can never be removed by this operation.
            let confirmed=try await vault.deleteDraft(
                id:id,expectedRevision:expectedRevision)
            loadedRevision=confirmed.revision
            N2DraftReminder.cancel(id:id,mode:vault.mode)
            failed=false
            message="Borrador eliminado y confirmado en la bóveda cifrada."
            // Do not decrypt/audit the same 9k-worker database yet again;
            // a later visit to the screen or pull-to-refresh loads changes.
        } catch {
            // Roll back the visual change; reconcile if another screen
            // wrote a new revision. Never report a failed commit as success.
            records=prior
            failed=true
            message="El borrador no se eliminó. Se restauró en la lista. Revisa los datos y vuelve a intentarlo."
            if let latest=try? await vault.readDraftsWithRevision() {
                records=latest.drafts
                loadedRevision=latest.revision
            }
        }
    }

    @MainActor
    private func load() async {
        guard deletingID==nil else{return}
        loading=true
        defer {loading=false}
        do {
            let latest=try await vault.readDraftsWithRevision()
            records=latest.drafts
            loadedRevision=latest.revision
            failed=false
            message="Borradores recuperables: \(records.count). Desliza para actualizar."
        }catch{
            records=[]
            loadedRevision=nil
            failed=true
            message="No se pudieron abrir los borradores. No se eliminó ningún registro."
        }
    }
}

