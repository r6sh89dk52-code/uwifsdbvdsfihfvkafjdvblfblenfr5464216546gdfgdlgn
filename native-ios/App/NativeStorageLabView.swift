import SwiftUI

/// This screen cannot load a real backup or persist any patient information.
struct NativeStorageLabView: View {
    @State private var revision: Int?
    @State private var busy = false
    @State private var message = "Prueba aislada, solo con un contador ficticio."

    var body: some View {
        Form {
            Section("Almacenamiento N1 · ensayo nativo") {
                Label("AES-256-GCM + Keychain del dispositivo", systemImage: "lock.shield")
                    .font(.headline)
                Text("Las únicas entradas permitidas son un identificador fijo de prueba y un número. No admite trabajadores, DNI ni atenciones.")
                    .font(.footnote)
                Text("Usa un identificador y archivos privados distintos de los de la build 222. Nunca reemplaza ni migra su información.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            Section("Generación cifrada") {
                LabeledContent("Última versión de prueba", value: revision.map(String.init) ?? "Sin registros")
                Button {
                    Task {
                        busy = true
                        defer { busy = false }
                        do {
                            revision = try await NativeEncryptedLabVault.shared.saveNextSyntheticRevision()
                            message = "Escritura cifrada y lectura de comprobación correctas."
                        } catch {
                            message = error.localizedDescription
                        }
                    }
                } label: {
                    Label("Guardar y verificar dato ficticio", systemImage: "externaldrive.badge.checkmark")
                }
                .disabled(busy)
                Text(message).font(.footnote).foregroundStyle(.secondary)
            }
            Section("Límite de seguridad") {
                Text("Todavía no hay importación clínica, escritura de trabajadores ni restauración de un respaldo. Esa fase exige pruebas de compatibilidad y recuperación ante interrupciones.")
                    .font(.footnote)
            }
        }
        .task {
            do { revision = try await NativeEncryptedLabVault.shared.readRevision() }
            catch { message = error.localizedDescription }
        }
    }
}
