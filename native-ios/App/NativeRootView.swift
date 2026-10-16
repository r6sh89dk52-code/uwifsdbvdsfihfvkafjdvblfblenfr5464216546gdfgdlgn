import SwiftUI
import DanperCore

private let danperRed = Color(red: 0.88, green: 0.09, blue: 0.16)

struct NativeRootView: View {
    var body: some View {
        TabView {
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
                                Text("Esta instalación es independiente de la build 222. No importa ni altera registros automáticamente.")
                                Text("Para utilizar datos clínicos reales faltan: restauración transaccional, validación de inventario y exportadores Excel nativos.")
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        } label: {
                            Text("MIGRACIÓN SEGURA").foregroundStyle(danperRed)
                        }
                        StatusCard(icon: "person.text.rectangle", title: "Trabajadores y atenciones",
                                   detail: "Modelo heredado inspeccionable. Edición desactivada hasta validar recuperación.")
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

            NavigationStack {
                AttentionPrototypeView()
                    .navigationTitle("Atención")
            }
            .tabItem { Label("Atención", systemImage: "cross.case") }

            NavigationStack {
                FEFOSandboxView()
                    .navigationTitle("FEFO")
            }
            .tabItem { Label("FEFO", systemImage: "shippingbox") }

            NavigationStack {
                BackupPreviewView()
                    .navigationTitle("Respaldo")
            }
            .tabItem { Label("Respaldo", systemImage: "lock.shield") }

            NavigationStack {
                NativeStorageLabView()
                    .navigationTitle("Almacén N1")
            }
            .tabItem { Label("Laboratorio", systemImage: "externaldrive") }
        }
        .tint(danperRed)
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

private struct AttentionPrototypeView: View {
    @State private var dni = ""
    @State private var reason = ""
    @State private var diagnostic = ""
    @State private var clinicalQuantity = 1
    @State private var preview = false

    var body: some View {
        Form {
            Section {
                Label("Formulario SwiftUI interactivo · solo simulación",
                      systemImage: "info.circle").foregroundStyle(danperRed)
                Text("No guarda personas, atenciones, tratamientos ni movimientos físicos. La app operativa sigue siendo la build 222.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            Section("Trabajador · datos ficticios") {
                TextField("DNI ficticio de 8 dígitos", text: $dni)
                    .keyboardType(.numberPad)
                    .onChange(of: dni) { _, new in
                        dni = String(new.filter(\.isNumber).prefix(8))
                    }
            }
            Section("Evaluación") {
                TextField("Motivo", text: $reason)
                TextField("Diagnóstico presuntivo", text: $diagnostic, axis: .vertical)
                    .lineLimit(2...4)
                Stepper("Cantidad clínica de prueba: \(clinicalQuantity)",
                        value: $clinicalQuantity, in: 1...100)
            }
            Section {
                Button("Revisar simulación") { preview = true }
                    .disabled(dni.count != 8 || reason.isEmpty || diagnostic.isEmpty)
                if preview {
                    Text("La atención NO fue guardada. En la versión final se aplicará FEFO al confirmar y luego se persistirá una sola transacción cifrada.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
        }
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
