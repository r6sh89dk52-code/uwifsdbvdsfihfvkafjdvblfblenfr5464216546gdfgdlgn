import Foundation
import SwiftUI
import LocalAuthentication
import DanperCore

/// Intentionally destructive ONLY for the independent N2 SYNTHETIC vault.
/// This screen never receives a workspace router or a clinical-data API.
struct N2DemoResetView:View {
    let onDeleted:()->Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @State private var summary:N2ProtectedStoreSummary?
    @State private var phrase=""
    @State private var confirm=false
    @State private var busy=false
    @State private var deleted=false
    @State private var status="Comprobando el entorno de prueba…"
    @State private var error=false

    private var canErase:Bool {
        !busy && !deleted && scenePhase == .active &&
        phrase==N2SyntheticResetScope.confirmation
    }

    var body:some View {
        ScrollView {
            VStack(alignment:.leading,spacing:16) {
                DanperPanel("Borrar todos los datos ficticios") {
                    Label("ELIMINACIÓN IRREVERSIBLE",systemImage:"trash.fill")
                        .font(.headline).foregroundStyle(.red)
                    Text("Se eliminará únicamente la bóveda de DEMOSTRACIÓN de esta app: trabajadores de prueba, atenciones, borradores, alergias, procedimientos, consumos, lotes, Kardex, movimientos, correcciones y sus registros cifrados.")
                        .font(.subheadline)
                        .fixedSize(horizontal:false,vertical:true)
                    Text("NO se borrará la bóveda CLÍNICA independiente, la build 222 ni sus datos. Tampoco se eliminarán respaldos que hayas exportado previamente a Archivos o compartido.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                DanperPanel("Registros de prueba actuales") {
                    if let summary {
                        LabeledContent("Trabajadores",value:String(summary.workers))
                        LabeledContent("Atenciones",value:String(summary.attentions))
                        LabeledContent("Borradores",value:String(summary.drafts))
                        LabeledContent("Movimientos físicos",value:String(summary.physicalMovements))
                        LabeledContent("Consumos pendientes",value:String(summary.pendingClinicalLines))
                    } else {
                        Text("La bóveda no está activa, ya fue eliminada o no puede leerse. La limpieza también permite retirar los archivos cifrados residuales de pruebas.")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                }
                if deleted {
                    DanperPanel {
                        Label("Datos de prueba eliminados",systemImage:"checkmark.shield.fill")
                            .foregroundStyle(.green)
                        Text("La fuente ficticia ya no está en el almacenamiento de la aplicación. No se volverá a generar a menos que inicies expresamente otra demostración.")
                            .font(.footnote)
                        Button("Volver a Inicio") {
                            onDeleted()
                            dismiss()
                        }
                        .buttonStyle(DanperPrimaryButton())
                    }
                } else {
                    DanperPanel("Confirmación de eliminación") {
                        Text("Escribe exactamente **BORRAR PRUEBAS** para habilitar la eliminación. Después deberás autorizarla con Face ID o el código del iPhone.")
                            .font(.footnote)
                        DanperField(title:"Frase de confirmación") {
                            TextField("BORRAR PRUEBAS",text:$phrase)
                                .textInputAutocapitalization(.characters)
                                .autocorrectionDisabled()
                                .accessibilityIdentifier("confirm-delete-demo-phrase")
                        }
                        Button(role:.destructive) {
                            confirm=true
                        } label: {
                            HStack {
                                if busy {ProgressView()}
                                Label(busy ? "Borrando datos de prueba…" :
                                      "Borrar definitivamente la demostración",
                                      systemImage:"trash")
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.red)
                        .disabled(!canErase)
                        .accessibilityIdentifier("delete-demo-all")
                    }
                }
                Text(status)
                    .font(.footnote)
                    .foregroundStyle(error ? Color.orange : Color.secondary)
                    .fixedSize(horizontal:false,vertical:true)
            }.padding(16)
        }
        .navigationTitle("Reiniciar pruebas")
        .navigationBarTitleDisplayMode(.inline)
        .danperFormChrome()
        .task {await inspect()}
        .confirmationDialog("¿Borrar TODOS los registros de prueba?",
                            isPresented:$confirm,titleVisibility:.visible) {
            Button("Sí, borrar todo lo ficticio",role:.destructive) {
                Task {await erase()}
            }
            Button("Cancelar",role:.cancel) {}
        } message: {
            Text("No podrás recuperar la demostración borrada desde el iPhone. La bóveda clínica y la build 222 permanecerán intactas.")
        }
    }

    @MainActor private func inspect() async {
        do {
            summary=try await N2SyntheticTrialIOSVault.shared.inspect()
            status=summary == nil ? "Sin registros de prueba activos." :
                "Se eliminarán TODOS los registros cifrados de la demostración."
            error=false
        } catch {
            summary=nil
            status="No se pudo leer la base de pruebas. Puedes eliminar también una bóveda cifrada deteriorada."
            error=true
        }
    }

    @MainActor private func erase() async {
        guard canErase else{return}
        busy=true
        error=false
        status="Autorizando eliminación…"
        defer {busy=false}
        do {
            let auth=LAContext()
            let authorized=try await auth.evaluatePolicy(
                .deviceOwnerAuthentication,
                localizedReason:"Eliminar definitivamente la bóveda ficticia de DANPER Salud Móvil")
            guard authorized,scenePhase == .active else {
                status="Eliminación cancelada: no se autorizó el dispositivo."
                error=true
                return
            }
            // Collect only DEMO draft IDs. Never clear all app notifications,
            // since clinical reminders may belong to another namespace.
            let demoDraftIDs=(try? await N2SyntheticTrialIOSVault.shared.readDrafts())?
                .map(\.id) ?? []
            try await N2SyntheticTrialIOSVault.shared.eraseEntireDemo(
                confirmation:phrase)
            for id in demoDraftIDs {N2DraftReminder.cancel(id:id)}
            let remaining=try await N2SyntheticTrialIOSVault.shared.inspect()
            guard remaining==nil else {
                throw N2SyntheticTrialIOSVault.Failure.resetIncomplete
            }
            summary=nil
            phrase=""
            deleted=true
            status="Limpieza confirmada. La bóveda clínica se mantuvo separada."
        } catch {
            error=true
            status="No se pudo confirmar el borrado completo: "+error.localizedDescription+
                " Si había archivos residuales, puedes reintentar la operación."
        }
    }
}
