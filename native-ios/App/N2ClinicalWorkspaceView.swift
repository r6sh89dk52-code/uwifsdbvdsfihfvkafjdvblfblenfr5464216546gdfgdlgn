import Foundation
import SwiftUI
import LocalAuthentication
import DanperCore

/// A completely separate navigation tree. Environment value is a constant for
/// this workspace's lifetime. Demo tabs beneath never hold clinical references.
struct N2ClinicalWorkspaceGateView:View {
    var authenticatedLaunch=false
    @Environment(\.scenePhase) private var scenePhase
    @State private var summary:N2ProtectedStoreSummary?
    @State private var busy=false
    @State private var showWorkspace=false
    @State private var automaticallyEntered=false
    @State private var gateContext:LAContext?
    @State private var gateCycle=UUID()
    @State private var message="Verificando la bóveda clínica independiente…"
    @State private var invalidSource=false

    var body:some View {
        ScrollView {
            VStack(alignment:.leading,spacing:16) {
                DanperPanel("Espacio clínico independiente") {
                    Label("Fuente clínica separada",systemImage:"lock.shield.fill")
                        .font(.headline)
                    Text("Puedes importar PERSONAL, restaurar una copia cifrada de Build 222 o comenzar con un primer trabajador manual. No se precargan registros.")
                        .font(.footnote).foregroundStyle(.secondary)
                    #if DEBUG
                    Label("EN VALIDACIÓN: todavía no está aprobada para atención de pacientes reales.",
                          systemImage:"exclamationmark.triangle.fill")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.orange)
                        .fixedSize(horizontal:false,vertical:true)
                    #endif
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
                        Text("Elige una sola fuente inicial: restaurar Build 222, importar PERSONAL o registrar manualmente el primer trabajador. Ninguna opción precarga atenciones ni lotes.")
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
                        NavigationLink {
                            N2FirstManualWorkerView()
                        } label: {
                            Label("Comenzar sin Excel · registrar primer trabajador",
                                  systemImage:"person.badge.plus")
                        }
                        .buttonStyle(DanperSecondaryButton())
                        .accessibilityIdentifier("clinical-first-run-manual-worker")
                        Text("Si no dispones de Excel ni respaldo, podrás comenzar registrando manualmente el primer trabajador. No se crean empleados, atenciones ni lotes de muestra. Si necesitas conservar información de Build 222, restaura su respaldo primero.")
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
        .onChange(of:summary?.revision) {_,_ in enterVerifiedWorkspaceIfReady()}
        // Returning from PERSONAL import must refresh the gate's source count.
        .onAppear {
            if scenePhase == .active {Task {await refresh()}}
        }
        .onChange(of:scenePhase) {_,phase in
            if phase == .active {enterVerifiedWorkspaceIfReady()}
            else if phase == .background {
                gateCycle=UUID()
                gateContext?.invalidate()
                gateContext=nil
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

    @MainActor private func enterVerifiedWorkspaceIfReady() {
        guard authenticatedLaunch,summary != nil,scenePhase == .active,
              !invalidSource,!automaticallyEntered else{return}
        automaticallyEntered=true
        showWorkspace=true
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
            if authenticatedLaunch {
                guard let verified=try await N2ProtectedClinicalIOSVault.shared.inspect(),
                      verified.revision>0,scenePhase == .active else{return}
                summary=verified
                showWorkspace=true
                return
            }
            let context=LAContext()
            gateContext=context
            let cycle=gateCycle
            guard try await context.evaluatePolicy(.deviceOwnerAuthentication,
                    localizedReason:"Entrar al espacio clínico independiente de DANPER") else {
                message="Autenticación no autorizada."
                return
            }
            guard cycle==gateCycle,scenePhase == .active else{return}
            gateContext=nil
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
struct N2ClinicalWorkspaceRootView:View {
    init(onClose:@escaping ()->Void){self.onClose=onClose}
    #if DEBUG
    init(layoutCounts:(today:Int,week:Int,drafts:Int)) {
        onClose={}
        layoutOnly=true
        _homeCounts=State(initialValue:layoutCounts)
    }
    #endif
    private var layoutOnly=false
    let onClose:()->Void
    @Environment(\.n2WorkspaceVault) private var vault
    @State private var homeCounts:(today:Int,week:Int,drafts:Int)?

    @Environment(\.dynamicTypeSize) private var homeTypeSize
    @Environment(\.scenePhase) private var scenePhase
    @State private var tab=0
    @State private var registeredDNI:String?
    @AppStorage("danper.visual.palette") private var visualPalette="danper"
    @AppStorage("danper.appearance") private var appearance="system"
    @AppStorage("danper.haptics.enabled") private var haptics=true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body:some View {
        VStack(spacing:0) {
            DanperBrandHeader {
                withAnimation(reduceMotion ? nil : DanperStyle.animation){tab=3}
            }
            TabView(selection:$tab) {
            NavigationStack {
                ScrollView {
                    VStack(alignment:.leading,spacing:12) {
                        HStack(spacing:12) {
                            Image(systemName:"person.crop.circle.fill")
                                .font(.system(size:44)).foregroundStyle(.secondary)
                                .frame(width:50,height:50)
                                .background(GlassClinical.red.opacity(0.08),in:Circle())
                                .accessibilityHidden(true)
                            VStack(alignment:.leading,spacing:3) {
                                Text("Bienvenido").font(.title2.weight(.bold))
                                Text("Departamento de Salud").font(.subheadline).foregroundStyle(.secondary)
                            }
                        }
                        VStack(alignment:.leading,spacing:8) {
                            HStack(spacing:12) {
                                VStack(alignment:.leading,spacing:3) {
                                    Text("DEPARTAMENTO DE SALUD")
                                        .font(.caption2.weight(.bold)).tracking(0.8)
                                        .foregroundStyle(GlassClinical.red)
                                    Text("Panel de inicio").font(.title2.weight(.bold))
                                    Text("Registro ambulatorio local")
                                        .font(.footnote).foregroundStyle(.secondary)
                                }
                                Spacer(minLength:0)
                                Image(systemName:"waveform.path.ecg")
                                    .font(.title.weight(.medium))
                                    .foregroundStyle(GlassClinical.red)
                                    .frame(width:54,height:58)
                                    .background(GlassClinical.red.opacity(0.10),in:RoundedRectangle(cornerRadius:17))
                                    .accessibilityHidden(true)
                            }
                            HStack(spacing:10) {
                                Image(systemName:"lock.shield").foregroundStyle(GlassClinical.red)
                                Text("Fuente clínica protegida").font(.footnote.weight(.semibold))
                            }
                            .frame(maxWidth:.infinity,alignment:.leading)
                            .padding(8)
                            .background(GlassClinical.red.opacity(0.06),in:RoundedRectangle(cornerRadius:13))
                        }
                        .padding(12).modifier(GlassClinicalSurface())
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
                            withAnimation(reduceMotion ? nil : DanperStyle.animation){tab=1}
                        } label: {
                            HStack(alignment:.center,spacing:8) {
                                VStack(alignment:.leading,spacing:9) {
                                    Text("ACCESO RÁPIDO")
                                        .font(.caption2.weight(.bold))
                                        .tracking(1.4)
                                        .foregroundStyle(.white.opacity(0.92))
                                    Text("Nueva atención")
                                        .font(.system(.title2,design:.rounded,weight:.bold))
                                        .foregroundStyle(.white)
                                    Text("Registra con menos pasos")
                                        .font(.subheadline).foregroundStyle(.white.opacity(0.82))
                                }
                                Spacer(minLength:4)
                                Image(systemName:"plus")
                                    .font(.system(size:32,weight:.light))
                                    .foregroundStyle(.white)
                                    .frame(width:54,height:54)
                                    .background(.white.opacity(0.13),in:Circle())
                                    .accessibilityHidden(true)
                            }
                            .padding(14)
                            .frame(maxWidth:.infinity,minHeight:98,alignment:.leading)
                            .background(GlassClinical.gradient,
                                        in:RoundedRectangle(cornerRadius:22))
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("clinical-home-new-attention")
                        HStack(spacing:10) {
                            homeMetric(homeCounts.map{String($0.today)} ?? "—","Hoy")
                            homeMetric(homeCounts.map{String($0.week)} ?? "—","Esta semana")
                            NavigationLink {
                                N2NativeDraftsDashboard()
                            } label: {
                                homeMetric(homeCounts.map{String($0.drafts)} ?? "—","Borradores")
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("clinical-home-draft-count-link")
                        }

                        Text("Herramientas")
                            .font(.title3.weight(.bold))
                            .frame(maxWidth:.infinity,alignment:.leading)
                        LazyVGrid(columns:homeTypeSize.isAccessibilitySize
                                  ? [GridItem(.flexible())]
                                  : [GridItem(.flexible(),spacing:12),GridItem(.flexible(),spacing:12)],
                                  spacing:12) {
                            homeTile("Trabajadores","Registrar o buscar personal",
                                     symbol:"person.badge.plus") {
                                N2NativeHistoryView(useProtectedVault:true,showWorkers:true)
                            }
                            homeTile("Kardex","Inventario y movimientos",
                                     symbol:"shippingbox.fill") {
                                N2Build222KardexHub()
                            }
                            homeTile("Indicador","Excel · 10 hojas",
                                     symbol:"tablecells") {
                                N2VerifiedIndicatorExportView()
                            }
                            homeTile("Historial","Consultar atenciones",
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
                        #if DEBUG
                        Label("Acceso protegido. Validar restauración, Kardex y Excel en el dispositivo antes de usar registros de pacientes reales.",
                              systemImage:"lock.shield")
                            .font(.caption).foregroundStyle(.secondary)
                        #endif
                        Button("Cerrar espacio clínico",role:.cancel) {onClose()}
                            .buttonStyle(DanperSecondaryButton())
                    }
                    .padding(16)
                }
                .background(GlassClinical.canvas)
                .navigationTitle("Inicio")
                .toolbar(.hidden,for:.navigationBar)
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
                        DanperToolLink(title:"Corte del día 9 · inventario único",
                                       symbol:"calendar.badge.clock") {N2KardexCutPreviewView()}
                        DanperToolLink(title:"Kardex de enfermería",
                                       symbol:"tablecells") {N2VerifiedNursingExportView()}
                        DanperToolLink(title:"Indicador ambulatorio · Excel",
                                       symbol:"doc.richtext") {N2VerifiedIndicatorExportView()}
                        DanperToolLink(title:"Vigilancia ocupacional · Excel",
                                       symbol:"figure.walk.motion") {N2OccupationalVigilanceExportView()}
                        DanperToolLink(title:"Respaldo cifrado",
                                       symbol:"lock.doc") {N2NativeBackupExportView()}
                        Button("Cerrar espacio clínico",role:.cancel) {onClose()}
                            .buttonStyle(DanperSecondaryButton())
                    }.padding(16)
                }
                .navigationTitle("Ajustes · Clínica")
                .toolbar(.hidden,for:.navigationBar)
            }
            .tabItem {Label("Ajustes",systemImage:"gearshape.fill")}.tag(3)
        }
        }
        .tint(DanperStyle.red)
        .environment(\.locale,Locale(identifier:"es_PE"))
        .preferredColorScheme(appearance=="system" ? nil :
                             appearance=="dark" ? .dark : .light)
        .animation(reduceMotion ? nil : DanperStyle.animation,value:tab)
        .sensoryFeedback(.selection,trigger:tab) {_,_ in haptics}
        .task(id:tab) {if tab==0 {await refreshHomeCounts()}}
        .opacity(scenePhase == .active ? 1 : 0)
        .accessibilityHidden(scenePhase != .active)
        .allowsHitTesting(scenePhase == .active)
        .onChange(of:tab) {old,current in
            if old==1 && current != 1 {registeredDNI=nil}
        }
        .onChange(of:scenePhase) {_,phase in
            if phase == .background {onClose()}
        }
    }
    @MainActor private func refreshHomeCounts() async {
        guard !layoutOnly else{return}
        do {
            var calendar=Calendar(identifier:.gregorian)
            calendar.timeZone=TimeZone(identifier:"America/Lima")!
            calendar.firstWeekday=2
            let now=Date()
            let formatter=DateFormatter()
            formatter.locale=Locale(identifier:"en_US_POSIX")
            formatter.timeZone=calendar.timeZone
            formatter.dateFormat="yyyy-MM-dd"
            let today=formatter.string(from:now)
            let weekStart=formatter.string(
                from:calendar.dateInterval(of:.weekOfYear,for:now)?.start ?? now)
            let counters=try await vault.dashboardCounters(
                today:today,weekStart:weekStart)
            homeCounts=counters.map {
                (today:$0.today,week:$0.week,drafts:$0.drafts)
            }
        }catch {
            homeCounts=nil
        }
    }
    private func homeMetric(_ count:String,_ label:String)->some View {
        VStack(alignment:.leading,spacing:4) {
            Image(systemName:label == "Hoy" ? "calendar" : label == "Esta semana" ? "chart.bar.fill" : "doc.text")
                .font(.caption.weight(.semibold))
                .foregroundStyle(label == "Hoy" ? GlassClinical.red : Color.secondary)
                .accessibilityHidden(true)
            Text(count).font(.title3.weight(.bold)).monospacedDigit().foregroundStyle(.primary)
            Text(label).font(.caption2).foregroundStyle(.secondary)
                .fixedSize(horizontal:false,vertical:true)
        }
        .padding(10).frame(maxWidth:.infinity,minHeight:80,alignment:.leading)
        .modifier(GlassClinicalSurface(radius:17))
        .accessibilityElement(children:.combine)
    }
    private func homeTile<Destination:View>(
        _ title:String,_ subtitle:String,symbol:String,
        @ViewBuilder destination:()->Destination)->some View {
        NavigationLink {
            destination()
        } label: {
            HStack(alignment:.top,spacing:9) {
                Image(systemName:symbol)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(GlassClinical.red)
                    .frame(width:34,height:40)
                    .background(GlassClinical.red.opacity(0.09),in:RoundedRectangle(cornerRadius:11))
                    .accessibilityHidden(true)
                VStack(alignment:.leading,spacing:5) {
                    Text(title).font(.subheadline.weight(.bold)).foregroundStyle(.primary)
                    Text(subtitle).font(.caption).foregroundStyle(.secondary)
                }
                .fixedSize(horizontal:false,vertical:true)
                .frame(maxWidth:.infinity,alignment:.leading)
            }
            .frame(maxWidth:.infinity,minHeight:65,alignment:.leading)
            .padding(12)
            .modifier(GlassClinicalSurface(radius:17))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("clinical-home-tool-"+title.lowercased())
    }

}
