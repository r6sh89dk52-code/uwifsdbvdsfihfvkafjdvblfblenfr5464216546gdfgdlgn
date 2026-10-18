import SwiftUI
import DanperCore

private let danperAccent=Color(red:0.88,green:0.09,blue:0.16)

/// A human-first beta: one explicit demo source, five clear navigation tabs.
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
    @State private var summary:N2ProtectedStoreSummary?
    @State private var loading=true
    @State private var preparing=false
    @State private var problem=""
    @State private var showAdvanced=false
    @State private var metrics:N2DashboardMetrics?
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("danper.appearance") private var appearance="system"
    @AppStorage("danper.haptics.enabled") private var haptics=true

    private var isReady:Bool { summary != nil || layoutOnly }
    var body:some View {
        TabView(selection:$tab) {
            NavigationStack { home }
                .tabItem{Label("Inicio",systemImage:"house.fill")}.tag(0)
            NavigationStack {
                if isReady {
                    N2NativeHistoryView(useProtectedVault:true)
                        .toolbar {
                            ToolbarItem(placement:.topBarTrailing) {
                                NavigationLink {
                                    N2NativeWorkerEditorView(onSaved:{dni in
                                        newlyRegisteredWorkerDNI=dni
                                        tab=2
                                    })
                                }label:{
                                    Label("Nuevo trabajador",
                                          systemImage:"person.badge.plus")
                                }
                            }
                        }
                }else{lockedTab(title:"Personal",symbol:"person.2")}
            }
            .tabItem{Label("Personal",systemImage:"person.2.fill")}.tag(1)
            NavigationStack {
                if isReady {
                    N2NativeClinicalFormView(
                        initialWorkerDNI:newlyRegisteredWorkerDNI)
                    .id(newlyRegisteredWorkerDNI ?? "new-attention")
                } else {lockedTab(title:"Atención",symbol:"cross.case")}
            }
            .tabItem{Label("Atención",systemImage:"cross.case.fill")}.tag(2)
            NavigationStack {
                if isReady {N2NativeDraftsDashboard()}
                else {lockedTab(title:"Borradores",symbol:"doc.text")}
            }
            .tabItem{Label("Borradores",systemImage:"doc.text.fill")}.tag(3)
            NavigationStack { toolsTab }
                .tabItem{Label("Más",systemImage:"square.grid.2x2.fill")}.tag(4)
        }
        .tint(DanperStyle.red)
        .environment(\.locale,Locale(identifier:"es_PE"))
        .animation(reduceMotion ? nil : DanperStyle.animation,value:tab)
        .sensoryFeedback(.selection,trigger:tab) {_,_ in haptics}
        .task(id:tab) {await refresh()}
        .onChange(of:tab) {previous,newTab in
            if previous==2 && newTab != 2 {
                newlyRegisteredWorkerDNI=nil
            }
        }
        .onChange(of:scenePhase) {_,phase in if phase == .active {Task {await refresh()}}}
    }

    private var home:some View {
        ScrollView {
            VStack(alignment:.leading,spacing:20) {
                HStack(spacing:14) {
                    Image("BrandLogo").resizable().scaledToFit()
                        .frame(width:68,height:68)
                        .clipShape(RoundedRectangle(cornerRadius:17))
                        .overlay(RoundedRectangle(cornerRadius:17)
                            .strokeBorder(.white.opacity(0.28),lineWidth:1))
                    VStack(alignment:.leading,spacing:5) {
                        Text("DANPER Salud")
                            .font(.system(.title2,design:.rounded,weight:.bold))
                            .foregroundStyle(.white)
                        Text("Bienvenido, Felipe")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.87))
                        Label("Salud ocupacional",systemImage:"checkmark.shield.fill")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.white.opacity(0.9))
                    }
                    Spacer(minLength:0)
                }
                .padding(18)
                .frame(maxWidth:.infinity,alignment:.leading)
                .background(
                    LinearGradient(colors:[danperAccent,Color(red:0.55,green:0.04,blue:0.14)],
                                   startPoint:.topLeading,endPoint:.bottomTrailing),
                    in:RoundedRectangle(cornerRadius:23)
                )
                .shadow(color:danperAccent.opacity(0.16),radius:14,y:6)
                Label("DANPER SALUD MÓVIL",
                      systemImage:"lock.shield")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(danperAccent)
                    .padding(.horizontal,12)
                    .padding(.vertical,8)
                    .background(danperAccent.opacity(0.09),in:Capsule())
                DanperPanel {
                    Label("MODO DE PRUEBA · DATOS FICTICIOS",
                          systemImage:"exclamationmark.shield.fill")
                        .font(.footnote.weight(.bold))
                        .foregroundStyle(.orange)
                    Text("Esta versión utiliza una bóveda de ensayo. No introduzcas datos de pacientes reales: la bóveda clínica independiente aún no está habilitada en las pantallas de trabajo.")
                        .font(.footnote).foregroundStyle(.secondary)
                        .fixedSize(horizontal:false,vertical:true)
                }
                .accessibilityIdentifier("clinical-demo-mode-warning")
                if isReady {
                    Button {tab=2} label: {
                        HStack {
                            VStack(alignment:.leading,spacing:7) {
                                Text("ACCESO RÁPIDO").font(.caption.weight(.bold))
                                Text("Nueva atención").font(.system(.title,design:.rounded,weight:.bold))
                                Text("Evaluación, tratamiento y consumo").font(.subheadline)
                            }
                            Spacer()
                            Image(systemName:"plus").font(.title.weight(.semibold))
                        }.foregroundStyle(.white).padding(22)
                            .frame(maxWidth:.infinity,alignment:.leading)
                            .background(DanperStyle.gradient,in:RoundedRectangle(cornerRadius:23))
                    }.buttonStyle(.plain)
                    if let metrics {
                        ViewThatFits(in:.horizontal) {
                            HStack(spacing:10) {
                                metric("Hoy",metrics.today,"sun.max.fill")
                                metric("Esta semana",metrics.week,"calendar")
                                metric("Borradores",metrics.drafts,"doc.text.fill")
                            }
                            VStack(spacing:10) {
                                metric("Hoy",metrics.today,"sun.max.fill")
                                metric("Esta semana",metrics.week,"calendar")
                                metric("Borradores",metrics.drafts,"doc.text.fill")
                            }
                        }
                    }
                }
                if !isReady {
                    VStack(alignment:.leading,spacing:14) {
                        Text("Comienza tu prueba").font(.title3.bold())
                        Text("Registra atenciones, administra el personal y consulta los reportes.")
                            .font(.subheadline).foregroundStyle(.secondary)
                        if loading || preparing {ProgressView("Preparando datos protegidos…")}
                        if !problem.isEmpty {Text(problem).font(.footnote).foregroundStyle(.orange)}
                        Button {Task {await startPractice()}} label: {
                            Label("Comenzar",systemImage:"play.fill")
                        }.buttonStyle(DanperPrimaryButton()).disabled(loading || preparing)
                    }.padding(18).background(DanperStyle.surface,in:RoundedRectangle(cornerRadius:20))
                }
                VStack(alignment:.leading,spacing:12) {
                    Text("Explora DANPER Salud")
                        .font(.title3.weight(.bold))
                    LazyVGrid(columns:[GridItem(.flexible(),spacing:12),
                                       GridItem(.flexible(),spacing:12)],spacing:12) {
                        quickInfo("1",title:"Personal",desc:"Trabajadores e historial.")
                        quickInfo("2",title:"Atención",desc:"Diagnósticos y tratamientos.")
                        quickInfo("3",title:"Borradores",desc:"Continúa registros pendientes.")
                        quickInfo("4",title:"Más",desc:"Inventario, Kardex y Excel.")
                    }
                }
                if isReady {
                    HStack(spacing:12) {
                        NavigationLink {N2NativeInventoryView()} label: {
                            Label("Inventario",systemImage:"shippingbox.fill")
                        }.buttonStyle(DanperSecondaryButton())
                        NavigationLink {N2VerifiedIndicatorExportView()} label: {
                            Label("Excel",systemImage:"tablecells.fill")
                        }.buttonStyle(DanperSecondaryButton())
                    }
                }
            }
            .padding(.horizontal,16)
            .padding(.vertical,18)
            .frame(maxWidth:.infinity,alignment:.leading)
        }
        .background(Color(uiColor:.systemGroupedBackground))
        .navigationTitle("Inicio")
        .navigationBarTitleDisplayMode(.inline)
    }
    private func metric(_ title:String,_ count:Int,_ symbol:String)->some View {
        VStack(alignment:.leading,spacing:8) {
            Image(systemName:symbol).foregroundStyle(DanperStyle.red)
            Text(count.formatted()).font(.system(.title,design:.rounded,weight:.bold)).monospacedDigit()
            Text(title).font(.caption).foregroundStyle(.secondary)
        }.padding(14).frame(maxWidth:.infinity,alignment:.leading)
            .background(DanperStyle.surface,in:RoundedRectangle(cornerRadius:18))
            .accessibilityElement(children:.combine)
    }
    private func quickInfo(_ index:String,title:String,desc:String)->some View {
        let symbols=["1":"person.2.fill","2":"cross.case.fill",
                     "3":"doc.text.fill","4":"square.grid.2x2.fill"]
        return Button {
            if isReady,let next=Int(index) {tab=next}
        } label: {
            VStack(alignment:.leading,spacing:10) {
                Image(systemName:symbols[index] ?? "square.grid.2x2")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(DanperStyle.red)
                    .frame(width:43,height:43)
                    .background(DanperStyle.red.opacity(0.1),
                                in:RoundedRectangle(cornerRadius:13))
                Text(title)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.primary)
                Text(desc)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal:false,vertical:true)
                Spacer(minLength:0)
                if isReady {
                    Image(systemName:"arrow.up.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(DanperStyle.red)
                        .frame(maxWidth:.infinity,alignment:.trailing)
                }
            }
            .padding(14)
            .frame(maxWidth:.infinity,minHeight:150,alignment:.topLeading)
            .background(DanperStyle.surface,
                        in:RoundedRectangle(cornerRadius:19))
            .overlay(RoundedRectangle(cornerRadius:19)
                .strokeBorder(Color.secondary.opacity(0.08),lineWidth:1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Abrir "+title)
        .disabled(!isReady)
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
    private var toolsTab:some View {
        ScrollView {
          VStack(alignment:.leading,spacing:16) {
            DanperPanel {
                Label(isReady ? "Herramientas disponibles" :
                    "Inicia la práctica desde Inicio",systemImage:"info.circle")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            if isReady {
                DanperPanel("Inventario y reportes") {
                    DanperToolLink(title:"Inventario y lotes",symbol:"shippingbox") {N2NativeInventoryView()}
                    DanperToolLink(title:"Conciliación de inventario",symbol:"checkmark.shield") {N2ReconciliationView()}
                    DanperToolLink(title:"Kardex de enfermería",symbol:"tablecells") {N2VerifiedNursingExportView()}
                    DanperToolLink(title:"Indicador ambulatorio · Excel",symbol:"doc.richtext") {N2VerifiedIndicatorExportView()}
                    DanperToolLink(title:"Respaldo cifrado",symbol:"lock.doc") {N2NativeBackupExportView()}
                }
            }
            DanperPanel("Datos reales · no se mezclan con las pruebas") {
                DanperToolLink(title:"Comprobar respaldo original (solo lectura)",symbol:"doc.text.magnifyingglass") {BackupPreviewView()}
                DisclosureGroup("Configuración avanzada",isExpanded:$showAdvanced) {
                    DanperToolLink(title:"Importación protegida en bóveda independiente",symbol:"lock.shield") {N2NativeActivationView()}
                    Text("Esta función es independiente de la demostración. No la necesitas para probar atenciones.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
            DanperPanel("Preferencias") {
                Picker("Apariencia",selection:$appearance) {
                    Text("Sistema").tag("system")
                    Text("Claro").tag("light")
                    Text("Oscuro").tag("dark")
                }.pickerStyle(.segmented)
                DanperCheckRow(selected:$haptics) {Text("Respuesta háptica")}
                LabeledContent("Responsable",value:"Felipe Azcárate Silva")
            }
            DanperPanel {
                Text("Versión beta SwiftUI · uso con información ficticia. No sustituye la build 222.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
          }.padding(16)
        }
        .navigationTitle("Más")
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
            if let model=try await N2SyntheticTrialIOSVault.shared.readHistory() {
                metrics=N2DashboardMetrics.calculate(visits:model.visits,now:Date())
            }
            problem=""
        }catch {
            summary=nil
            problem=trialFailureMessage(error)
        }
    }
    @MainActor
    private func startPractice() async {
        guard !preparing else{return}
        preparing=true
        defer{preparing=false}
        do {
            summary=try await N2SyntheticTrialIOSVault.shared.startSyntheticDemo()
            if let model=try await N2SyntheticTrialIOSVault.shared.readHistory() {
                metrics=N2DashboardMetrics.calculate(visits:model.visits,now:Date())
            }
            problem=""
        }catch {
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
            case .keychainStatus(let code):
                return "No se pudo acceder al Keychain de pruebas (código iOS: \(code)). Conservamos los archivos; comparte este código para corregir la activación."
            }
        }
        let details=error as NSError
        return "No se pudo iniciar la práctica (\(details.domain), código \(details.code)). Ningún dato fue borrado; comparte este diagnóstico."
    }
}

