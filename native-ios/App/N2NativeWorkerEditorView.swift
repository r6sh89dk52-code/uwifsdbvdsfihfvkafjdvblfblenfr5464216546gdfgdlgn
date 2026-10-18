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
    @State private var birthDate=Date()
    @State private var ubigeo=""
    @State private var revision:Int?
    @State private var busy=false
    @State private var savedDNI=""
    @State private var status=""
    @State private var failed=false

    private func iso(_ date:Date)->String {
        let f=DateFormatter()
        f.calendar=Calendar(identifier:.gregorian)
        f.timeZone=TimeZone(identifier:"America/Lima")
        f.dateFormat="yyyy-MM-dd"
        return f.string(from:date)
    }
    private var today:String{iso(Date())}
    private var birthISO:String{hasBirthDate ? iso(birthDate) : ""}
    private var ageLabel:String {
        guard hasBirthDate,
              let years=N2WorkerAge.years(birthDate:birthISO,on:today) else{return ""}
        return "Edad actual: \(years) años. Se actualizará automáticamente."
    }
    private var ready:Bool {
        revision != nil && !busy && savedDNI.isEmpty &&
        !existingDNI.contains(dni) && dni.count==8 && dni.hasPrefix("000000") &&
        dni.utf8.allSatisfy{(48...57).contains($0)} &&
        names.trimmingCharacters(in:.whitespacesAndNewlines).count>=5 &&
        (sex.isEmpty || ["M","F"].contains(sex)) &&
        (!hasBirthDate || N2WorkerAge.years(birthDate:birthISO,on:today) != nil)
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
                DanperPanel("Identificación") {
                    DanperField(title:"DNI") {
                        TextField("Ej. 00000006",text:$dni)
                            .keyboardType(.numberPad)
                            .disabled(!savedDNI.isEmpty)
                    }
                    Text("En esta beta utiliza un DNI de ocho cifras que comience por 000000.")
                        .font(.caption).foregroundStyle(.secondary)
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
                        Label("No se cargó el catálogo completo de áreas. Puedes escribir el área manualmente.",
                              systemImage:"exclamationmark.triangle")
                            .font(.footnote).foregroundStyle(.orange)
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
                    if hasBirthDate {
                        DatePicker("Fecha de nacimiento",selection:$birthDate,
                                   in:...Date(),displayedComponents:.date)
                            .datePickerStyle(.compact)
                            .environment(\.locale,Locale(identifier:"es_PE"))
                        if !ageLabel.isEmpty {
                            Label(ageLabel,systemImage:"calendar")
                                .font(.footnote).foregroundStyle(.secondary)
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
                if let onSaved, !savedDNI.isEmpty {
                    Button {onSaved(savedDNI)} label: {
                        Label("Continuar atención",systemImage:"arrow.right.circle.fill")
                    }.buttonStyle(DanperPrimaryButton())
                } else {
                    Button {save()} label: {
                        Label(busy ? "Guardando…" : "Guardar trabajador",
                              systemImage:"person.badge.plus")
                    }.buttonStyle(DanperPrimaryButton()).disabled(!ready)
                }
            }.padding(16).background(.regularMaterial)
        }
        .navigationTitle("Nuevo trabajador")
        .danperFormChrome()
        .sensoryFeedback(.success,trigger:savedDNI) {_,_ in haptics}
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
        if let url=Bundle.main.url(forResource:"n2-organization-areas",
                                   withExtension:"json",subdirectory:"N1sDemoResources"),
           let data=try? Data(contentsOf:url),
           let list=try? JSONDecoder().decode([N2OfficialArea].self,from:data),
           N2AreaAutocomplete.isComplete(official:list) {
            officialAreas=list
            areaCatalogIncomplete=false
        } else {
            officialAreas=[]
            areaCatalogIncomplete=true
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
    private func save() {
        guard ready,let current=revision else{return}
        let candidate=dni
        let fields:[String:Any]=[
            "dni":candidate,
            "name":names.trimmingCharacters(in:.whitespacesAndNewlines),
            "area":area.trimmingCharacters(in:.whitespacesAndNewlines),
            "labor":labor.trimmingCharacters(in:.whitespacesAndNewlines),
            "site":site,"sex":sex,
            "age":N2WorkerAge.years(birthDate:birthISO,on:today)
                .map(String.init) ?? "",
            "birthDate":birthISO,
            "ubigeo":ubigeo.trimmingCharacters(in:.whitespacesAndNewlines)
        ]
        guard let bytes=try? JSONSerialization.data(withJSONObject:fields) else{return}
        busy=true
        Task {
            defer {busy=false}
            do {
                let result=try await N2SyntheticTrialIOSVault.shared.registerWorker(
                    bytes,at:Int64(Date().timeIntervalSince1970*1000),
                    expectedRevision:current)
                revision=result.revision
                existingDNI.insert(candidate)
                savedDNI=candidate
                failed=false
                status="Trabajador registrado correctamente."
            } catch {
                failed=true
                status="No se pudo registrar. Comprueba el DNI y vuelve a intentarlo."
            }
        }
    }
}
