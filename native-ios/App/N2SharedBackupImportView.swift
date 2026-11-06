import SwiftUI

/// Uses the existing restore flows and device-owner authentication. No share
/// extension, app group, shared Keychain entitlement or automatic restore.
struct N2SharedBackupImportView:View {
    let file:URL
    @Environment(\.dismiss) private var dismiss
    var body:some View {
        NavigationStack {
            List {
                Section("Respaldo cifrado recibido") {
                    Text("El archivo fue copiado sin modificar el original. Elige el alcance; después se comprobarán la contraseña, el formato y la integridad.")
                    NavigationLink("Recuperación completa en una fuente vacía") {
                        N2SimpleRestoreView(kind:.complete,onRestored:{dismiss()},incomingFile:file)
                    }
                    NavigationLink("Restaurar historial conservando inventario") {
                        N2SimpleRestoreView(kind:.clinical,onRestored:{dismiss()},incomingFile:file)
                    }
                    Text("No borres la aplicación ni la fuente existente. La recuperación completa se bloqueará si ya contiene datos.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Recibir respaldo")
            .toolbar {ToolbarItem(placement:.cancellationAction){Button("Cerrar"){dismiss()}}}
        }
        .interactiveDismissDisabled()
    }
}
