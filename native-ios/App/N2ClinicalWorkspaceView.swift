import Foundation
import SwiftUI
import LocalAuthentication
import DanperCore

/// A completely separate navigation tree. Environment value is a constant for
/// this workspace's lifetime. Demo tabs beneath never hold clinical references.
struct N2ClinicalWorkspaceGateView:View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var summary:N2ProtectedStoreSummary?
    @State private var busy=false
    @State private var showWorkspace=false
    @State private var message="Verificando la bóveda clínica independiente…"
    @State private var invalidSource=false

    var body:some View {
        ScrollView {
            VStack(alignment:.leading,spacing:16) {
                DanperPanel("Espacio clínico independiente") {
                    Label("Fuente clínica separada",systemImage:"lock.shield.fill")
                        .font(.headline)
                    Text("No contiene ni fusiona datos de la demostración. Los registros que se creen aquí permanecerán exclusivamente en la bóveda CLÍNICA.")
                        .font(.footnote).foregroundStyle(.secondary)
                    Label("EN VALIDACIÓN: todavía no está aprobada para atención de pacientes reales.",
                          systemImage:"exclamationmark.triangle.fill")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.orange)
                        .fixedSize(horizontal:false,vertical:true)
                }
                DanperPanel("Verificar la fuente") {
                    if let summary {
                        LabeledContent("Trabajadores",value:String(summary.workers))
                        LabeledContent("Atenciones",value:String(summary.attentions))
                        LabeledContent("Movimientos físicos",value:String(summary.physicalMovements))
                        LabeledContent("Pendientes",value:String(summary.pendingClinicalLines))
                        Label("Bóveda clínica cifrada identificada",
                              systemImage:"checkmark.shield.fill")
                            .foregroundStyle(.green)
                    } else {
                        Text("Primero debe existir una copia original verificada. La demostración ficticia nunca se convierte automáticamente en esta fuente.")
                            .font(.subheadline).foregroundStyle(.secondary)
                        NavigationLink {
                            N2NativeActivationView()
                        } label: {
                            Label("Importación protegida · fuente única",
                                  systemImage:"doc.badge.arrow.up")
                        }
                        .buttonStyle(DanperSecondaryButton())
                    }
                    Button {
                        Task {await refresh()}
                    } label: {
                        Label("Comprobar bóveda clínica",systemImage:"arrow.clockwise")
                    }
                    .buttonStyle(DanperSecondaryButton())
                    .disabled(busy)
                }
                DanperPanel("Acceso de evaluación") {
                    Button {
                        Task {await openWithAuthentication()}
                    } label: {
                        HStack(spacing:10) {
                            if busy {ProgressView().tint(.white)}
                            Label("Entrar al espacio clínico",systemImage:"faceid")
                        }
                    }
                    .buttonStyle(DanperPrimaryButton())
                    .disabled(summary == nil || busy || scenePhase != .active)
                    Text(message).font(.footnote)
                        .foregroundStyle(invalidSource ? Color.orange : Color.secondary)
                    Text("Requiere autenticación adicional. El espacio se cierra cuando la aplicación deja de estar activa y no permite cambiar de fuente dentro de una atención.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }.padding(16)
        }
        .navigationTitle("Acceso clínico")
        .danperFormChrome()
        .task {await refresh()}
        .onChange(of:scenePhase) {_,phase in
            if phase != .active {
                showWorkspace=false
                busy=false
                summary=nil
            }
        }
        .fullScreenCover(isPresented:$showWorkspace) {
            N2ClinicalWorkspaceRootView {
                showWorkspace=false
            }
            .environment(\.n2WorkspaceVault,.clinical)
        }
    }

    @MainActor private func refresh() async {
        guard !busy else{return}
        busy=true
        defer {busy=false}
        do {
            summary=try await N2ProtectedClinicalIOSVault.shared.inspect()
            invalidSource=false
            message=summary == nil
                ? "No se encontró una fuente clínica independiente."
                : "Fuente encontrada. Necesitas autenticarte para abrir este espacio."
        } catch {
            summary=nil
            invalidSource=true
            message="La bóveda clínica no superó la verificación. Acceso bloqueado; no se han modificado sus registros."
        }
    }

    @MainActor private func openWithAuthentication() async {
        guard !busy,scenePhase == .active,summary != nil else{return}
        busy=true
        defer {busy=false}
        do {
            let context=LAContext()
            guard try await context.evaluatePolicy(.deviceOwnerAuthentication,
                    localizedReason:"Entrar al espacio clínico independiente de DANPER") else {
                message="Autenticación no autorizada."
                return
            }
            // Re-read AFTER authentication; an old cached count never grants
            // permission to access a missing or otherwise invalid source.
            guard let verified=try await N2ProtectedClinicalIOSVault.shared.inspect(),
                  verified.revision>0,scenePhase == .active else {
                summary=nil
                invalidSource=true
                message="No se pudo verificar nuevamente la fuente clínica."
                return
            }
            summary=verified
            invalidSource=false
            showWorkspace=true
        } catch {
            invalidSource=true
            message="Autenticación o verificación fallida. La bóveda permanece cerrada."
        }
    }
}

/// All children inherit a FIXED clinical environment. The independently
/// mounted demo application's tabs keep their default .demo environment.
private struct N2ClinicalWorkspaceRootView:View {
    let onClose:()->Void
    @Environment(\.scenePhase) private var scenePhase
    @State private var tab=0
    @State private var registeredDNI:String?
    var body:some View {
        TabView(selection:$tab) {
            NavigationStack {
                ScrollView {
                    VStack(alignment:.leading,spacing:16) {
                        DanperPanel {
                            Label("ESPACIO CLÍNICO · FUENTE INDEPENDIENTE",
                                  systemImage:"cross.case.fill")
                                .font(.headline)
                            Text("Evaluación técnica en curso. No utilizar con pacientes reales hasta aprobar las pruebas de restauración, inventario y exportación.")
                                .font(.footnote).foregroundStyle(.orange)
                        }
                        Button {
                            tab=2
                        } label: {
                            Label("Registrar nueva atención",systemImage:"plus.circle.fill")
                        }
                        .buttonStyle(DanperPrimaryButton())
                        NavigationLink {
                            N2NativeInventoryView()
                        } label: {
                            Label("Inventario por lotes",systemImage:"shippingbox")
                        }
                        .buttonStyle(DanperSecondaryButton())
                        NavigationLink {
                            N2VerifiedIndicatorExportView()
                        } label: {
                            Label("Indicador ambulatorio · Excel",systemImage:"tablecells")
                        }
                        .buttonStyle(DanperSecondaryButton())
                        Button("Cerrar espacio clínico",role:.cancel) {onClose()}
                            .buttonStyle(DanperSecondaryButton())
                    }.padding(16)
                }
                .navigationTitle("DANPER · Clínica")
            }
            .tabItem {Label("Inicio",systemImage:"house.fill")}.tag(0)
            NavigationStack {
                N2NativeHistoryView(useProtectedVault:true)
                    .toolbar {
                        ToolbarItem(placement:.topBarTrailing) {
                            NavigationLink {
                                N2NativeWorkerEditorView(onSaved:{dni in
                                    registeredDNI=dni
                                    tab=2
                                })
                            } label: {
                                Label("Nuevo trabajador",systemImage:"person.badge.plus")
                            }
                        }
                    }
            }
            .tabItem {Label("Personal",systemImage:"person.2.fill")}.tag(1)
            NavigationStack {
                N2NativeClinicalFormView(initialWorkerDNI:registeredDNI)
                    .id(registeredDNI ?? "clinical-attention")
            }
            .tabItem {Label("Atención",systemImage:"cross.case.fill")}.tag(2)
            NavigationStack {
                N2NativeDraftsDashboard()
            }
            .tabItem {Label("Borradores",systemImage:"doc.text.fill")}.tag(3)
            NavigationStack {
                ScrollView {
                    VStack(alignment:.leading,spacing:14) {
                        DanperPanel {
                            Label("Fuente clínica cifrada",
                                  systemImage:"lock.shield.fill")
                                .font(.headline)
                            Text("No se permite mezclar ni importar archivos de la demostración.")
                                .font(.footnote).foregroundStyle(.secondary)
                        }
                        DanperToolLink(title:"Inventario y lotes",
                                       symbol:"shippingbox") {N2NativeInventoryView()}
                        DanperToolLink(title:"Conciliación de inventario",
                                       symbol:"checkmark.shield") {N2ReconciliationView()}
                        DanperToolLink(title:"Kardex de enfermería",
                                       symbol:"tablecells") {N2VerifiedNursingExportView()}
                        DanperToolLink(title:"Indicador ambulatorio · Excel",
                                       symbol:"doc.richtext") {N2VerifiedIndicatorExportView()}
                        DanperToolLink(title:"Respaldo cifrado",
                                       symbol:"lock.doc") {N2NativeBackupExportView()}
                        Button("Cerrar espacio clínico",role:.cancel) {onClose()}
                            .buttonStyle(DanperSecondaryButton())
                    }.padding(16)
                }
                .navigationTitle("Más · Clínica")
            }
            .tabItem {Label("Más",systemImage:"square.grid.2x2.fill")}.tag(4)
        }
        .tint(DanperStyle.red)
        .environment(\.locale,Locale(identifier:"es_PE"))
        .onChange(of:tab) {old,current in
            if old==2 && current != 2 {registeredDNI=nil}
        }
        .onChange(of:scenePhase) {_,phase in
            if phase != .active {onClose()}
        }
    }
}
