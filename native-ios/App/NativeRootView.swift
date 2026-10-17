import SwiftUI
import DanperCore

private let danperAccent=Color(red:0.88,green:0.09,blue:0.16)

/// A human-first beta: one explicit demo source, five clear navigation tabs.
/// No clinical import occurs during launch. Real build222 data are never read.
struct NativeRootView:View {
    @State private var tab=0
    @State private var summary:N2ProtectedStoreSummary?
    @State private var loading=true
    @State private var preparing=false
    @State private var problem=""
    @State private var showAdvanced=false

    private var isReady:Bool { summary != nil }
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
                                    N2NativeWorkerEditorView()
                                }label:{
                                    Label("Nuevo trabajador ficticio",
                                          systemImage:"person.badge.plus")
                                }
                            }
                        }
                }else{lockedTab(title:"Personal",symbol:"person.2")}
            }
            .tabItem{Label("Personal",systemImage:"person.2.fill")}.tag(1)
            NavigationStack {
                if isReady {N2NativeClinicalFormView()}
                else {lockedTab(title:"Atención",symbol:"cross.case")}
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
        .tint(danperAccent)
        .task {await refresh()}
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
                        Text("Tu espacio de enfermería")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.87))
                        Label("Beta nativa SwiftUI",systemImage:"checkmark.shield.fill")
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
                Label("MODO DE PRUEBAS · SOLO DATOS FICTICIOS",
                      systemImage:"lock.shield")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(danperAccent)
                    .padding(.horizontal,12)
                    .padding(.vertical,8)
                    .background(danperAccent.opacity(0.09),in:Capsule())
                VStack(alignment:.leading,spacing:12) {
                    Text(isReady ? "Listo para comenzar" :
                        "Comienza a probar la aplicación")
                        .font(.title3.bold())
                    Text(isReady ?
                         "Ya tienes un entorno de demostración cifrado. Puedes practicar atenciones, consultar el historial y revisar el inventario sin tocar tu aplicación anterior." :
                         "Para registrar una atención de prueba, activa primero el ejemplo ficticio. No necesitas importar un respaldo ni configurar un inventario real.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal:false,vertical:true)
                    if loading || preparing {
                        HStack {
                            ProgressView()
                            Text(preparing ? "Creando práctica cifrada…" :
                                 "Comprobando los datos locales…")
                                .font(.footnote)
                        }
                    }else if !problem.isEmpty {
                        Label(problem,systemImage:"exclamationmark.triangle")
                            .font(.footnote)
                            .foregroundStyle(.orange)
                            .fixedSize(horizontal:false,vertical:true)
                            .padding(11)
                            .frame(maxWidth:.infinity,alignment:.leading)
                            .background(Color.orange.opacity(0.08),
                                        in:RoundedRectangle(cornerRadius:12))
                    }
                    if isReady {
                        Label("Demostración activa · \(summary?.workers ?? 0) trabajadores y \(summary?.attentions ?? 0) registros",
                              systemImage:"checkmark.circle.fill")
                            .font(.footnote)
                            .foregroundStyle(.green)
                        Button {
                            tab=2
                        }label:{
                            Label("Registrar una atención",
                                  systemImage:"cross.case.fill")
                                .frame(maxWidth:.infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .tint(danperAccent)
                        Button {
                            tab=1
                        }label:{
                            Label("Buscar trabajador o historial",
                                  systemImage:"person.text.rectangle")
                                .frame(maxWidth:.infinity)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                    }else{
                        Button {
                            Task {await startPractice()}
                        }label:{
                            Label("Empezar con datos ficticios",
                                  systemImage:"play.fill")
                                .frame(maxWidth:.infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .tint(danperAccent)
                        .disabled(loading || preparing)
                    }
                }
                .padding(18)
                .frame(maxWidth:.infinity,alignment:.leading)
                .background(Color(uiColor:.secondarySystemGroupedBackground),
                            in:RoundedRectangle(cornerRadius:20))
                .shadow(color:Color.black.opacity(0.055),radius:12,y:3)
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
                VStack(alignment:.leading,spacing:7) {
                    Label("Tus datos reales permanecen separados",
                          systemImage:"lock.shield")
                        .font(.subheadline.weight(.semibold))
                    Text("La build 222 sigue intacta. Esta beta no recupera datos reales automáticamente y todavía no reemplaza tu herramienta de trabajo.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                .padding(15)
                .frame(maxWidth:.infinity,alignment:.leading)
            }
            .padding(.horizontal,16)
            .padding(.vertical,18)
            .frame(maxWidth:.infinity,alignment:.leading)
        }
        .background(Color(uiColor:.systemGroupedBackground))
        .navigationTitle("Inicio")
        .navigationBarTitleDisplayMode(.inline)
    }
    private func quickInfo(_ index:String,title:String,desc:String)->some View {
        VStack(alignment:.leading,spacing:9) {
            Text(index).font(.subheadline.bold())
                .foregroundStyle(.white)
                .frame(width:31,height:31)
                .background(danperAccent,in:Circle())
            Text(title).font(.subheadline.bold())
            Text(desc).font(.caption).foregroundStyle(.secondary)
                .fixedSize(horizontal:false,vertical:true)
            Spacer(minLength:0)
        }
        .padding(14)
        .frame(maxWidth:.infinity,minHeight:130,alignment:.topLeading)
        .background(Color(uiColor:.secondarySystemGroupedBackground),
                    in:RoundedRectangle(cornerRadius:16))
        .accessibilityElement(children:.combine)
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
        List {
            Section {
                Label(isReady ? "Pruebas ficticias habilitadas" :
                    "Inicia la práctica desde Inicio",systemImage:"info.circle")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            if isReady {
                Section("Inventario y reportes de prueba") {
                    NavigationLink {
                        N2NativeInventoryView()
                    }label:{
                        Label("Inventario y lotes",systemImage:"shippingbox")
                    }
                    NavigationLink {
                        N2ReconciliationView()
                    }label:{
                        Label("Conciliación de inventario",
                              systemImage:"checkmark.shield")
                    }
                    NavigationLink {
                        N2VerifiedNursingExportView()
                    }label:{
                        Label("Kardex de enfermería",
                              systemImage:"tablecells")
                    }
                    NavigationLink {
                        N2VerifiedIndicatorExportView()
                    }label:{
                        Label("Indicador ambulatorio · Excel",
                              systemImage:"doc.richtext")
                    }
                    NavigationLink {
                        N2NativeBackupExportView()
                    }label:{
                        Label("Respaldar datos ficticios cifrados",
                              systemImage:"lock.doc")
                    }
                }
            }
            Section("Datos reales · no se mezclan con las pruebas") {
                NavigationLink {
                    BackupPreviewView()
                }label:{
                    Label("Comprobar respaldo original (solo lectura)",
                          systemImage:"doc.text.magnifyingglass")
                }
                DisclosureGroup("Configuración avanzada",isExpanded:$showAdvanced) {
                    NavigationLink {
                        N2NativeActivationView()
                    }label:{
                        Label("Importación protegida en bóveda independiente",
                              systemImage:"lock.shield")
                    }
                    Text("Esta función es independiente de la demostración. No la necesitas para probar atenciones.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
            Section {
                Text("Versión beta SwiftUI · uso con información ficticia. No sustituye la build 222.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Más")
        .navigationBarTitleDisplayMode(.inline)
    }
    @MainActor
    private func refresh() async {
        loading=true
        defer{loading=false}
        do {
            summary=try await N2SyntheticTrialIOSVault.shared.inspect()
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
