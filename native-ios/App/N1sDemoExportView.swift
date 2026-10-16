import Foundation
import SwiftUI
import UIKit
import DanperCore

/// Produces exclusively compiled-in synthetic examples. Does not read the
/// clinic instance, N1m staging vault, backups, real Kardex or Keychain.
private enum N1sBundledExamples {
    enum Failure: Error { case missingTestResource }
    static func generate(_ kind: N1sDemoWorkbookKind) throws -> Data {
        let prefix = kind == .indicator ? "n1s-indicator" : "n1s-nursing"
        guard let templateURL = Bundle.main.url(
                    forResource: prefix + "-template-store", withExtension: "zip",
                    subdirectory: "N1sDemoResources"),
              let planURL = Bundle.main.url(
                    forResource: prefix + "-plan", withExtension: "json",
                    subdirectory: "N1sDemoResources") else {
            throw Failure.missingTestResource
        }
        return try N1sDemoExportBridge.create(kind,
                base: Data(contentsOf:templateURL),
                manifest: Data(contentsOf:planURL))
    }
}

private struct N1sExportShareItem: Identifiable {
    let id = UUID()
    let url: URL
}

private struct N1sShareController: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }
    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}

struct N1sDemoExportView: View {
    @State private var kind: N1sDemoWorkbookKind = .indicator
    @State private var working = false
    @State private var status = "Solo datos totalmente ficticios."
    @State private var shareItem: N1sExportShareItem?
    @State private var temporaryFolder: URL?

    var body: some View {
        Form {
            Section("Exportación SwiftUI · DEMOSTRACIÓN") {
                Label("SIN DATOS CLÍNICOS REALES", systemImage: "checkmark.shield.fill")
                    .foregroundStyle(.orange)
                    .font(.headline)
                Text("Los dos libros se generan con plantillas saneadas y movimientos sintéticos incluidos en esta aplicación de prueba. No se leen pacientes, inventario, respaldos ni borradores.")
                    .font(.footnote)
                Picker("Libro", selection: $kind) {
                    Text("Indicador Ambulatorio · 10 hojas").tag(N1sDemoWorkbookKind.indicator)
                    Text("Kardex Enfermería · 98 productos").tag(N1sDemoWorkbookKind.nursing)
                }
                .pickerStyle(.inline)
            }
            Section("Generar y compartir") {
                Button {
                    generate()
                } label: {
                    Label(working ? "Generando..." : "Generar Excel ficticio y abrir Compartir",
                          systemImage: "square.and.arrow.up")
                }
                .disabled(working)
                Text(status)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Text("El nombre del archivo lleva DEMO_NO_OFICIAL. El sistema borrará su copia temporal al cerrar Compartir.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Section("Antes de activar datos reales") {
                Text("Faltan el libro conectado al ledger cifrado, las pruebas con Excel de escritorio, la restauración clínica integral y la validación en un iPhone físico. La build 222 permanece independiente.")
                    .font(.footnote)
            }
        }
        .navigationTitle("Excel nativo · prueba")
        .sheet(item: $shareItem, onDismiss: removeTemporaryFile) { item in
            N1sShareController(url: item.url)
        }
    }

    @MainActor
    private func generate() {
        guard !working else { return }
        working = true
        status = "Comprobando y escribiendo libro ficticio..."
        let requested = kind
        Task {
            defer { working = false }
            do {
                let data = try await Task.detached(priority: .userInitiated) {
                    try N1sBundledExamples.generate(requested)
                }.value
                removeTemporaryFile()
                let folder = FileManager.default.temporaryDirectory
                    .appendingPathComponent("danper-n1s-demo-" + UUID().uuidString,
                                            isDirectory: true)
                try FileManager.default.createDirectory(at: folder,
                                                       withIntermediateDirectories: true)
                temporaryFolder = folder
                let url = folder.appendingPathComponent(requested.filename)
                try data.write(to: url, options: .atomic)
                status = "Libro ficticio generado: " + requested.filename
                shareItem = N1sExportShareItem(url: url)
            } catch {
                status = "No se pudo generar la simulación. El stock y los respaldos no se modificaron."
                removeTemporaryFile()
            }
        }
    }

    @MainActor
    private func removeTemporaryFile() {
        if let folder = temporaryFolder {
            try? FileManager.default.removeItem(at: folder)
        }
        temporaryFolder = nil
    }
}
