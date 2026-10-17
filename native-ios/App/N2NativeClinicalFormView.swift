import Foundation
import SwiftUI
import DanperCore

/// Native N2 editor uses only an explicitly activated, isolated clinical
/// vault. Nothing reads the build222 installation or N1g demo drafts.
struct N2NativeClinicalFormView:View {
    private let brand=Color(red:0.88,green:0.09,blue:0.16)
    private let categories=[
        "ACCIDENTE COMUN","ACCIDENTE DE TRABAJO","ENFERMEDAD",
        "TOMA DE PRESIÓN ARTERIAL","MATERNIDAD","OTROS"
    ]
    private let systems=[
        "CEFALEA","CIRCULATORIO","DIGESTIVO","ENDOCRINOLOGO",
        "ENFERMEDADES CRONICAS","GENITAL Y REPRODUCTIVO","NEUROLOGICO",
        "OSTEOMUSCULAR","PIEL Y ANEXOS","RESPIRATORIO","SENSORIAL",
        "URINARIO/RENAL","OTROS"
    ]
    private let procedures=[
        "OBSERVACION","TRATAMIENTO ORAL","INYECTABLE","CURACION DE HERIDA",
        "APLICACION DE CREMA","LAVADO OCULAR","CONTROL",
        "RETIRO DE PUNTOS DE SUTURA","SUTURAS","TOMA DE PETAR"
    ]
    @State private var context:N2FormContext?
    @State private var form=N2NativeFormDraft()
    @State private var step=0
    @State private var busy=false
    @State private var saved=false
    @State private var fault=false
    @State private var status="Abriendo bóveda cifrada N2…"
    @State private var chooseWorker=false
    @State private var chooseProduct=false
    @State private var search=""
    @State private var allergyStatus="unknown"
    @State private var allergySubstances=""
    @State private var editingAllergy=false
    @State private var autosaveTask:Task<Void,Never>?
    @State private var lastAutosaveTimestamp:Int64=0
    @Environment(\.scenePhase) private var scenePhase

