import Foundation
import SwiftUI
import DanperCore

/// Manual worker registration into the isolated clinical store.
/// If entered from an attention, the completed person returns to that encounter.
struct N2NativeWorkerEditorView:View {
    private let onSaved:((String)->Void)?
    init(initialDNI:String="",onSaved:((String)->Void)?=nil) {
        self.onSaved=onSaved
        _dni=State(initialValue:initialDNI)
    }
    @AppStorage("danper.haptics.enabled") private var haptics=true
    @State private var existingDNI=Set<String>()
    @State private var existingAreas=[String:String]()
    @State private var officialAreas=[N2OfficialArea]()
    @State private var areaCatalogIncomplete=false
    @State private var areaCatalogDiagnostics=""
    @State private var dni=""
    @State private var names=""
    @State private var area=""
    @FocusState private var areaFocused:Bool
    @State private var areaSuggestionsVisible=true
    @State private var areaRevealTask:Task<Void,Never>?
    @Environment(\.danperReveal) private var reveal
    private let areaAnchor="worker-area-suggestions"
    @State private var labor=""
    @State private var site="LA VENTUROSA"
    @State private var sex=""
    @State private var hasBirthDate=false
    @State private var birthDateText=""
    @State private var manualAgeText=""
    @FocusState private var birthDateFocused:Bool
    @State private var ubigeo=""
    @State private var revision:Int?
    @State private var busy=false
    @State private var savedDNI=""
    @State private var status=""
    @State private var failed=false
    @State private var showSaveError=false
    @State private var validationAttempted=false
    @State private var saveIssues=[String]()

