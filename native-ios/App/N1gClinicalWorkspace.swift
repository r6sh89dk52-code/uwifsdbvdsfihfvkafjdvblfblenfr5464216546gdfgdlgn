import SwiftUI
import DanperCore

/// All inputs are fixed fictitious choices. Nothing here can import, write
/// clinical data, open the existing Keychain vault, or dispense medicines.
private enum N1gUI {
    static let red = Color(red: 0.88, green: 0.09, blue: 0.16)
    static var now: Int64 { Int64(Date().timeIntervalSince1970 * 1000) }
    static func notice(_ error: Error) -> String {
        guard let e = error as? N1gError else { return "No se pudo realizar esta simulación." }
        switch e {
        case .incompleteWorker: return "Selecciona un trabajador ficticio."
        case .incompleteEvaluation: return "Completa categoría, diagnóstico y procedimiento."
        case .allergyNotReviewed: return "Revisa primero el estado de alergias."
        case .correctionNeedsAudit: return "Este borrador de corrección no puede reemplazar una atención guardada sin una auditoría."
        case .demoRosterFull: return "El padrón ficticio está completo."
        case .workerNotFound: return "El trabajador no existe en el padrón ficticio."
        case .invalidQuantity: return "Elige una cantidad ficticia de 1 a 20."
        default: return "Acción no disponible en esta versión de prueba."
        }
    }
}
struct N1gSafetyHeader: View {
    var body: some View {
        Label {
            VStack(alignment: .leading, spacing: 3) {
                Text("SIMULACIÓN NATIVA · SIN DATOS REALES")
                    .font(.caption.weight(.bold))
                Text("Los cambios viven solo en la memoria de esta sesión. No se guardan historias, stock ni archivos.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        } icon: {
            Image(systemName: "checkmark.shield.fill").foregroundStyle(N1gUI.red)
        }
        .padding(.vertical, 5)
        .accessibilityElement(children: .combine)
    }
}
struct N1gRosterScreen: View {
    @Binding var clinic: N1gClinic
    @Binding var selectedTab: Int
    @State private var search = ""
    @State private var message = ""

    var body: some View {
        List {
            Section { N1gSafetyHeader() }
            Section {
                Button {
                    do {
                        let w = try clinic.addFictionalWorker()
                        message = "Trabajador ficticio añadido: \(w.id)"
                    } catch { message = N1gUI.notice(error) }
                } label: { Label("Añadir persona ficticia", systemImage: "person.badge.plus") }
                .foregroundStyle(N1gUI.red)
                Text("El padrón de prueba solo contiene nombres y DNI inventados; no permite importar empleados.")
                    .font(.footnote).foregroundStyle(.secondary)
                if !message.isEmpty { Text(message).font(.footnote) }
            } header: { Text("Padrón local de demostración") }
            Section("Personas ficticias · \(clinic.workers.count)") {
                ForEach(clinic.search(search)) { worker in
                    VStack(alignment: .leading, spacing: 7) {
                        HStack(alignment: .firstTextBaseline) {
                            Text(worker.name).font(.headline)
                            Spacer(minLength: 4)
                            Text(worker.id).font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                        }
                        Label(worker.site, systemImage: "building.2").font(.caption)
                        Text(worker.area).font(.footnote).foregroundStyle(.secondary)
                        Button {
                            let draftID = clinic.newDraft(at: N1gUI.now)
                            do {
                                try clinic.edit(draftID, .worker(worker.id), at: N1gUI.now)
                                selectedTab = 2
                            } catch { message = N1gUI.notice(error) }
                        } label: { Label("Atender en simulación", systemImage: "arrow.right.circle") }
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(N1gUI.red)
                    }
                    .padding(.vertical, 6)
                }
            }
        }
        .searchable(text: $search, prompt: "Nombre, DNI ficticio o sede")
        .navigationTitle("Personal")
    }
}

struct N1gAttentionScreen: View {
    @Binding var clinic: N1gClinic
    @State private var step = 0
    @State private var message = ""

    private enum Field { case worker, category, diagnosis, procedure, product, result }
    private func binding(_ key: Field, id: UUID) -> Binding<String> {
        Binding(
            get: {
                guard let draft = clinic.activeDraft, draft.id == id else { return "" }
                switch key {
                case .worker: return draft.workerID ?? ""
                case .category: return draft.category
                case .diagnosis: return draft.diagnosis
                case .procedure: return draft.procedure
                case .product: return draft.product
                case .result: return draft.result
                }
            },
            set: { selected in
                let mutation: N1gChange
                switch key {
                case .worker:
                    guard !selected.isEmpty else { return }
                    mutation = .worker(selected)
                case .category: mutation = .category(selected)
                case .diagnosis: mutation = .diagnosis(selected)
                case .procedure: mutation = .procedure(selected)
                case .product: mutation = .product(selected)
                case .result: mutation = .result(selected)
                }
                do { try clinic.edit(id, mutation, at: N1gUI.now); message = "" }
                catch { message = N1gUI.notice(error) }
            }
        )
    }
    private func allergyBinding(_ workerID: String) -> Binding<String> {
        Binding(
            get: { clinic.allergies[workerID]?.rawValue ?? "" },
            set: { selected in
                guard let status = N1gAllergy(rawValue: selected) else { return }
                do { try clinic.reviewAllergy(status, for: workerID); message = "" }
                catch { message = N1gUI.notice(error) }
            }
        )
    }

    var body: some View {
        Group {
            if let active = clinic.activeDraft {
                Form {
                    Section { N1gSafetyHeader() }
                    if active.originID != nil {
                        Section {
                            Label("Borrador de corrección: puedes revisar los campos, pero no sustituir una atención confirmada sin auditoría.", systemImage: "exclamationmark.triangle")
                                .foregroundStyle(.orange)
                                .font(.footnote)
                        }
                    }
                    Section {
                        Picker("Etapa", selection: $step) {
                            Text("Persona").tag(0)
                            Text("Evaluar").tag(1)
                            Text("Tratar").tag(2)
                            Text("Cierre").tag(3)
                        }
                        .pickerStyle(.segmented)
                        Text("Paso \(step+1) de 4")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    if step == 0 {
                        Section("1 · Trabajador") {
                            Picker("Persona ficticia", selection: binding(.worker, id: active.id)) {
                                Text("Seleccionar").tag("")
                                ForEach(clinic.workers) { w in Text(w.name).tag(w.id) }
                            }
                            if let person = clinic.worker(active.workerID) {
                                LabeledContent("DNI ficticio", value: person.id)
                                LabeledContent("Sede", value: person.site)
                                LabeledContent("Área", value: person.area)
                            }
                            Text("Usa la pestaña Personal para buscar personas ficticias o agregar otra.")
                                .font(.footnote).foregroundStyle(.secondary)
                        }
                    }
                    if step == 1 {
                        Section("2 · Evaluación clínica ficticia") {
                            Picker("Categoría", selection: binding(.category,id:active.id)) {
                                Text("Seleccionar").tag("")
                                ForEach(N1gClinic.categories,id:\.self) { Text($0).tag($0) }
                            }
                            Picker("Diagnóstico de prueba", selection: binding(.diagnosis,id:active.id)) {
                                Text("Seleccionar").tag("")
                                ForEach(N1gClinic.diagnoses,id:\.self) { Text($0).tag($0) }
                            }
                        }
                        Section("Alergias · revisar antes de registrar") {
                            if let wid = active.workerID {
                                Picker("Estado", selection: allergyBinding(wid)) {
                                    Text("Sin revisar").tag("")
                                    Text("Desconocido").tag(N1gAllergy.unknown.rawValue)
                                    Text("Niega alergias conocidas").tag(N1gAllergy.none.rawValue)
                                    Text("Conocidas · sustancia ficticia").tag(N1gAllergy.known.rawValue)
                                }
                                if clinic.allergies[wid] == .known {
                                    Text("Sustancia simulada: SUSTANCIA FICTICIA X")
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                            } else {
                                Text("Selecciona antes un trabajador ficticio.")
                                    .foregroundStyle(.secondary)
                            }
                            Text("La opción «desconocido» NO significa que el trabajador niegue alergias.")
                                .font(.footnote).foregroundStyle(.secondary)
                        }
                    }
                    if step == 2 {
                        Section("3 · Tratamiento (sin Kardex)") {
                            Picker("Procedimiento", selection: binding(.procedure,id:active.id)) {
                                Text("Seleccionar").tag("")
                                ForEach(N1gClinic.procedures,id:\.self) { Text($0).tag($0) }
                            }
                            Picker("Producto ficticio opcional", selection: binding(.product,id:active.id)) {
                                ForEach(N1gClinic.products,id:\.self) {
                                    Text($0.isEmpty ? "Sin medicamento" : $0).tag($0)
                                }
                            }
                            if !active.product.isEmpty {
                                Stepper("Cantidad simulada: \(active.quantity)", value:
                                    Binding(get: { clinic.activeDraft?.quantity ?? 1 },
                                            set: { value in try? clinic.edit(active.id, .quantity(value), at: N1gUI.now) }),
                                        in: 1...20)
                            }
                            Text("Los productos son inventados: ningún movimiento físico ni apertura de lote se ejecuta.")
                                .font(.footnote).foregroundStyle(.secondary)
                        }
                    }
                    if step == 3 {
                        Section("4 · Resultado de demostración") {
                            Picker("Destino", selection: binding(.result,id:active.id)) {
                                ForEach(N1gClinic.results,id:\.self) { Text($0).tag($0) }
                            }
                            LabeledContent("Trabajador", value: clinic.worker(active.workerID)?.name ?? "Pendiente")
                            LabeledContent("Categoría", value: active.category.isEmpty ? "Pendiente" : active.category)
                            LabeledContent("Diagnóstico", value: active.diagnosis.isEmpty ? "Pendiente" : active.diagnosis)
                            LabeledContent("Alergias", value: active.workerID.flatMap { clinic.allergies[$0]?.rawValue } ?? "Sin revisar")
                            LabeledContent("Procedimiento", value: active.procedure.isEmpty ? "Pendiente" : active.procedure)
                            if !active.product.isEmpty {
                                LabeledContent("Producto", value: active.product)
                                LabeledContent("Cantidad simulada", value: "\(active.quantity)")
                            }
                        }
                        Section {
                            Button {
                                do {
                                    try clinic.saveDemo(active.id, at:N1gUI.now)
                                    message = "Simulación guardada solo en memoria. No se creó ninguna salida Kardex."
                                    step = 0
                                } catch { message = N1gUI.notice(error) }
                            } label: { Label("Guardar únicamente simulación", systemImage:"checkmark.seal") }
                                .disabled(active.originID != nil)
                            if active.originID != nil {
                                Text("La corrección permanece como borrador hasta implementar el flujo auditado.")
                                    .font(.footnote).foregroundStyle(.orange)
                            }
                        }
                    }
                    Section {
                        HStack {
                            if step > 0 {
                                Button("Anterior") { step -= 1 }
                            }
                            Spacer()
                            if step < 3 {
                                Button("Siguiente") { step += 1 }
                                    .buttonStyle(.borderedProminent)
                            }
                        }
                        Button {
                            clinic.closeDraft()
                            message = "Borrador conservado únicamente durante esta sesión."
                            step = 0
                        } label: { Label("Salir y conservar borrador en memoria", systemImage:"square.and.arrow.down") }
                    }
                    if !message.isEmpty { Section { Text(message).font(.footnote) } }
                }
            } else {
                ContentUnavailableView {
                    Label("Atención ficticia", systemImage:"cross.case")
                } description: {
                    Text("Formulario nativo de cuatro pasos. No permite introducir datos reales ni efectuar descuentos de stock.")
                } actions: {
                    Button {
                        _ = clinic.newDraft(at:N1gUI.now)
                        message = ""
                        step = 0
                    } label: { Label("Iniciar simulación", systemImage:"plus.circle.fill") }
                        .buttonStyle(.borderedProminent)
                        .tint(N1gUI.red)
                }
            }
        }
        .navigationTitle("Atención")
    }
}

struct N1gHistoryScreen: View {
    @Binding var clinic: N1gClinic
    @Binding var selectedTab: Int
    @State private var message = ""
    var body: some View {
        List {
            Section { N1gSafetyHeader() }
            Section("Borradores en memoria · \(clinic.drafts.count)") {
                if clinic.drafts.isEmpty {
                    Text("Sin borradores pendientes").foregroundStyle(.secondary)
                }
                ForEach(clinic.drafts) { draft in
                    VStack(alignment:.leading,spacing:8) {
                        Text(clinic.worker(draft.workerID)?.name ?? "Persona por seleccionar")
                            .font(.headline)
                        Text(draft.originID == nil ? "Borrador de atención" : "Corrección sin aplicar")
                            .font(.caption).foregroundStyle(.secondary)
                        HStack {
                            Button("Continuar") {
                                do { try clinic.openDraft(draft.id);selectedTab=2 }
                                catch { message = N1gUI.notice(error) }
                            }
                            .buttonStyle(.borderedProminent)
                            Button("Eliminar") {
                                do { try clinic.removeDraft(draft.id) }
                                catch { message = N1gUI.notice(error) }
                            }
                            .buttonStyle(.bordered)
                        }
                        .font(.subheadline)
                    }
                    .padding(.vertical,5)
                }
            }
            Section("Simulaciones guardadas · \(clinic.saved.count)") {
                if clinic.saved.isEmpty { Text("Todavía no hay atenciones simuladas").foregroundStyle(.secondary) }
                ForEach(clinic.saved) { saved in
                    VStack(alignment:.leading,spacing:6) {
                        Text(clinic.worker(saved.workerID)?.name ?? "Ficticio")
                            .font(.headline)
                        Text(saved.diagnosis).font(.subheadline)
                        Text("Solo memoria · Sin movimiento físico")
                            .font(.caption).foregroundStyle(.secondary)
                        Button("Crear borrador de corrección") {
                            do { _ = try clinic.correctionDraft(of:saved.id, at:N1gUI.now);selectedTab=2 }
                            catch { message = N1gUI.notice(error) }
                        }
                        .font(.footnote.weight(.semibold))
                    }
                    .padding(.vertical,5)
                }
            }
            if !message.isEmpty { Section { Text(message).font(.footnote) } }
        }
        .navigationTitle("Borradores")
    }
}
