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
        _saved=State(initialValue:saved)
        _chooseProduct=State(initialValue:showCatalog)
        _expandedMedication=State(initialValue:nil)
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
    @State private var workersByDNI=[String:N2FormWorker]()
    @State private var context:N2FormContext?
    @State private var pendingMappingItemID:String?
    @State private var pendingPhysicalItemID:String?
    @State private var showStockRegistration=false
    @State private var containerDecisionIDs=[String]()
    @State private var containerDecisionIndex=0
    @State private var showContainerDecision=false
    @State private var form=N2NativeFormDraft()
    @StateObject private var keyboard=DanperKeyboardState()
    @State private var step=0
    @State private var busy=false
    @FocusState private var focusedField:String?
    @State private var validationMessage=""
    @State private var showValidation=false
    @State private var validationIssueCode:String?
    @State private var highlightedField:String?
    @State private var scrollIssueRequest:DanperScrollRequest?
    @State private var choiceOpenCounter=0
    @State private var savedLines:[String:String]=[:]
    @State private var savedKardex:[String:Double]=[:]
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("danper.haptics.enabled") private var haptics=true
    @State private var saved=false
    @State private var fault=false
    @State private var status="Preparando el registro…"
    @State private var expandedMedication:String?
    @State private var collapsedMedicationGroups=Set<String>()
    @State private var showMissingWorker=false
    @State private var showWorkerSearch=false
    @State private var registerAfterSearch=false
    @State private var showNewWorker=false
    @State private var workerDNIInput=""
    @State private var workerNameInput=""
    @State private var notFoundDNI=""
    @State private var dniLookupTask:Task<Void,Never>?
    @FocusState private var workerDNIFocused:Bool
    @FocusState private var workerNameFocused:Bool
    @State private var editingWorkerDNI:String?
    @State private var allergyFeedback=""
    @State private var allergySaveFailed=false
    @State private var chooseProduct=false
    @State private var showOtherProcedures=false
    @State private var chooseDraft=false
    @State private var draftToDelete:String?
    @State private var drafts=[N2RecoverableDraft]()
    @State private var useCustomSegment=false
    /// A legacy free-text segment stays editable and never disappears when
    /// the user returns to a previously saved clinical draft.
    private var segmentChoice:Binding<String> {
        Binding(get:{
            if useCustomSegment {return N2OsteomuscularSegments.custom}
            if form.segment.isEmpty {return ""}
            return N2OsteomuscularSegments.isKnown(form.segment)
                ? form.segment : N2OsteomuscularSegments.custom
        },set:{option in
            if option==N2OsteomuscularSegments.custom {
                if N2OsteomuscularSegments.isKnown(form.segment) {
                    form.segment=""
                }
                useCustomSegment=true
            } else {
                useCustomSegment=false
                form.segment=option
            }
        })
    }
    @State private var allergyStatus="unknown"
    @State private var allergySubstances=""
    @State private var editingAllergy=false
    @State private var allergyConfirmationProduct:String?
    @State private var allergyMatches=[String]()
    @State private var autosaveTask:Task<Void,Never>?
    @State private var lastAutosaveTimestamp:Int64=0
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    private let stepTitles=["Trabajador","Evaluación","Tratamiento","Resultado"]
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
        guard !form.dni.isEmpty else{return nil}
        // A failed DNI lookup must not rescan 10k workers for every SwiftUI render.
        if !workersByDNI.isEmpty {return workersByDNI[form.dni]}
        return context?.workers.first(where:{$0.dni==form.dni})
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
        allergySaveFailed=false
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
        if let worker=workersByDNI[digits] {
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
            if let worker=workersByDNI[digits] {
                selectWorker(worker)
            } else {
                notFoundDNI=digits
                workerDNIFocused=false
                showMissingWorker=true
            }
        }
    }
    var body:some View {
        editorBody
            .onChange(of:form) {old,new in
                if let context {formChanged(old,new,context)}
            }
            .onChange(of:context?.revision) {_,_ in
                if let context {indexWorkers(context)}
            }
            .onChange(of:keyboard.visible) {_,visible in
                if visible && focusedField=="diagnosis" {
                    scrollIssueRequest=DanperScrollRequest(fieldID:"clinical-diagnosis")
                }
            }
    }
    private var editorBody:some View {
        Group {
            if let context {
                DanperScrollView(jumpRequest:scrollIssueRequest) {
                    formContents(context)
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
                    if !saved && !keyboard.visible {actions(context)
                        .accessibilityIdentifier("attention-step-actions")
                        .transition(.move(edge:.bottom).combined(with:.opacity))}
                }
                .animation(reduceMotion ? nil : DanperStyle.animation,value:keyboard.visible)
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
                .alert(containerDecisionTitle,isPresented:$showContainerDecision) {
                    Button("Sí, abrí uno nuevo · Kardex 1") {
                        recordContainerDecision(opened:true)
                    }
                    Button("No, usé el abierto · Kardex 0") {
                        recordContainerDecision(opened:false)
                    }
                    Button("Volver",role:.cancel) {
                        containerDecisionIDs=[]
                        containerDecisionIndex=0
                    }
                } message: {
                    Text(containerDecisionMessage)
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
                .sheet(isPresented:$showWorkerSearch,onDismiss:{
                    if registerAfterSearch {
                        registerAfterSearch=false
                        editingWorkerDNI=nil
                        notFoundDNI=""
                        showNewWorker=true
                    }
                }) {
                    NavigationStack {
                        N2WorkerSearchSheet(workers:context.workers,
                            onSelect:{worker in
                                selectWorker(worker)
                                showWorkerSearch=false
                            },onNewWorker:{
                                // Wait for dismissal to finish before showing another sheet.
                                registerAfterSearch=true
                                showWorkerSearch=false
                            })
                    }
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
                .sheet(isPresented:$showStockRegistration,onDismiss:{
                    Task {await refreshDispensing(retry:false)}
                }) {
                    NavigationStack {
                        N2SimpleInventoryView(initialOperation:"lot")
                            .toolbar {
                                ToolbarItem(placement:.topBarTrailing) {
                                    Button("Cerrar") {showStockRegistration=false}
                                }
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
                .onChange(of:step) {_,_ in scheduleDraft() }
                .alert("Faltan datos para continuar",isPresented:$showValidation) {
                    Button("Ir al campo") {focusFirstMissing(context)}
                    Button("Cerrar",role:.cancel){}
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

    @ViewBuilder private func formContents(_ context:N2FormContext)->some View {
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
                            ForEach(form.items) {med in
                                VStack(alignment:.leading,spacing:5) {
                                    Text(medicationName(med.code,context)).font(.headline)
                                    Text("Cantidad clínica: \(med.quantity)").font(.caption)
                                    if let r=savedKardex[med.id] {Text("Kardex R: \(r.formatted())").font(.caption)}
                                    Text(savedLines[med.id] ?? "Atención conservada").font(.caption).foregroundStyle(.secondary)
                                    if savedLines[med.id]?.hasPrefix("Incidencia de inventario:")==true {
                                        Button("Resolver en Inventario") {showStockRegistration=true}.buttonStyle(.bordered)
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
    private func formChanged(_ old:N2NativeFormDraft,_ new:N2NativeFormDraft,_ context:N2FormContext) {
        if highlightedField != nil {highlightedField=nil}
        if !form.blueBandage {form.returned=false}
        if old.items != new.items || old.procedures != new.procedures {
            form.refreshProcedureSuggestions(catalog:context.products)
        }
        scheduleDraft()
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
                            let violations=target<=step ? [] :
                                (step..<target).flatMap {index in
                                    issueCodes(for:index,context:context)
                                }
                            if violations.isEmpty {
                                withAnimation(reduceMotion ? nil : DanperStyle.animation){step=target}
                            } else {presentValidation(violations)}
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
                }.padding(12).danperGlassSurface(cornerRadius:16)
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
                        workerDNIFocused=false
                        workerNameFocused=false
                        showWorkerSearch=true
                    } label: {
                        Label("Buscar en padrón",systemImage:"person.2")
                            .font(.subheadline.weight(.semibold))
                            .lineLimit(2).minimumScaleFactor(0.8)
                            .frame(maxWidth:.infinity,minHeight:48)
                    }
                    .buttonStyle(DanperSecondaryButton())
                    .accessibilityIdentifier("attention-browse-workers")
                    .id("attention-worker-search")
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

        }
    }
    private func clinicalSection()->some View {
        VStack(alignment:.leading,spacing:16) {
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
                        ],openRequest:highlightedField=="allergy-status" ? choiceOpenCounter : 0,
                          highlighted:highlightedField=="allergy-status")
                        .id("allergy-status")
                    if allergyStatus=="known" {
                        DanperField(title:"Sustancias reportadas",highlighted:highlightedField=="allergy-substances") {
                            TextField("Indica las sustancias",text:$allergySubstances,
                                      axis:.vertical).lineLimit(2...5)
                                .focused($focusedField,equals:"allergy-substances")
                        }.id("allergy-substances")
                    }
                    if !allergyFeedback.isEmpty {
                        Label(allergyFeedback,systemImage:allergySaveFailed
                              ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(allergySaveFailed ? Color.orange : Color.green)
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
        DanperPanel("Evaluación clínica") {
            DanperDateField(title:"Fecha de atención",selection:dateSelection)
                .id("clinical-date")
            DanperField(title:"Hora de atención",highlighted:highlightedField=="clinical-time") {
                TextField("HH:mm",text:$form.time).focused($focusedField,equals:"time")
                    .keyboardType(.numbersAndPunctuation)
            }.id("clinical-time")
            DanperChoiceField(title:"Tipo de atención",selection:$form.category,
                options:categories,openRequest:highlightedField=="clinical-category" ? choiceOpenCounter : 0,
                highlighted:highlightedField=="clinical-category")
                .id("clinical-category")
            if N1hClinicalValidator.systemRequired.contains(form.category) {
                DanperChoiceField(title:"Sistema afectado",selection:$form.system,
                    options:systems,openRequest:highlightedField=="clinical-system" ? choiceOpenCounter : 0,
                    highlighted:highlightedField=="clinical-system")
                    .id("clinical-system")
                if form.system=="OSTEOMUSCULAR" {
                    DanperChoiceField(title:"Segmento osteomuscular",
                        selection:segmentChoice,
                        options:N2OsteomuscularSegments.options + [N2OsteomuscularSegments.custom],
                        openRequest:highlightedField=="clinical-segment" ? choiceOpenCounter : 0,
                        highlighted:highlightedField=="clinical-segment")
                        .accessibilityIdentifier("clinical-osteomuscular-segment-choice")
                        .id("clinical-segment")
                    if segmentChoice.wrappedValue==N2OsteomuscularSegments.custom {
                        DanperField(title:"Especificar segmento anatómico",
                                    highlighted:highlightedField=="clinical-segment") {
                            TextField("Describe la zona afectada",text:$form.segment)
                                .focused($focusedField,equals:"segment")
                                .accessibilityIdentifier("clinical-segment-other")
                        }
                    }
                }
            }
            DanperField(title:"Diagnóstico presuntivo",highlighted:highlightedField=="clinical-diagnosis") {
                TextField("Escribe para buscar o registrar",text:$form.diagnosis,axis:.vertical)
                    .accessibilityIdentifier("clinical-diagnosis-input")
                    .focused($focusedField,equals:"diagnosis").lineLimit(2...5)
            }.id("clinical-diagnosis")
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
            independentProceduresSection()
                .id("treatment-procedures")
            if !layoutDetailOnly {
                medicationPickerSection(context)
            }
            medicationFields(context)
                .id("treatment-medications")
        }
    }

    private func independentProceduresSection()->some View {
            DanperPanel("Procedimientos independientes") {
                Text("Puedes registrar una curación u otro procedimiento por separado, incluso sin medicamentos.")
                    .font(.subheadline).foregroundStyle(.secondary)
                DanperCheckRow(selected:Binding(
                    get:{form.procedures.contains("CURACION DE HERIDA")},
                    set:{enabled in
                        if enabled {
                            if !form.procedures.contains("CURACION DE HERIDA") {
                                form.procedures.append("CURACION DE HERIDA")
                            }
                        } else {
                            form.procedures.removeAll{$0=="CURACION DE HERIDA"}
                        }
                    }
                )) {
                    Text("Se realizó CURACION DE HERIDA").font(.subheadline.weight(.semibold))
                }
                Button {
                    withAnimation(reduceMotion ? nil : DanperStyle.animation) {
                        showOtherProcedures.toggle()
                    }
                } label: {
                    HStack(spacing:8) {
                        Image(systemName:showOtherProcedures ? "chevron.down" : "chevron.right")
                        Text("Otro procedimiento (opcional)").font(.subheadline.weight(.medium))
                        Spacer()
                        if !form.procedures.filter({$0 != "CURACION DE HERIDA"}).isEmpty {
                            Text("\(form.procedures.filter{$0 != "CURACION DE HERIDA"}.count)")
                                .font(.caption.weight(.bold))
                        }
                    }.foregroundStyle(.primary)
                }
                .buttonStyle(.plain)
                .frame(minHeight:44)
                .accessibilityIdentifier("expand-other-procedures")
                if showOtherProcedures {
                    ForEach(procedureGroups.indices,id:\.self) { index in
                        let group=procedureGroups[index]
                        let choices=group.values.filter{$0 != "CURACION DE HERIDA"}
                        if !choices.isEmpty {
                            VStack(alignment:.leading,spacing:9) {
                                Text(group.title)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                ForEach(choices,id:\.self) { value in
                                    procedureOption(value)
                                }
                            }.padding(9)
                                .background(DanperStyle.canvas,
                                            in:RoundedRectangle(cornerRadius:14))
                        }
                    }
                }
                if form.hasWound {
                    DanperChoiceField(title:"¿Se envió la foto?",selection:Binding(
                        get:{form.photoReviewed ? (form.photoSent ? "SI" : "NO") : ""},
                        set:{form.photoReviewed = !$0.isEmpty;form.photoSent = $0=="SI"}
                    ),options:["SI","NO"],labels:["SI":"Sí, se envió","NO":"No se envió"],
                        openRequest:highlightedField=="treatment-photo" ? choiceOpenCounter : 0,
                        highlighted:highlightedField=="treatment-photo")
                        .id("treatment-photo")
                }
                DanperCheckRow(selected:$form.blueBandage) {
                    Text("Se colocó banda o curita azul").font(.subheadline)
                }
                if form.blueBandage {
                    DanperCheckRow(selected:$form.returned) {
                        Text("Se devolvió la banda o curita").font(.subheadline)
                    }
                }
            }
    }

    private func medicationPickerSection(_ context:N2FormContext)->some View {
        DanperPanel("Medicamentos e insumos") {
            Text("Cada producto mantiene su propio procedimiento. Toca una fila para editar cantidades y declaración de consumo.")
                .font(.caption).foregroundStyle(.secondary)
            Button {withAnimation(reduceMotion ? nil : DanperStyle.animation){chooseProduct.toggle()}} label: {
                Label(form.items.isEmpty ? "Agregar medicamento/insumo" : "Agregar otro medicamento/insumo",systemImage:"plus")
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

            Label("Inventario compartido · conteo consolidado",systemImage:"shippingbox")
                .font(.footnote).foregroundStyle(.secondary)
            Text("\(context.products.clinical.count) productos · selección múltiple")
                .font(.footnote).foregroundStyle(.secondary)
        }
    }

    private func appendClinicalMedication(_ code:String) {
        let med=N2FormMedication(code:code)
        form.items.append(med)
        // Build 222: insertion shows a compact row. Expand only after a tap.
        expandedMedication=nil
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
    /// The Build 222 lists medicines in collapsible procedure groups.
    /// Grouping is presentational; editing still binds to the same medications.
    private var medicationGroupNames:[String] {
        var groups:[String]=[]
        for med in form.items {
            let name=med.procedure.isEmpty ? "POR CONFIRMAR" : med.procedure
            if !groups.contains(name){groups.append(name)}
        }
        return groups
    }
    /// Split group layout from individual editing; SwiftUI's type checker
    /// must not infer the entire medication/FEFO editor in one expression.
    @ViewBuilder
    private func medicationFields(_ context:N2FormContext)->some View {
        ForEach(medicationGroupNames,id:\.self) { group in
            medicationGroup(group,context:context)
        }
    }
    private func procedureGroupName(_ name:String)->String {
        name.isEmpty ? "POR CONFIRMAR" : name
    }
    private func medicationGroup(_ group:String,context:N2FormContext)->some View {
        let quantity=form.items.filter{
            procedureGroupName($0.procedure)==group
        }.count
        let collapsed=collapsedMedicationGroups.contains(group)
        return DanperPanel {
            Button {
                withAnimation(reduceMotion ? nil : DanperStyle.animation) {
                    if collapsed {
                        collapsedMedicationGroups.remove(group)
                    } else {
                        collapsedMedicationGroups.insert(group)
                    }
                }
            } label: {
                HStack(spacing:10) {
                    Text(group.capitalized(with:Locale(identifier:"es_PE")))
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.primary)
                    Text("\(quantity) producto(s)")
                        .font(.caption).foregroundStyle(.secondary)
                    Spacer(minLength:0)
                    Image(systemName:collapsed ? "chevron.down" : "chevron.up")
                        .font(.caption).foregroundStyle(.secondary)
                }
                .frame(maxWidth:.infinity,minHeight:45,alignment:.leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("medication-procedure-group-"+group)
            if !collapsed {
                ForEach($form.items) { $medication in
                    if procedureGroupName(medication.procedure)==group {
                        N2MedicationRowView(
                            medication:$medication,
                            context:context,
                            visitDate:form.date,
                            dispensingSite:form.dispensingSite,
                            procedures:procedures,
                            allergyWarning:!allergyTextMatches(
                                medication.code,context:context).isEmpty,
                            expandedID:$expandedMedication,
                            onRemove:{
                                form.items.removeAll{$0.id==medication.id}
                            },onMappingConfirmed:{
                                Task { @MainActor in
                                    autosaveTask?.cancel()
                                    do {
                                        self.context=try await vault.clinicalFormContext()
                                        fault=false
                                    }
                                    catch {status="No se pudo actualizar el inventario. Vuelve a abrir la atención."}
                                }
                            })
                    }
                }
            }
        }
    }
    /// Reuses the clinical validator's ordered field IDs instead of inferring
    /// destinations from translated error strings or UI labels.
    private func issueCodes(for stage:Int,context:N2FormContext)->[String] {
        var issues=form.clinicalIssues(step:stage,context:context)
        if stage==2 {
            if form.procedures.isEmpty && form.items.isEmpty {
                issues.append("treatment-selection")
            }
            if form.hasWound && !form.photoReviewed {
                issues.append("treatment-photo")
            }
        }
        return issues
    }
    private func issueMessage(_ code:String)->String {
        let extra=[
            "treatment-selection":"Selecciona al menos un procedimiento o producto.",
            "treatment-site":"Selecciona el tópico de dispensación.",
            "treatment-photo":"Indica si se envió la foto."
        ]
        return N2ClinicalFormOptions.messages[code] ?? extra[code] ?? "Revisa el campo indicado."
    }
    private func presentValidation(_ codes:[String]) {
        guard let first=codes.first else{return}
        validationIssueCode=first
        validationMessage=codes.map(issueMessage).joined(separator:"\n")
        showValidation=true
    }
    private func focusFirstMissing(_ context:N2FormContext) {
        let code=validationIssueCode ?? (0...3)
            .flatMap{issueCodes(for:$0,context:context)}.first
        guard let code else{return}
        let field:String
        let destination:Int
        switch code {
        case "worker-dni","worker-name":
            step=0
            showWorkerSearch=true
            return
        case "clinical-date": destination=1;field="clinical-date"
        case "clinical-time": destination=1;field="clinical-time"
        case "clinical-category": destination=1;field="clinical-category"
        case "clinical-system": destination=1;field="clinical-system"
        case "clinical-segment": destination=1;field="clinical-segment"
        case "clinical-diagnosis": destination=1;field="clinical-diagnosis"
        case "allergy-status": destination=1;field="allergy-status"
        case "allergy-substances": destination=1;field="allergy-substances"
        case "treatment-items": destination=2;field="treatment-medications"
        case "treatment-selection": destination=2;field="treatment-procedures"
        case "treatment-site": destination=2;field="treatment-site"
        case "treatment-photo": destination=2;field="treatment-photo"
        case "result-permission-time": destination=3;field="result-permission-time"
        default:destination=step;field="validation-top"
        }
        highlightedField=field
        withAnimation(reduceMotion ? nil : DanperStyle.animation) {
            step=destination
        }
        Task { @MainActor in
            await Task.yield()
            scrollIssueRequest=DanperScrollRequest(fieldID:field)
            await Task.yield()
            switch field {
            case "clinical-time":focusedField="time"
            case "clinical-segment":focusedField="segment"
            case "clinical-diagnosis":focusedField="diagnosis"
            case "allergy-substances":focusedField="allergy-substances"
            case "result-permission-time":focusedField="permission-time"
            case "clinical-category","clinical-system","allergy-status",
                 "treatment-site","treatment-photo":
                choiceOpenCounter+=1
            case "treatment-medications":
                if let first=form.items.first {
                    collapsedMedicationGroups.removeAll()
                    expandedMedication=first.id
                } else {chooseProduct=true}
            default:break
            }
        }
    }
    private var extraTreatmentRequirements:[String] {
        var missing=[String]()
        if form.procedures.isEmpty && form.items.isEmpty {missing.append("Selecciona al menos un procedimiento o producto.")}
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
            DanperPanel("Resultado y controles") {
                DanperChoiceField(title:"Situación al finalizar",selection:$form.permission,options:["NO","SI"],
                                  labels:["NO":"Continúa laborando","SI":"Se retira con permiso"])
                if form.permission=="SI" {
                    DanperField(title:"Hora del permiso",highlighted:highlightedField=="result-permission-time") {
                        TextField("HH:mm",text:$form.permissionTime)
                            .keyboardType(.numbersAndPunctuation)
                            .focused($focusedField,equals:"permission-time")
                    }.id("result-permission-time")
                }
                if !pendingRequirements.isEmpty {
                    Label(pendingRequirements.joined(separator:"\n"),systemImage:"exclamationmark.triangle")
                        .font(.footnote).foregroundStyle(.orange).fixedSize(horizontal:false,vertical:true)
                }
                Text("Antes de guardar, DANPER preguntará por cada frasco o caja si abriste uno nuevo (Kardex 1) o usaste el que ya estaba abierto (Kardex 0). No necesitas abrir los detalles de cada insumo. Si no hay envases disponibles, quedará pendiente.")
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
                        let errors=issueCodes(for:step,context:context)
                        if errors.isEmpty {
                            highlightedField=nil
                            withAnimation(reduceMotion ? nil : DanperStyle.animation){step+=1}
                        } else {presentValidation(errors)}
                    } else {
                        let errors=(0...3).flatMap{issueCodes(for:$0,context:context)}
                        if errors.isEmpty {beginContainerReview(context)}

                        else {presentValidation(errors)}
                    }
                } label: {
                    if dynamicTypeSize.isAccessibilitySize {
                        Text(step<3 ? "Siguiente" : (busy ? "Guardando…" : "Guardar"))
                            .lineLimit(1).fixedSize(horizontal:false,vertical:true)
                    } else {
                        Label(step<3 ? "Siguiente" :
                              (busy ? "Confirmando…" : "Guardar atención"),
                              systemImage:step<3 ? "arrow.right" : "checkmark.shield.fill")
                    }
                }
                .buttonStyle(DanperPrimaryButton())
                .disabled(busy)
            }

        }
        .padding(.horizontal,16)
        .padding(.top,10)
        .padding(.bottom,6)
        .background(.regularMaterial)
        .overlay(alignment:.top) {Rectangle().fill(.quaternary).frame(height:0.5)}
    }

    @MainActor
    private func refreshDispensing(retry:Bool) async {
        guard !busy else{return}
        busy=true
        defer {busy=false}
        do {
            let current=try await vault.clinicalFormContext()
            if retry {_=try await vault.retryDispensing(visitID:form.id,expectedRevision:current.revision)}
            context=try await vault.clinicalFormContext()
            savedLines=try await vault.dispensingStatus(visitID:form.id)
            savedKardex=Dictionary(uniqueKeysWithValues:try await vault.dispensingLines(visitID:form.id).compactMap{line in line.kardexQuantity.map{(line.id,$0)}})
            status="Atención conservada. Consumos verificados nuevamente; revisa los pendientes."
        } catch {status="No se pudo conciliar. La atención original permanece registrada; revisa los datos físicos y la cronología."}
    }
    private func indexWorkers(_ context:N2FormContext) {
        workersByDNI=Dictionary(context.workers.map{($0.dni,$0)},uniquingKeysWith:{first,_ in first})
    }
    private func blankForm()->N2NativeFormDraft {
        var result=N2NativeFormDraft()
        if !vault.isClinical {result.responsible="OPERADOR FICTICIO";result.responsibleDni="00000091"}
        return result
    }
    @MainActor private func load() async {
        do {
            let prepared=try await vault.prepareClinicalForm()
            // Consistent one-revision view; avoids reopening/decrypting
            // and validating the whole clinical database for drafts.
            context=prepared.context
            indexWorkers(prepared.context)
            drafts=prepared.drafts
            if let requestedDraftID {
                guard let recovered=drafts.first(where:{$0.id==requestedDraftID}) else {
                    fault=true
                    status="El borrador solicitado no existe o fue eliminado. No se han modificado registros."
                    return
                }
                form=recovered.form
                step=recovered.stage
                status="Borrador recuperado."
            } else {
                let (date,time)=limaClock()
                if !vault.isClinical {form.responsible="OPERADOR FICTICIO";form.responsibleDni="00000091"}
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
        guard !editingAllergy,let current=context,form.dni==dni else{return}
        editingAllergy=true
        var didCommit=false
        allergySaveFailed=false
        allergyFeedback=""
        // A draft autosave can race the journal revision; stop an outstanding
        // debounced task before the short, verified allergy transaction.
        autosaveTask?.cancel()
        defer {
            editingAllergy=false
            if didCommit {scheduleDraft()}
        }
        do {
            let statusToSave=allergyStatus
            let normalized=statusToSave=="known" ? allergySubstances : ""
            let revision=try await vault.currentRevision()
            let committed=try await vault.reviewAllergiesRevision(
                dni:dni,status:statusToSave,substances:normalized,
                at:now,expectedRevision:revision)
            if revision==current.revision {
                context=current.withCommittedAllergy(
                    dni:dni,status:statusToSave,substances:normalized,
                    revision:committed)
            } else {
                // An independent draft, roster or inventory update happened
                // while the form was open; never silently overwrite its context.
                context=try await vault.clinicalFormContext()
            }
            didCommit=true
            status="Revisión de alergias guardada."
            allergyFeedback="Alergias revisadas y guardadas"
            allergySaveFailed=false
            fault=false
        } catch {
            // Never display a green success when the transaction was rejected.
            // Retain user input to allow retry and avoid clobbering the draft.
            status="No se pudo guardar la revisión de alergias."
            allergyFeedback="No se guardaron los cambios. Intenta nuevamente."
            allergySaveFailed=true
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
        guard !layoutOnly,let context,!busy,!saved,!fault,!editingAllergy,
              meaningfulDraft else{return}
        autosaveTask?.cancel()
        let version=form
        autosaveTask=Task { @MainActor in
            if !immediate {
                do {try await Task.sleep(for:.milliseconds(650))}
                catch{return}
            }
            guard !Task.isCancelled,!editingAllergy else{return}
            do{
                let latestRevision=try await vault.currentRevision()
                // A cancelled autosave must never race the final save with
                // the same journal revision or replace its success banner.
                guard !Task.isCancelled,!saved,!busy,!editingAllergy else{return}
                let patch=try version.makeDraftPatch(context:context,stage:step)
                let timestamp=max(Int64(Date().timeIntervalSince1970*1000),
                                  lastAutosaveTimestamp+1)
                let committed=try await vault.saveDraft(
                    id:version.id,changes:patch,at:timestamp,
                    expectedRevision:latestRevision)
                guard !Task.isCancelled,!saved,!busy,!editingAllergy else{return}
                if let existing=self.context,existing.revision==latestRevision {
                    self.context=existing.withCommittedRevision(committed.revision)
                }
                lastAutosaveTimestamp=timestamp
                await N2DraftReminder.schedule(id:version.id,mode:vault.mode)
                status="Borrador guardado."
            }catch{
                if !Task.isCancelled && !saved && !editingAllergy {
                    fault=true
                    status="No se pudo guardar el borrador. Edición bloqueada hasta verificar el almacenamiento."
                }
            }
        }
    }
    /// Each container is confirmed in an explicit save-time dialog. Editing
    /// the medication row is no longer needed just to declare an opening.
    private func containerCodes(_ medication:N2FormMedication,
                                context:N2FormContext)->Set<String> {
        let verified=context.products.authorizedNursingOptions(for:medication.code)
        let operational=context.operationalMappings.filter{
            $0.clinicalCode==medication.code
        }.map(\.inventoryID)
        return Set(verified.map(\.id)+operational)
    }
    private func isContainerMedication(_ medication:N2FormMedication,
                                        context:N2FormContext)->Bool {
        let ids=containerCodes(medication,context:context)
        if context.lots.contains(where:{
            ids.contains($0.kardexCode) &&
            N2ContainerAccounting.isContainer(unit:$0.unit)
        }) {return true}
        return context.products.nursing.contains(where:{
            ids.contains($0.id) &&
            ($0.unit.map{N2ContainerAccounting.isContainer(unit:$0)} ?? false)
        })
    }
    private var containerDecisionMedication:N2FormMedication? {
        guard containerDecisionIDs.indices.contains(containerDecisionIndex) else{
            return nil
        }
        let itemID=containerDecisionIDs[containerDecisionIndex]
        return form.items.first(where:{$0.id==itemID})
    }
    private var containerDecisionName:String {
        guard let item=containerDecisionMedication else{return "el producto"}
        return context?.products.clinical.first(where:{$0.code==item.code})?.name
            ?? item.code
    }
    private var containerDecisionTitle:String {
        guard let item=containerDecisionMedication,let context else{
            return "¿Abriste un envase nuevo?"
        }
        let codes=containerCodes(item,context:context)
        let lotUnits=context.lots.filter{codes.contains($0.kardexCode)}.map(\.unit)
        let catalogUnits=context.products.nursing.filter{codes.contains($0.id)}.compactMap(\.unit)
        let units=lotUnits + catalogUnits
        let kind=units.contains(where:{$0.uppercased()=="CJA"}) ? "caja" :
            units.contains(where:{$0.uppercased()=="FCO"}) ? "frasco" : "envase"
        return "¿Abriste un \(kind) nuevo?"
    }
    private var containerDecisionMessage:String {
        let order=containerDecisionIndex+1
        let total=containerDecisionIDs.count
        return "\(containerDecisionName) · \(order) de \(total). SÍ: abriste una caja o frasco nuevo (Kardex 1) y confirmas agotado el anterior si había uno abierto. NO: utilizaste uno abierto anteriormente (Kardex 0), sin restar una nueva caja. Si su apertura anterior no figura en el inventario, DANPER conservará tu declaración sin crear una apertura pasada ni alterar las existencias."
    }
    private func beginContainerReview(_ context:N2FormContext) {
        guard !busy,!saved else{return}
        Task {await confirm()}
    }

    private func recordContainerDecision(opened:Bool) {
        guard let context,let item=containerDecisionMedication,
              let idx=form.items.firstIndex(where:{$0.id==item.id}) else{
            showContainerDecision=false
            containerDecisionIDs=[]
            return
        }
        let linked=containerCodes(item,context:context)
        let alreadyOpen=context.lots.contains(where:{
            linked.contains($0.kardexCode) && $0.openContainers>0
        })
        let earlierOpened=form.items.prefix(idx).contains(where:{prior in
            prior.approveOpening &&
            !containerCodes(prior,context:context).isDisjoint(with:linked)
        })
        // Yes confirms exhaustion of the prior open container. This flag is
        // assessed atomically in the ledger, never treated as an extra debit.
        form.items[idx].reusePreviouslyOpened = !opened
        form.items[idx].approveOpening=opened
        form.items[idx].newContainers=opened ? 1:0
        form.items[idx].closePriorContainer=opened && (alreadyOpen || earlierOpened)
        // Clinical quantity remains the number of needles/items used.
        // For a box/bottle declared REUSED, physical volume is not
        // implicitly the clinical quantity; official nursing R is zero.
        form.items[idx].physicalQuantity=0
        let available=context.options(for:item.code,at:form.date,
                                      site:form.dispensingSite)
        let previouslySelected=available.first(where:{
            $0.id==form.items[idx].selectedLotID
        })
        // A previously selected SEALED lot must never defeat the user's
        // explicit "No, I reused an OPEN one". Pick the earliest-expiring
        // verifiably open lot even if the row already had another lot ID.
        // If the opening happened on an earlier row of this same visit,
        // the FEFO transaction will see that staged opening.
        let matchingExisting=opened
            ? (previouslySelected?.sealed ?? 0)>0
            : ((previouslySelected?.openContainers ?? 0)>0 ||
               (earlierOpened && previouslySelected != nil))
        if !matchingExisting {
            let preferred:N2FormLot?
            if opened {
                preferred=available.first(where:{$0.sealed>0})
            } else {
                preferred=available.first(where:{$0.openContainers>0})
                    ?? (earlierOpened ? available.first(where:{$0.sealed>0}) : nil)
            }
            // Do not silently choose a sealed box for a declared reuse.
            form.items[idx].selectedLotID=preferred?.id ?? ""
        }
        showContainerDecision=false
        containerDecisionIndex+=1
        if containerDecisionIndex==containerDecisionIDs.count {
            containerDecisionIDs=[]
            containerDecisionIndex=0
            Task {await confirm()}
        }else {
            Task { @MainActor in
                await Task.yield()
                showContainerDecision=true
            }
        }
    }

    @MainActor
    private func confirm() async {
        guard let context,!busy,!saved,!fault else{return}
        let previousAutosave=autosaveTask
        autosaveTask=nil
        previousAutosave?.cancel()
        busy=true
        status="Guardando la atención y verificando los consumos…"
        defer{busy=false}
        // If an autosave already reached the journal, allow it to complete
        // BEFORE reading the revision for this final, atomic clinical save.
        await previousAutosave?.value
        do {
            let fresh=try await vault.clinicalFormContext()
            let raw=try form.makeSavedVisit(context:fresh)
            _=try await vault.saveAttention(
                raw,at:now,expectedRevision:fresh.revision)
            saved=true
            fault=false
            drafts.removeAll(where:{$0.id==form.id})
            N2DraftReminder.cancel(id:form.id,mode:vault.mode)
            status="Atención guardada correctamente."
            // A single read provides BOTH physical status and R. Avoid four
            // consecutive decryptions of a 9,000+ worker clinical vault.
            do {
                let lines=try await vault.dispensingLines(visitID:form.id)
                savedLines=Dictionary(uniqueKeysWithValues:lines.map{($0.id,$0.result)})
                savedKardex=Dictionary(uniqueKeysWithValues:lines.compactMap{
                    line in line.kardexQuantity.map{(line.id,$0)}
                })
            }catch {
                status="Atención guardada y cifrada. El detalle de consumos no se pudo actualizar: consúltalo en Historial."
            }
        }catch {
            status="No se pudo confirmar la atención. No repitas el registro sin revisar primero Historial y Borradores."
            fault=true
        }
    }
    @MainActor
    private func resume(_ record:N2RecoverableDraft) {
        autosaveTask?.cancel()
        form=record.form
        step=record.stage
        collapsedMedicationGroups.removeAll()
        expandedMedication=nil
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
            let freshRevision=try await vault.currentRevision()
            _=try await vault.deleteDraft(
                id:id,expectedRevision:freshRevision)
            N2DraftReminder.cancel(id:id,mode:vault.mode)
            // Load the updated context and draft list from ONE generation.
            let prepared=try await vault.prepareClinicalForm()
            drafts=prepared.drafts
            context=prepared.context
            if form.id==id {
                autosaveTask?.cancel()
                form=blankForm()
                let (date,time)=limaClock()
                if !vault.isClinical {form.responsible="OPERADOR FICTICIO";form.responsibleDni="00000091"}
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
        form=blankForm()
        collapsedMedicationGroups.removeAll()
        expandedMedication=nil
        let (date,time)=limaClock()
        form.date=date
        form.time=time
        step=0
        status="Nuevo registro clínico N2."
    }
}

