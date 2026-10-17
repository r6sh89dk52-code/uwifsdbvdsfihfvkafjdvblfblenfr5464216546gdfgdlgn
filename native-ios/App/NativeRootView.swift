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
                HStack(spacing:12) {
                    Image("BrandLogo").resizable().scaledToFit()
                        .frame(width:56,height:56)
                        .clipShape(RoundedRectangle(cornerRadius:13))
                    VStack(alignment:.leading,spacing:3) {
                        Text("DANPER Salud").font(.title2.bold())
                        Text("Tu espacio de enfermería")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                    Spacer(minLength:0)
                }
                Label("VERSIÓN DE PRUEBA · DATOS FICTICIOS",
                      systemImage:"checkmark.shield")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(danperAccent)
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
                            .font(.footnote).foregroundStyle(.orange)
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
                            in:RoundedRectangle(cornerRadius:18))
                VStack(alignment:.leading,spacing:12) {
                    Text("¿Qué puedes hacer?")
                        .font(.headline)
                    quickInfo("1",title:"Personal",desc:"Buscar trabajadores ficticios y revisar sus atenciones.")
                    quickInfo("2",title:"Atención",desc:"Registrar diagnósticos, procedimientos y medicamentos.")
                    quickInfo("3",title:"Borradores",desc:"Continuar registros pendientes con seguridad.")
                    quickInfo("4",title:"Más",desc:"Abrir inventario, Kardex, Excel y herramientas.")
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
        HStack(alignment:.top,spacing:12) {
            Text(index).font(.subheadline.bold())
                .foregroundStyle(.white)
                .frame(width:28,height:28)
                .background(danperAccent,in:Circle())
            VStack(alignment:.leading,spacing:3) {
                Text(title).font(.subheadline.bold())
                Text(desc).font(.footnote).foregroundStyle(.secondary)
                    .fixedSize(horizontal:false,vertical:true)
            }
        }
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
            problem="No se pudo comprobar el espacio de prueba. Conservamos los datos y no hemos reiniciado nada."
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
            problem="No fue posible preparar el ejemplo. No se borraron datos; intenta cerrar y abrir de nuevo."
        }
    }
}
