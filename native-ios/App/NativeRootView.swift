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
                .tabItem { Label("Inicio",systemImage:"house.fill") }.tag(0)
            NavigationStack {
                if isReady {
                    N2NativeClinicalFormView(initialWorkerDNI:newlyRegisteredWorkerDNI)
                        .id(newlyRegisteredWorkerDNI ?? "new-attention")
                } else {
                    lockedTab(title:"Registrar",symbol:"cross.case")
                }
            }
            .tabItem { Label("Registrar",systemImage:"plus.circle.fill") }.tag(1)
            NavigationStack {
                if isReady {
                    N2NativeHistoryView(useProtectedVault:true)
                        .toolbar {
                            ToolbarItem(placement:.topBarTrailing) {
                                NavigationLink {
                                    N2NativeWorkerEditorView(onSaved:{dni in
                                        newlyRegisteredWorkerDNI=dni
                                        tab=1
                                    })
                                } label: {
                                    Label("Nuevo trabajador",systemImage:"person.badge.plus")
                                }
                            }
                        }
                } else {
                    lockedTab(title:"Historial",symbol:"clipboard")
                }
            }
            .tabItem { Label("Historial",systemImage:"list.clipboard.fill") }.tag(2)
            NavigationStack { toolsTab }
                .tabItem { Label("Ajustes",systemImage:"gearshape.fill") }.tag(3)
        }
        .tint(DanperStyle.red)
        .environment(\.n2WorkspaceVault,.demo)
        .environment(\.locale,Locale(identifier:"es_PE"))
        .animation(reduceMotion ? nil : DanperStyle.animation,value:tab)
        .sensoryFeedback(.selection,trigger:tab) {_,_ in haptics}
        .task(id:tab) {await refresh()}
        .onChange(of:tab) {previous,newTab in
            if previous == 1 && newTab != 1 {
                newlyRegisteredWorkerDNI=nil
            }
        }
        .onChange(of:scenePhase) {_,phase in
            if phase == .active {Task {await refresh()}}
        }
    }

    private var home:some View {
        ScrollView {
            VStack(alignment:.leading,spacing:20) {
                HStack(spacing:12) {
                    Image("BrandLogo").resizable().scaledToFit()
                        .frame(width:43,height:43)
                        .clipShape(RoundedRectangle(cornerRadius:11))
                    VStack(alignment:.leading,spacing:1) {
                        Text("DANPER").font(.system(.headline,design:.rounded,weight:.heavy))
                        Text("SALUD MÓVIL").font(.caption2.weight(.bold))
                            .tracking(1.3).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button {tab=3} label: {
                        Image(systemName:"gearshape")
                            .font(.title3.weight(.medium))
                            .foregroundStyle(.primary)
                            .frame(width:44,height:44)
                    }
                    .accessibilityLabel("Ajustes")
                }
                VStack(alignment:.leading,spacing:8) {
                    Text("DEPARTAMENTO DE SALUD")
                        .font(.caption2.weight(.bold)).tracking(1.5)
                        .foregroundStyle(DanperStyle.red)
                    HStack(alignment:.center,spacing:10) {
                        Text("Bienvenido, Felipe")
                            .font(.system(.title,design:.rounded,weight:.bold))
                        Spacer()
                        Image(systemName:"waveform.path.ecg")
                            .font(.title2.weight(.semibold))
                            .foregroundStyle(DanperStyle.red)
                            .frame(width:52,height:52)
                            .background(DanperStyle.red.opacity(0.09),
                                        in:RoundedRectangle(cornerRadius:17))
                    }
                    Text("Departamento de Salud · Registro ambulatorio local")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
                .frame(maxWidth:.infinity,alignment:.leading)
                .padding(.horizontal,2)
                .padding(.vertical,3)
                DisclosureGroup {
                    Text("Esta versión utiliza una bóveda de ensayo independiente. No introduzcas datos clínicos reales hasta validar la migración y las pruebas en iPhone.")
                        .font(.footnote).foregroundStyle(.secondary)
                        .padding(.top,6)
                } label: {
                    Label("Modo de prueba · Solo datos ficticios",
                          systemImage:"exclamationmark.shield")
                        .font(.footnote.weight(.semibold)).foregroundStyle(.orange)
                }
                .padding(14)
                .background(DanperStyle.red.opacity(0.07),
                            in:RoundedRectangle(cornerRadius:16))
                .overlay(RoundedRectangle(cornerRadius:16)
                    .strokeBorder(DanperStyle.red.opacity(0.17)))
                .accessibilityIdentifier("clinical-demo-mode-warning")
                if isReady {
                    Button {tab=1} label: {
                        HStack {
                            VStack(alignment:.leading,spacing:7) {
                                Text("ACCESO RÁPIDO").font(.caption.weight(.bold))
                                Text("Nueva atención").font(.system(.title,design:.rounded,weight:.bold))
                                Text("Evaluación, tratamiento y consumo").font(.subheadline)
                            }
                            Spacer()
                            Image(systemName:"plus").font(.title.weight(.semibold))
                        }.foregroundStyle(.white).padding(20)
                            .frame(maxWidth:.infinity,minHeight:130,alignment:.leading)
                            .background(DanperStyle.gradient,in:RoundedRectangle(cornerRadius:23))
                            .shadow(color:DanperStyle.red.opacity(0.18),radius:13,y:7)
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
                    Text("Herramientas").font(.title3.weight(.bold))
                    LazyVGrid(columns:[GridItem(.flexible(),spacing:12),
                                       GridItem(.flexible(),spacing:12)],spacing:12) {
                        shortcut("Historial","Consultar atenciones","list.clipboard.fill") {
                            N2NativeHistoryView(useProtectedVault:true)
                        }
                        shortcut("Trabajadores","Registrar o buscar personal","person.badge.plus") {
                            N2NativeHistoryView(useProtectedVault:true)
                        }
                        shortcut("Pendientes","Recuperar borradores","doc.badge.clock") {
                            N2NativeDraftsDashboard()
                        }
                        shortcut("Alergias","Revisar antes del tratamiento","cross.vial.fill") {
                            N2NativeClinicalFormView()
                        }
                        shortcut("Kardex","Inventario y reportes","shippingbox.fill") {
                            N2Build222KardexHub()
                        }
                        shortcut("Exportar","Indicador ambulatorio · 10 hojas","tablecells.fill") {
                            N2VerifiedIndicatorExportView()
                        }
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
    private func shortcut<Destination:View>(
        _ title:String,_ description:String,_ symbol:String,
        @ViewBuilder destination:()->Destination
    )->some View {
        NavigationLink(destination:destination) {
            VStack(alignment:.leading,spacing:9) {
                Image(systemName:symbol)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(DanperStyle.red)
                    .frame(width:43,height:43)
                    .background(DanperStyle.red.opacity(0.09),
                                in:RoundedRectangle(cornerRadius:12))
                Text(title).font(.subheadline.weight(.bold))
                    .foregroundStyle(.primary)
                Text(description).font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal:false,vertical:true)
                Spacer(minLength:0)
            }
            .padding(14)
            .frame(maxWidth:.infinity,minHeight:124,alignment:.topLeading)
            .background(DanperStyle.surface,in:RoundedRectangle(cornerRadius:18))
            .overlay(RoundedRectangle(cornerRadius:18)
                .strokeBorder(Color.secondary.opacity(0.10),lineWidth:1))
        }
        .buttonStyle(.plain)
        .disabled(!isReady)
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
                DanperToolLink(title:"Acceso al espacio clínico independiente",symbol:"cross.case.fill") {
                    N2ClinicalWorkspaceGateView()
                }
                Text("Acceso mediante autenticación adicional y fuente clínica cifrada. Continúa en validación; no usar con pacientes reales.")
                    .font(.caption).foregroundStyle(.orange)
                DanperToolLink(title:"Comprobar respaldo original (solo lectura)",symbol:"doc.text.magnifyingglass") {BackupPreviewView()}
                DisclosureGroup("Configuración avanzada",isExpanded:$showAdvanced) {
                    DanperToolLink(title:"Importación protegida en bóveda independiente",symbol:"lock.shield") {N2NativeActivationView()}
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
                Text("Solo elimina registros creados en la demostración B11. Las fuentes clínicas y la build 222 no se tocan. Se exige confirmación escrita y autenticación.")
                    .font(.caption).foregroundStyle(.secondary)
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
        .navigationTitle("Ajustes")
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

