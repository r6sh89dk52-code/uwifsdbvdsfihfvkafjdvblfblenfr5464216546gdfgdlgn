import SwiftUI
import UniformTypeIdentifiers
import DanperCore

/// Optional, explicit inactive staging. Never opens real clinical records.
struct N1nInactivePreparationView:View {
    @State private var password=""
    @State private var ownCopy=false
    @State private var reviewed=false
    @State private var understands=false
    @State private var choosing=false
    @State private var confirming=false
    @State private var working=false
    @State private var prepared:N1mRealClinicalStagingVault.Prepared?
    @State private var message=""
    @State private var failed=false
    private var allowed:Bool {
        ownCopy && reviewed && understands &&
        password.utf16.count >= 14 && password.utf16.count <= 200 && !working
    }
    var body:some View {
        Form {
            Section("Copia única · cifrada · INACTIVA") {
                Label("No restaura ni fusiona pacientes",systemImage:"lock.shield.fill")
                    .font(.headline)
                Text("La preparación conserva los datos en una bóveda independiente. Nunca sustituye la build 222 ni agrega información al formulario ficticio.")
                if let prepared {
                    LabeledContent("Trabajadores",value:"\(prepared.workers)")
                    LabeledContent("Atenciones",value:"\(prepared.attentions)")
                    LabeledContent("Borradores",value:"\(prepared.drafts)")
                    LabeledContent("Consumos pendientes",value:"\(prepared.unresolvedConsumptions)")
                    Label("Cifrado preparado, sin activar",systemImage:"checkmark.shield")
                        .foregroundStyle(.green)
                } else {
                    Text("No hay preparación confirmada.").foregroundStyle(.secondary)
                }
            }
            Section("Revisión explícita") {
                Toggle("Seleccionaré solo mi copia original build 222.",isOn:$ownCopy)
                Toggle("Revisé los posibles registros ficticios; pueden existir otros sin marcar.",isOn:$reviewed)
                Toggle("Entiendo que NO se importará, mezclará ni activará ningún dato clínico.",isOn:$understands)
                Text("La procedencia declarada no garantiza autenticidad. Utiliza antes la inspección de respaldo real.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            Section("Preparar en este iPhone") {
                SecureField("Contraseña del respaldo (mín. 14 caracteres)",text:$password)
                    .textContentType(.password)
                Button {
                    confirming=true
                } label: {
                    Label(working ? "Verificando…" : "Elegir y preparar archivo",
                          systemImage:"lock.doc")
                }
                .disabled(!allowed)
                if !message.isEmpty {
                    Text(message).font(.footnote)
                        .foregroundStyle(failed ? Color.red : Color.secondary)
                }
                Text("La contraseña se borra al seleccionar el archivo. No se muestran nombres ni diagnósticos, ni se envían datos a GitHub.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Revisión de bóveda")
        .danperFormChrome()
        .confirmationDialog("Preparación cifrada, sin restauración",
                            isPresented:$confirming,titleVisibility:.visible) {
            Button("Seleccionar respaldo") { choosing=true }
            Button("Cancelar",role:.cancel) {}
        } message: {
            Text("Se permitirá una sola fuente completa; cualquier otra diferente será rechazada.")
        }
        .fileImporter(isPresented:$choosing,allowedContentTypes:[.item],
                      allowsMultipleSelection:false) { result in
            switch result {
            case .failure:
                password=""
                message="No se pudo abrir el selector."
                failed=true
            case .success(let urls):
                guard let url=urls.first else {
                    password=""
                    return
                }
                let pass=password
                password=""
                let ack=N1nAcknowledgment(originalBuild222:ownCopy,
                    reviewedForDemo:reviewed,understandsNoRestore:understands)
                working=true
                failed=false
                message="Preparación local en curso…"
                Task.detached(priority:.userInitiated) {
                    do {
                        let receipt=try await PortableBackupInspector.prepareInactive(
                            url:url,password:pass,acknowledgment:ack)
                        await MainActor.run {
                            prepared=receipt
                            failed=false
                            working=false
                            message="Preparado y cifrado. No se importaron datos clínicos."
                        }
                    } catch {
                        await MainActor.run {
                            working=false
                            failed=true
                            message="Preparación rechazada: \(error.localizedDescription). No se modificó la build 222."
                        }
                    }
                }
            }
        }
        .task { await inspectExisting() }
    }
    @MainActor private func inspectExisting() async {
        do {
            prepared=try await N1mRealClinicalStagingIOSVault.shared.preparedSummary()
        } catch {
            failed=true
            message="Una preparación existente no pudo verificarse; no se sobrescribirá."
        }
    }
}
