import Foundation
import SwiftUI
import DanperCore

/// Active ONLY after a verified one-source protected N2 vault exists.
/// Writes a new manual worker atomically, never modifies worker identity.
struct N2NativeWorkerEditorView:View {
    @State private var dni=""
    @State private var names=""
    @State private var area=""
    @State private var labor=""
    @State private var site="LA VENTUROSA"
    @State private var sex=""
    @State private var age=""
    @State private var ubigeo=""
    @State private var revision:Int?
    @State private var busy=false
    @State private var status="Comprobando práctica cifrada…"
    @State private var failed=false

    private var ready:Bool {
        revision != nil && !busy && dni.count==8 && dni.hasPrefix("000000") &&
        names.uppercased().hasPrefix("PERSONA FICTICIA ") &&
        dni.utf8.allSatisfy{(48...57).contains($0)} &&
        !names.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty &&
        (sex.isEmpty || ["M","F"].contains(sex)) &&
        (age.isEmpty || (Int(age).map{(0...120).contains($0)} == true))
    }
    var body:some View {
        Form {
            Section {
                Label("Modo de prueba — datos ficticios",systemImage:"lock.shield")
                    .font(.caption).foregroundStyle(DanperStyle.red)
                if failed {Text(status).font(.footnote).foregroundStyle(.orange)}
            }
            Section("Identificación") {
                Text("DNI de prueba: 000000 seguido de dos cifras. Nombre: PERSONA FICTICIA seguido de un identificador.")
                    .font(.caption).foregroundStyle(.secondary)
                TextField("DNI ficticio (ej. 00000006)",text:$dni)
                    .keyboardType(.numberPad)
                TextField("Nombre (PERSONA FICTICIA SEIS)",text:$names)
                    .textInputAutocapitalization(.characters)
            }
            Section("Datos laborales") {
                TextField("Área (opcional)",text:$area)
                TextField("Cargo / labor",text:$labor)
                Picker("Sede",selection:$site) {
                    Text("La Venturosa").tag("LA VENTUROSA")
                    Text("Planta Chepén").tag("PLANTA CHEPEN")
                }
            }
            Section("Datos personales opcionales") {
                Picker("Sexo registrado",selection:$sex) {
                    Text("No consignado").tag("")
                    Text("M").tag("M")
                    Text("F").tag("F")
                }
                TextField("Edad (opcional)",text:$age).keyboardType(.numberPad)
                TextField("Ubigeo (opcional)",text:$ubigeo)
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .safeAreaInset(edge:.bottom) {
            Button {save()} label: {
                Label(busy ? "Guardando…" : "Guardar trabajador",systemImage:"person.badge.plus")
            }.buttonStyle(DanperPrimaryButton()).disabled(!ready)
                .padding(16).background(.regularMaterial)
        }
        .navigationTitle("Nuevo trabajador")
        .danperFormChrome()
        .task {
            do {
                if let vault=try await N2SyntheticTrialIOSVault.shared.inspect() {
                    revision=vault.revision
                }
                status=revision==nil ? "Activa el modo prueba desde Inicio para continuar." :
                    "Entorno ficticio listo; estos datos no se mezclan con la build 222."
            }catch{
                failed=true;status="Error de integridad de la bóveda. Registro bloqueado."
            }
        }
    }
    @MainActor
    private func save() {
        guard ready,let current=revision else{return}
        let fields:[String:Any]=[
            "dni":dni,"name":names.trimmingCharacters(in:.whitespacesAndNewlines),
            "area":area,"labor":labor,"site":site,
            "sex":sex,"age":age,"ubigeo":ubigeo
        ]
        guard let bytes=try? JSONSerialization.data(withJSONObject:fields) else{return}
        busy=true
        Task {
            do {
                let result=try await N2SyntheticTrialIOSVault.shared.registerWorker(
                    bytes,at:Int64(Date().timeIntervalSince1970*1000),
                    expectedRevision:current)
                revision=result.revision
                failed=false
                status="Nuevo trabajador guardado en revisión cifrada \(result.revision)."
                dni="";names="";area="";labor="";sex="";age="";ubigeo=""
            }catch{
                failed=true
                status="No se guardó: DNI repetido, datos inválidos o revisión obsoleta. Comprueba el directorio."
            }
            busy=false
        }
    }
}

