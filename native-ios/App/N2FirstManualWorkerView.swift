import Foundation
import SwiftUI
import LocalAuthentication
import DanperCore

/// First-time, file-free admission to the CLINICAL vault.
/// No employee, visit, lot or medication is ever invented or preloaded.
/// Only the manually entered and reviewed FIRST worker becomes the source.
struct N2FirstManualWorkerView:View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dismiss) private var dismiss
    @State private var dni=""
    @State private var fullName=""
    @State private var site=""
    @State private var area=""
    @State private var labor=""
    @State private var confirmed=false
    @State private var busy=false
    @State private var finished=false
    @State private var failed=false
    @State private var message="Ingresa los datos del primer trabajador para comenzar sin Excel."
    private var valid:Bool {
        dni.utf8.count==8 &&
        dni.utf8.allSatisfy{(48...57).contains($0)} &&
        fullName.trimmingCharacters(in:.whitespacesAndNewlines).count>=5 &&
        ["LA VENTUROSA","PLVENTUROSA"].contains(site) &&
        scenePhase == .active && !busy && !finished
    }
    var body:some View {
        DanperScrollView {
            VStack(alignment:.leading,spacing:16) {
                DanperPanel("Comenzar sin Excel ni respaldo") {
                    Label("Primer trabajador · registro manual",
                          systemImage:"person.badge.plus")
                        .font(.headline)
                    Text("No se cargarán registros de prueba. Se creará una fuente cifrada únicamente con los datos que introduzcas y apruebes aquí. Inicialmente habrá 0 atenciones, 0 lotes y 0 consumos.")
                        .font(.footnote).foregroundStyle(.secondary)
                    Text("Si tienes atenciones o Kardex antiguos en la Build 222, restaura su copia cifrada en lugar de crear esta fuente. No puedes fusionar posteriormente dos bases distintas.")
                        .font(.footnote.weight(.semibold)).foregroundStyle(.orange)
                }
                if !finished {
                    DanperPanel("Identificación") {
                        DanperField(title:"DNI") {
                            TextField("8 dígitos",text:$dni)
                                .keyboardType(.numberPad)
                                .onChange(of:dni) {_,value in
                                    dni=String(value.filter{$0.isNumber}.prefix(8))
                                }
                                .accessibilityIdentifier("first-manual-worker-dni")
                        }
                        DanperField(title:"Apellidos y nombres") {
                            TextField("Apellidos y nombres",text:$fullName)
                                .textContentType(.name)
                                .textInputAutocapitalization(.words)
                                .accessibilityIdentifier("first-manual-worker-name")
                        }
                        DanperChoiceField(title:"Sede verificada",selection:$site,
                            options:["LA VENTUROSA","PLVENTUROSA"],
                            labels:["LA VENTUROSA":"Fundo La Venturosa",
                                    "PLVENTUROSA":"Planta La Venturosa"])
                        DanperField(title:"Área (opcional)") {
                            TextField("Área de trabajo",text:$area)
                        }
                        DanperField(title:"Labor (opcional)") {
                            TextField("Labor",text:$labor)
                        }
                    }
                    Button {
                        confirmed=true
                    } label: {
                        Label(busy ? "Creando fuente protegida…" : "Revisar y crear base nueva",
                              systemImage:"lock.shield.fill")
                    }
                    .buttonStyle(DanperPrimaryButton())
                    .disabled(!valid)
                    .accessibilityIdentifier("first-manual-worker-activate")
                } else {
                    DanperPanel("Fuente clínica creada") {
                        Label("Primer trabajador registrado y bóveda cifrada verificada",
                              systemImage:"checkmark.shield.fill")
                            .foregroundStyle(.green)
                        LabeledContent("Trabajadores","1")
                        LabeledContent("Atenciones","0")
                        LabeledContent("Lotes","0")
                        Button("Volver para entrar a DANPER") {dismiss()}
                            .buttonStyle(DanperPrimaryButton())
                    }
                }
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(failed ? Color.red : Color.secondary)
                    .accessibilityIdentifier("first-manual-worker-status")
            }.padding(16)
        }
        .navigationTitle("Crear fuente clínica")
        .danperFormChrome()
        .confirmationDialog("¿Crear una base clínica nueva sin registros anteriores?",
                            isPresented:$confirmed,titleVisibility:.visible) {
            Button("Crear e ingresar primer trabajador") {
                Task {await create()}
            }
            Button("Cancelar",role:.cancel) {}
        } message: {
            Text("Esta operación no toca la Build 222. Si ya tienes una fuente clínica en B11, no se permitirá reemplazarla.")
        }
    }
    @MainActor private func create() async {
        guard valid else{return}
        busy=true;failed=false
        defer{busy=false}
        do {
            // Check before AND after device owner authentication to avoid
            // overwriting any prior imported/restored clinical source.
            guard try await N2ProtectedClinicalIOSVault.shared.inspect()==nil else {
                throw N2ProtectedStoreError.targetNotEmpty
            }
            let authentication=LAContext()
            guard try await authentication.evaluatePolicy(
                .deviceOwnerAuthentication,
                localizedReason:"Autorizar el primer registro manual de DANPER") else {
                throw N2ProtectedStoreError.unsafeSource
            }
            guard scenePhase == .active,
                  try await N2ProtectedClinicalIOSVault.shared.inspect()==nil else {
                throw N2ProtectedStoreError.targetNotEmpty
            }
            let timestamp=Int64(Date().timeIntervalSince1970*1000)
            let worker:[String:String]=[
                "dni":dni,"name":fullName.trimmingCharacters(in:.whitespacesAndNewlines),
                "site":site,"area":area,"labor":labor,"sex":"",
                "age":"","birthDate":"","ubigeo":""
            ]
            let data=try JSONSerialization.data(withJSONObject:worker)
            let initial=try N2EmptyDemoSnapshot.make()
            let source=try N2SnapshotEditor.addWorker(
                snapshot:initial,worker:data,at:timestamp)
            // Production snapshot validation and audit remain unchanged.
            let result=try await N2ProtectedClinicalIOSVault.shared
                .activateOnlyWithConsent(source,approvedByUser:true)
            guard result.workers==1,result.attentions==0,
                  result.physicalMovements==0,result.pendingClinicalLines==0 else {
                throw N2ProtectedStoreError.unsafeSource
            }
            finished=true
            message="Base inicializada sin Excel, muestras ni datos clínicos históricos."
        }catch{
            failed=true
            message="No se pudo crear la fuente. No se sobrescribió ningún registro. Comprueba la autenticación y el estado de la bóveda."
        }
    }
}
