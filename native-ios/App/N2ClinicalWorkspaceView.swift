import Foundation
import SwiftUI
import LocalAuthentication
import DanperCore

/// A completely separate navigation tree. Environment value is a constant for
/// this workspace's lifetime. Demo tabs beneath never hold clinical references.
struct N2ClinicalWorkspaceGateView:View {
    var authenticatedLaunch=false
    var sessionUnlocked=true
    var onLock:()->Void={}
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.danperAuthenticatedSession) private var inheritedAuthentication
    @State private var summary:N2ProtectedStoreSummary?
    @State private var checked=false
    @State private var sourceInspectionRevision=0
    @State private var inspectedSourceRevision=0
    @State private var busy=false
    @State private var invalidSource=false
    @State private var authorized=false
    @State private var gateContext:LAContext?
    @State private var gateCycle=UUID()
    @State private var message=""

    var body:some View {
        Group {
            if !checked {
                DanperLoadingState(title:"Preparando DANPER…")
                    .frame(maxWidth:.infinity,maxHeight:.infinity)
                    .accessibilityIdentifier("clinical-source-loading")
            } else if invalidSource {
                DanperErrorState(message:message,retry:{Task {await refresh()}})
                    .padding(24).accessibilityIdentifier("clinical-source-error")
            } else if summary != nil {
                if authenticatedLaunch || authorized || inheritedAuthentication {
                    N2ClinicalWorkspaceRootView(onClose:onLock)
                        .environment(\.n2WorkspaceVault,.clinical)
                        .environment(\.danperAuthenticatedSession,sessionUnlocked)
                } else {
                    DanperAccessView(unlocking:busy,canRetry:!busy,error:message,
                        onUnlock:{Task {await authorize()}})
                        .task {await authorize()}
                }
            } else {
                NavigationStack {
                    initialSetup.onAppear {Task {await refresh()}}
                }
            }
        }
        .background(DanperBackdrop())
        .task(id:"\(sourceInspectionAllowed)-\(sourceInspectionRevision)") {
            if sourceInspectionAllowed {
                if sourceInspectionRevision != inspectedSourceRevision || !checked || invalidSource {
                    await refresh()
                    inspectedSourceRevision=sourceInspectionRevision
                } else if summary != nil {await verifyRevision()}
            }
        }
        .onChange(of:scenePhase) {_,phase in
            if phase == .background {
                gateCycle=UUID();gateContext?.invalidate();gateContext=nil
                if !authenticatedLaunch {authorized=false}
            }
        }
    }
    private var sourceInspectionAllowed:Bool {
        scenePhase == .active && (!authenticatedLaunch || sessionUnlocked)
    }
    private var initialSetup:some View {
        ScrollView {
            VStack(alignment:.leading,spacing:16) {
                Text("Configura DANPER").font(.title2.bold())
                    .accessibilityIdentifier("clinical-empty-setup")
                DanperPanel("Verificar la fuente") {

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
                            N2SimpleRestoreView(kind:.complete).environment(\.n2WorkspaceVault,.clinical)
                        } label: {
                            Label("Restaurar copia cifrada Build 222",
                                  systemImage:"lock.doc")
                        }
                        .buttonStyle(DanperSecondaryButton())
                        .accessibilityIdentifier("clinical-first-run-restore-222")
                        NavigationLink {
                            N2FirstManualWorkerView(onContinue:{
                                // A navigation destination retains its creation
                                // closure. Signal State here; the gate's task must
                                // read the current scene/session, not that capture.
                                sourceInspectionRevision+=1
                            })
                        } label: {
                            Label("Comenzar sin Excel · registrar primer trabajador",
                                  systemImage:"person.badge.plus")
                        }
                        .buttonStyle(DanperSecondaryButton())
                        .accessibilityIdentifier("clinical-first-run-manual-worker")
                        Text("Si no dispones de Excel ni respaldo, podrás comenzar registrando manualmente el primer trabajador. No se crean empleados, atenciones ni lotes de muestra. Si necesitas conservar información de Build 222, restaura su respaldo primero.")
                            .font(.footnote).foregroundStyle(.secondary)
                }
            }.padding(16)
        }
        .navigationTitle("Comenzar")
        .danperFormChrome()
    }
    @MainActor private func refresh() async {
        guard !busy,sourceInspectionAllowed else{return}
        let span=N2PerformanceSpan("Clinical gate refresh");defer{span.end()}
        busy=true
        defer {busy=false;checked=true}
        do {
            summary=try await N2ProtectedClinicalIOSVault.shared.inspect()
            let evidence=await N2ProtectedClinicalIOSVault.shared.hasStoredClinicalSource()
            invalidSource=summary == nil && evidence
            message=invalidSource ? "No se pudo verificar la fuente protegida. Tus registros se conservan." : ""
        } catch {
            invalidSource=true
            message="No se pudo verificar la fuente protegida. Tus registros se conservan. Vuelve a intentarlo."
        }
    }
    @MainActor private func verifyRevision() async {
        let span=N2PerformanceSpan("Clinical revision verification");defer{span.end()}
        do {
            _=try await N2ProtectedClinicalIOSVault.shared.currentRevision()
        }catch {
            invalidSource=true;message="No se pudo verificar la fuente protegida. Tus registros se conservan."
        }
    }
    @MainActor private func authorize() async {
        guard !busy,scenePhase == .active else{return}
        busy=true;defer{busy=false}
        let context=LAContext();gateContext=context
        let cycle=gateCycle
        do {
            let accepted=try await context.evaluatePolicy(.deviceOwnerAuthentication,
                localizedReason:"Acceder a DANPER Salud Móvil")
            guard accepted,cycle==gateCycle,scenePhase == .active else{return}
            _=try await N2ProtectedClinicalIOSVault.shared.currentRevision()
            authorized=true;message="";gateContext=nil
        }catch {message="No se pudo verificar tu identidad. Intenta nuevamente."}
    }
}

