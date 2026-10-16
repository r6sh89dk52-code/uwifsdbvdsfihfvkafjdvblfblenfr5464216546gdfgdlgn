import SwiftUI
import UniformTypeIdentifiers
import DanperCore

struct BackupPreviewView: View {
    @State private var password = ""
    @State private var isPickerOpen = false
    @State private var isInspecting = false
    @State private var summary: N1BackupManifest?
    @State private var error = ""

    var body: some View {
        Form {
            Section {
                Label("Solo lectura, sin restauración", systemImage: "lock.shield.fill")
                    .font(.headline)
                    .foregroundStyle(.green)
                Text("Esta pantalla verifica el respaldo .danperbackup de la build 222 con su contraseña original. Solo muestra recuentos; no guarda los pacientes ni modifica Keychain, lotes o atenciones.")
                    .font(.footnote)
                Text("No compartas la contraseña ni el respaldo en el chat ni en GitHub.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            Section("Verificar una copia existente") {
                SecureField("Contraseña de tu respaldo", text: $password)
                    .textContentType(.password)
                Button {
                    summary = nil
                    error = ""
                    isPickerOpen = true
                } label: {
                    Label(isInspecting ? "Verificando…" : "Seleccionar respaldo cifrado",
                          systemImage: "doc.badge.gearshape")
                }
                .disabled(password.count < 14 || isInspecting)
                if !error.isEmpty {
                    Text(error).foregroundStyle(.red).font(.footnote)
                }
            }
            if let summary {
                Section("Contenido comprobado · solo cantidades") {
                    LabeledContent("Trabajadores", value: "\(summary.workers)")
                    LabeledContent("Atenciones", value: "\(summary.attentions)")
                    LabeledContent("Alergias", value: "\(summary.allergies)")
                    LabeledContent("Lotes", value: "\(summary.lots)")
                    LabeledContent("Movimientos físicos", value: "\(summary.movements)")
                    LabeledContent("Equivalencias", value: "\(summary.catalogMappings)")
                    LabeledContent("Incidencias", value: "\(summary.deliveryIncidents)")
                    LabeledContent("Conciliaciones", value: "\(summary.ambulatoryReconciliation)")
                    LabeledContent("Consumos clínicos sin movimiento vinculado",
                                   value: "\(summary.unresolvedClinicalItems)")
                    Text("Verificar el respaldo no lo importa. No se realizó ninguna restauración.")
                        .font(.footnote).foregroundStyle(.secondary)
                    Button("Ocultar resultado") { self.summary = nil }
                }
            }
        }
        .fileImporter(isPresented: $isPickerOpen, allowedContentTypes: [.item],
                      allowsMultipleSelection: false) { result in
            switch result {
            case .failure:
                error = "No se pudo abrir el selector de archivos."
            case .success(let urls):
                guard let url = urls.first else { return }
                let pass = password
                password = ""
                isInspecting = true
                Task.detached(priority: .userInitiated) {
                    let output = Result { try PortableBackupInspector.inspect(url: url, password: pass) }
                    await MainActor.run {
                        isInspecting = false
                        switch output {
                        case .success(let checked):
                            summary = checked
                            error = ""
                        case .failure(let problem):
                            summary = nil
                            error = problem.localizedDescription
                        }
                    }
                }
            }
        }
    }
}
