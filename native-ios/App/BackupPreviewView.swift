import SwiftUI
import UniformTypeIdentifiers
import DanperCore

/// N1l never exposes restored patient data; only source counts and flags.
/// The demo clinic is NOT the destination for a future real import.
struct BackupPreviewView: View {
    @State private var password = ""
    @State private var filePicker = false
    @State private var inspecting = false
    @State private var audit: N1lSourceAudit?
    @State private var errorMessage = ""

    var body: some View {
        Form {
            introduction
            verificationControls
            if let audit {
                sourceSection(audit)
                recordSection(audit)
                warningSection(audit)
            }
        }
        .fileImporter(isPresented:$filePicker,
                      allowedContentTypes:[.item],
                      allowsMultipleSelection:false) { result in
            switch result {
            case .failure:
                errorMessage = "No se pudo abrir el selector de archivos."
            case .success(let urls):
                guard let url = urls.first else { return }
                let pass = password
                password = ""
                inspecting = true
                Task.detached(priority:.userInitiated) {
                    let result = Result { try PortableBackupInspector.audit(url:url,password:pass) }
                    await MainActor.run {
                        inspecting = false
                        switch result {
                        case .success(let report):
                            audit = report
                            errorMessage = ""
                        case .failure(let problem):
                            audit = nil
                            errorMessage = problem.localizedDescription
                        }
                    }
                }
            }
        }
    }

    private var introduction: some View {
        Section {
            Label("Inspección real · sin restauración",systemImage:"lock.shield.fill")
                .font(.headline).foregroundStyle(.green)
            Text("Selecciona una copia cifrada de la build 222 desde tu propio iPhone. Esta pantalla NO modifica la aplicación anterior ni suma trabajadores o atenciones ficticias.")
            Text("La contraseña y los registros se procesan únicamente en el dispositivo. No compartas el respaldo ni la contraseña en GitHub o el chat.")
                .font(.footnote).foregroundStyle(.secondary)
        } header: { Text("Fuente única: build 222") }
    }

    private var verificationControls: some View {
        Section("Auditar copia cifrada") {
            SecureField("Contraseña de respaldo (mínimo 14 caracteres)",text:$password)
                .textContentType(.password)
            Button {
                audit = nil
                errorMessage = ""
                filePicker = true
            } label: {
                Label(inspecting ? "Inspeccionando…" : "Seleccionar respaldo .danperbackup",
                      systemImage:"doc.badge.gearshape")
            }
            .disabled(password.count < 14 || inspecting)
            if !errorMessage.isEmpty {
                Text(errorMessage).foregroundStyle(.red).font(.footnote)
            }
        }
    }

    private func sourceSection(_ report:N1lSourceAudit) -> some View {
        Section("Trabajadores y clínica") {
            LabeledContent("Trabajadores",value:"\(report.manifest.workers)")
            LabeledContent("Atenciones totales",value:"\(report.manifest.attentions)")
            LabeledContent("Atenciones guardadas",value:"\(report.saved)")
            LabeledContent("Borradores",value:"\(report.drafts)")
            LabeledContent("Correcciones",value:"\(report.corrections)")
            LabeledContent("Alergias documentadas",value:"\(report.allergyKnown)")
            LabeledContent("Niega alergias",value:"\(report.allergyNone)")
            LabeledContent("Alergias desconocidas",value:"\(report.allergyUnknown)")
            LabeledContent("Atenciones sin coincidencia en padrón",
                           value:"\(report.missingRosterReferences)")
            LabeledContent("Correcciones sin original",
                           value:"\(report.danglingCorrections)")
        }
    }

    private func recordSection(_ report:N1lSourceAudit) -> some View {
        Section("Inventario, consumos y conciliación") {
            LabeledContent("Lotes",value:"\(report.manifest.lots)")
            LabeledContent("Movimientos físicos",value:"\(report.manifest.movements)")
            LabeledContent("Equivalencias",value:"\(report.manifest.catalogMappings)")
            LabeledContent("Incidencias",value:"\(report.manifest.deliveryIncidents)")
            LabeledContent("Conciliaciones",value:"\(report.manifest.ambulatoryReconciliation)")
            LabeledContent("Consumos clínicos aún sin vínculo físico",
                           value:"\(report.unresolvedClinicalConsumptions)")
            Text("Los consumos sin vínculo no deben eliminarse automáticamente: conservaremos sus asociaciones y estado de verificación hasta conciliarlos.")
                .font(.footnote).foregroundStyle(.secondary)
        }
    }

    private func warningSection(_ report:N1lSourceAudit) -> some View {
        Section("Prevención de mezclas") {
            let demo = report.obviousDemoWorkerMarkers + report.obviousDemoClinicalMarkers
            LabeledContent("Marcadores ficticios reconocidos",value:"\(demo)")
            if demo > 0 {
                Label("Hay indicios explícitos de registros ficticios. Este respaldo necesita depuración y verificación antes de una migración.",systemImage:"exclamationmark.shield")
                    .foregroundStyle(.orange)
            }
            Text("El cifrado garantiza autenticidad del archivo, NO prueba que todos sus registros sean reales. Algunos ficticios pueden no tener marcador.")
                .font(.footnote)
            Text("Destino nativo: sin verificar. Restauración DESHABILITADA. El único modo futuro admitido será una base clínica nativa vacía con reemplazo íntegro desde UNA sola fuente auditada; nunca una unión con simulaciones.")
                .font(.footnote).foregroundStyle(.secondary)
            Label("No se importó, eliminó ni modificó ningún registro.",systemImage:"checkmark.shield")
                .foregroundStyle(.green)
            Button("Cerrar resultados") { audit = nil }
        }
    }
}
