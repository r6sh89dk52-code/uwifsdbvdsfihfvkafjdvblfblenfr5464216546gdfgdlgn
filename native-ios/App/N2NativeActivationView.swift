import SwiftUI
import UniformTypeIdentifiers
import DanperCore

/// Protected native one-source admission. Never imports from the N1g demo or
/// live build222 sandbox. Explicit local .danperbackup file only.
struct N2NativeActivationView:View {
    @State private var password=""
    @State private var isOriginal=false
    @State private var hasReviewedDemo=false
    @State private var understands=false
    @State private var choosing=false
    @State private var confirming=false
    @State private var busy=false
    @State private var summary:N2ProtectedStoreSummary?
    @State private var status="Sin importación nativa activa."
    @State private var failed=false

    private var allowed:Bool {
        !busy && summary==nil && isOriginal && hasReviewedDemo &&
        understands && (14...200).contains(password.count)
    }
    var body:some View {
        Form {
            Section("Importación ÚNICA · iOS nativo") {
                Label("Nueva bóveda independiente de la build 222",
                      systemImage:"lock.shield.fill").font(.headline)
                Text("No se eliminan ni fusionan atenciones o inventarios. La app original mantiene sus archivos y su Keychain.")
                    .font(.footnote)
                if let summary {
                    LabeledContent("Trabajadores",value:String(summary.workers))
                    LabeledContent("Atenciones",value:String(summary.attentions))
                    LabeledContent("Guardadas",value:String(summary.saved))
                    LabeledContent("Borradores",value:String(summary.drafts))
                    LabeledContent("Movimientos Kardex",value:String(summary.physicalMovements))
                    LabeledContent("Consumos pendientes",value:String(summary.pendingClinicalLines))
                    Label("Fuente N2 cifrada y verificada",systemImage:"checkmark.shield")
                        .foregroundStyle(.green)
                }
            }
            Section("Revisiones obligatorias") {
                Toggle("Es una copia original y completa de mi build 222.",
                       isOn:$isOriginal)
                Toggle("He revisado si contiene datos ficticios mezclados con datos reales.",
                       isOn:$hasReviewedDemo)
                Toggle("Entiendo que este proceso creará una bóveda nueva, sin modificar la anterior.",
                       isOn:$understands)
                Text("La verificación automática detecta algunas señales de demostración, pero no puede certificar por sí sola la procedencia de todas las historias.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            Section("Seleccionar respaldo cifrado") {
                SecureField("Contraseña original de respaldo",text:$password)
                    .textContentType(.password)
                Button {
                    confirming=true
                } label: {
                    Label(busy ? "Importación protegida..." :
                         "Revisar e importar UNA copia",systemImage:"lock.doc")
                }
                .disabled(!allowed)
                if !status.isEmpty {
                    Text(status).font(.footnote)
                        .foregroundStyle(failed ? Color.red : Color.secondary)
                }
                Text("La contraseña solo se usa localmente para descifrar y verificar. Se descarta del formulario después de seleccionar el archivo.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section("Estado de la migración") {
                Text("Activar una bóveda cifrada no declara completa la migración. Continúan siendo obligatorias las pruebas de historias, medicamentos, FEFO y los dos libros Excel antes de reemplazar el trabajo en build 222.")
                    .font(.footnote)
            }
        }
        .navigationTitle("Fuente clínica nativa")
        .confirmationDialog("¿Crear la bóveda clínica N2?",isPresented:$confirming,
                            titleVisibility:.visible) {
            Button("Seleccionar mi .danperbackup") {choosing=true}
            Button("Cancelar",role:.cancel) {}
        } message: {
            Text("Se aceptará solo una fuente, previamente validada. No podrá agregarse un segundo respaldo sobre ella.")
        }
        .fileImporter(isPresented:$choosing,allowedContentTypes:[.item],
                      allowsMultipleSelection:false){ result in
            let pass=password
            password=""
            switch result {
            case .failure:
                status="No se pudo elegir un respaldo; no se realizaron cambios."
                failed=true
            case .success(let urls):
                guard let file=urls.first else{return}
                guard isOriginal && hasReviewedDemo && understands else{
                    status="Consentimiento o revisión pendiente."
                    failed=true
                    return
                }
                busy=true
                failed=false
                status="Verificando estructura, historial, Kardex y cifrado…"
                Task.detached(priority:.userInitiated) {
                    do {
                        let answer=try await PortableBackupInspector.activateProtectedSource(
                            url:file,password:pass,explicitConsent:true)
                        await MainActor.run {
                            summary=answer
                            failed=false
                            busy=false
                            status="Copia importada en la bóveda nativa independiente; la build 222 sigue intacta."
                        }
                    }catch{
                        await MainActor.run {
                            busy=false
                            failed=true
                            status="Importación rechazada o incompleta. No se modificó la build 222 ni se mezclaron datos."
                        }
                    }
                }
            }
        }
        .task {
            do {
                summary=try await N2ProtectedClinicalIOSVault.shared.inspect()
                if summary != nil {
                    status="La bóveda N2 ya existe. No se aceptará otra fuente."
                }
            }catch{
                failed=true
                status="No fue posible verificar la bóveda N2. Importación bloqueada."
            }
        }
        .onDisappear {password=""}
    }
}
