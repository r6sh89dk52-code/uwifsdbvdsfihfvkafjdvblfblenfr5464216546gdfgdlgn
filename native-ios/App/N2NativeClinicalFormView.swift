import Foundation
import SwiftUI
import DanperCore

/// Native N2 editor uses only an explicitly activated, isolated clinical
/// vault. Nothing reads the build222 installation or N1g demo drafts.
struct N2NativeClinicalFormView:View {
    @Environment(\.n2WorkspaceVault) private var vault
    let requestedDraftID:String?
    private var initialWorkerDNI:String?
    init(requestedDraftID:String?=nil,initialWorkerDNI:String?=nil) {
        self.requestedDraftID=requestedDraftID
        self.initialWorkerDNI=initialWorkerDNI
    }
    #if DEBUG
    init(layoutContext:N2FormContext,draft:N2NativeFormDraft,step:Int,validationMessage:String="",saved:Bool=false,showCatalog:Bool=false,detailOnly:Bool=false,layoutOutcomes:[String:String]=[:]) {
        requestedDraftID=nil
        layoutOnly=true
        layoutDetailOnly=detailOnly
        _savedLines=State(initialValue:layoutOutcomes)
        _previewLines=State(initialValue:layoutOutcomes)
        _previewReady=State(initialValue:!layoutOutcomes.isEmpty)
        _saved=State(initialValue:saved)
        _chooseProduct=State(initialValue:showCatalog)
        _expandedMedication=State(initialValue:draft.items.first?.id)
        _context=State(initialValue:layoutContext)
        _form=State(initialValue:draft)
        _step=State(initialValue:step)
        _validationMessage=State(initialValue:validationMessage)
        _showValidation=State(initialValue:!validationMessage.isEmpty)
    }
    #endif
    private var layoutOnly=false
    private var layoutDetailOnly=false
    private let brand=Color(red:0.88,green:0.09,blue:0.16)
    private let categories=N2ClinicalFormOptions.categories
    private let systems=N2ClinicalFormOptions.systems
    private let procedures=N2ProcedureRules.procedures
    @State private var context:N2FormContext?
    @State private var form=N2NativeFormDraft()
    @State private var step=0
    @State private var busy=false
    @FocusState private var focusedField:String?
    @State private var validationMessage=""
    @State private var showValidation=false
    @State private var previewLines:[String:String]=[:]
    @State private var previewReady=false
    @State private var previewBusy=false
    @State private var previewError=""
    @State private var savedLines:[String:String]=[:]
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("danper.haptics.enabled") private var haptics=true
    @State private var saved=false
    @State private var fault=false
    @State private var status="Preparando el registro…"
    @State private var expandedMedication:String?
    @State private var showMissingWorker=false
    @State private var showNewWorker=false
    @State private var workerDNIInput=""
    @State private var workerNameInput=""
    @State private var notFoundDNI=""
    @State private var dniLookupTask:Task<Void,Never>?
    @FocusState private var workerDNIFocused:Bool
    @FocusState private var workerNameFocused:Bool
    @State private var editingWorkerDNI:String?
    @State private var allergyFeedback=""
    @State private var chooseProduct=false
    @State private var chooseDraft=false
    @State private var draftToDelete:String?
    @State private var drafts=[N2RecoverableDraft]()
    @State private var allergyStatus="unknown"
    @State private var allergySubstances=""
    @State private var editingAllergy=false
    @State private var allergyConfirmationProduct:String?
    @State private var allergyMatches=[String]()
    @State private var autosaveTask:Task<Void,Never>?
    @State private var lastAutosaveTimestamp:Int64=0
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    private let stepTitles=["Trabajador y alergias","Evaluación clínica",
                            "Tratamiento y consumo","Confirmar atención"]
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
    private var nameSuggestions:[N2FormWorker] {
        let query=workerNameInput.trimmingCharacters(in:.whitespacesAndNewlines)
        guard query.count>=2,form.dni.isEmpty else{return []}
        return N2NativeWorkerLookup.nameMatches(query,
            in:context?.workers ?? [],limit:5)
    }
    private func selectWorker(_ worker:N2FormWorker) {
        dniLookupTask?.cancel()
        form.dni=worker.dni
        workerDNIInput=worker.dni
        workerNameInput=worker.name
        workerDNIFocused=false
        workerNameFocused=false
        notFoundDNI=""
        showMissingWorker=false
        allergyStatus=context?.allergies[worker.dni]?.status ?? "unknown"
        allergySubstances=context?.allergies[worker.dni]?.substances ?? ""
        allergyFeedback=""
    }
    private func workerAgeDescription(_ worker:N2FormWorker)->String {
        if let age=N2WorkerAge.years(birthDate:worker.birthDate,on:form.date) {
            return "\(age) años"
        }
        if let age=Int(worker.age),(0...120).contains(age) {
            return "\(age) años (declarada)"
        }
        return "No consignada"
    }
    private func enteredWorkerDNI(_ value:String) {
        dniLookupTask?.cancel()
        let digits=N2NativeWorkerLookup.numericDNI(value)
        if workerDNIInput != digits {workerDNIInput=digits}
        if let worker=N2NativeWorkerLookup.exactDNI(digits,
            in:context?.workers ?? []) {
            selectWorker(worker)
            return
        }
        form.dni=""
        workerNameInput=""
        notFoundDNI=""
        guard digits.count==8,!layoutOnly else{return}
        dniLookupTask=Task { @MainActor in
            do {try await Task.sleep(for:.milliseconds(400))}catch{return}
            guard workerDNIInput==digits,!Task.isCancelled else{return}
            if let worker=N2NativeWorkerLookup.exactDNI(digits,
                in:context?.workers ?? []) {
                selectWorker(worker)
            } else {
                notFoundDNI=digits
                workerDNIFocused=false
                showMissingWorker=true
            }
        }
    }
    var body:some View {
        Group {
            if let context {
                DanperScrollView {
                  VStack(alignment:.leading,spacing:16) {
                    if fault {
                        DanperStatusBanner(symbol:"exclamationmark.shield.fill",title:"Revisa el registro",detail:status)
                    } else if !saved && !layoutDetailOnly {
                        VStack(alignment:.leading,spacing:4) {
                            Text("REGISTRO AMBULATORIO")
                                .font(.caption2.weight(.bold))
                                .tracking(1.25)
                                .foregroundStyle(DanperStyle.red)
                            Text("Nueva atención")
                                .font(.system(.title2,design:.rounded,weight:.bold))
                            Label(lastAutosaveTimestamp>0
                                  ? "Borrador protegido · autoguardado activo"
                                  : "Autoguardado activo · aviso de borradores",
                                  systemImage:"checkmark.shield")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        .frame(maxWidth:.infinity,alignment:.leading)
                    }
                    if !saved && !drafts.isEmpty {
                        DanperPanel("Registros pendientes") {
                            Button {
                                chooseDraft=true
                            } label: {
                                Label("Retomar borrador cifrado (\(drafts.count))",
                                      systemImage:"arrow.uturn.backward.doc")
                            }
                        }
                    }
                    if saved {
                        DanperPanel {
                            Image(systemName:savedLines.values.allSatisfy{$0=="Descontado"} ? "checkmark.circle.fill" : "checkmark.shield.fill").font(.system(size:48)).foregroundStyle(.green)
                            Text("Atención registrada").font(.title2.bold())
                            if savedLines.values.contains(where:{$0 != "Descontado"}) {
                                Label("Hay consumos sin salida física. Revisa el motivo de cada producto.",systemImage:"exclamationmark.triangle")
                                    .font(.footnote).foregroundStyle(.orange)
                            } else if !form.items.isEmpty {
                                Label("Dispensación descontada automáticamente",systemImage:"checkmark.circle.fill")
                                    .font(.footnote).foregroundStyle(.green)
                            }
                            Text(currentWorker?.name ?? form.dni).font(.headline)
                            Text(DanperDatePresentation.displayDateTime(form.date,form.time)).font(.subheadline).foregroundStyle(.secondary)
                            Divider()
                            reviewValue("Diagnóstico",form.diagnosis)
                            ForEach(form.items) {med in
                                let result=savedLines[med.id] ?? "Pendiente de conciliar"
                                HStack(alignment:.top,spacing:10) {
                                    Image(systemName:result=="Descontado" ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                                        .foregroundStyle(result=="Descontado" ? Color.green : Color.orange)
                                    VStack(alignment:.leading,spacing:5) {
                                        Text(medicationName(med.code,context)).font(.subheadline.weight(.semibold))
                                        Text("Cantidad \(med.quantity) · "+result).font(.caption).foregroundStyle(.secondary)
                                    }
                                }
                            }
                            if !form.procedures.isEmpty {reviewValue("Procedimientos",form.procedures.map{$0.capitalized}.joined(separator:", "))}
                            Button {startAnother()} label: {Label("Nueva atención",systemImage:"plus")}
                                .buttonStyle(DanperPrimaryButton())
                            NavigationLink {N2NativeHistoryView(useProtectedVault:true)} label: {Label("Ver historial y consumos",systemImage:"clock.arrow.circlepath")}
                                .buttonStyle(DanperSecondaryButton())
                        }
                    } else {
                        if !layoutDetailOnly {stepHeading}
                        if step==0 {workerSection(context)}
                        if step==1 {clinicalSection()}
                        if step==2 {treatmentSection(context)}
                        if step==3 {reviewSection(context)}
                        if dynamicTypeSize.isAccessibilitySize {
                            DanperPanel {Button("Guardar borrador") {scheduleDraft(immediate:true)}}
                        }
                    }
                  }.padding(16)
                }
                .id("\(step)-\(saved)")
                .navigationTitle(saved ? "Atención registrada" : "Nueva atención")
                .navigationBarTitleDisplayMode(.inline)
                .danperFormChrome()
                .scrollDismissesKeyboard(.interactively)
                .toolbar {
                    if !saved {
                        ToolbarItem(placement:.topBarTrailing) {
                            Button {scheduleDraft(immediate:true)} label: {
                                Image(systemName:"square.and.arrow.down").foregroundStyle(.secondary)
                            }.accessibilityLabel("Guardar borrador").disabled(busy)
                        }
                    }
                }
                .safeAreaInset(edge:.bottom,spacing:0) {
                    if !saved {actions(context)}
                }
                .animation(reduceMotion ? nil : DanperStyle.animation,value:step)
                .sensoryFeedback(.selection,trigger:step) {_,_ in haptics}
                .sensoryFeedback(.selection,trigger:form.procedures.count) {_,_ in haptics}
                .sensoryFeedback(.success,trigger:saved) {_,_ in haptics}
                .confirmationDialog("Revisar coincidencia textual de alergia",
                    isPresented:Binding(
                        get:{allergyConfirmationProduct != nil},
                        set:{if !$0 {allergyConfirmationProduct=nil}}
                    ),titleVisibility:.visible) {
                    Button("Agregar y conservar advertencia") {
                        if let code=allergyConfirmationProduct {
                            appendClinicalMedication(code)
                        }
                        allergyConfirmationProduct=nil
                    }
                    Button("Cancelar",role:.cancel) {
                        allergyConfirmationProduct=nil
                    }
                } message: {
                    Text("Posible coincidencia con alergia declarada: \(allergyMatches.joined(separator: ", ")). Esta alerta usa solo texto; no verifica principios activos ni reacciones cruzadas. Comprueba la indicación antes de cualquier administración.")
                }
                .alert("Trabajador no registrado",isPresented:$showMissingWorker) {
                    Button("Registrar trabajador") {
                        showNewWorker=true
                    }
                    Button("Cerrar",role:.cancel) {
                        workerDNIInput=""
                        workerNameInput=""
                        notFoundDNI=""
                        form.dni=""
                    }
                } message: {
                    Text("No encontramos el DNI \(notFoundDNI) en Personal. Puedes registrarlo ahora y continuar esta misma atención.")
                }
                .sheet(isPresented:$showNewWorker,onDismiss:{
                    editingWorkerDNI=nil
                    notFoundDNI=""
                }) {
                    NavigationStack {
                        N2NativeWorkerEditorView(
                            initialDNI:notFoundDNI,
                            editingDNI:editingWorkerDNI,
                            onSaved:{dni in
                                Task {await didRegisterWorker(dni)}
                            })
                        .toolbar {
                            ToolbarItem(placement:.topBarLeading) {
                                Button("Cerrar") {
                                    showNewWorker=false
                                }
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
                .onChange(of:form.dni) {_,dni in
                    if let worker=context.workers.first(where:{$0.dni==dni}) {
                        workerDNIInput=dni
                        workerNameInput=worker.name
                    }
                    allergyStatus=context.allergies[dni]?.status ?? "unknown"
                    allergySubstances=context.allergies[dni]?.substances ?? ""
                    allergyFeedback=context.allergies[dni]?.reviewed == true
                        ? "Alergias revisadas" : ""
                }
                .task(id:form) {
                    if step==3 && !saved && !layoutOnly {
                        do {try await Task.sleep(for:.milliseconds(800))} catch{return}
                        await refreshDispensingPreview()
                    }
                }
                .onChange(of:form) {_,_ in
                    previewReady=false
                    if !form.blueBandage {form.returned=false}
                    form.refreshProcedureSuggestions(catalog:context.products)
                    scheduleDraft()
                }
                .alert("Completa este paso",isPresented:$showValidation) {
                    Button("Revisar",role:.cancel) {focusFirstMissing(context)}
                } message: {Text(validationMessage)}
                .onChange(of:scenePhase) {_,phase in
                    if phase != .active {scheduleDraft(immediate:true)}
                }
                .onDisappear {
                    scheduleDraft(immediate:true)
                }
            } else {
                ContentUnavailableView(
                    fault ? "Datos no disponibles" : "Preparando formulario",
                    systemImage:"lock.shield",
                    description:Text(status))
                .task {await load()}
            }
        }
        .tint(brand)
    }

    private var stepHeading:some View {
        VStack(alignment:.leading,spacing:12) {
            HStack(alignment:.firstTextBaseline) {
                Text(stepTitles[step]).font(.title3.bold())
                Spacer(minLength:4)
                Text("\(step+1) de 4").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            }
            ScrollViewReader { proxy in
            ScrollView(.horizontal,showsIndicators:false) {
                HStack(spacing:8) {
                    ForEach(0..<4) { target in
                        Button {
                            guard let context else{return}
                            let missing=target<=step ? [] : (step..<target).flatMap { index in
                                form.clinicalIssues(step:index,context:context).map{N2ClinicalFormOptions.messages[$0] ?? $0} + (index==2 ? extraTreatmentRequirements : [])
                            }
                            let allergyMissing=step==0 && target>0 ? form.clinicalIssues(step:1,context:context).filter{$0.hasPrefix("allergy-")}.map{N2ClinicalFormOptions.messages[$0] ?? $0} : []
                            if (missing+allergyMissing).isEmpty {
                                withAnimation(reduceMotion ? nil : DanperStyle.animation){step=target}
                            } else {validationMessage=(missing+allergyMissing).joined(separator:"\n");showValidation=true}
                        } label: {
                            HStack(spacing:7) {
                                Text("\(target+1)").font(.caption.bold())
                                    .frame(width:24,height:24)
                                    .background(step==target ? DanperStyle.red : Color.secondary.opacity(0.10),in:Circle())
                                    .foregroundStyle(step==target ? .white : .primary)
                                Text(["Trabajador","Evaluación","Tratamiento","Resultado"][target]).font(.caption.weight(.semibold))
                                    .foregroundStyle(.primary)
                            }.padding(10).frame(minHeight:44)
                                .background(step==target ? DanperStyle.red.opacity(0.08) : DanperStyle.surface,in:RoundedRectangle(cornerRadius:14))
                                .overlay(RoundedRectangle(cornerRadius:14).strokeBorder(step==target ? DanperStyle.red.opacity(0.45) : Color.secondary.opacity(0.16)))
                        }.buttonStyle(.plain).accessibilityAddTraits(step==target ? .isSelected : []).id(target)
                    }
                }
            }
            .onAppear {proxy.scrollTo(step,anchor:.center)}
            }
            if step>0 && !dynamicTypeSize.isAccessibilitySize,let worker=currentWorker {
                HStack(spacing:10) {
                    Image(systemName:"person.crop.circle").foregroundStyle(.secondary)
                    VStack(alignment:.leading,spacing:4) {
                        Text(worker.name).font(.caption.weight(.semibold))
                        Text("DNI "+worker.dni).font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer(minLength:4)
                    Button("Editar") {step=0}.font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                }.padding(12).background(DanperStyle.surface,in:RoundedRectangle(cornerRadius:16))
            }
        }
    }
    /// Build 222's worker-first workflow, entirely native and backed by the
    /// authenticated worker directory. Worker edits occur ONLY in the
    /// validated worker editor; a visit never silently modifies the roster.
    private func workerSection(_ context:N2FormContext)->some View {
        VStack(alignment:.leading,spacing:14) {
            DanperPanel("Trabajador") {
                HStack(spacing:10) {
                    Button {
                        // Activates inline search in the same encounter rather
                        // than navigating to a disconnected read-only roster.
                        if currentWorker != nil {
                            form.dni=""
                            workerDNIInput=""
                            workerNameInput=""
                            allergyStatus="unknown"
                            allergySubstances=""
                            allergyFeedback=""
                        }
                        workerDNIFocused=false
                        workerNameFocused=true
                    } label: {
                        Label("Buscar en padrón",systemImage:"person.2")
                            .font(.subheadline.weight(.semibold))
                            .lineLimit(2).minimumScaleFactor(0.8)
                            .frame(maxWidth:.infinity,minHeight:48)
                    }
                    .buttonStyle(DanperSecondaryButton())
                    .accessibilityIdentifier("attention-browse-workers")
                    Button {
                        editingWorkerDNI=nil
                        notFoundDNI=workerDNIInput.count==8 ? workerDNIInput : ""
                        workerNameFocused=false
                        workerDNIFocused=false
                        showNewWorker=true
                    } label: {
                        Label("Nuevo trabajador",systemImage:"person.badge.plus")
                            .font(.subheadline.weight(.semibold))
                            .lineLimit(2).minimumScaleFactor(0.8)
                            .frame(maxWidth:.infinity,minHeight:48)
                    }
                    .buttonStyle(DanperPrimaryButton())
                    .accessibilityIdentifier("attention-add-worker")
                }
                DanperField(title:"DNI") {
                    HStack(spacing:10) {
                        TextField("8 dígitos",text:$workerDNIInput)
                            .keyboardType(.numberPad)
                            .focused($workerDNIFocused)
                            .accessibilityIdentifier("attention-worker-dni")
                            .onChange(of:workerDNIInput) {_,value in
                                enteredWorkerDNI(value)
                            }
                        if !workerDNIInput.isEmpty {
                            Image(systemName:currentWorker == nil
                                  ? "magnifyingglass" : "checkmark.circle.fill")
                                .foregroundStyle(currentWorker == nil
                                                 ? Color.secondary : Color.green)
                                .accessibilityHidden(true)
                        }
                    }
                }
                DanperField(title:"Nombre completo") {
                    if let worker=currentWorker {
                        HStack {
                            Text(worker.name)
                                .foregroundStyle(.primary)
                                .frame(maxWidth:.infinity,alignment:.leading)
                                .accessibilityIdentifier("attention-worker-name")
                            Image(systemName:"checkmark.seal.fill")
                                .foregroundStyle(.green)
                        }
                    } else {
                        TextField("Apellidos y nombres",text:$workerNameInput)
                            .textInputAutocapitalization(.words)
                            .autocorrectionDisabled()
                            .focused($workerNameFocused)
                            .submitLabel(.search)
                            .accessibilityIdentifier("attention-worker-name-query")
                    }
                }
                if !nameSuggestions.isEmpty {
                    VStack(spacing:3) {
                        ForEach(nameSuggestions) { person in
                            Button {
                                selectWorker(person)
                            } label: {
                                HStack(spacing:10) {
                                    Image(systemName:"person.crop.circle")
                                        .foregroundStyle(DanperStyle.red)
                                    VStack(alignment:.leading,spacing:3) {
                                        Text(person.name)
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundStyle(.primary)
                                        Text("DNI "+person.dni)
                                            .font(.caption).foregroundStyle(.secondary)
                                    }
                                    Spacer(minLength:4)
                                    Image(systemName:"arrow.up.left")
                                        .foregroundStyle(.secondary)
                                }
                                .frame(maxWidth:.infinity,alignment:.leading)
                                .padding(12)
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("attention-worker-option-"+person.dni)
                            Divider().opacity(0.35)
                        }
                    }
                    .background(DanperStyle.canvas,
                                in:RoundedRectangle(cornerRadius:13))
                    .accessibilityIdentifier("attention-worker-suggestions")
                }
                if workerDNIInput.count==8 && currentWorker==nil && !showMissingWorker {
                    Button {
                        notFoundDNI=workerDNIInput
                        editingWorkerDNI=nil
                        showMissingWorker=true
                    } label: {
                        Label("Registrar DNI "+workerDNIInput,
                              systemImage:"person.badge.plus")
                    }
                    .buttonStyle(DanperSecondaryButton())
                }
                if let worker=currentWorker {
                    Label("Trabajador identificado en el padrón",
                          systemImage:"checkmark.circle.fill")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.green)
                    VStack(alignment:.leading,spacing:12) {
                        LabeledContent("Sede",
                            value:worker.site=="PLVENTUROSA"
                                  ? "Planta La Venturosa" : "Fundo La Venturosa")
                        LabeledContent("Área",
                            value:worker.area.isEmpty ? "No consignada" : worker.area)
                        LabeledContent("Labor",
                            value:worker.labor.isEmpty ? "No consignada" : worker.labor)
                        LabeledContent("Sexo",
                            value:worker.sex=="M" ? "Masculino" :
                                  worker.sex=="F" ? "Femenino" : "No consignado")
                        LabeledContent("Edad",value:workerAgeDescription(worker))
                        LabeledContent("Ubigeo",
                            value:worker.ubigeo.isEmpty ? "No consignado" : worker.ubigeo)
                    }
                    .font(.subheadline)
                    .padding(14)
                    .background(DanperStyle.canvas,
                                in:RoundedRectangle(cornerRadius:14))
                    Button {
                        editingWorkerDNI=worker.dni
                        notFoundDNI=""
                        workerNameFocused=false
                        showNewWorker=true
                    } label: {
                        Label("Completar o corregir ficha laboral",
                              systemImage:"square.and.pencil")
                    }
                    .buttonStyle(DanperSecondaryButton())
                    .accessibilityIdentifier("attention-edit-worker-profile")
                    Text("Las modificaciones de la ficha se guardan en el padrón cifrado y no reescriben atenciones anteriores.")
                        .font(.caption).foregroundStyle(.secondary)
                } else {
                    Text("Busca por DNI o por nombres. Si no figura en el padrón, regístralo y continúa esta misma atención.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }

            if let worker=currentWorker {
                DanperPanel("Alergias del trabajador") {
                    Label("Revisión obligatoria antes del tratamiento",
                          systemImage:"exclamationmark.shield")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.orange)
                    DanperChoiceField(title:"Revisión de alergias",
                        selection:$allergyStatus,
                        options:["unknown","none","known"],
                        labels:[
                            "unknown":"No evaluado",
                            "none":"Niega alergias conocidas",
                            "known":"Alergias reportadas"
                        ])
                    if allergyStatus=="known" {
                        DanperField(title:"Sustancias reportadas") {
                            TextField("Indica las sustancias",text:$allergySubstances,
                                      axis:.vertical).lineLimit(2...5)
                        }
                    }
                    if !allergyFeedback.isEmpty {
                        Label(allergyFeedback,systemImage:"checkmark.circle.fill")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.green)
                    }
                    Button(editingAllergy
                           ? "Guardando…" : "Guardar revisión de alergias") {
                        Task {await recordAllergy(worker.dni)}
                    }
                    .buttonStyle(DanperSecondaryButton())
                    .disabled(editingAllergy ||
                        (allergyStatus=="known" &&
                         allergySubstances.trimmingCharacters(in:.whitespaces).isEmpty))
                }
            }
        }
    }
    private func clinicalSection()->some View {
        DanperPanel("Evaluación clínica") {
            DanperDateField(title:"Fecha de atención",selection:dateSelection)
            DanperField(title:"Hora de atención") {
                TextField("HH:mm",text:$form.time).focused($focusedField,equals:"time")
                    .keyboardType(.numbersAndPunctuation)
            }
            DanperChoiceField(title:"Tipo de atención",selection:$form.category,options:categories)
            if N1hClinicalValidator.systemRequired.contains(form.category) {
                DanperChoiceField(title:"Sistema afectado",selection:$form.system,options:systems)
                if form.system=="OSTEOMUSCULAR" {
                    DanperField(title:"Segmento anatómico") {
                        TextField("Describe la zona afectada",text:$form.segment).focused($focusedField,equals:"segment")
                    }
                }
            }
            DanperField(title:"Diagnóstico presuntivo") {
                TextField("Escribe para buscar o registrar",text:$form.diagnosis,axis:.vertical)
                    .focused($focusedField,equals:"diagnosis").lineLimit(2...5)
            }
            if !form.diagnosis.isEmpty {
                let suggestions=N2ClinicalFormOptions.diagnoses.filter {
                    $0.localizedStandardContains(form.diagnosis) && $0 != form.diagnosis
                }
                ForEach(Array(suggestions.prefix(5)),id:\.self) { diagnosis in
                    Button {form.diagnosis=diagnosis;focusedField=nil} label: {
                        HStack {Text(diagnosis).foregroundStyle(.primary);Spacer();Image(systemName:"arrow.up.left").foregroundStyle(.secondary)}
                            .font(.subheadline).padding(12).frame(maxWidth:.infinity,alignment:.leading)
                            .background(DanperStyle.canvas,in:RoundedRectangle(cornerRadius:12))
                    }.buttonStyle(.plain)
                }
            }
        }
    }
    private var procedureGroups:[(title:String,symbol:String,values:[String])] {
        let candidates:[(String,String,[String])]=[
            ("Observación y controles","stethoscope",["OBSERVACION","CONTROL","TOMA DE PETAR"]),
            ("Tratamientos y aplicaciones","cross.vial.fill",["TRATAMIENTO ORAL","INYECTABLE","APLICACION DE CREMA","APLICACION DE GOTAS OFTALMICAS"]),
            ("Curaciones y procedimientos","bandage.fill",["CURACION DE HERIDA","LAVADO OCULAR","RETIRO DE PUNTOS DE SUTURA","SUTURAS","EXTRACCION DE CUERPO EXTRAÑO"])
        ]
        let listed=Set(candidates.flatMap{$0.2})
        var result:[(title:String,symbol:String,values:[String])]=candidates.map { group in
            (title:group.0,symbol:group.1,
             values:group.2.filter{procedures.contains($0)})
        }
        let remaining=procedures.filter{!listed.contains($0)}
        if !remaining.isEmpty {
            result.append((title:"Otros procedimientos",symbol:"list.bullet",values:remaining))
        }
        return result.filter{!$0.values.isEmpty}
    }

    private func procedureOption(_ value:String)->some View {
        let chosen=form.procedures.contains(value)
        return Button {
            if chosen {form.procedures.removeAll{$0==value}}
            else {form.procedures.append(value)}
        } label:{
            HStack(spacing:8) {
                Image(systemName:chosen ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(chosen ? DanperStyle.red : Color.secondary)
                Text(value.capitalized(with:Locale(identifier:"es_PE")))
                    .font(.subheadline.weight(chosen ? .semibold : .regular))
                    .foregroundStyle(.primary).multilineTextAlignment(.leading)
                Spacer(minLength:0)
            }
            .padding(11).frame(maxWidth:.infinity,minHeight:54,alignment:.leading)
            .background(chosen ? DanperStyle.red.opacity(0.1) : DanperStyle.canvas,
                        in:RoundedRectangle(cornerRadius:13))
            .overlay(RoundedRectangle(cornerRadius:13)
                .strokeBorder(chosen ? DanperStyle.red.opacity(0.38) : Color.secondary.opacity(0.12)))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(chosen ? .isSelected : [])
    }

    private func treatmentSection(_ context:N2FormContext)->some View {
        Group {
        if !layoutDetailOnly {
        DanperPanel("Medicamentos e insumos") {
            Text("Busca productos; valida procedimiento, cantidad y lote FEFO antes de guardar.")
                .font(.caption).foregroundStyle(.secondary)
            Button {withAnimation(reduceMotion ? nil : DanperStyle.animation){chooseProduct.toggle()}} label: {
                Label("Agregar medicamento o insumo",systemImage:"plus.circle.fill")
            }
            .buttonStyle(DanperPrimaryButton())
            .accessibilityIdentifier("add-clinical-product")
            if chooseProduct {
                DanperInlineSearch(title:"Buscar medicamento o insumo",placeholder:"Ej. Paracetamol",
                    options:context.products.clinical.map{DanperSearchOption(id:$0.code,title:$0.name,detail:$0.unit+" · Código "+$0.code)},
                    onSelect:{code in
                        let matches=allergyTextMatches(code,context:context)
                        if matches.isEmpty {
                            appendClinicalMedication(code)
                        } else {
                            allergyMatches=Array(Set(matches)).sorted()
                            allergyConfirmationProduct=code
                        }
                    },onClose:{chooseProduct=false})
            }

            DanperChoiceField(title:"Tópico de dispensación",selection:Binding(
                get:{form.dispensingSite},set:{site in
                    guard site != form.dispensingSite else{return}
                    form.dispensingSite=site
                    for i in form.items.indices {
                        form.items[i].selectedLotID="";form.items[i].physicalQuantity=0
                        form.items[i].approveOpening=false
                    }
                }
            ),options:["LA VENTUROSA","PLVENTUROSA"],labels:["LA VENTUROSA":"Fundo La Venturosa","PLVENTUROSA":"Planta La Venturosa"])
            Text("\(context.products.clinical.count) productos · selección múltiple")
                .font(.footnote).foregroundStyle(.secondary)
        }
        }
        medicationFields(context)
        DanperPanel("Procedimientos") {
            Text("Acciones realizadas durante la atención")
                .font(.subheadline.weight(.semibold))
            Text("Marca únicamente lo realizado. Los medicamentos, sus lotes y consumos se registran arriba.")
                .font(.caption).foregroundStyle(.secondary)
            ForEach(procedureGroups.indices,id:\.self) { index in
                let group=procedureGroups[index]
                VStack(alignment:.leading,spacing:10) {
                    Label(group.title,systemImage:group.symbol)
                        .font(.subheadline.weight(.semibold)).foregroundStyle(DanperStyle.red)
                    LazyVGrid(columns:dynamicTypeSize.isAccessibilitySize
                        ? [GridItem(.flexible())]
                        : [GridItem(.flexible(),spacing:10),GridItem(.flexible(),spacing:10)],
                        spacing:10) {
                        ForEach(group.values,id:\.self) {item in procedureOption(item)}
                    }
                }.padding(12)
                    .background(DanperStyle.canvas,in:RoundedRectangle(cornerRadius:16))
            }
            if !form.procedures.isEmpty {
                Text("\(form.procedures.count) procedimiento(s) seleccionado(s)")
                    .font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            }
            if form.hasWound {
                DanperChoiceField(title:"¿Se envió la foto?",selection:Binding(
                    get:{form.photoReviewed ? (form.photoSent ? "SI" : "NO") : ""},
                    set:{form.photoReviewed = !$0.isEmpty;form.photoSent = $0=="SI"}
                ),options:["SI","NO"],labels:["SI":"Sí, se envió","NO":"No se envió"])
            }
            DanperCheckRow(selected:$form.blueBandage) {Text("Se colocó banda o curita azul").font(.subheadline)}
            if form.blueBandage {
                DanperCheckRow(selected:$form.returned) {Text("Se devolvió la banda o curita").font(.subheadline)}
            }
        }
    }
        }
    private func appendClinicalMedication(_ code:String) {
        let med=N2FormMedication(code:code)
        form.items.append(med)
        expandedMedication=med.id
        if let context {form.refreshProcedureSuggestions(catalog:context.products)}
    }
    private func medicationName(_ code:String,_ context:N2FormContext)->String {
        context.products.clinical.first(where:{$0.code==code})?.name ?? code
    }
    private func allergyTextMatches(_ code:String,context:N2FormContext)->[String] {
        let current=allergyStatus=="known" ? allergySubstances : ""
        let record=context.allergies[form.dni]
        let documented=record?.status=="known" ? (record?.substances ?? "") : ""
        return N2MedicationAllergyTextMatch.matches(
            productName:medicationName(code,context),
            substances:current + ";" + documented)
    }
    @ViewBuilder
    private func medicationFields(_ context:N2FormContext)->some View {
        ForEach($form.items) { $med in
            DanperPanel {
                Button {withAnimation(reduceMotion ? nil : DanperStyle.animation) {
                    expandedMedication = expandedMedication==med.id ? nil : med.id
                }} label: {
                    HStack(alignment:.top,spacing:12) {
                        Image(systemName:"cross.vial.fill").foregroundStyle(DanperStyle.red)
                            .padding(10).background(DanperStyle.red.opacity(0.08),in:RoundedRectangle(cornerRadius:12))
                        VStack(alignment:.leading,spacing:6) {
                            Text(medicationName(med.code,context)).font(.subheadline.weight(.bold)).foregroundStyle(.primary)
                            Text("Cantidad \(med.quantity) · \(med.procedure.isEmpty ? "Procedimiento pendiente" : med.procedure.capitalized)")
                                .font(.caption).foregroundStyle(.secondary)
                            if !allergyTextMatches(med.code,context:context).isEmpty {
                                Label("Revisar posible coincidencia de alergia",systemImage:"exclamationmark.triangle.fill")
                                    .font(.caption).foregroundStyle(.orange)
                            }
                        }.frame(maxWidth:.infinity,alignment:.leading)
                        Image(systemName:expandedMedication==med.id ? "chevron.up" : "chevron.down")
                            .font(.caption.weight(.bold)).foregroundStyle(.secondary)
                    }.contentShape(Rectangle())
                }.buttonStyle(.plain)
                if expandedMedication==med.id || med.procedure.isEmpty {
                    Divider()
                    Text(med.code+" · "+(context.products.clinical.first{$0.code==med.code}?.unit ?? ""))
                        .font(.caption).foregroundStyle(.secondary)
                    DanperField(title:"Cantidad clínica") {
                        HStack {
                            Button {if med.quantity>1 {med.quantity-=1}} label: {Image(systemName:"minus.circle").frame(width:44,height:44)}.disabled(med.quantity<=1)
                            TextField("Cantidad",value:$med.quantity,format:.number)
                                .keyboardType(.numberPad).multilineTextAlignment(.center).accessibilityLabel("Cantidad clínica")
                            Button {med.quantity+=1} label: {Image(systemName:"plus.circle").frame(width:44,height:44)}
                        }.buttonStyle(.plain).font(.title3).foregroundStyle(.primary)
                    }
                    DanperChoiceField(title:"Procedimiento",selection:Binding(
                        get:{med.procedure},set:{med.procedure=$0;med.procedureConfirmed=true;med.procedureSource="manual"}
                    ),options:procedures)
                    Text(med.procedureConfirmed ? "Elección confirmada" :
                         med.procedureSource=="presentation" ? "Sugerido por la presentación del producto" :
                         med.procedureSource=="context" ? "Sugerido por el contexto de la atención" :
                         "Selecciona el procedimiento utilizado")
                        .font(.caption).foregroundStyle(.secondary)
                    if !med.procedureConfirmed && !med.procedure.isEmpty {
                        Button {med.procedureConfirmed=true} label: {Label("Confirmar sugerencia",systemImage:"checkmark")}
                            .buttonStyle(DanperSecondaryButton())
                    }
                    let matches=context.options(for:med.code,at:form.date,site:form.dispensingSite)
                    DanperChoiceField(title:"Existencia física",selection:Binding(
                        get:{med.selectedLotID},set:{value in
                            med.selectedLotID=value;med.approveOpening=false
                            let unit=context.products.clinical.first{$0.code==med.code}?.unit ?? ""
                            if ["UND","TBL","PAR"].contains(unit.uppercased()) {med.physicalQuantity=Double(med.quantity)}
                        }
                    ),options:[""]+matches.map(\.id),labels:Dictionary(uniqueKeysWithValues:
                        [("","Automático por FEFO / pendiente")]+matches.map{($0.id,$0.name+" · Lote "+$0.id+" · Vence "+DanperDatePresentation.display($0.expires))}))
                    if let first=matches.first {
                        Text("FEFO: "+first.id+" · Disponible: "+matches.reduce(0){$0+$1.total}.formatted())
                            .font(.caption).foregroundStyle(.secondary)
                    } else {
                        Label("Sin existencia aprobada vigente. Se registrará como consumo pendiente.",systemImage:"exclamationmark.triangle")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    if !med.selectedLotID.isEmpty {
                        if let selected=matches.first(where:{$0.id==med.selectedLotID}) {
                            Text("Existencia: "+selected.total.formatted()+" · Capacidad por envase: "+selected.capacity.formatted())
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        DanperField(title:"Unidades físicas usadas (mL, UND…)") {
                            TextField("Cantidad física",value:$med.physicalQuantity,format:.number).keyboardType(.decimalPad)
                        }
                        if matches.contains(where:{$0.sealed>0}) {
                            DanperCheckRow(selected:$med.approveOpening) {Text("Autorizo abrir un frasco o caja nuevo").font(.subheadline)}
                        }
                    }
                    Button(role:.destructive) {form.items.removeAll{$0.id==med.id}} label: {
                        Label("Quitar producto",systemImage:"trash").font(.caption.weight(.semibold))
                    }.buttonStyle(.plain)
                }
            }
        }
    }
    private func focusFirstMissing(_ context:N2FormContext) {
        if currentWorker==nil {step=0;workerDNIFocused=true;return}
        if !form.clinicalIssues(step:1,context:context).filter({$0.hasPrefix("allergy-")}).isEmpty {step=0;return}
        if !form.clinicalIssues(step:1,context:context).isEmpty {step=1}
        else if !form.clinicalIssues(step:2,context:context).isEmpty || !extraTreatmentRequirements.isEmpty {step=2}
        else {step=3}
        if form.category.isEmpty {focusedField="category"}
        else if form.system=="OSTEOMUSCULAR" && form.segment.isEmpty {focusedField="segment"}
        else if form.diagnosis.isEmpty {focusedField="diagnosis"}
        else {focusedField="time"}
    }
    private var extraTreatmentRequirements:[String] {
        var missing=[String]()
        if form.procedures.isEmpty && form.items.isEmpty {missing.append("Selecciona al menos un procedimiento o producto.")}
        if !form.items.isEmpty && form.dispensingSite.isEmpty {missing.append("Selecciona el tópico de dispensación.")}
        if form.hasWound && !form.photoReviewed {missing.append("Indica si se envió la foto.")}
        return missing
    }
    private var pendingRequirements:[String] {
        guard let context else{return ["Espera a que termine la verificación de los datos."]}
        return (0...3).flatMap{form.clinicalIssues(step:$0,context:context)}
            .map{N2ClinicalFormOptions.messages[$0] ?? $0}+extraTreatmentRequirements
    }
    private var stepRequirements:[String] {
        guard let context else{return ["Espera a que termine la verificación de los datos."]}
        let issues=form.clinicalIssues(step:step,context:context).map{N2ClinicalFormOptions.messages[$0] ?? $0}
        let allergies=step==0 ? form.clinicalIssues(step:1,context:context).filter{$0.hasPrefix("allergy-")}.map{N2ClinicalFormOptions.messages[$0] ?? $0} : []
        return issues+allergies+(step==2 ? extraTreatmentRequirements : [])
    }
    private var previewPending:Bool {previewReady && previewLines.values.contains{$0 != "Descontado"}}
    @MainActor
    private func refreshDispensingPreview() async {
        guard !layoutOnly,!saved,!previewBusy,pendingRequirements.isEmpty else{return}
        if form.items.isEmpty {previewReady=true;previewLines=[:];return}
        previewBusy=true;previewReady=false;previewError=""
        defer{previewBusy=false}
        do {
            let fresh=try await vault.clinicalFormContext()
            let raw=try form.makeSavedVisit(context:fresh)
            let results=try await vault.previewAttention(raw,visitID:form.id,at:now,expectedRevision:fresh.revision)
            guard !Task.isCancelled else{return}
            previewLines=results;previewReady=results.count==form.items.count
        } catch {
            if !Task.isCancelled {previewError="No se pudo comprobar el stock actual. Actualiza la verificación antes de guardar."}
        }
    }
    private func reviewSection(_ context:N2FormContext)->some View {
        Group {
            DanperPanel("Resumen de la atención") {
                Label(currentWorker?.name ?? "Trabajador pendiente",systemImage:"person.crop.circle.fill").font(.headline)
                Text("DNI "+form.dni+" · "+DanperDatePresentation.displayDateTime(form.date,form.time))
                    .font(.caption).foregroundStyle(.secondary)
                Divider()
                reviewValue("Evaluación",form.category.capitalized)
                reviewValue("Diagnóstico",form.diagnosis)
                ForEach(form.items) {med in
                    reviewValue(medicationName(med.code,context),"Cantidad \(med.quantity) · \(med.procedure.capitalized)")
                }
                if !form.procedures.isEmpty {reviewValue("Procedimientos",form.procedures.map{$0.capitalized}.joined(separator:", "))}
                Button("Editar evaluación") {step=1}.buttonStyle(DanperSecondaryButton())
            }
            if !form.items.isEmpty {
                DanperPanel("Dispensación al guardar") {
                    if previewBusy {ProgressView("Comprobando stock y FEFO…")}
                    if previewReady {
                        ForEach(form.items) {med in
                            let result=previewLines[med.id] ?? "Verificación incompleta"
                            HStack(alignment:.top,spacing:10) {
                                Image(systemName:result=="Descontado" ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                                    .foregroundStyle(result=="Descontado" ? Color.green : Color.orange)
                                VStack(alignment:.leading,spacing:5) {
                                    Text(medicationName(med.code,context)).font(.subheadline.weight(.semibold))
                                    Text(result=="Descontado" ? "Se descontará automáticamente al guardar" : "Sin salida física: "+result)
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                            }
                        }
                    } else if !previewBusy {
                        Text(previewError.isEmpty ? "Completa la revisión para comprobar los consumos." : previewError)
                            .font(.caption).foregroundStyle(.secondary)
                        Button("Actualizar verificación") {Task {await refreshDispensingPreview()}}
                            .buttonStyle(DanperSecondaryButton())
                    }
                    if previewPending {
                        DanperToolLink(title:"Revisar existencias y sedes",symbol:"shippingbox") {N2NativeInventoryView()}
                        Text("Guardar con pendientes conserva el registro clínico, pero no acredita una salida de stock.").font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            DanperPanel("Resultado y controles") {
                DanperChoiceField(title:"Situación al finalizar",selection:$form.permission,options:["NO","SI"],
                                  labels:["NO":"Continúa laborando","SI":"Se retira con permiso"])
                if form.permission=="SI" {
                    DanperField(title:"Hora del permiso") {TextField("HH:mm",text:$form.permissionTime).keyboardType(.numbersAndPunctuation)}
                }
                if !pendingRequirements.isEmpty {
                    Label(pendingRequirements.joined(separator:"\n"),systemImage:"exclamationmark.triangle")
                        .font(.footnote).foregroundStyle(.orange).fixedSize(horizontal:false,vertical:true)
                }
                Text("La atención y los consumos válidos se guardan juntos. Podrás revisar cualquier consumo pendiente en el historial.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }
    private func reviewValue(_ title:String,_ value:String)->some View {
        VStack(alignment:.leading,spacing:5) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.subheadline.weight(.medium)).fixedSize(horizontal:false,vertical:true)
        }
    }
    private func actions(_ context:N2FormContext)->some View {
        VStack(spacing:8) {
            HStack(spacing:12) {
                if step>0 {
                    Button {withAnimation(DanperStyle.animation){step-=1}} label: {
                        if dynamicTypeSize.isAccessibilitySize {
                            Image(systemName:"chevron.left").accessibilityLabel("Anterior")
                        } else {Label("Anterior",systemImage:"chevron.left")}
                    }
                    .buttonStyle(DanperSecondaryButton())
                }
                Button {
                    if step<3 {
                        let missing=stepRequirements
                        if missing.isEmpty {withAnimation(reduceMotion ? nil : DanperStyle.animation){step+=1}}
                        else {validationMessage=missing.joined(separator:"\n");showValidation=true}
                    } else {
                        if pendingRequirements.isEmpty {Task {await confirm()}}
                        else {validationMessage=pendingRequirements.joined(separator:"\n");showValidation=true}
                    }
                } label: {
                    if dynamicTypeSize.isAccessibilitySize {
                        Text(step<3 ? "Siguiente" : (busy ? "Guardando…" : "Guardar"))
                            .lineLimit(1).fixedSize(horizontal:false,vertical:true)
                    } else {
                        Label(step<3 ? "Siguiente" :
                              (busy ? "Confirmando…" : previewPending ? "Guardar con pendientes" : "Guardar atención"),
                              systemImage:step<3 ? "arrow.right" : "checkmark.shield.fill")
                    }
                }
                .buttonStyle(DanperPrimaryButton())
                .disabled(busy || previewBusy || (step==3 && !form.items.isEmpty && pendingRequirements.isEmpty && !previewReady && !layoutOnly))
            }

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
            let source=try await vault.clinicalFormContext()
            context=source
            drafts=try await vault.readDrafts()
            if let requestedDraftID {
                guard let recovered=drafts.first(where:{$0.id==requestedDraftID}) else {
                    fault=true
                    status="El borrador solicitado no existe o fue eliminado. No se han modificado registros."
                    return
                }
                form=recovered.form
                step=0
                status="Borrador recuperado."
            } else {
                let (date,time)=limaClock()
                form.date=date
                form.time=time
                status="Formulario preparado."
                if let initialWorkerDNI,
                   let worker=context?.workers.first(where:{$0.dni==initialWorkerDNI}) {
                    selectWorker(worker)
                    allergyStatus=context?.allergies[initialWorkerDNI]?.status ?? "unknown"
                    allergySubstances=context?.allergies[initialWorkerDNI]?.substances ?? ""
                } else {
                    workerDNIInput=""
                    workerNameInput=""
                }
            }
        }catch{
            fault=true
            status="No se pudieron cargar los datos. Ningún registro fue modificado."
        }
    }

    @MainActor
    private func recordAllergy(_ dni:String) async {
        editingAllergy=true
        defer{editingAllergy=false}
        do{
            let normalized=allergyStatus=="known" ? allergySubstances : ""
            let fresh=try await vault.clinicalFormContext()
            let updated=try await vault
                .reviewAllergies(dni:dni,status:allergyStatus,
                    substances:normalized,at:now,
                    expectedRevision:fresh.revision)
            context=try await vault.clinicalFormContext()
            status="Revisión de alergias guardada."
            allergyFeedback="Alergias revisadas y guardadas"
            fault=false
        }catch{
            status="No se pudo guardar la revisión de alergias."
            allergyFeedback="No se guardaron los cambios. Intenta nuevamente."
            fault=true
        }
    }
    @MainActor
    private func didRegisterWorker(_ dni:String) async {
        do {
            let fresh=try await vault.clinicalFormContext()
            guard fresh.workers.contains(where:{$0.dni==dni}) else{return}
            context=fresh
            form.dni=dni
            allergyStatus=fresh.allergies[dni]?.status ?? "unknown"
            allergySubstances=fresh.allergies[dni]?.substances ?? ""
            allergyFeedback=""
            workerDNIInput=dni
            workerNameInput=fresh.workers.first(where:{$0.dni==dni})?.name ?? ""
            notFoundDNI=""
            showNewWorker=false
            step=0
        } catch {
            validationMessage="Se registró el trabajador, pero no se pudo actualizar su ficha. Vuelve a buscarlo en Personal."
            showValidation=true
        }
    }

    private var meaningfulDraft:Bool {
        !form.dni.isEmpty || !form.category.isEmpty || !form.system.isEmpty ||
        !form.diagnosis.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty ||
        !form.items.isEmpty
    }
    private func scheduleDraft(immediate:Bool=false) {
        guard !layoutOnly,let context,!busy,!saved,!fault,meaningfulDraft else{return}
        autosaveTask?.cancel()
        let version=form
        autosaveTask=Task { @MainActor in
            if !immediate {
                do {try await Task.sleep(for:.milliseconds(650))}
                catch{return}
            }
            guard !Task.isCancelled else{return}
            do{
                let latest=try await vault.clinicalFormContext()
                let patch=try version.makeDraftPatch(context:context)
                let timestamp=max(Int64(Date().timeIntervalSince1970*1000),
                                  lastAutosaveTimestamp+1)
                let result=try await vault.saveDraft(
                    id:version.id,changes:patch,at:timestamp,
                    expectedRevision:latest.revision)
                lastAutosaveTimestamp=timestamp
                await N2DraftReminder.schedule(id:version.id,mode:vault.mode)
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
            let fresh=try await vault.clinicalFormContext()
            let raw=try form.makeSavedVisit(context:fresh)
            let outcome=try await vault.saveAttention(
                raw,at:now,expectedRevision:fresh.revision)
            savedLines=try await vault.dispensingStatus(visitID:form.id)
            saved=true
            N2DraftReminder.cancel(id:form.id,mode:vault.mode)
            self.context=try await vault.clinicalFormContext()
            drafts=try await vault.readDrafts()
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
            let fresh=try await vault.clinicalFormContext()
            _=try await vault.deleteDraft(
                id:id,expectedRevision:fresh.revision)
            N2DraftReminder.cancel(id:id,mode:vault.mode)
            drafts=try await vault.readDrafts()
            context=try await vault.clinicalFormContext()
            if form.id==id {
                autosaveTask?.cancel()
                form=N2NativeFormDraft()
                let (date,time)=limaClock()
                form.date=date
                form.time=time
                step=0
            }
            status="Borrador eliminado."
        }catch {
            fault=true
            status="No se pudo eliminar el borrador. Inténtalo nuevamente."
        }
    }

    private func startAnother() {
        dniLookupTask?.cancel()
        workerDNIInput=""
        workerNameInput=""
        notFoundDNI=""
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

