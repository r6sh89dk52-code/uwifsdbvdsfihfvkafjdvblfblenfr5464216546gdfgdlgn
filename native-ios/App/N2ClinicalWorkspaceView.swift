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
                    Text("Importa el padrón PERSONAL desde Excel o restaura una copia cifrada de la Build 222. Ninguna fuente se cargará automáticamente.")
                        .font(.footnote).foregroundStyle(.secondary)
                    Label("EN VALIDACIÓN: todavía no está aprobada para atención de pacientes reales.",
                          systemImage:"exclamationmark.triangle.fill")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.orange)
                        .fixedSize(horizontal:false,vertical:true)
                }
                DanperPanel("Verificar la fuente") {
                    if let summary {
                        NavigationLink {
                            N2NativePersonalImportView()
                        } label: {
                            Label("Importar o conciliar Excel PERSONAL",systemImage:"person.2.arrow.trianglehead.counterclockwise")
                        }
                        .buttonStyle(DanperSecondaryButton())
                        LabeledContent("Trabajadores",value:String(summary.workers))
                        LabeledContent("Atenciones",value:String(summary.attentions))
                        LabeledContent("Movimientos físicos",value:String(summary.physicalMovements))
                        LabeledContent("Pendientes",value:String(summary.pendingClinicalLines))
                        Label("Bóveda clínica cifrada identificada",
                              systemImage:"checkmark.shield.fill")
                        Text("Ya existe una fuente cifrada. Importar de nuevo PERSONAL conciliará el padrón sin borrar atenciones, consumos ni lotes. Para restaurar otro respaldo se necesita una base independiente.")
                            .font(.caption).foregroundStyle(.secondary)
                            .foregroundStyle(.green)
                    } else {
                        Text("Elige una sola fuente inicial. Si vas a conservar atenciones y Kardex anteriores, restaura primero el respaldo cifrado de la Build 222. Si quieres un padrón nuevo, importa directamente PERSONAL.")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.secondary)
                        NavigationLink {
                            N2NativePersonalImportView()
                        } label: {
                            Label("Importar trabajadores desde Excel PERSONAL",
                                  systemImage:"tablecells")
                        }
                        .buttonStyle(DanperPrimaryButton())
                        .accessibilityIdentifier("clinical-first-run-import-personal")
                        NavigationLink {
                            N2NativeActivationView()
                        } label: {
                            Label("Restaurar copia cifrada Build 222",
                                  systemImage:"lock.doc")
                        }
                        .buttonStyle(DanperSecondaryButton())
                        .accessibilityIdentifier("clinical-first-run-restore-222")
                        Text("Usa PERSONAL únicamente si deseas comenzar con un padrón nuevo y SIN las atenciones ni el inventario antiguos. Una vez creada la bóveda clínica, no se sobrescribe con otro respaldo.")
                            .font(.footnote).foregroundStyle(.secondary)
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
        // Returning from PERSONAL import must refresh the gate's source count.
        .onAppear {
            if scenePhase == .active {Task {await refresh()}}
        }
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
    @AppStorage("danper.visual.palette") private var visualPalette="danper"
    @AppStorage("danper.appearance") private var appearance="system"
    @AppStorage("danper.haptics.enabled") private var haptics=true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body:some View {
        TabView(selection:$tab) {
            NavigationStack {
                ScrollView {
                    VStack(alignment:.leading,spacing:18) {
                        HStack(spacing:11) {
                            Image("BrandLogo").resizable().scaledToFit()
                                .frame(width:44,height:44)
                                .clipShape(RoundedRectangle(cornerRadius:11))
                            VStack(alignment:.leading,spacing:1) {
                                Text("DANPER")
                                    .font(.system(.headline,design:.rounded,weight:.heavy))
                                Text("SALUD MÓVIL")
                                    .font(.caption2.weight(.bold)).tracking(1.3)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer(minLength:8)
                            Button {withAnimation(reduceMotion ? nil : DanperStyle.animation){tab=3}} label:{
                                Image(systemName:"gearshape")
                                    .font(.title3)
                                    .foregroundStyle(.primary)
                                    .frame(width:44,height:44)
                            }
                            .accessibilityLabel("Ajustes")
                        }
                        VStack(alignment:.leading,spacing:9) {
                            Text("DEPARTAMENTO DE SALUD")
                                .font(.caption2.weight(.bold)).tracking(1.3)
                                .foregroundStyle(DanperStyle.red)
                            HStack(spacing:12) {
                                Text("Bienvenido a DANPER")
                                    .font(.system(.title,design:.rounded,weight:.bold))
                                    .fixedSize(horizontal:false,vertical:true)
                                Spacer(minLength:4)
                                Image(systemName:"waveform.path.ecg")
                                    .font(.title2.weight(.semibold))
                                    .foregroundStyle(DanperStyle.red)
                            }
                            Text("Registro ambulatorio local · Fuente clínica cifrada")
                                .font(.subheadline).foregroundStyle(.secondary)
                        }
                        .frame(maxWidth:.infinity,alignment:.leading)
                        .padding(19)
                        .background(DanperStyle.surface,
                                    in:RoundedRectangle(cornerRadius:20))
                        if visualPalette=="salud" {
                            HStack(spacing:8) {
                                VStack(alignment:.leading,spacing:6) {
                                    Label("SALUD OCUPACIONAL",
                                          systemImage:"cross.case.fill")
                                        .font(.caption2.weight(.bold))
                                    Text("Prevención, atención y seguimiento")
                                        .font(.subheadline.weight(.semibold))
                                    Text("Un mismo registro para ambas sedes.")
                                        .font(.caption).opacity(0.9)
                                }.foregroundStyle(.white)
                                Spacer(minLength:0)
                                N2HealthMascot().frame(width:112,height:112)
                            }
                            .padding(.leading,16).padding(.trailing,6)
                            .frame(maxWidth:.infinity,minHeight:124)
                            .background(
                                LinearGradient(colors:[
                                    Color(red:0.02,green:0.38,blue:0.78),
                                    Color(red:0.01,green:0.69,blue:0.89)],
                                    startPoint:.leading,endPoint:.trailing),
                                in:RoundedRectangle(cornerRadius:20))
                        }
                        Button {
                            withAnimation(reduceMotion ? nil : DanperStyle.animation) {
                                tab=1
                            }
                        } label: {
                            Label("Registrar nueva atención",
                                  systemImage:"plus.circle.fill")
                                .frame(maxWidth:.infinity,minHeight:48)
                        }
                        .buttonStyle(DanperPrimaryButton())
                        .accessibilityIdentifier("clinical-home-new-attention")

                        Text("Herramientas")
                            .font(.title3.weight(.bold))
                            .frame(maxWidth:.infinity,alignment:.leading)
                        LazyVGrid(columns:[GridItem(.flexible(),spacing:12),
                                           GridItem(.flexible(),spacing:12)],
                                  spacing:12) {
                            homeTile("Personal","Padrón Excel",
                                     symbol:"person.2.fill") {
                                N2NativePersonalImportView()
                            }
                            homeTile("Kardex","Inventario y movimientos",
                                     symbol:"shippingbox.fill") {
                                N2Build222KardexHub()
                            }
                            homeTile("Indicador","Excel · 10 hojas",
                                     symbol:"tablecells") {
                                N2VerifiedIndicatorExportView()
                            }
                            homeTile("Historial","Atenciones registradas",
                                     symbol:"list.clipboard.fill") {
                                N2NativeHistoryView(useProtectedVault:true)
                            }
                            homeTile("Borradores","Registros pendientes",
                                     symbol:"doc.text.fill") {
                                N2NativeDraftsDashboard()
                            }
                            homeTile("Respaldo","Copia cifrada",
                                     symbol:"lock.doc") {
                                N2NativeBackupExportView()
                            }
                        }
                        Label("Acceso protegido. Validar restauración, Kardex y Excel en el dispositivo antes de usar registros de pacientes reales.",
                              systemImage:"lock.shield")
                            .font(.caption).foregroundStyle(.secondary)
                        Button("Cerrar espacio clínico",role:.cancel) {onClose()}
                            .buttonStyle(DanperSecondaryButton())
                    }
                    .padding(16)
                }
                .navigationTitle("Inicio")
            }
            .tabItem {Label("Inicio",systemImage:"house.fill")}.tag(0)
            NavigationStack {
                N2NativeClinicalFormView(initialWorkerDNI:registeredDNI)
                    .id(registeredDNI ?? "clinical-attention")
            }
            .tabItem {Label("Registrar",systemImage:"plus.circle.fill")}.tag(1)
            NavigationStack {
                N2NativeHistoryView(useProtectedVault:true)
                    .toolbar {
                        ToolbarItem(placement:.topBarTrailing) {
                            NavigationLink {
                                N2NativeWorkerEditorView(onSaved:{dni in
                                    registeredDNI=dni
                                    tab=1
                                })
                            } label: {
                                Label("Nuevo trabajador",systemImage:"person.badge.plus")
                            }
                        }
                    }
            }
            .tabItem {Label("Historial",systemImage:"list.clipboard.fill")}.tag(2)
            NavigationStack {
                ScrollView {
                    VStack(alignment:.leading,spacing:14) {
                        DanperPanel {
                            Label("Fuente clínica cifrada",
                                  systemImage:"lock.shield.fill")
                                .font(.headline)
                            Text("No se mezclan padrones, inventarios o atenciones de otras fuentes sin verificación.")
                                .font(.footnote).foregroundStyle(.secondary)
                        }
                        DanperPanel("Apariencia") {
                            Picker("Colores",selection:$visualPalette) {
                                Text("DANPER rojo").tag("danper")
                                Text("Salud azul").tag("salud")
                            }
                            .pickerStyle(.segmented)
                            Picker("Modo",selection:$appearance) {
                                Text("Sistema").tag("system")
                                Text("Claro").tag("light")
                                Text("Oscuro").tag("dark")
                            }.pickerStyle(.segmented)
                        }
                        DanperToolLink(title:"Importar / conciliar PERSONAL",
                                       symbol:"person.crop.rectangle.stack") {N2NativePersonalImportView()}
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
                .navigationTitle("Ajustes · Clínica")
            }
            .tabItem {Label("Ajustes",systemImage:"gearshape.fill")}.tag(3)
        }
        .tint(DanperStyle.red)
        .environment(\.locale,Locale(identifier:"es_PE"))
        .preferredColorScheme(appearance=="system" ? nil :
                             appearance=="dark" ? .dark : .light)
        .animation(reduceMotion ? nil : DanperStyle.animation,value:tab)
        .sensoryFeedback(.selection,trigger:tab) {_,_ in haptics}
        .opacity(scenePhase == .active ? 1 : 0)
        .accessibilityHidden(scenePhase != .active)
        .allowsHitTesting(scenePhase == .active)
        .onChange(of:tab) {old,current in
            if old==1 && current != 1 {registeredDNI=nil}
        }
        .onChange(of:scenePhase) {_,phase in
            if phase != .active {onClose()}
        }
    }
    private func homeTile<Destination:View>(
        _ title:String,_ subtitle:String,symbol:String,
        @ViewBuilder destination:()->Destination)->some View {
        NavigationLink {
            destination()
        } label: {
            VStack(alignment:.leading,spacing:9) {
                Image(systemName:symbol)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(DanperStyle.red)
                    .frame(width:43,height:43)
                    .background(DanperStyle.red.opacity(0.09),
                                in:RoundedRectangle(cornerRadius:13))
                Text(title).font(.subheadline.weight(.bold))
                    .foregroundStyle(.primary)
                Text(subtitle).font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal:false,vertical:true)
                Spacer(minLength:0)
            }
            .frame(maxWidth:.infinity,minHeight:119,alignment:.topLeading)
            .padding(13)
            .background(DanperStyle.surface,
                        in:RoundedRectangle(cornerRadius:17))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("clinical-home-tool-"+title.lowercased())
    }

}
