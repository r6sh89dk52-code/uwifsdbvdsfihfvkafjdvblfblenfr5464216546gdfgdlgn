import Foundation
import SwiftUI
import DanperCore

/// Native N2 editor uses only an explicitly activated, isolated clinical
/// vault. Nothing reads the build222 installation or N1g demo drafts.
struct N2NativeClinicalFormView:View {
    let requestedDraftID:String?
    init(requestedDraftID:String?=nil) {self.requestedDraftID=requestedDraftID}
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
    @State private var chooseDraft=false
    @State private var draftToDelete:String?
    @State private var drafts=[N2RecoverableDraft]()
    @State private var search=""
    @State private var allergyStatus="unknown"
    @State private var allergySubstances=""
    @State private var editingAllergy=false
    @State private var autosaveTask:Task<Void,Never>?
    @State private var lastAutosaveTimestamp:Int64=0
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    private let stepTitles=["Trabajador y alergias","Evaluación clínica",
                            "Procedimientos y consumos","Confirmar atención"]
    private var dateSelection:Binding<Date> {
        Binding(get:{
            let f=DateFormatter()
            f.locale=Locale(identifier:"en_US_POSIX")
            f.timeZone=TimeZone(identifier:"America/Lima")
            f.dateFormat="yyyy-MM-dd"
            return f.date(from:form.date) ?? Date()
        },set:{date in
            let f=DateFormatter()
            f.locale=Locale(identifier:"en_US_POSIX")
            f.timeZone=TimeZone(identifier:"America/Lima")
            f.dateFormat="yyyy-MM-dd"
            form.date=f.string(from:date)
        })
    }

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
                        DanperStatusBanner(
                            symbol:fault ? "exclamationmark.shield.fill" : "lock.shield.fill",
                            title:fault ? "Comprueba el almacenamiento" : "Registro clínico protegido",
                            detail:status)
                    }
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                    if !saved && !drafts.isEmpty {
                        Section("Registros pendientes") {
                            Button {
                                chooseDraft=true
                            } label: {
                                Label("Retomar borrador cifrado (\(drafts.count))",
                                      systemImage:"arrow.uturn.backward.doc")
                            }
                        }
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
                    }
                }
                .navigationTitle("Nueva atención")
                .navigationBarTitleDisplayMode(.inline)
                .danperFormChrome()
                .scrollDismissesKeyboard(.interactively)
                .safeAreaInset(edge:.bottom,spacing:0) {
                    if !saved {actions(context)}
                }
                .animation(DanperStyle.animation,value:step)
                .sensoryFeedback(.selection,trigger:step)
                .sensoryFeedback(.selection,trigger:form.procedures.count)
                .sensoryFeedback(.success,trigger:saved)
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
                .sheet(isPresented:$chooseDraft) {
                    NavigationStack {
                        List {
                            ForEach(drafts) { entry in
                                HStack {
                                    Button {
                                        resume(entry)
                                    } label: {
                                        VStack(alignment:.leading,spacing:3) {
                                            Text(entry.workerName.isEmpty ? "Registro sin trabajador" : entry.workerName)
                                                .foregroundStyle(.primary)
                                            Text(DanperDatePresentation.displayDateTime(entry.form.date,entry.form.time))
                                                .font(.caption).foregroundStyle(.secondary)
                                        }
                                    }
                                    Spacer()
                                    Button(role:.destructive) {
                                        draftToDelete=entry.id
                                    } label: {
                                        Image(systemName:"trash")
                                    }
                                    .disabled(busy)
                                }
                            }
                        }
                        .navigationTitle("Borradores cifrados")
                        .toolbar {
                            ToolbarItem(placement:.topBarTrailing) {
                                Button("Cerrar"){chooseDraft=false}
                            }
                        }
                        .confirmationDialog("¿Eliminar este borrador?",isPresented:Binding(
                            get:{draftToDelete != nil},
                            set:{if !$0 {draftToDelete=nil}}
                        ),titleVisibility:.visible) {
                            Button("Eliminar borrador",role:.destructive) {
                                if let id=draftToDelete {
                                    draftToDelete=nil
                                    Task {await deleteRecoveredDraft(id)}
                                }
                            }
                            Button("Cancelar",role:.cancel){draftToDelete=nil}
                        } message: {
                            Text("Esta acción no elimina atenciones ya guardadas.")
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
            DanperStepProgress(step:step,titles:stepTitles)
        }
        .listRowInsets(EdgeInsets())
        .listRowBackground(Color.clear)
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
            LabeledContent("Fecha",value:DanperDatePresentation.display(form.date))
            DatePicker("Cambiar fecha",selection:dateSelection,displayedComponents:.date)
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
            LazyVGrid(columns:dynamicTypeSize.isAccessibilitySize ?
                      [GridItem(.flexible())] :
                      [GridItem(.flexible(),spacing:10),GridItem(.flexible(),spacing:10)],
                      spacing:10) {
                ForEach(procedures,id:\.self){option in
                    let selected=form.procedures.contains(option)
                    Button {
                        if selected {
                            form.procedures.removeAll{$0==option}
                        }else {
                            form.procedures.append(option)
                        }
                    } label: {
                        HStack(spacing:8) {
                            Image(systemName:selected ? "checkmark.circle.fill" : "circle")
                                .font(.headline)
                                .foregroundStyle(selected ? DanperStyle.red : Color.secondary)
                            Text(option.capitalized(with:Locale(identifier:"es_PE")))
                                .font(.subheadline.weight(selected ? .semibold : .regular))
                                .foregroundStyle(.primary)
                                .multilineTextAlignment(.leading)
                            Spacer(minLength:0)
                        }
                        .padding(11)
                        .frame(maxWidth:.infinity,minHeight:56,alignment:.leading)
                        .background(selected ? DanperStyle.red.opacity(0.10) :
                                    DanperStyle.canvas,in:RoundedRectangle(cornerRadius:13))
                        .overlay(RoundedRectangle(cornerRadius:13)
                            .strokeBorder(selected ? DanperStyle.red.opacity(0.38) :
                                          Color.secondary.opacity(0.12),lineWidth:1))
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(selected ? .isSelected : [])
                }
            }
            .padding(.vertical,5)
            Text("Selecciona uno o varios procedimientos. Las entregas de medicamentos se registran por separado.")
                .font(.caption).foregroundStyle(.secondary)
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
                        Text(lot.name+" · "+lot.id+" · "+DanperDatePresentation.display(lot.expires))
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
            LabeledContent("Fecha",value:DanperDatePresentation.displayDateTime(form.date,form.time))
            LabeledContent("Diagnóstico",value:form.diagnosis)
            LabeledContent("Medicamentos",value:String(form.items.count))
            LabeledContent("Procedimientos",value:form.procedures.joined(separator:", "))
            Text("Al guardar, se realizará una transacción cifrada que incluye la atención y todos sus descuentos físicos válidos. Un envase nuevo exige la autorización anterior.")
                .font(.footnote).foregroundStyle(.secondary)
        }
    }
    private func actions(_ context:N2FormContext)->some View {
        VStack(spacing:8) {
            HStack(spacing:12) {
                if step>0 {
                    Button {withAnimation(DanperStyle.animation){step-=1}} label: {
                        Label("Anterior",systemImage:"chevron.left")
                    }
                    .buttonStyle(DanperSecondaryButton())
                }
                Button {
                    if step<3 {
                        withAnimation(DanperStyle.animation){step+=1}
                    } else {
                        Task {await confirm()}
                    }
                } label: {
                    Label(step<3 ? "Siguiente" :
                          (busy ? "Confirmando…" : "Guardar atención"),
                          systemImage:step<3 ? "arrow.right" : "checkmark.shield.fill")
                }
                .buttonStyle(DanperPrimaryButton())
                .disabled(busy)
            }
            Button {
                scheduleDraft(immediate:true)
            }label:{
                Label("Guardar borrador",systemImage:"square.and.arrow.down")
                    .font(.footnote.weight(.semibold))
                    .frame(maxWidth:.infinity,minHeight:36)
            }
            .buttonStyle(.plain)
            .foregroundStyle(DanperStyle.red)
            .disabled(busy)
        }
        .padding(.horizontal,16)
        .padding(.top,10)
        .padding(.bottom,6)
        .background(.regularMaterial)
        .overlay(alignment:.top) {Rectangle().fill(.quaternary).frame(height:0.5)}
    }

    @MainActor
    private func load() async {
        do {
            let source=try await N2SyntheticTrialIOSVault.shared.clinicalFormContext()
            context=source
            drafts=try await N2SyntheticTrialIOSVault.shared.readDrafts()
            if let requestedDraftID {
                guard let recovered=drafts.first(where:{$0.id==requestedDraftID}) else {
                    fault=true
                    status="El borrador solicitado no existe o fue eliminado. No se han modificado registros."
                    return
                }
                form=recovered.form
                step=0
                status="Borrador cifrado recuperado · revisión \(source.revision)"
            } else {
                let (date,time)=limaClock()
                form.date=date
                form.time=time
                status="Bóveda cifrada disponible · revisión \(source.revision)"
            }
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
            let fresh=try await N2SyntheticTrialIOSVault.shared.clinicalFormContext()
            let updated=try await N2SyntheticTrialIOSVault.shared
                .reviewAllergies(dni:dni,status:allergyStatus,
                    substances:normalized,at:now,
                    expectedRevision:fresh.revision)
            context=try await N2SyntheticTrialIOSVault.shared.clinicalFormContext()
            status="Alergias revisadas en revisión \(updated.revision)."
            fault=false
        }catch{
            status="No se confirmó el registro de alergias. Verifica el estado de la bóveda."
            fault=true
        }
    }
    private var meaningfulDraft:Bool {
        !form.dni.isEmpty || !form.category.isEmpty || !form.system.isEmpty ||
        !form.diagnosis.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty ||
        !form.items.isEmpty
    }
    private func scheduleDraft(immediate:Bool=false) {
        guard let context,!busy,!saved,!fault,meaningfulDraft else{return}
        autosaveTask?.cancel()
        let version=form
        autosaveTask=Task { @MainActor in
            if !immediate {
                do {try await Task.sleep(for:.milliseconds(650))}
                catch{return}
            }
            guard !Task.isCancelled else{return}
            do{
                let latest=try await N2SyntheticTrialIOSVault.shared.clinicalFormContext()
                let patch=try version.makeDraftPatch(context:context)
                let timestamp=max(Int64(Date().timeIntervalSince1970*1000),
                                  lastAutosaveTimestamp+1)
                let result=try await N2SyntheticTrialIOSVault.shared.saveDraft(
                    id:version.id,changes:patch,at:timestamp,
                    expectedRevision:latest.revision)
                lastAutosaveTimestamp=timestamp
                await N2DraftReminder.schedule(id:version.id)
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
            let fresh=try await N2SyntheticTrialIOSVault.shared.clinicalFormContext()
            let raw=try form.makeSavedVisit(context:fresh)
            let outcome=try await N2SyntheticTrialIOSVault.shared.saveAttention(
                raw,at:now,expectedRevision:fresh.revision)
            saved=true
            N2DraftReminder.cancel(id:form.id)
            self.context=try await N2SyntheticTrialIOSVault.shared.clinicalFormContext()
            drafts=try await N2SyntheticTrialIOSVault.shared.readDrafts()
            status="Atención confirmada y cifrada en revisión \(outcome.revision). Comprobar consumos pendientes desde el historial."
        }catch {
            status="No se pudo confirmar la atención. La operación fue rechazada y el stock no se debe descontar parcialmente."
            fault=true
        }
    }
    @MainActor
    private func resume(_ record:N2RecoverableDraft) {
        autosaveTask?.cancel()
        form=record.form
        step=0
        chooseDraft=false
        fault=false
        status="Borrador cifrado recuperado. Revisa la información antes de guardar."
    }

    @MainActor
    private func deleteRecoveredDraft(_ id:String) async {
        guard !busy else{return}
        busy=true
        defer {busy=false}
        do {
            let fresh=try await N2SyntheticTrialIOSVault.shared.clinicalFormContext()
            _=try await N2SyntheticTrialIOSVault.shared.deleteDraft(
                id:id,expectedRevision:fresh.revision)
            N2DraftReminder.cancel(id:id)
            drafts=try await N2SyntheticTrialIOSVault.shared.readDrafts()
            context=try await N2SyntheticTrialIOSVault.shared.clinicalFormContext()
            if form.id==id {
                autosaveTask?.cancel()
                form=N2NativeFormDraft()
                let (date,time)=limaClock()
                form.date=date
                form.time=time
                step=0
            }
            status="Borrador eliminado de la bóveda cifrada."
        }catch {
            fault=true
            status="No se pudo eliminar el borrador. Revisa la bóveda antes de editar."
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
