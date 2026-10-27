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
    @Environment(\.n2WorkspaceVault) private var vault
    @Environment(\.scenePhase) private var scenePhase
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
            .safeAreaInset(edge:.bottom,spacing:0) {DanperFloatingTabs(selection:$tab)}
        }
        .background(DanperStyle.canvas)
        .tint(DanperStyle.red)
        .environment(\.locale,Locale(identifier:"es_PE"))
        .preferredColorScheme(appearance=="system" ? nil : appearance=="dark" ? .dark : .light)
        .task(id:tab) {if tab==0 {await refreshHomeCounts()}}
        .sheet(isPresented:$showNewAttention,onDismiss:{
            registeredDNI=nil
            Task {await refreshHomeCounts()}
        }) {
            NavigationStack {
                N2NativeClinicalFormView(initialWorkerDNI:registeredDNI)
                    .toolbar {
                        ToolbarItem(placement:.cancellationAction) {
                            Button("Cerrar") {showNewAttention=false}
                                .accessibilityIdentifier("premium-close-attention")
                        }
                    }
            }
            .presentationDragIndicator(.visible)
        }
        .opacity(scenePhase == .active ? 1 : 0)
        .accessibilityHidden(scenePhase != .active)
        .allowsHitTesting(scenePhase == .active)
        .onChange(of:scenePhase) {_,phase in
            if phase == .background {onClose()}
        }
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
                HStack {
                    Text("Herramientas").font(.title2.weight(.bold))
                    Spacer()
                    Button("Ver todas",systemImage:"chevron.right") {tab=3}
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
        .background(DanperStyle.canvas)
        .refreshable {await refreshHomeCounts()}
    }
    @MainActor private func refreshHomeCounts() async {
        guard !layoutOnly else{return}
        do {
            let period=N2HomeCalendarPeriod(now:Date())
            let counters=try await vault.dashboardCounters(today:period.today,weekStart:period.weekStart)
            homeCounts=counters.map{DanperHomeCounts(today:$0.today,week:$0.week,month:$0.month)}
            countError=false
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
    private var settings:some View {
        ScrollView {
            VStack(alignment:.leading,spacing:15) {
                DanperVersionPanel()
                DanperPanel("Apariencia") {
                    Picker("Colores",selection:$visualPalette) {
                        Text("DANPER rojo").tag("danper");Text("Salud azul").tag("salud")
                    }.pickerStyle(.segmented)
                    Picker("Modo",selection:$appearance) {
                        Text("Sistema").tag("system");Text("Claro").tag("light");Text("Oscuro").tag("dark")
                    }.pickerStyle(.segmented)
                }
                DanperPanel("Personal y atenciones") {
                    DanperToolLink(title:"Trabajadores",symbol:"person.2") {N2NativeHistoryView(useProtectedVault:true,showWorkers:true)}
                    DanperToolLink(title:"Borradores",symbol:"doc.badge.clock") {N2NativeDraftsDashboard()}
                    DanperToolLink(title:"Revisión de alergias",symbol:"cross.vial") {N2NativeClinicalFormView()}
                    DanperToolLink(title:"Importar / conciliar PERSONAL",symbol:"person.crop.rectangle.stack") {N2NativePersonalImportView()}
                }
                DanperPanel("Inventario y reportes") {
                    DanperToolLink(title:"Inventario y lotes",symbol:"shippingbox") {N2NativeInventoryView()}
                    DanperToolLink(title:"Corte del día 9 · inventario único",symbol:"calendar.badge.clock") {N2KardexCutPreviewView()}
                    DanperToolLink(title:"Kardex de enfermería",symbol:"tablecells") {N2VerifiedNursingExportView()}
                    DanperToolLink(title:"Indicador ambulatorio · Excel",symbol:"doc.richtext") {N2VerifiedIndicatorExportView()}
                    DanperToolLink(title:"Vigilancia ocupacional · Excel",symbol:"figure.walk.motion") {N2OccupationalVigilanceExportView()}
                    DanperToolLink(title:"Estadísticas",symbol:"chart.bar.fill") {DanperStatisticsView()}
                }
                DanperPanel("Seguridad") {
                    DanperToolLink(title:"Respaldo cifrado",symbol:"lock.doc") {N2NativeBackupExportView()}
                    Button("Cerrar espacio clínico",role:.cancel) {onClose()}.buttonStyle(DanperSecondaryButton())
                }
            }.padding(16)
        }.navigationTitle("Ajustes").navigationBarTitleDisplayMode(.inline)
            .background(DanperStyle.canvas)
    }
}