/// Clinical and DEMO shells share presentation; their vault environments stay fixed.
struct N2ClinicalWorkspaceRootView:View {
    init(onClose:@escaping ()->Void){self.onClose=onClose}
    #if DEBUG
    init(layoutCounts:(today:Int,week:Int,month:Int),layoutTab:Int=0) {
        onClose={};layoutOnly=true
        _homeCounts=State(initialValue:DanperHomeCounts(today:layoutCounts.today,week:layoutCounts.week,month:layoutCounts.month))
        _tab=State(initialValue:layoutTab)
    }
    #endif
    private var layoutOnly=false
    let onClose:()->Void
    @Environment(\.danperAuthenticatedSession) private var sessionAuthenticated
    @Environment(\.n2WorkspaceVault) private var vault
    @Environment(\.scenePhase) private var scenePhase
    @State private var loadingHomeCounts=false
    @State private var homeRefreshPending=false
    @State private var clinicalAlerts=[N2ClinicalAlert]()
    @State private var notificationError=false
    @State private var alertClock=Date()
    @State private var homeRevision:Int?
    @State private var homeDay=""
    @State private var homeCounts:DanperHomeCounts?
    @State private var countError=false
    @State private var tab=0
    @State private var registeredDNI:String?
    @State private var showNewAttention=false
    @AppStorage("danper.visual.palette") private var visualPalette="danper"
    @AppStorage("danper.appearance") private var appearance="system"
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    var body:some View {
        VStack(spacing:0) {
            DanperBrandHeader {tab=3}
            TabView(selection:$tab) {
                NavigationStack {home.toolbar(.hidden,for:.tabBar)}
                    .toolbar(.hidden,for:.tabBar)
                    .tabItem {Label("Inicio",systemImage:"house.fill")}.tag(0)
                NavigationStack {
                    N2NativeHistoryView(useProtectedVault:true)
                        .toolbar(.hidden,for:.tabBar)
                        .toolbar {
                            ToolbarItem(placement:.topBarTrailing) {
                                NavigationLink {
                                    N2NativeWorkerEditorView(onSaved:{dni in
                                        registeredDNI=dni;showNewAttention=true
                                    })
                                } label: {Label("Nuevo trabajador",systemImage:"person.badge.plus")}
                            }
                        }
                }.toolbar(.hidden,for:.tabBar)
                    .tabItem {Label("Historial",systemImage:"list.clipboard.fill")}.tag(1)
                NavigationStack {N2NativeDraftsDashboard().toolbar(.hidden,for:.tabBar)}
                    .toolbar(.hidden,for:.tabBar)
                    .tabItem {Label("Borradores",systemImage:"doc.text.fill")}.tag(2)
                NavigationStack {settings.toolbar(.hidden,for:.tabBar)}
                    .toolbar(.hidden,for:.tabBar)
                    .tabItem {Label("Ajustes",systemImage:"gearshape.fill")}.tag(3)
            }
            .toolbar(.hidden,for:.tabBar)
        }
        .danperFloatingNavigation(selection:$tab)
        .environment(\.n2WorkspaceTab,tab)
        .environment(\.colorScheme,.dark)
        .background(DanperBackdrop())
        .tint(DanperStyle.red)
        .environment(\.locale,Locale(identifier:"es_PE"))
        .preferredColorScheme(.dark)
        .task(id:tab) {if tab==0 {await refreshHomeCounts()}}
        .onReceive(Timer.publish(every:30,on:.main,in:.common).autoconnect()) { now in
            if sessionAuthenticated,scenePhase == .active,tab==0 {alertClock=now}
        }
        .onReceive(NotificationCenter.default.publisher(for:N2WorkspaceChanges.notification).receive(on:RunLoop.main)) { event in
            guard N2WorkspaceChanges.matches(event,vault),sessionAuthenticated,scenePhase == .active,
                  let kind=event.userInfo?["kind"] as? String,
                  (tab==0 && !showNewAttention) || ["inventory","restore"].contains(kind) else{return}
            Task {await refreshHomeCounts()}
        }
        .onChange(of:sessionAuthenticated) {_,active in
            if active {Task {await refreshHomeCounts()}}
        }
        .sheet(isPresented:$showNewAttention,onDismiss:{
            registeredDNI=nil
            Task {await refreshHomeCounts()}
        }) {
            DanperAttentionEditor(initialWorkerDNI:registeredDNI)

        }
        .opacity(scenePhase == .active ? 1 : 0)
        .accessibilityHidden(scenePhase != .active)
        .allowsHitTesting(scenePhase == .active)
        .onChange(of:scenePhase) {_,phase in
            if phase == .background {showNewAttention=false}
            else if phase == .active {Task {await refreshHomeCounts()}}
        }
    }
    private var actionableAlerts:[N2ClinicalAlert] {
        let now=Int64(alertClock.timeIntervalSince1970*1000)
        let expired=Set(clinicalAlerts.filter{$0.kind == .expiryDay && $0.dueAt<=now}.map(\.sourceID))
        return clinicalAlerts.filter {$0.dueAt<=now && !($0.kind == .expiryWarning && expired.contains($0.sourceID))}
    }
    private var home:some View {
        ScrollView {
            VStack(alignment:.leading,spacing:12) {
                DanperHomeWelcome()
                DanperNewAttentionCard {showNewAttention=true}
                DanperHomeMetricRow(counts:homeCounts)
                if countError {
                    DanperErrorState(message:"No se pudieron actualizar las cifras.",retry:{Task {await refreshHomeCounts()}})
                } else if homeCounts==nil {
                    DanperLoadingState(title:"Actualizando cifras…")
                }
                if !clinicalAlerts.isEmpty {
                    DanperPanel("Alertas y avisos · \(actionableAlerts.count)") {
                        ForEach(actionableAlerts.prefix(8)) { alert in
                            Label(alert.detail,systemImage:alert.kind == .draft ? "doc.badge.clock":"exclamationmark.triangle")
                                .font(.footnote)
                        }
                        NavigationLink("Ver todas las alertas") {
                            List(clinicalAlerts) { alert in
                                VStack(alignment:.leading,spacing:4) {
                                    Text(alert.detail)
                                    Text(alert.dueAt<=Int64(alertClock.timeIntervalSince1970*1000) ? "Pendiente de revisar":"Aviso programable")
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                            }.navigationTitle("Alertas")
                        }
                        if notificationError {
                            Text("No se pudieron programar algunos avisos locales. Las alertas siguen disponibles aquí.")
                                .font(.caption).foregroundStyle(.orange)
                        }
                    }
                }
                HStack {
                    Text("Herramientas").font(.title2.weight(.bold))
                    Spacer()
                    NavigationLink {toolsPage(title:"Herramientas",showPreferences:false)} label: {Label("Ver todas",systemImage:"chevron.right")}
                        .accessibilityIdentifier("glass-home-all-tools")
                        .font(.caption.weight(.semibold))
                }.padding(.top,3)
                LazyVGrid(columns:dynamicTypeSize.isAccessibilitySize ? [GridItem(.flexible())] : [GridItem(.flexible(),spacing:10),GridItem(.flexible(),spacing:10)],spacing:10) {
                    homeTile("Trabajadores","Registrar o buscar personal",symbol:"person.badge.plus") {
                        N2NativeHistoryView(useProtectedVault:true,showWorkers:true)
                    }
                    homeTile("Kardex","Inventario y movimientos",symbol:"shippingbox.fill") {N2Build222KardexHub()}
                    homeTile("Estadísticas","Reportes e indicadores",symbol:"chart.bar.fill") {DanperStatisticsView()}
                    homeTile("Indicadores","Exportaciones de salud",symbol:"list.clipboard.fill") {DanperExportsView()}
                }
            }.padding(14)
        }
        .navigationTitle("Inicio").toolbar(.hidden,for:.navigationBar)
        .background(DanperBackdrop())
        .refreshable {await refreshHomeCounts()}
    }
    @MainActor private func refreshHomeCounts() async {
        guard !layoutOnly,sessionAuthenticated else{return}
        if loadingHomeCounts {homeRefreshPending=true;return}
        loadingHomeCounts=true
        defer {
            loadingHomeCounts=false
            if homeRefreshPending {
                homeRefreshPending=false
                Task {await refreshHomeCounts()}
            }
        }
        do {
            let period=N2HomeCalendarPeriod(now:Date())
            let counters=try await vault.dashboardSnapshot(today:period.today,weekStart:period.weekStart)
            guard sessionAuthenticated,scenePhase == .active else{return}
            homeRevision=counters?.revision;homeDay=period.today
            homeCounts=counters.map{DanperHomeCounts(today:$0.today,week:$0.week,month:$0.month)}
            alertClock=Date()
            clinicalAlerts=counters?.alerts ?? []
            countError=false
            do {try await N2InventoryAlertNotifications.shared.reconcile(clinicalAlerts,mode:vault.mode);notificationError=false}
            catch {notificationError=true}
        }catch {
            homeCounts=nil;countError=true
        }
    }
    private func homeTile<Destination:View>(_ title:String,_ subtitle:String,symbol:String,
        @ViewBuilder destination:()->Destination)->some View {
        NavigationLink(destination:destination) {
            DanperToolCard(title:title,subtitle:subtitle,symbol:symbol)
        }.buttonStyle(.plain)
            .accessibilityLabel(title+": "+subtitle)
            .accessibilityIdentifier("clinical-home-tool-"+title.lowercased())
    }
    private var settings:some View {toolsPage(title:"Ajustes",showPreferences:true)}
    private func toolsPage(title:String,showPreferences:Bool)->some View {
        ScrollView {
            VStack(alignment:.leading,spacing:15) {
            if !showPreferences {
                DanperPanel("Accesos rápidos") {
                    DanperToolLink(title:"Trabajadores",symbol:"person.badge.plus") {N2NativeHistoryView(useProtectedVault:true,showWorkers:true)}
                    DanperToolLink(title:"Kardex",symbol:"shippingbox.fill") {N2Build222KardexHub()}
                    DanperToolLink(title:"Estadísticas",symbol:"chart.bar.fill") {DanperStatisticsView()}
                    DanperToolLink(title:"Indicadores",symbol:"list.clipboard.fill") {DanperExportsView()}
                }
            }
                if showPreferences {
                DanperVersionPanel()
                DanperPanel("Apariencia") {
                    DanperDisplayNamePreference()
                    Picker("Colores",selection:$visualPalette) {
                        Text("DANPER rojo").tag("danper");Text("Salud azul").tag("salud")
                    }.pickerStyle(.segmented)
                    Picker("Hoja de compartir",selection:$appearance) {
                        Text("Sistema").tag("system");Text("Claro").tag("light");Text("Oscuro").tag("dark")
                    }.pickerStyle(.segmented)
                }
                }
                DanperPanel("Personal y atenciones") {
                    DanperToolLink(title:"Trabajadores",symbol:"person.2") {N2NativeHistoryView(useProtectedVault:true,showWorkers:true)}
                    DanperToolLink(title:"Borradores",symbol:"doc.badge.clock") {N2NativeDraftsDashboard()}
                    DanperAttentionLauncher(title:"Revisión de alergias",symbol:"cross.vial")
                    DanperToolLink(title:"Importar / conciliar PERSONAL",symbol:"person.crop.rectangle.stack") {N2NativePersonalImportView()}
                }
                DanperPanel("Inventario y reportes") {
                    DanperToolLink(title:"Inventario y existencias",symbol:"shippingbox") {N2SimpleInventoryView()}
                    DanperToolLink(title:"Corte del día 9 · inventario único",symbol:"calendar.badge.clock") {N2SimpleCutView()}
                    DanperToolLink(title:"Kardex de enfermería",symbol:"tablecells") {N2VerifiedNursingExportView()}
                    DanperToolLink(title:"Indicador ambulatorio · Excel",symbol:"doc.richtext") {N2VerifiedIndicatorExportView()}
                    DanperToolLink(title:"Vigilancia ocupacional · Excel",symbol:"figure.walk.motion") {N2OccupationalVigilanceExportView()}
                    DanperToolLink(title:"Estadísticas",symbol:"chart.bar.fill") {DanperStatisticsView()}
                }
                DanperPanel("Seguridad") {
                    DanperToolLink(title:"Respaldo cifrado",symbol:"lock.doc") {N2NativeBackupExportView()}
                    DanperToolLink(title:"Restaurar historial sin reemplazar inventario",symbol:"clock.arrow.circlepath") {N2SimpleRestoreView(kind:.clinical)}
                    if showPreferences {Button("Bloquear aplicación",role:.cancel) {onClose()}.buttonStyle(DanperSecondaryButton())}
                }
            }.padding(16)
        }.navigationTitle(title).navigationBarTitleDisplayMode(.inline)
            .danperFormChrome()
    }
}
