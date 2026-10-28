import SwiftUI
import DanperCore

private let danperAccent=Color(red:0.88,green:0.09,blue:0.16)

/// Build 222 navigation in native SwiftUI; sensitive data remain in the isolated demo vault.
/// No clinical import occurs during launch. Real build222 data are never read.
struct NativeRootView:View {
    init() {}
    #if DEBUG
    init(layoutMetrics:N2DashboardMetrics) {
        layoutOnly=true
        _metrics=State(initialValue:layoutMetrics)
        _loading=State(initialValue:false)
    }
    #endif
    private var layoutOnly=false
    @State private var tab=0
    @State private var newlyRegisteredWorkerDNI:String?
    @State private var showNewAttention=false
    @State private var homeCounts:DanperHomeCounts?
    @State private var summary:N2ProtectedStoreSummary?
    @State private var loading=true
    @State private var preparing=false
    @State private var problem=""
    @State private var showAdvanced=false
    @State private var metrics:N2DashboardMetrics?
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @AppStorage("danper.appearance") private var appearance="system"
    @AppStorage("danper.visual.palette") private var visualPalette="danper"
    @AppStorage("danper.haptics.enabled") private var haptics=true

    private var isReady:Bool { summary != nil || layoutOnly }
    var body:some View {
        VStack(spacing:0) {
            DanperBrandHeader {tab=3}
            TabView(selection:$tab) {
                NavigationStack {home.toolbar(.hidden,for:.tabBar)}
                    .toolbar(.hidden,for:.tabBar)
                    .tabItem { Label("Inicio",systemImage:"house.fill") }.tag(0)
                NavigationStack {
                    if isReady {
                        N2NativeHistoryView(useProtectedVault:true)
                        .toolbar(.hidden,for:.tabBar)
                            .toolbar {
                                ToolbarItem(placement:.topBarTrailing) {
                                    NavigationLink {
                                        N2NativeWorkerEditorView(onSaved:{dni in
                                            newlyRegisteredWorkerDNI=dni;showNewAttention=true
                                        })
                                    } label: {Label("Nuevo trabajador",systemImage:"person.badge.plus")}
                                }
                            }
                    } else {lockedTab(title:"Historial",symbol:"clipboard")}
                }.toolbar(.hidden,for:.tabBar)
                    .tabItem {Label("Historial",systemImage:"list.clipboard.fill")}.tag(1)
                NavigationStack {
                    if isReady {N2NativeDraftsDashboard()}
                    else {lockedTab(title:"Borradores",symbol:"doc.badge.clock")}
                }.toolbar(.hidden,for:.tabBar)
                    .tabItem {Label("Borradores",systemImage:"doc.text.fill")}.tag(2)
                NavigationStack {toolsTab.toolbar(.hidden,for:.tabBar)}
                    .toolbar(.hidden,for:.tabBar)
                    .tabItem {Label("Ajustes",systemImage:"gearshape.fill")}.tag(3)
            }
            .toolbar(.hidden,for:.tabBar)
        }
        .danperFloatingNavigation(selection:$tab)
        .environment(\.colorScheme,.dark)
        .background(DanperBackdrop())
        .tint(DanperStyle.red)
        .environment(\.n2WorkspaceVault,.demo)
        .environment(\.locale,Locale(identifier:"es_PE"))
        .task(id:tab) {if tab==0 {await refresh()}}
        .sheet(isPresented:$showNewAttention,onDismiss:{
            newlyRegisteredWorkerDNI=nil
            Task {await refresh()}
        }) {
            DanperAttentionEditor(initialWorkerDNI:newlyRegisteredWorkerDNI)

        }
        .onChange(of:scenePhase) {_,phase in
            if phase == .active {Task {await refresh()}}
        }
    }

