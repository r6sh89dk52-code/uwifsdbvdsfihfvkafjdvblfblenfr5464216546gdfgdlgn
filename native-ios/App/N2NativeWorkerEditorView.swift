import Foundation
import SwiftUI
import DanperCore

private struct N2OfficialAreaOption:Decodable {
    let site:String
    let area:String
    let code:String
}

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
    @State private var officialAreas=[N2OfficialAreaOption]()
    @State private var dni=""
    @State private var names=""
    @State private var area=""
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
        let term=area.trimmingCharacters(in:.whitespacesAndNewlines)
        guard term.count>=2 else{return []}
        let official=officialAreas.filter{$0.site==site}.map(\.area)
        return Set(official+Array(existingAreas.keys))
            .filter{$0.localizedStandardContains(term) &&
                    $0.localizedCaseInsensitiveCompare(area) != .orderedSame}
            .sorted {left,right in
                let a=left.folding(options:[.diacriticInsensitive,.caseInsensitive],
                                   locale:Locale(identifier:"es_PE"))
                          .hasPrefix(term.folding(options:[.diacriticInsensitive,.caseInsensitive],
                                                  locale:Locale(identifier:"es_PE")))
                let b=right.folding(options:[.diacriticInsensitive,.caseInsensitive],
                                    locale:Locale(identifier:"es_PE"))
                           .hasPrefix(term.folding(options:[.diacriticInsensitive,.caseInsensitive],
                                                   locale:Locale(identifier:"es_PE")))
                return a == b ? left.localizedStandardCompare(right)==.orderedAscending : a
            }
            .prefix(5).map{$0}
    }
    var body:some View {
        ScrollView {
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
                    }
                    if !areaSuggestions.isEmpty {
                        VStack(spacing:0) {
                            ForEach(areaSuggestions,id:\.self) { suggestion in
                                Button {
                                    area=suggestion
                                } label: {
                                    HStack {
                                        Image(systemName:"building.2.crop.circle")
                                            .foregroundStyle(.secondary)
                                        Text(suggestion).foregroundStyle(.primary)
                                        Spacer()
                                        Image(systemName:"arrow.up.left").foregroundStyle(.secondary)
                                    }.padding(.vertical,10)
                                }.buttonStyle(.plain)
                                if suggestion != areaSuggestions.last {Divider()}
                            }
                        }
                        .padding(.horizontal,12)
                        .background(DanperStyle.canvas,in:RoundedRectangle(cornerRadius:13))
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
        .onChange(of:site) {_,_ in updateAreas()}
    }
    @MainActor
    private func load() async {
        if let url=Bundle.main.url(forResource:"n2-organization-areas",
                                   withExtension:"json",subdirectory:"N1sDemoResources"),
           let data=try? Data(contentsOf:url),
           let list=try? JSONDecoder().decode([N2OfficialAreaOption].self,from:data) {
            officialAreas=list
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