    private func iso(_ date:Date)->String {
        let f=DateFormatter()
        f.calendar=Calendar(identifier:.gregorian)
        f.timeZone=TimeZone(identifier:"America/Lima")
        f.dateFormat="yyyy-MM-dd"
        return f.string(from:date)
    }
    private var today:String{iso(Date())}
    private var birthISO:String {
        guard hasBirthDate else{return ""}
        return N2WorkerBirthDateEntry.validatedISO(birthDateText,on:today) ?? ""
    }
    private var ageLabel:String {
        guard !birthISO.isEmpty,
              let years=N2WorkerAge.years(birthDate:birthISO,on:today) else{return ""}
        return "Edad actual: \(years) años. Se actualizará automáticamente."
    }
    private var birthDateComplete:Bool {
        N2WorkerBirthDateEntry.digits(birthDateText).count==8
    }
    private var ageEntryIsValid:Bool {
        manualAgeText.isEmpty ||
        N2WorkerBirthDateEntry.manualAge(manualAgeText) != nil
    }
    private var registrationIssues:[String] {
        N2WorkerRegistrationGate.issues(
            dni:dni.trimmingCharacters(in:.whitespacesAndNewlines),
            names:names,site:site, isBirthDateKnown:hasBirthDate,
            birthDateValid:!birthISO.isEmpty,
            manuallyEnteredAge:manualAgeText,knownDNI:existingDNI,
            storeAvailable:revision != nil)
    }
    private var ready:Bool {
        !busy && savedDNI.isEmpty && registrationIssues.isEmpty
    }
    private var areaSuggestions:[String] {
        guard areaSuggestionsVisible else{return []}
        return N2AreaAutocomplete.suggestions(
            query:area,site:site,official:officialAreas,
            known:Array(existingAreas.keys))
    }
    var body:some View {
        DanperScrollView {
            VStack(alignment:.leading,spacing:16) {
                if failed || !savedDNI.isEmpty {
                    DanperPanel {
                        Label(status,systemImage:failed ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                            .foregroundStyle(failed ? Color.orange : Color.green)
                            .fixedSize(horizontal:false,vertical:true)
                    }
                }
                if validationAttempted && !saveIssues.isEmpty {
                    DanperPanel("Revisa el registro") {
                        ForEach(saveIssues,id:\.self) { message in
                            Label(message,systemImage:"exclamationmark.circle.fill")
                                .font(.footnote).foregroundStyle(.orange)
                                .fixedSize(horizontal:false,vertical:true)
                        }
                    }
                    .accessibilityIdentifier("worker-registration-validation")
                }
                DanperPanel("Identificación") {
                    DanperField(title:"DNI") {
                        TextField("Ej. 00000006",text:$dni)
                            .keyboardType(.numberPad)
                            .disabled(!savedDNI.isEmpty)
                    }
                    HStack(alignment:.center,spacing:8) {
                        Text("Para esta evaluación se utilizan identificadores de prueba.")
                            .font(.caption).foregroundStyle(.secondary)
                        Spacer(minLength:0)
                        Button("Generar DNI") {
                            if let sample=N2WorkerRegistrationGate.availableDemoDNI(excluding:existingDNI) {
                                dni=sample
                                saveIssues=[]
                                failed=false
                            } else {
                                status="No quedan identificadores disponibles para esta evaluación."
                                failed=true
                                showSaveError=true
                            }
                        }
                        .font(.caption.weight(.semibold))
                        .buttonStyle(.bordered)
                        .tint(DanperStyle.red)
                        .accessibilityIdentifier("generate-demo-worker-dni")
                    }
                    if existingDNI.contains(dni) {
                        Label("Este DNI ya está registrado.",systemImage:"person.crop.circle.badge.exclamationmark")
                            .font(.footnote).foregroundStyle(.orange)
                    }
                    DanperField(title:"Nombres y apellidos") {
                        TextField("Ej. Mariana Torres Salazar",text:$names)
                            .textInputAutocapitalization(.words)
                            .textContentType(.name)
                            .disabled(!savedDNI.isEmpty)
                    }
                }
                DanperPanel("Datos laborales") {
                    DanperChoiceField(title:"Sede",selection:$site,
                        options:["LA VENTUROSA","PLVENTUROSA"],
                        labels:["LA VENTUROSA":"Fundo La Venturosa",
                                "PLVENTUROSA":"Planta La Venturosa"])
                    DanperField(title:"Área") {
                        TextField("Escribe o selecciona un área",text:$area)
                            .textInputAutocapitalization(.words)
                            .focused($areaFocused)
                            .accessibilityIdentifier("worker-area-search")
                    }
                    if areaCatalogIncomplete {
                        Label("No se pudo cargar el catálogo completo. Puedes escribir el área manualmente.",
                              systemImage:"exclamationmark.triangle")
                            .font(.footnote).foregroundStyle(.orange)
                        if !areaCatalogDiagnostics.isEmpty {
                            Text(areaCatalogDiagnostics)
                                .font(.caption2).foregroundStyle(.secondary)
                                .accessibilityIdentifier("area-catalog-diagnostic")
                        }
                    } else {
                        let total=N2AreaAutocomplete.officialCount(site:site,official:officialAreas)
                        if total>0 {
                            Text("\(total) áreas oficiales disponibles para \(site=="PLVENTUROSA" ? "Planta La Venturosa" : "Fundo La Venturosa"). Toca el campo para explorar o escribe para filtrar.")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    if !areaSuggestions.isEmpty {
                        ScrollView(.vertical) {
                            LazyVStack(spacing:6) {
                                ForEach(areaSuggestions,id:\.self) { suggestion in
                                    Button {
                                        area=suggestion
                                        areaFocused=false
                                        areaSuggestionsVisible=false
                                    } label: {
                                        HStack(spacing:10) {
                                            Image(systemName:"building.2")
                                                .foregroundStyle(.secondary)
                                            Text(suggestion)
                                                .font(.subheadline.weight(.semibold))
                                                .foregroundStyle(.primary)
                                                .multilineTextAlignment(.leading)
                                            Spacer(minLength:4)
                                            Image(systemName:"arrow.up.left")
                                                .foregroundStyle(.secondary)
                                        }.padding(12)
                                            .background(DanperStyle.canvas,
                                                        in:RoundedRectangle(cornerRadius:12))
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityIdentifier("area-option-"+N2AreaAutocomplete.normalize(suggestion))
                                }
                            }.padding(6)
                        }
                        .frame(maxHeight:260)
                        .background(DanperStyle.surface,
                                    in:RoundedRectangle(cornerRadius:15))
                        .overlay(RoundedRectangle(cornerRadius:15)
                            .strokeBorder(Color.secondary.opacity(0.15)))
                        .id(areaAnchor)
                    }
                    Text("Puedes escribir un área nueva. Si no existe en el catálogo oficial, su código quedará vacío en Excel.")
                        .font(.caption).foregroundStyle(.secondary)
                    DanperField(title:"Cargo / labor") {
                        TextField("Cargo o función",text:$labor)
                            .textInputAutocapitalization(.words)
                    }
                }
                DanperPanel("Datos personales") {
                    DanperChoiceField(title:"Sexo registrado",selection:$sex,
                        options:["","M","F"],
                        labels:["":"No consignado","M":"Masculino","F":"Femenino"])
                    Toggle("Conozco la fecha de nacimiento",isOn:$hasBirthDate)
                        .tint(DanperStyle.red)
                        .onChange(of:hasBirthDate) {_,known in
                            // Switching modes clears the other entry so it
                            // cannot be accidentally saved as a stale value.
                            if known {
                                manualAgeText=""
                            } else {
                                birthDateText=""
                                birthDateFocused=false
                            }
                        }
                    if hasBirthDate {
                        DanperField(title:"Fecha de nacimiento") {
                            TextField("DD/MM/AAAA",text:$birthDateText)
                                .keyboardType(.numberPad)
                                .focused($birthDateFocused)
                                .accessibilityLabel("Fecha de nacimiento, día mes y año")
                                .accessibilityIdentifier("worker-birth-date-text")
                                .onChange(of:birthDateText) {_,input in
                                    let formatted=N2WorkerBirthDateEntry.format(input)
                                    if input != formatted {birthDateText=formatted}
                                }
                        }
                        if !birthDateComplete {
                            Text("Escribe ocho dígitos, por ejemplo 18101999. Los separadores se agregan automáticamente.")
                                .font(.caption).foregroundStyle(.secondary)
                        } else if birthISO.isEmpty {
                            Label("La fecha no es válida o es posterior a hoy.",
                                  systemImage:"exclamationmark.circle")
                                .font(.caption).foregroundStyle(.orange)
                        } else if !ageLabel.isEmpty {
                            Label(ageLabel,systemImage:"calendar")
                                .font(.footnote).foregroundStyle(.secondary)
                        }
                    } else {
                        DanperField(title:"Edad (opcional)") {
                            TextField("Edad en años",text:$manualAgeText)
                                .keyboardType(.numberPad)
                                .accessibilityIdentifier("worker-manual-age")
                                .onChange(of:manualAgeText) {_,input in
                                    let cleaned=String(decoding:input.utf8
                                        .filter{(48...57).contains($0)}.prefix(3),
                                        as:UTF8.self)
                                    if input != cleaned {manualAgeText=cleaned}
                                }
                        }
                        if !ageEntryIsValid {
                            Label("Introduce una edad válida entre 0 y 120 años.",
                                  systemImage:"exclamationmark.circle")
                                .font(.caption).foregroundStyle(.orange)
                        } else {
                            Text("Si no conoces la fecha de nacimiento, la edad quedará registrada como dato declarado; no se actualizará automáticamente.")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    DanperField(title:"Ubigeo (opcional)") {
                        TextField("Ubigeo",text:$ubigeo)
                            .keyboardType(.numberPad)
                    }
                }
            }.padding(16)
        }
        .scrollDismissesKeyboard(.interactively)
        .safeAreaInset(edge:.bottom) {
            VStack(spacing:8) {
                if !savedDNI.isEmpty {
                    if let onSaved {
                        Button {onSaved(savedDNI)} label: {
                            Label("Continuar atención",systemImage:"arrow.right.circle.fill")
                        }
                        .buttonStyle(DanperPrimaryButton())
                        .accessibilityIdentifier("worker-continue-attention")
                    } else {
                        Label("Puedes consultar este trabajador desde Personal o iniciar una atención.",
                              systemImage:"checkmark.seal.fill")
                            .font(.footnote).foregroundStyle(.green)
                        Button {prepareNextWorker()} label: {
                            Label("Registrar otro trabajador",systemImage:"person.badge.plus")
                        }
                        .buttonStyle(DanperSecondaryButton())
                    }
                } else {
                    Button {save()} label: {
                        HStack {
                            if busy {ProgressView().tint(.white)}
                            Label(busy ? "Guardando trabajador…" : "Guardar trabajador",
                                  systemImage:busy ? "hourglass" : "person.badge.plus")
                        }
                    }
                    .buttonStyle(DanperPrimaryButton())
                    .disabled(busy)
                    .accessibilityIdentifier("worker-save")
                }
            }.padding(16).background(.regularMaterial)
        }
        .navigationTitle("Nuevo trabajador")
        .danperFormChrome()
        .sensoryFeedback(.success,trigger:savedDNI) {_,_ in haptics}
        .alert("No se pudo guardar",isPresented:$showSaveError) {
            Button("Entendido",role:.cancel) {}
        } message: {
            Text(status.isEmpty ? "Revisa los datos del trabajador.":status)
        }
        .task {await load()}
        .onChange(of:site) {previous,newValue in
            if previous != newValue {
                // An area from Fundo cannot be carried silently into PL Venturosa.
                area=""
                areaFocused=false
            }
            updateAreas()
            areaSuggestionsVisible=true
        }
        .onChange(of:area) {_,_ in
            if areaFocused {areaSuggestionsVisible=true}
            requestAreaReveal()
        }
        .onChange(of:areaFocused) {_,active in
            if active {
                areaSuggestionsVisible=true
                requestAreaReveal()
            }
        }
        .onDisappear {areaRevealTask?.cancel()}
    }
    @MainActor
    private func load() async {
        // The official catalog is also compiled into the Swift app target,
        // so Xcode resource folder-reference behavior cannot hide it.
        let compiled=N2GeneratedOfficialAreas.entries
        if N2AreaAutocomplete.isComplete(official:compiled) {
            officialAreas=compiled
            areaCatalogIncomplete=false
            areaCatalogDiagnostics=""
        } else {
        // Retain the legacy JSON resource locations only as a fallback.
        let locations:[URL?]=[
            Bundle.main.url(forResource:"DANPEROfficialAreas",withExtension:"json"),
            Bundle.main.url(forResource:"n2-organization-areas",withExtension:"json",
                            subdirectory:"N1sDemoResources"),
            Bundle.main.url(forResource:"n2-organization-areas",withExtension:"json")
        ]
        var attempts=[String]()
        var validated:[N2OfficialArea]?
        for location in locations {
            guard let url=location else {
                attempts.append("Recurso no encontrado")
                continue
            }
            do {
                let bytes=try Data(contentsOf:url)
                let list=try JSONDecoder().decode([N2OfficialArea].self,from:bytes)
                let fondo=N2AreaAutocomplete.officialCount(site:"LA VENTUROSA",official:list)
                let planta=N2AreaAutocomplete.officialCount(site:"PLVENTUROSA",official:list)
                guard N2AreaAutocomplete.isComplete(official:list) else {
                    attempts.append("\(url.lastPathComponent): fundo \(fondo)/31, planta \(planta)/124")
                    continue
                }
                validated=list
                break
            } catch {
                attempts.append("\(url.lastPathComponent): formato inválido")
            }
        }
        if let validated {
            officialAreas=validated
            areaCatalogIncomplete=false
            areaCatalogDiagnostics=""
        } else {
            officialAreas=[]
            areaCatalogIncomplete=true
            areaCatalogDiagnostics=attempts.joined(separator:" · ")
        }
        }
        do {
            if let vault=try await N2SyntheticTrialIOSVault.shared.inspect() {
                revision=vault.revision
                let context=try await N2SyntheticTrialIOSVault.shared.clinicalFormContext()
                existingDNI=Set(context.workers.map(\.dni))
                workers=context.workers
                updateAreas()
            }
        } catch {
            failed=true
            status="No se pudo abrir Personal. Los registros existentes no se modificaron."
        }
    }
    private func requestAreaReveal() {
        areaRevealTask?.cancel()
        areaRevealTask=Task { @MainActor in
            do {try await Task.sleep(for:.milliseconds(260))} catch{return}
            if areaFocused && !areaSuggestions.isEmpty {reveal(areaAnchor)}
        }
    }
    @State private var workers=[N2FormWorker]()
    private func updateAreas() {
        let unique=Set(workers.filter{$0.site==site && !$0.area.isEmpty}
                          .map(\.area))
        existingAreas=Dictionary(uniqueKeysWithValues:unique.map{($0,$0)})
    }

    @MainActor
    private func prepareNextWorker() {
        dni=""
        names=""
        area=""
        labor=""
        sex=""
        hasBirthDate=false
        birthDateText=""
        manualAgeText=""
        ubigeo=""
        savedDNI=""
        status=""
        failed=false
        showSaveError=false
        validationAttempted=false
        saveIssues=[]
        areaSuggestionsVisible=true
        Task {await load()}
    }

    @MainActor
    private func save() {
        guard !busy,savedDNI.isEmpty else{return}
        validationAttempted=true
        saveIssues=registrationIssues
        if !saveIssues.isEmpty {
            status=saveIssues.first ?? "Comprueba los datos del registro."
            failed=true
            showSaveError=true
            return
        }
        guard let current=revision else {
            status="No se pudieron verificar los datos locales. Cierra el formulario y vuelve a intentarlo."
            failed=true
            showSaveError=true
            return
        }
        let candidate=dni.trimmingCharacters(in:.whitespacesAndNewlines)
        let fields:[String:Any]=[
            "dni":candidate,
            "name":names.trimmingCharacters(in:.whitespacesAndNewlines),
            "area":area.trimmingCharacters(in:.whitespacesAndNewlines),
            "labor":labor.trimmingCharacters(in:.whitespacesAndNewlines),
            "site":site,"sex":sex,
            "age":hasBirthDate
                ? (N2WorkerAge.years(birthDate:birthISO,on:today)
                   .map(String.init) ?? "")
                : (N2WorkerBirthDateEntry.manualAge(manualAgeText)
                   .map(String.init) ?? ""),
            "birthDate":birthISO,
            "ubigeo":ubigeo.trimmingCharacters(in:.whitespacesAndNewlines)
        ]
        guard let bytes=try? JSONSerialization.data(withJSONObject:fields) else {
            status="No se pudieron preparar los datos. Comprueba los campos y vuelve a intentarlo."
            failed=true
            showSaveError=true
            return
        }
        busy=true
        failed=false
        status="Guardando…"
        Task { @MainActor in
            defer {busy=false}
            do {
                var expected=current
                var stored:N2ProtectedStoreSummary?
                do {
                    stored=try await N2SyntheticTrialIOSVault.shared.registerWorker(
                        bytes,at:Int64(Date().timeIntervalSince1970*1000),
                        expectedRevision:expected)
                } catch N2ProtectedStoreError.staleRevision {
                    // Another tab may have saved a draft in the meantime.
                    // Retry one time with the latest revision, without
                    // resetting or replacing the existing encrypted data.
                    let fresh=try await N2SyntheticTrialIOSVault.shared.clinicalFormContext()
                    if fresh.workers.contains(where:{$0.dni==candidate}) {
                        throw N2SnapshotEditError.duplicateWorker
                    }
                    expected=fresh.revision
                    stored=try await N2SyntheticTrialIOSVault.shared.registerWorker(
                        bytes,at:Int64(Date().timeIntervalSince1970*1000),
                        expectedRevision:expected)
                }
                guard let result=stored else {throw N2SnapshotEditError.validationFailed}
                // Read back the persisted record before claiming success.
                let confirmed=try await N2SyntheticTrialIOSVault.shared.clinicalFormContext()
                guard confirmed.workers.contains(where:{$0.dni==candidate}) else {
                    throw N2SnapshotEditError.validationFailed
                }
                revision=result.revision
                existingDNI.insert(candidate)
                workers=confirmed.workers
                updateAreas()
                savedDNI=candidate
                failed=false
                saveIssues=[]
                status="Trabajador guardado correctamente. DNI \(candidate)."
            } catch {
                failed=true
                switch error {
                case N2SnapshotEditError.duplicateWorker:
                    status="Este DNI ya está registrado. Regresa a Personal para seleccionarlo."
                    existingDNI.insert(candidate)
                case N2SnapshotEditError.invalidWorker:
                    status="El registro contiene datos no válidos. Verifica el DNI de prueba, la edad y la fecha de nacimiento."
                case N2SnapshotEditError.validationFailed:
                    status="No se pudo confirmar el guardado. Los registros anteriores se conservan."
                case N2ProtectedStoreError.staleRevision:
                    status="El historial cambió mientras guardabas. Vuelve a intentarlo."
                default:
                    status="No fue posible guardar este trabajador. Comprueba el almacenamiento y vuelve a intentarlo."
                }
                saveIssues=[status]
                showSaveError=true
                #if DEBUG
                print("DANPER trabajador: "+String(reflecting:error))
                #endif
            }
        }
    }
}
