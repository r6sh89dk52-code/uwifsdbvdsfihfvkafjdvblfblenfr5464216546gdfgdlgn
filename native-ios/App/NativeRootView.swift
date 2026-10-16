import SwiftUI
import DanperCore

private let danperRed = Color(red: 0.88, green: 0.09, blue: 0.16)

struct NativeRootView: View {
    @State private var clinic = N1gClinic()
    @State private var selectedTab = 0
    @State private var demoReady = false
    @State private var demoStorageMessage = "Abriendo almacenamiento cifrado de pruebas…"
    @State private var writeTask: Task<Void, Never>?
    @State private var demoClock = N1jRevisionClock()
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        HStack(spacing: 14) {
                            Image(systemName: "cross.case.fill")
                                .font(.title)
                                .foregroundStyle(danperRed)
                            VStack(alignment: .leading) {
                                Text("DANPER").font(.largeTitle.bold())
                                Text("Salud Móvil Nativa").font(.subheadline).foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 12)
                        GroupBox {
                            VStack(alignment: .leading, spacing: 9) {
                                Label("SwiftUI real, sin WebView", systemImage: "checkmark.seal.fill")
                                    .font(.headline)
                                Text("Esta instalación es independiente de la build 222. Solo los borradores FICTICIOS se guardan en un almacén cifrado separado.")
                                Text(demoStorageMessage)
                                    .font(.footnote)
                                    .foregroundStyle(demoReady ? .secondary : .orange)
                                Text("Para utilizar datos clínicos reales faltan: restauración transaccional, validación de inventario y exportadores Excel nativos.")
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        } label: {
                            Text("MIGRACIÓN SEGURA").foregroundStyle(danperRed)
                        }
                        NavigationLink {
                            BackupPreviewView()
                                .navigationTitle("Respaldo real · lectura")
                        } label: {
                            Label {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Comprobar respaldo real").font(.headline)
                                    Text("Se abre únicamente en tu iPhone, con contraseña; inspección sin restaurar datos ni alterar el Kardex.")
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                            } icon: {
                                Image(systemName: "lock.doc.fill")
                                    .font(.title3)
                                    .foregroundStyle(danperRed)
                            }
                            .padding(13)
                            .background(Color(uiColor: .secondarySystemGroupedBackground),
                                        in: RoundedRectangle(cornerRadius: 15))
                        }
                        .buttonStyle(.plain)
                        StatusCard(icon: "person.text.rectangle", title: "Trabajadores y atenciones",
                                   detail: "Registro SwiftUI en preparación. Las simulaciones están aisladas; los datos reales se comprueban mediante respaldo cifrado en modo lectura.")
                        StatusCard(icon: "pills", title: "FEFO nativo",
                                   detail: "Motor Swift independiente con pruebas de lotes, vencimientos y envases.")
                        StatusCard(icon: "doc.zipper", title: "Respaldo cifrado",
                                   detail: "Lectura local del formato .danperbackup; solo muestra totales.")
                        StatusCard(icon: "tablecells", title: "Indicador y Kardex",
                                   detail: "Pendientes de portar y contrastar contra el Excel oficial original.")
                    }
                    .padding()
                }
                .navigationTitle("Inicio")
            }
            .tabItem { Label("Inicio", systemImage: "house") }
            .tag(0)

            NavigationStack {
                N1gRosterScreen(clinic: $clinic, selectedTab: $selectedTab)
                    .disabled(!demoReady)
            }
            .tabItem { Label("Personal", systemImage: "person.2") }
            .tag(1)

            NavigationStack {
                N1gAttentionScreen(clinic: $clinic)
                    .disabled(!demoReady)
            }
            .tabItem { Label("Atención", systemImage: "cross.case") }
            .tag(2)

            NavigationStack {
                N1gHistoryScreen(clinic: $clinic, selectedTab: $selectedTab)
                    .disabled(!demoReady)
            }
            .tabItem { Label("Borradores", systemImage: "doc.text") }
            .tag(3)

            NavigationStack {
                List {
                    Section("Herramientas nativas") {
                        NavigationLink {
                            FEFOSandboxView().navigationTitle("FEFO")
                        } label: { Label("FEFO ficticio", systemImage: "shippingbox") }
                        NavigationLink {
                            BackupPreviewView().navigationTitle("Respaldo")
                        } label: { Label("Verificar respaldo · solo lectura", systemImage: "lock.shield") }
                        NavigationLink {
                            NativeStorageLabView().navigationTitle("Laboratorio")
                        } label: { Label("Laboratorio N1 aislado", systemImage: "externaldrive") }
                    }
                    Section("Seguridad") {
                        Text("N1i cifra borradores de simulación en un almacén independiente. No se admiten datos reales. La build 222 y sus registros no se modifican.")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                }
                .navigationTitle("Herramientas")
            }
            .tabItem { Label("Más", systemImage: "square.grid.2x2") }
            .tag(4)
        }
        .tint(danperRed)
        .task {
            guard !demoReady else { return }
            do {
                if let recovered = try await N1iDemoDraftIOSVault.shared.loadWithRevision() {
                    // The authenticated revision is the first value the UI uses,
                    // avoiding reset-to-zero and a stale overwrite after restart.
                    demoClock = N1jRevisionClock(recoveredRevision:recovered.revision)
                    clinic = recovered.clinic
                    demoStorageMessage = "Simulación cifrada recuperada (revisión \(recovered.revision))."
                } else {
                    demoClock = N1jRevisionClock()
                    demoStorageMessage = "Almacén ficticio disponible: guardado cifrado por revisión."
                }
                demoReady = true
            } catch {
                demoReady = false
                demoStorageMessage = "Error de verificación del almacén de prueba. Edición bloqueada para evitar sobrescribir datos."
            }
        }
        .onChange(of: clinic.visits) { _, _ in scheduleDemoWrite() }
        .onChange(of: clinic.workers) { _, _ in scheduleDemoWrite() }
        .onChange(of: clinic.allergies) { _, _ in scheduleDemoWrite() }
        .onChange(of: clinic.activeDraftID) { _, _ in scheduleDemoWrite() }
        .onChange(of: scenePhase) { _, next in
            if next != .active { scheduleDemoWrite(immediately: true) }
        }
    }

    private func scheduleDemoWrite(immediately: Bool = false) {
        guard demoReady else { return }
        // Capture clock and *value* synchronously. An older Task may already
        // be running despite cancellation; the persisted revision blocks it
        // from replacing a newer committed generation.
        let revision: Int64
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
                // Superseded background jobs must not show a success or
                // overwrite a fresh UI status. A *latest* stale revision means
                // another writer advanced the vault: stop rather than reset.
                if demoClock.isLatest(revision) {
                    demoReady = false
                    demoStorageMessage = "Existe una revisión cifrada más nueva. Edición bloqueada."
                }
            } catch {
                if demoClock.isLatest(revision) {
                    demoReady = false
                    demoStorageMessage = "Falló el guardado cifrado de prueba. Edición bloqueada; no cierres sin revisar."
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