    private var now:Int64 {Int64(Date().timeIntervalSince1970*1000)}
    private func limaClock()->(String,String) {
        let formatter=DateFormatter()
        formatter.timeZone=TimeZone(identifier:"America/Lima")
        formatter.dateFormat="yyyy-MM-dd"
        let date=formatter.string(from:Date())
        formatter.dateFormat="HH:mm"
        return(date,formatter.string(from:Date()))
    }
    private var currentWorker:N2FormWorker? {
        context?.workers.first(where:{$0.dni==form.dni})
    }
    var body:some View {
        Group {
            if let context {
                Form {
                    Section {
                        Label("BÓVEDA N2 · DATOS CLÍNICOS LOCALES",
                              systemImage:"lock.shield.fill")
                            .foregroundStyle(brand)
                        Text(status).font(.footnote)
                            .foregroundStyle(fault ? Color.red : Color.secondary)
                    }
                    if saved {
                        Section {
                            Label("Atención guardada y verificada",
                                  systemImage:"checkmark.shield.fill")
                                .foregroundStyle(.green)
                            Button("Registrar otra atención") {
                                startAnother()
                            }
                        }
                    } else {
                        stepHeading
                        if step==0 {workerSection(context)}
                        if step==1 {clinicalSection()}
                        if step==2 {treatmentSection(context)}
                        if step==3 {reviewSection(context)}
                        actions(context)
                    }
                }
                .navigationTitle("Atención N2")
                .sheet(isPresented:$chooseWorker) {
                    NavigationStack {
                        List {
                            ForEach(context.workers.filter{w in
                                search.isEmpty || w.dni.localizedStandardContains(search) ||
                                w.name.localizedStandardContains(search)
                            }) {w in
                                Button {
                                    form.dni=w.dni
                                    search=""
                                    chooseWorker=false
                                } label:{
                                    VStack(alignment:.leading) {
                                        Text(w.name).foregroundStyle(.primary)
                                        Text(w.dni+" · "+w.area)
                                            .font(.caption).foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                        .searchable(text:$search,prompt:"DNI o nombres")
                        .navigationTitle("Seleccionar trabajador")
                        .toolbar{
                            ToolbarItem(placement:.topBarTrailing) {
                                Button("Cerrar"){chooseWorker=false}
                            }
                        }
                    }
                }
                .sheet(isPresented:$chooseProduct) {
                    NavigationStack {
                        List {
                            ForEach(context.products.clinicalMatches(search).prefix(150)) {p in
                                Button {
                                    form.items.append(N2FormMedication(code:p.code))
                                    chooseProduct=false
                                    search=""
                                } label: {
                                    VStack(alignment:.leading,spacing:3) {
                                        Text(p.name).foregroundStyle(.primary)
                                        Text(p.code+" · "+p.unit)
                                            .font(.caption).foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                        .searchable(text:$search,prompt:"Código o nombre del material")
                        .navigationTitle("Medicamentos e insumos")
                        .toolbar{
                            ToolbarItem(placement:.topBarTrailing) {
                                Button("Cerrar"){chooseProduct=false}
                            }
                        }
                    }
                }
                .onChange(of:form) {_,_ in scheduleDraft() }
                .onChange(of:scenePhase) {_,phase in
                    if phase != .active {scheduleDraft(immediate:true)}
                }
                .onDisappear {
                    scheduleDraft(immediate:true)
                }
            } else {
                ContentUnavailableView(
                    fault ? "Bóveda no disponible" : "Verificando historia clínica",
                    systemImage:"lock.shield",
                    description:Text(status))
                .task {await load()}
            }
        }
        .tint(brand)
    }

    private var stepHeading:some View {
        Section {
            HStack {
                Text(["1 · Trabajador y alergias","2 · Evaluación",
                      "3 · Procedimientos y consumos","4 · Confirmar atención"][step])
                    .font(.headline)
                Spacer()
                Text("\(step+1)/4").font(.caption).foregroundStyle(.secondary)
            }
        }
    }
    private func workerSection(_ context:N2FormContext)->some View {
        Section("Identificación") {
            Button {
                chooseWorker=true
            } label: {
                HStack {
                    Label(currentWorker?.name ?? "Buscar trabajador",systemImage:"person.crop.rectangle")
                    Spacer()
                    Image(systemName:"magnifyingglass")
                }
            }
            if let worker=currentWorker {
                LabeledContent("DNI",value:worker.dni)
                LabeledContent("Área",value:worker.area)
                LabeledContent("Sede",value:worker.site)
                Text("Alergias revisadas antes de registrar medicamentos.")
                    .font(.footnote).foregroundStyle(.secondary)
                Picker("Estado de alergias",selection:$allergyStatus) {
                    Text("No evaluado").tag("unknown")
                    Text("Niega alergias conocidas").tag("none")
                    Text("Alergias reportadas").tag("known")
                }
                if allergyStatus=="known" {
                    TextField("Sustancias reportadas",text:$allergySubstances,
                              axis:.vertical).lineLimit(2...5)
                }
                Button(editingAllergy ? "Verificando..." : "Confirmar revisión de alergias") {
                    Task {await recordAllergy(worker.dni)}
                }
                .disabled(editingAllergy || allergyStatus=="known" &&
                          allergySubstances.trimmingCharacters(in:.whitespaces).isEmpty)
            }
        }
    }
    private func clinicalSection()->some View {
        Section("Datos de la atención") {
            TextField("Fecha AAAA-MM-DD",text:$form.date)
                .keyboardType(.numbersAndPunctuation)
            TextField("Hora HH:mm",text:$form.time)
                .keyboardType(.numbersAndPunctuation)
            Picker("Tipo de atención",selection:$form.category) {
                Text("Seleccionar").tag("")
                ForEach(categories,id:\.self){Text($0).tag($0)}
            }
            Picker("Sistema afectado",selection:$form.system) {
                Text("Seleccionar").tag("")
                ForEach(systems,id:\.self){Text($0).tag($0)}
            }
            TextField("Segmento anatómico (si corresponde)",text:$form.segment)
            TextField("Diagnóstico presuntivo",text:$form.diagnosis,axis:.vertical)
                .lineLimit(2...5)
            Picker("Permiso",selection:$form.permission) {
                Text("No").tag("NO")
                Text("Sí").tag("SI")
            }
            if form.permission=="SI" {
                TextField("Hora del permiso HH:mm",text:$form.permissionTime)
            }
        }
    }
    private func treatmentSection(_ context:N2FormContext)->some View {
        Section("Procedimientos") {
            Picker("Procedimiento principal",selection:Binding(
                get:{form.procedures.first ?? "OBSERVACION"},
                set:{form.procedures=[$0]}
            )) {
                ForEach(procedures,id:\.self){Text($0).tag($0)}
            }
            if form.procedures.contains(where:{
                $0.contains("HERIDA") || $0=="SUTURAS"
            }) {
                Toggle("Foto enviada (SI/NO)",isOn:$form.photoSent)
            }else {
                Text("ENVÍO FOTO = NO para atenciones sin lesión o curación.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            Toggle("Se colocó banda o curita azul",isOn:$form.blueBandage)
            if form.blueBandage {
                Toggle("Se devolvió la banda o curita",isOn:$form.returned)
            }
        }
    }
    private func medicationName(_ code:String,_ context:N2FormContext)->String {
        context.products.clinical.first(where:{$0.code==code})?.name ?? code
    }
    @ViewBuilder
    private func medicationFields(_ context:N2FormContext)->some View {
        ForEach($form.items) { $med in
            Section {
                HStack {
                    VStack(alignment:.leading,spacing:3) {
                        Text(medicationName(med.code,context)).font(.headline)
                        Text(med.code).font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button(role:.destructive) {
                        form.items.removeAll{$0.id==med.id}
                    } label: {Image(systemName:"trash")}
                }
                TextField("Cantidad clínica",value:$med.quantity,format:.number)
                    .keyboardType(.numberPad)
                Picker("Procedimiento del producto",selection:$med.procedure) {
                    ForEach(procedures,id:\.self){Text($0).tag($0)}
                }
                let matches=context.options(for:med.code,at:form.date)
                Picker("Lote físico FEFO",selection:$med.selectedLotID) {
                    Text("Pendiente / automático si es unidad").tag("")
                    ForEach(matches) {lot in
                        Text(lot.name+" · "+lot.id+" · "+lot.expires)
                            .tag(lot.id)
                    }
                }
                if !med.selectedLotID.isEmpty {
                    let selected=matches.first{$0.id==med.selectedLotID}
                    TextField("Unidades físicas usadas (mL, UND…)",
                              value:$med.physicalQuantity,format:.number)
                        .keyboardType(.decimalPad)
                    if selected?.needsOpening==true {
                        Toggle("Autorizo abrir un frasco o caja nuevo",
                               isOn:$med.approveOpening)
                    }
                    Text("El sistema recalcula el reparto FEFO al confirmar. No inventa existencias ni convierte el tamaño del envase en dosis.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        Section {
            Button {
                chooseProduct=true
            } label: {
                Label("Agregar medicamento o insumo",systemImage:"plus")
            }
            Text("La cantidad clínica se guarda aunque no exista salida física verificable; el Kardex nunca convierte un pendiente en cero.")
                .font(.footnote).foregroundStyle(.secondary)
        }
    }
    private func reviewSection(_ context:N2FormContext)->some View {
        Section("Revisión antes de guardar") {
            LabeledContent("Trabajador",value:currentWorker?.name ?? "Pendiente")
            LabeledContent("Fecha",value:form.date+" "+form.time)
            LabeledContent("Diagnóstico",value:form.diagnosis)
            LabeledContent("Medicamentos",value:String(form.items.count))
            LabeledContent("Procedimientos",value:form.procedures.joined(separator:", "))
            Text("Al guardar, se realizará una transacción cifrada que incluye la atención y todos sus descuentos físicos válidos. Un envase nuevo exige la autorización anterior.")
                .font(.footnote).foregroundStyle(.secondary)
        }
    }
    private func actions(_ context:N2FormContext)->some View {
        Section {
            HStack {
                if step>0 {
                    Button("Anterior") {step-=1}
                        .buttonStyle(.bordered)
                }
                Spacer()
                if step<3 {
                    Button("Siguiente") {step+=1}
                        .buttonStyle(.borderedProminent)
                }else{
                    Button(busy ? "Confirmando…" : "Guardar atención") {
                        Task {await confirm()}
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(busy)
                }
            }
            Button("Guardar borrador ahora") {
                scheduleDraft(immediate:true)
            }
            .disabled(busy)
        }
    }

    @MainActor
    private func load() async {
        do {
            let source=try await N2ProtectedClinicalIOSVault.shared.clinicalFormContext()
            context=source
            let (date,time)=limaClock()
            form.date=date
            form.time=time
            status="Bóveda cifrada disponible · revisión \(source.revision)"
        }catch{
            fault=true
            status="No hay una fuente clínica N2 verificada o su integridad falló. No se guardó ningún dato."
        }
    }

    @MainActor
    private func recordAllergy(_ dni:String) async {
        editingAllergy=true
        defer{editingAllergy=false}
        do{
            let normalized=allergyStatus=="known" ? allergySubstances : ""
            let fresh=try await N2ProtectedClinicalIOSVault.shared.clinicalFormContext()
            let updated=try await N2ProtectedClinicalIOSVault.shared
                .reviewAllergies(dni:dni,status:allergyStatus,
                    substances:normalized,at:now,
                    expectedRevision:fresh.revision)
            context=try await N2ProtectedClinicalIOSVault.shared.clinicalFormContext()
            status="Alergias revisadas en revisión \(updated.revision)."
            fault=false
        }catch{
            status="No se confirmó el registro de alergias. Verifica el estado de la bóveda."
            fault=true
        }
    }
    private func scheduleDraft(immediate:Bool=false) {
        guard let context,!busy,!saved,!fault else{return}
        autosaveTask?.cancel()
        let version=form
        autosaveTask=Task { @MainActor in
            if !immediate {
                do {try await Task.sleep(for:.milliseconds(650))}
                catch{return}
            }
            guard !Task.isCancelled else{return}
            do{
                let latest=try await N2ProtectedClinicalIOSVault.shared.clinicalFormContext()
                let patch=try version.makeDraftPatch(context:context)
                let timestamp=max(Int64(Date().timeIntervalSince1970*1000),
                                  lastAutosaveTimestamp+1)
                let result=try await N2ProtectedClinicalIOSVault.shared.saveDraft(
                    id:version.id,changes:patch,at:timestamp,
                    expectedRevision:latest.revision)
                lastAutosaveTimestamp=timestamp
                status="Borrador cifrado · revisión \(result.revision)."
            }catch{
                if !Task.isCancelled && !saved {
                    fault=true
                    status="No se pudo guardar el borrador. Edición bloqueada hasta verificar el almacenamiento."
                }
            }
        }
    }
    @MainActor
    private func confirm() async {
        guard let context,!busy,!saved,!fault else{return}
        autosaveTask?.cancel()
        busy=true
        defer{busy=false}
        do {
            let fresh=try await N2ProtectedClinicalIOSVault.shared.clinicalFormContext()
            let raw=try form.makeSavedVisit(context:fresh)
            let outcome=try await N2ProtectedClinicalIOSVault.shared.saveAttention(
                raw,at:now,expectedRevision:fresh.revision)
            saved=true
            self.context=try await N2ProtectedClinicalIOSVault.shared.clinicalFormContext()
            status="Atención confirmada y cifrada en revisión \(outcome.revision). Comprobar consumos pendientes desde el historial."
        }catch {
            status="No se pudo confirmar la atención. La operación fue rechazada y el stock no se debe descontar parcialmente."
            fault=true
        }
    }
    private func startAnother() {
        saved=false
        fault=false
        form=N2NativeFormDraft()
        let (date,time)=limaClock()
        form.date=date
        form.time=time
        step=0
        status="Nuevo registro clínico N2."
    }
}