    private var home:some View {
        ScrollView {
            VStack(alignment:.leading,spacing:12) {
                DanperHomeWelcome(isDemo:true)
                if isReady {
                    DanperNewAttentionCard(action:{showNewAttention=true},identifier:"demo-home-new-attention")
                    DanperHomeMetricRow(counts:homeCounts ?? metrics.map{DanperHomeCounts(today:$0.today,week:$0.week,month:$0.month)})
                }
                if !isReady {
                    DanperPanel("¿Cómo deseas comenzar?") {
                        Text("Elige el origen de los datos. No se importará ni restaurará nada automáticamente.")
                            .font(.subheadline).foregroundStyle(.secondary)
                        if loading || preparing {
                            ProgressView("Preparando almacenamiento cifrado…")
                        }
                        if !problem.isEmpty {
                            Label(problem,systemImage:"exclamationmark.triangle")
                                .font(.footnote).foregroundStyle(.orange)
                                .fixedSize(horizontal:false,vertical:true)
                        }
                        Button {
                            Task {await startPractice(withSample:false)}
                        } label: {
                            Label("Empezar con una base vacía",
                                  systemImage:"tray")
                        }
                        .buttonStyle(DanperPrimaryButton())
                        .disabled(loading || preparing || !problem.isEmpty)
                        .accessibilityIdentifier("start-empty-demo")
                        Text("0 trabajadores, 0 atenciones, 0 consumos y 0 lotes. Podrás registrar datos de prueba desde cero.")
                            .font(.caption).foregroundStyle(.secondary)

                        Button {
                            Task {await startPractice(withSample:true)}
                        } label: {
                            Label("Cargar ejemplo ficticio",
                                  systemImage:"person.3.sequence")
                        }
                        .buttonStyle(DanperSecondaryButton())
                        .disabled(loading || preparing || !problem.isEmpty)
                        .accessibilityIdentifier("start-sample-demo")
                        Text("Este ejemplo siempre incluye los mismos cinco trabajadores y atenciones sintéticas. Nunca es una base nueva vacía.")
                            .font(.caption).foregroundStyle(.secondary)

                        Divider()
                        NavigationLink {
                            N2NativePersonalImportView()
                        } label: {
                            Label("Importar trabajadores desde Excel",
                                  systemImage:"doc.badge.plus")
                                .font(.subheadline.weight(.semibold))
                                .frame(maxWidth:.infinity,minHeight:48)
                        }
                        .buttonStyle(DanperSecondaryButton())
                        .accessibilityIdentifier("start-import-personal-xlsx")
                        Text("Lee la hoja PERSONAL del .xlsx y permite verificar DNIs, nombres, sexo, área y sede. Se guarda en una bóveda clínica independiente, nunca mezclada con la demostración. Requiere autenticación.")
                            .font(.caption).foregroundStyle(.secondary)
                        NavigationLink {
                            N2SimpleRestoreView(kind:.complete).environment(\.n2WorkspaceVault,.clinical)
                        } label: {
                            Label("Restaurar respaldo cifrado Build 222",
                                  systemImage:"lock.doc")
                                .font(.subheadline.weight(.semibold))
                                .frame(maxWidth:.infinity,minHeight:48)
                        }
                        .buttonStyle(DanperSecondaryButton())
                        .accessibilityIdentifier("start-restore-build222")
                    }
                }

                HStack {
                    Text("Herramientas").font(.title2.weight(.bold))
                    Spacer()
                    NavigationLink {toolsPage(title:"Herramientas",showPreferences:false)} label: {Label("Ver todas",systemImage:"chevron.right")}
                        .accessibilityIdentifier("glass-home-all-tools")
                        .font(.caption.weight(.semibold))
                }
                LazyVGrid(columns:dynamicTypeSize.isAccessibilitySize ? [GridItem(.flexible())] : [GridItem(.flexible(),spacing:10),GridItem(.flexible(),spacing:10)],spacing:10) {
                    shortcut("Trabajadores","Registrar o buscar personal","person.badge.plus") {
                        N2NativeHistoryView(useProtectedVault:true,showWorkers:true)
                    }
                    shortcut("Kardex","Inventario y movimientos","shippingbox.fill") {N2Build222KardexHub()}
                    shortcut("Estadísticas","Reportes e indicadores","chart.bar.fill") {DanperStatisticsView()}
                    shortcut("Indicadores","Exportaciones de salud","list.clipboard.fill") {DanperExportsView()}
                }
            }.padding(14)
        }.background(DanperBackdrop())
            .navigationTitle("Inicio").toolbar(.hidden,for:.navigationBar)
    }
    private func shortcut<Destination:View>(_ title:String,_ description:String,_ symbol:String,
        @ViewBuilder destination:()->Destination)->some View {
        NavigationLink(destination:destination) {
            DanperToolCard(title:title,subtitle:description,symbol:symbol)
        }.buttonStyle(.plain).disabled(!isReady)
            .accessibilityLabel(title+": "+description)
    }
    private func lockedTab(title:String,symbol:String)->some View {
        ContentUnavailableView {
            Label("Antes de empezar",systemImage:symbol)
        }description:{
            Text("Activa la demostración ficticia desde Inicio. Es gratuita, local y no necesita respaldo real.")
        }actions:{
            Button("Ir a Inicio") {tab=0}
                .buttonStyle(.borderedProminent)
                .tint(danperAccent)
        }
        .navigationTitle(title)
    }
    private var toolsTab:some View {toolsPage(title:"Ajustes",showPreferences:true)}
    private func toolsPage(title:String,showPreferences:Bool)->some View {
        ScrollView {
          VStack(alignment:.leading,spacing:16) {
            if showPreferences {DanperVersionPanel()}
            DanperPanel {
                Label(isReady ? "DEMO · Solo datos ficticios" :
                    "Inicia la práctica desde Inicio",systemImage:"info.circle")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            if isReady {
                DanperPanel("Personal y atenciones") {
                    DanperToolLink(title:"Trabajadores",symbol:"person.2") {N2NativeHistoryView(useProtectedVault:true,showWorkers:true)}
                    DanperAttentionLauncher(title:"Alergias",symbol:"cross.vial")
                    DanperToolLink(title:"Estadísticas",symbol:"chart.bar.fill") {DanperStatisticsView()}
                }
                DanperPanel("Inventario y reportes") {
                    DanperToolLink(title:"Inventario y existencias",symbol:"shippingbox") {N2SimpleInventoryView()}
                    DanperToolLink(title:"Corte del día 9 · inventario único",symbol:"calendar.badge.clock") {N2SimpleCutView()}
                    DanperToolLink(title:"Kardex de enfermería",symbol:"tablecells") {N2VerifiedNursingExportView()}
                    DanperToolLink(title:"Indicador ambulatorio · Excel",symbol:"doc.richtext") {N2VerifiedIndicatorExportView()}
                    DanperToolLink(title:"Vigilancia ocupacional · Excel",symbol:"figure.walk.motion") {N2OccupationalVigilanceExportView()}
                    DanperToolLink(title:"Respaldo cifrado",symbol:"lock.doc") {N2NativeBackupExportView()}
                    DanperToolLink(title:"Restaurar historial sin reemplazar inventario",symbol:"clock.arrow.circlepath") {N2SimpleRestoreView(kind:.clinical)}
                }
            }
            DanperPanel("Datos reales · no se mezclan con las pruebas") {
                 DanperToolLink(title:"Importar trabajadores desde Excel PERSONAL",
                                symbol:"doc.badge.plus") {
                     N2NativePersonalImportView()
                 }
                 Text("Revisa los datos antes de confirmar la importación. No se mezclarán con esta DEMO.")
                     .font(.caption).foregroundStyle(.secondary)
                DanperToolLink(title:"Acceso al espacio clínico independiente",symbol:"cross.case.fill") {
                    N2ClinicalWorkspaceGateView()
                }
                Text("Requiere autenticación. Los datos clínicos permanecen separados de la DEMO.")
                    .font(.caption).foregroundStyle(.orange)
                DanperToolLink(title:"Comprobar respaldo original (solo lectura)",symbol:"doc.text.magnifyingglass") {BackupPreviewView()}
                DisclosureGroup("Configuración avanzada",isExpanded:$showAdvanced) {
                    DanperToolLink(title:"Importación protegida en bóveda independiente",symbol:"lock.shield") {N2SimpleRestoreView(kind:.complete).environment(\.n2WorkspaceVault,.clinical)}
                    Text("Esta función es independiente de la demostración. No la necesitas para probar atenciones.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
            DanperPanel("Restablecer entorno de prueba") {
                NavigationLink {
                    N2DemoResetView(onDeleted:{
                        // The demo workspace is never silently re-initialized.
                        summary=nil
                        metrics=nil
                        newlyRegisteredWorkerDNI=nil
                        tab=0
                        Task {await refresh()}
                    })
                } label: {
                    Label("Borrar TODOS los datos ficticios",
                          systemImage:"trash")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.red)
                }
                Text("Elimina solo los datos DEMO. Tus datos clínicos se conservan. Requiere confirmación escrita y autenticación.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            if showPreferences {
            DanperPanel("Identidad visual") {
                Picker("Colores del aplicativo",selection:$visualPalette) {
                    Text("DANPER rojo").tag("danper")
                    Text("Salud azul").tag("salud")
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("danper-visual-palette")
                Label(visualPalette=="salud"
                      ? "Azul institucional, celeste y fondos suaves."
                      : "Rojo DANPER y superficies clásicas.",
                      systemImage:"paintpalette")
                    .font(.caption).foregroundStyle(.secondary)
            }
            DanperPanel("Preferencias") {
                DanperDisplayNamePreference()
                Picker("Hoja de compartir",selection:$appearance) {
                    Text("Sistema").tag("system")
                    Text("Claro").tag("light")
                    Text("Oscuro").tag("dark")
                }.pickerStyle(.segmented)
                DanperCheckRow(selected:$haptics) {Text("Respuesta háptica")}
                LabeledContent("Responsable",value:N2ClinicianIdentity.name)
                LabeledContent("DNI del responsable",value:N2ClinicianIdentity.dni)
            }
            }
            DanperPanel {
                Text("DEMO · Utiliza únicamente información ficticia.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
          }.padding(16)
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .danperFormChrome()
    }
    @MainActor
    private func refresh() async {
        guard !layoutOnly else{return}
        loading=true
        defer{loading=false}
        do {
            summary=try await N2SyntheticTrialIOSVault.shared.inspect()
            let period=N2HomeCalendarPeriod(now:Date())
            let counters=try await N2SyntheticTrialIOSVault.shared.dashboardCounters(today:period.today,weekStart:period.weekStart)
            homeCounts=counters.map{DanperHomeCounts(today:$0.today,week:$0.week,month:$0.month)}
            problem=""
        }catch {
            summary=nil
            problem=trialFailureMessage(error)
        }
    }
    @MainActor
    private func startPractice(withSample:Bool) async {
        guard !preparing,summary==nil,problem.isEmpty else{return}
        preparing=true
        defer{preparing=false}
        do {
            let result:N2ProtectedStoreSummary
            if withSample {
                result=try await N2SyntheticTrialIOSVault.shared.startSyntheticDemo()
            } else {
                result=try await N2SyntheticTrialIOSVault.shared.startEmptyDemo()
                guard result.workers==0,result.attentions==0,
                      result.drafts==0,result.physicalMovements==0 else {
                    throw N2SyntheticTrialIOSVault.Failure.blockedMigration
                }
            }
            summary=result
            let period=N2HomeCalendarPeriod(now:Date())
            let counters=try await N2SyntheticTrialIOSVault.shared.dashboardCounters(today:period.today,weekStart:period.weekStart)
            homeCounts=counters.map{DanperHomeCounts(today:$0.today,week:$0.week,month:$0.month)}
            problem=""
        } catch {
            summary=nil
            metrics=nil
            problem=trialFailureMessage(error)
        }
    }

    /// Read-only diagnostic. Never deletes keys, overwrites encrypted trial data,
    /// or attempts to access the real clinical vault.
    private func trialFailureMessage(_ error:Error)->String {
        if let issue=error as? N2SyntheticTrialIOSVault.Failure {
            switch issue {
            case .missingKey:
                return "Se detectaron archivos ficticios anteriores sin su clave de prueba. Se conservaron. No desinstales la beta hasta revisar la recuperación."
            case .unavailableKeychain:
                return "iOS no pudo abrir el almacenamiento seguro de prueba. Mantén el iPhone desbloqueado e inténtalo otra vez."
            case .keyInvalid:
                return "La clave de prueba tiene un formato inesperado. Se conservaron los archivos."
            case .blockedMigration:
                return "El ejemplo ficticio no superó la validación. No se importaron ni modificaron datos."
            case .resetIncomplete:
                return "La eliminación de los datos ficticios quedó incompleta. La clave de prueba se invalidó, pero quedan archivos cifrados por retirar. Repite el borrado desde Ajustes → Restablecer entorno de prueba; la bóveda clínica y la build 222 permanecen intactas."
            case .keychainStatus(let code):
                return "No se pudo acceder al Keychain de pruebas (código iOS: \(code)). Conservamos los archivos; comparte este código para corregir la activación."
            }
        }
        let details=error as NSError
        return "No se pudo iniciar la práctica (\(details.domain), código \(details.code)). Ningún dato fue borrado; comparte este diagnóstico."
    }
}

