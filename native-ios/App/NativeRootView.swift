import SwiftUI
import DanperCore

private let danperRed = Color(red: 0.88, green: 0.09, blue: 0.16)

/// Smaller computed tabs avoid a SwiftUI type-checker explosion with
/// a five-tab NavigationStack plus nested asynchronous state handlers.
struct NativeRootView: View {
    @State private var clinic = N1gClinic()
    @State private var selectedTab = 0
    @State private var demoReady = false
    @State private var restoring = false
    @State private var demoStorageMessage = "Abriendo almacenamiento cifrado de pruebas…"
    @State private var writeTask: Task<Void, Never>?
    @State private var demoClock = N1jRevisionClock()
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        TabView(selection:$selectedTab) {
            homeTab
            workersTab
            attentionTab
            draftsTab
            toolsTab
        }
        .tint(danperRed)
        .task { await loadDemo() }
        .onChange(of: clinic.visits) { _, _ in scheduleDemoWrite() }
        .onChange(of: clinic.workers) { _, _ in scheduleDemoWrite() }
        .onChange(of: clinic.allergies) { _, _ in scheduleDemoWrite() }
        .onChange(of: clinic.activeDraftID) { _, _ in scheduleDemoWrite() }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { scheduleDemoWrite(immediately:true) }
        }
    }

    private var homeTab: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment:.leading,spacing:17) {
                    HStack(spacing:14) {
                        Image(systemName:"cross.case.fill")
                            .font(.largeTitle).foregroundStyle(danperRed)
                        VStack(alignment:.leading) {
                            Text("DANPER").font(.largeTitle.bold())
                            Text("Salud Móvil Nativa").font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    GroupBox("MIGRACIÓN SEGURA") {
                        VStack(alignment:.leading,spacing:8) {
                            Text("SwiftUI nativo · Sin WebView")
                                .font(.headline)
                            Text("La build 222 no se reemplaza ni se modifica.")
                            Text(demoStorageMessage)
                                .font(.footnote)
                                .foregroundStyle(demoReady ? Color.secondary : Color.orange)
                            Text("La gestión clínica real requiere todavía importación verificada y paridad del Kardex/Excel.")
                                .font(.footnote)
                        }
                        .frame(maxWidth:.infinity,alignment:.leading)
                    }
                    readOnlyBackupLink
                    GroupBox("CLÍNICA N2 · BÓVEDA PROTEGIDA") {
                        VStack(alignment:.leading,spacing:12) {
                            Text("Acceso nativo independiente de la demostración. Se necesita importar una sola copia cifrada y revisada antes de trabajar con datos clínicos.")
                                .font(.footnote).foregroundStyle(.secondary)
                            NavigationLink {
                                N2NativeActivationView()
                            } label: {
                                Label("Revisar / activar fuente clínica N2",systemImage:"lock.shield")
                            }
                            NavigationLink {
                                N2NativeHistoryView(useProtectedVault:true)
                            } label: {
                                Label("Consultar historial cifrado N2",systemImage:"person.text.rectangle")
                            }
                            NavigationLink {
                                N2NativeClinicalFormView()
                            } label: {
                                Label("Atención clínica N2",systemImage:"cross.case.fill")
                            }
                            Text("La atención ficticia de las otras pestañas sigue separada. Esta compilación todavía NO sustituye la build 222.")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        .frame(maxWidth:.infinity,alignment:.leading)
                    }
                    StatusCard(icon:"person.text.rectangle",title:"Trabajadores y atenciones",
                        detail:"Formulario nativo guiado en entorno ficticio, separado de los datos reales.")
                    StatusCard(icon:"pills",title:"FEFO nativo",
                        detail:"Reglas Swift probadas en Linux con inventario ficticio.")
                    StatusCard(icon:"tablecells",title:"Indicador y Kardex",
                        detail:"Los dos libros se generan con datos ficticios; falta validar el uso clínico en iPhone.")
                }
                .padding()
            }
            .navigationTitle("Inicio")
        }
        .tabItem { Label("Inicio",systemImage:"house") }
        .tag(0)
    }

    private var readOnlyBackupLink: some View {
        NavigationLink {
            BackupPreviewView()
                .navigationTitle("Respaldo real · lectura")
        } label: {
            HStack(spacing:12) {
                Image(systemName:"lock.doc.fill")
                    .font(.title3).foregroundStyle(danperRed)
                VStack(alignment:.leading,spacing:4) {
                    Text("Comprobar respaldo real").font(.headline)
                    Text("Solo lectura: inspecciona una copia local con contraseña sin restaurar ni alterar consumos.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer(minLength:0)
                Image(systemName:"chevron.right").foregroundStyle(.tertiary)
            }
            .padding(14)
            .background(Color(uiColor:.secondarySystemGroupedBackground),
                        in:RoundedRectangle(cornerRadius:15))
        }
        .buttonStyle(.plain)
    }

    private var workersTab: some View {
        NavigationStack {
            N1gRosterScreen(clinic:$clinic,selectedTab:$selectedTab)
                .disabled(!demoReady)
        }
        .tabItem { Label("Personal",systemImage:"person.2") }
        .tag(1)
    }

    private var attentionTab: some View {
        NavigationStack {
            N1gAttentionScreen(clinic:$clinic)
                .disabled(!demoReady)
        }
        .tabItem { Label("Atención",systemImage:"cross.case") }
        .tag(2)
    }

    private var draftsTab: some View {
        NavigationStack {
            N1gHistoryScreen(clinic:$clinic,selectedTab:$selectedTab)
                .disabled(!demoReady)
        }
        .tabItem { Label("Borradores",systemImage:"doc.text") }
        .tag(3)
    }

    private var toolsTab: some View {
        NavigationStack {
            List {
                Section("Herramientas nativas") {
                    NavigationLink {
                        FEFOSandboxView().navigationTitle("FEFO")
                    } label: { Label("FEFO ficticio",systemImage:"shippingbox") }
                    NavigationLink {
                        BackupPreviewView().navigationTitle("Respaldo")
                    } label: { Label("Inspección de respaldo real · solo lectura",systemImage:"lock.shield") }
                    NavigationLink {
                        N1nInactivePreparationView()
                    } label: { Label("Preparar respaldo cifrado · inactivo",systemImage:"lock.doc") }
                    NavigationLink {
                        N2NativeHistoryView()
                    } label: { Label("Personal e historial N2 · ficticio",systemImage:"person.text.rectangle") }
                    NavigationLink {
                        N2NativeActivationView()
                    } label: { Label("Importación única a bóveda N2",systemImage:"lock.shield") }
                    NavigationLink {
                        N2NativeHistoryView(useProtectedVault:true)
                    } label: { Label("Historial cifrado N2 · lectura",systemImage:"doc.text.magnifyingglass") }
                    NavigationLink {
                        N2NativeWorkerEditorView()
                    } label: { Label("Registrar trabajador N2",systemImage:"person.badge.plus") }
                    NavigationLink {
                        N2NativeClinicalFormView()
                    } label: { Label("Nueva atención clínica N2",systemImage:"cross.case.fill") }
                    NavigationLink {
                        N1sDemoExportView()
                    } label: { Label("Exportar dos Excel ficticios",systemImage:"tablecells") }
                    NavigationLink {
                        NativeStorageLabView().navigationTitle("Laboratorio")
                    } label: { Label("Laboratorio N1 aislado",systemImage:"externaldrive") }
                }
                Section("Seguridad") {
                    Text("N1j cifra las simulaciones ficticias en un almacén independiente y protege las revisiones. La build 222 permanece intacta.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Herramientas")
        }
        .tabItem { Label("Más",systemImage:"square.grid.2x2") }
        .tag(4)
    }

    @MainActor
    private func loadDemo() async {
        guard !demoReady && !restoring else { return }
        restoring = true
        defer { restoring = false }
        do {
            if let previous = try await N1iDemoDraftIOSVault.shared.loadWithRevision() {
                demoClock = N1jRevisionClock(recoveredRevision:previous.revision)
                clinic = previous.clinic
                demoStorageMessage = "Simulación cifrada recuperada · revisión \(previous.revision)."
            } else {
                demoClock = N1jRevisionClock()
                demoStorageMessage = "Almacén ficticio disponible: guardado cifrado por revisión."
            }
            demoReady = true
        } catch {
            demoReady = false
            demoStorageMessage = "Error de verificación del almacén ficticio. Edición bloqueada."
        }
    }

    private func scheduleDemoWrite(immediately: Bool = false) {
        guard demoReady else { return }
        let revision:Int64
        do { revision = try demoClock.capture() }
        catch {
            demoReady = false
            demoStorageMessage = "Se agotaron las revisiones de prueba. Edición bloqueada."
            return
        }
        let snapshot = clinic
        writeTask?.cancel()
        writeTask = Task {
            if !immediately {
                do { try await Task.sleep(nanoseconds:650_000_000) }
                catch { return }
            }
            guard !Task.isCancelled else { return }
            do {
                try await N1iDemoDraftIOSVault.shared.save(snapshot,revision:revision)
                if demoClock.isLatest(revision) {
                    demoStorageMessage = "Borrador ficticio cifrado · revisión \(revision) confirmada."
                }
            } catch N1iEncryptedDemoDraftVault.Failure.staleRevision {
                if demoClock.isLatest(revision) {
                    demoReady = false
                    demoStorageMessage = "Existe una revisión cifrada más nueva. Edición bloqueada."
                }
            } catch {
                if demoClock.isLatest(revision) {
                    demoReady = false
                    demoStorageMessage = "Falló el guardado cifrado de prueba. Edición bloqueada."
                }
            }
        }
    }
}

private struct StatusCard: View {
    let icon: String
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(danperRed)
                .frame(width: 34)
            VStack(alignment: .leading, spacing: 5) {
                Text(title).font(.headline)
                Text(detail).font(.subheadline).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .secondarySystemGroupedBackground),
                    in: RoundedRectangle(cornerRadius: 16))
    }
}

private struct FEFOSandboxView: View {
    @State private var quantity: Double = 5
    @State private var unit = "UND"

    private var plan: FEFOPlan {
        if unit == "UND" {
            return FEFOPreview.plan(lots: [
                NativeStockLot(id: "A-01", code: "E-22", name: "EJEMPLO",
                    expires: "2026-12-01", catalogUnit: "UND", container: "unidad",
                    unitsPerContainer: 1, sealedContainers: 0, looseUnits: 2, openedRemaining: 0),
                NativeStockLot(id: "A-02", code: "E-22", name: "EJEMPLO",
                    expires: "2027-12-01", catalogUnit: "UND", container: "unidad",
                    unitsPerContainer: 1, sealedContainers: 0, looseUnits: 10, openedRemaining: 0)
            ], kardexCode: "E-22", clinicalUnit: "UND",
               physicalQuantity: quantity, atLocalDate: "2026-10-16")
        }
        return FEFOPreview.plan(lots: [
            NativeStockLot(id: "CAJA-01", code: "E-57", name: "CAJA FICTICIA",
                expires: "2027-12-01", catalogUnit: "CJA", container: "caja",
                unitsPerContainer: 20, sealedContainers: 1, looseUnits: 0, openedRemaining: 0)
        ], kardexCode: "E-57", clinicalUnit: "CJA",
           physicalQuantity: quantity, atLocalDate: "2026-10-16")
    }

    var body: some View {
        Form {
            Section {
                Label("Simulación FEFO en memoria", systemImage: "shippingbox")
                    .foregroundStyle(danperRed)
                Text("Los lotes son ficticios. No se modifica el Kardex existente ni se guardan datos.")
                    .font(.footnote).foregroundStyle(.secondary)
                Picker("Tipo", selection: $unit) {
                    Text("Unidades").tag("UND")
                    Text("Caja").tag("CJA")
                }
                .onChange(of: unit) { _, _ in quantity = unit == "UND" ? 5 : 1 }
                Stepper("Consumo físico: \(Int(quantity))",
                        value: $quantity, in: 1...10, step: 1)
            }
            Section("Plan de salida") {
                if plan.isReady {
                    ForEach(Array(plan.issues.enumerated()), id: \.offset) { _, issue in
                        LabeledContent(issue.lotID, value: "\(issue.physicalAmount.formatted()) usados · R = \(issue.excelR.formatted())")
                    }
                    LabeledContent("R total del Indicador", value: plan.totalR.formatted())
                    Label("Solo cálculo: sin descuento real", systemImage: "checkmark.circle")
                        .foregroundStyle(.green)
                } else {
                    Text(plan.pendingReason ?? "Pendiente")
                        .foregroundStyle(.orange)
                }
            }
        }
    }
}
