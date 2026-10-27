import SwiftUI
import DanperCore

struct N2SimpleProductEditor:View {
    let context:N2SimpleInventoryContext
    let operation:N2SimpleInventoryCommand.Operation
    let product:N2SimpleProduct?
    var incident:N2SimpleIncident?=nil
    var onInitial:((N2SimpleProduct)->Void)?=nil
    @Environment(\.n2WorkspaceVault) private var vault
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @State private var code=""
    @State private var query=""
    @State private var quantity=""
    @State private var mode=""
    @State private var expiryChoice="keep"
    @State private var expiryDate=Date()
    @State private var responsible=""
    @State private var reason=""
    @State private var rChoice=""
    @State private var busy=false
    @State private var error=""
    @State private var confirm=false
    @State private var eventID=UUID().uuidString
    private var selected:N2ClinicalCatalogProduct? {context.catalog.clinical.first{$0.code==code}}
    private var amount:Double? {
        Double(quantity.trimmingCharacters(in:.whitespacesAndNewlines).replacingOccurrences(of:",",with:"."))
    }
    private var title:String {
        switch operation {
        case .register:return onInitial==nil ? "Registrar inventario":"Conteo físico inicial"
        case .receipt:return "Registrar ingreso"
        case .outflow:return "Registrar salida"
        case .count:return "Actualizar conteo"
        case .expiry:return "Actualizar vencimiento"
        case .resolveIncident:return "Resolver salida"
        }
    }
    private var valid:Bool {
        guard !busy,selected != nil,!responsible.trimmingCharacters(in:.whitespaces).isEmpty,
              !reason.trimmingCharacters(in:.whitespaces).isEmpty else{return false}
        if operation == .resolveIncident {return product?.mode != .presentation || ["0","1"].contains(rChoice)}
        if operation == .expiry {return true}
        guard let q=amount,q.isFinite,q>=0,q<=10_000_000,abs((q*1000).rounded()-q*1000)<0.00001 else{return false}
        if [.receipt,.outflow].contains(operation),q<=0{return false}
        let effective=product?.mode.rawValue ?? mode
        guard ["units","presentation"].contains(effective) else{return false}
        return effective != "presentation" || q.rounded()==q
    }
    var body:some View {
        ScrollView {
            VStack(alignment:.leading,spacing:16) {
                productFields
                quantityFields
                expiryFields
                DanperPanel("Responsable y motivo") {
                    DanperField(title:"Responsable") {TextField("Responsable",text:$responsible).accessibilityIdentifier("simple-command-operator")}
                    DanperField(title:"Motivo") {TextField("Motivo del registro",text:$reason,axis:.vertical).accessibilityIdentifier("simple-command-reason")}
                }
                if !error.isEmpty {Text(error).font(.footnote).foregroundStyle(.red)}
                Button {
                    if onInitial != nil {saveInitial()}else{confirm=true}
                } label:{Label(busy ? "Guardando…":(onInitial != nil ? "Agregar conteo":"Guardar"),systemImage:"checkmark")}
                    .buttonStyle(DanperPrimaryButton()).disabled(!valid).accessibilityIdentifier("simple-command-save")
            }.padding(16)
        }.navigationTitle(title).navigationBarTitleDisplayMode(.inline).danperFormChrome()
            .toolbar {ToolbarItem(placement:.cancellationAction){Button("Cancelar"){dismiss()}}}
            .onAppear {prepare()}
            .onChange(of:scenePhase) {_,phase in if phase == .background {dismiss()}}
            .opacity(vault.isClinical && scenePhase != .active ? 0:1)
            .accessibilityHidden(vault.isClinical && scenePhase != .active)
            .confirmationDialog("Confirmar operación",isPresented:$confirm,titleVisibility:.visible) {
                Button(operation == .count ? "Confirmar conteo físico":"Confirmar registro") {Task {await save()}}
                Button("Cancelar",role:.cancel){}
            } message:{Text(confirmationText)}
    }
    @ViewBuilder private var productFields:some View {
        DanperPanel("Medicamento o insumo") {
            if let product {
                Text(product.name).font(.headline)
                Text("Presentación original: "+product.unit).font(.footnote).foregroundStyle(.secondary)
                if operation != .register {LabeledContent("Existencia actual",value:product.quantity.formatted())}
            }else {
                TextField("Buscar por nombre o código",text:$query).accessibilityIdentifier("simple-product-query")
                if let selected {Label(selected.name,systemImage:"checkmark.circle").font(.headline)}
                ForEach(Array(context.catalog.clinicalMatches(query).filter{candidate in
                    context.state?.products.contains(where:{$0.code==candidate.code}) != true
                }.prefix(10))) {p in
                    Button {
                        code=p.code;mode=N2SimpleInventory.suggestedMode(unit:p.unit)?.rawValue ?? ""
                    } label:{VStack(alignment:.leading){Text(p.name);Text(p.unit).font(.caption).foregroundStyle(.secondary)}}
                        .accessibilityIdentifier("simple-select-"+p.code)
                }
            }
            if operation == .register,let selected {
                Text("Unidad original del catálogo: "+selected.unit).font(.caption)
                if let known=N2SimpleInventory.suggestedMode(unit:selected.unit) {
                    Text(known == .presentation ? "Se cuentan presentaciones completas.":"Se cuentan unidades dispensadas.").font(.footnote)
                }else {
                    DanperChoiceField(title:"Cómo se cuenta físicamente",selection:$mode,
                        options:["","units","presentation"],
                        labels:["":"Elige una opción","units":"Unidades del catálogo","presentation":"Presentaciones completas"])
                    Text("Elige cómo haces el conteo. No se calcularán litros, mililitros ni unidades internas por presentación.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
        }
    }
    @ViewBuilder private var quantityFields:some View {
        if operation == .resolveIncident,let incident {
            DanperPanel("Declaración del consumo") {
                Text("Cantidad clínica conservada: "+incident.clinicalQuantity.formatted()+" "+incident.unit)
                if product?.mode == .presentation {
                    DanperChoiceField(title:"¿Abriste una presentación nueva?",selection:$rChoice,
                        options:["","1","0"],labels:["":"Selecciona una opción","1":"Sí — Kardex R=1","0":"No — Kardex R=0"])
                }
                if let product,incident.clinicalAt<product.lastCountAt {
                    Text("El uso es anterior al último conteo físico. Esta resolución conservará el conteo y no descontará otra vez.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
        }else if operation != .expiry {
            DanperPanel {
                DanperField(title:operation == .count || operation == .register ? "Cantidad física contada":"Cantidad") {
                    TextField("Cantidad",text:$quantity)
                        .keyboardType((product?.mode.rawValue ?? mode)=="presentation" ? .numberPad:.decimalPad)
                        .accessibilityIdentifier("simple-edit-quantity")
                }
                if let product,let amount,operation == .count {
                    LabeledContent("Diferencia",value:(amount-product.quantity).formatted())
                    Text("El conteo físico confirmado prevalece sobre el saldo calculado.").font(.caption).foregroundStyle(.secondary)
                }
            }
        }
    }
    @ViewBuilder private var expiryFields:some View {
        if [.register,.count,.expiry].contains(operation) {
            DanperPanel("Vencimiento de referencia") {
                DanperChoiceField(title:operation == .register ? "Próximo vencimiento":"¿Cambió el próximo vencimiento de este medicamento?",
                    selection:$expiryChoice,options:operation == .register ? ["pending","update"]:["keep","update","pending"],
                    labels:["keep":"Mantener fecha","update":"Actualizar fecha verificada","pending":"Pendiente de verificar"])
                if expiryChoice=="update" {DanperDateField(title:"Próximo vencimiento",selection:$expiryDate)}
                Text("Es una referencia manual, no una certificación de todas las existencias físicas. Cambiarla no cambia el stock.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }
    private var expiryValue:String? {
        if expiryChoice=="update" {
            let f=DateFormatter();f.timeZone=TimeZone(identifier:"America/Lima");f.dateFormat="yyyy-MM-dd"
            return f.string(from:expiryDate)
        }
        if expiryChoice=="pending" {return product?.expiry ?? ""}
        if operation == .expiry {return product?.expiry ?? ""}
        return nil
    }
    private var confirmationText:String {
        if operation == .resolveIncident,let incident,let product,incident.clinicalAt<product.lastCountAt {
            return "Se conservará el conteo físico. La atención no se registrará de nuevo ni se repetirá el descuento."
        }
        if operation == .count {return "Se registrará la cantidad realmente contada y su diferencia con el saldo calculado."}
        return "Se guardará este registro con responsable y motivo. No se seleccionarán lotes ni se calcularán envases internos."
    }
    private func prepare() {
        guard code.isEmpty else{return}
        if let product {
            code=product.code;mode=product.mode.rawValue
            if [.count,.register].contains(operation) {quantity=String(product.quantity)}
            if let date=ISO8601DateFormatter().date(from:product.expiry+"T17:00:00Z") {expiryDate=date}
            if let r=incident?.declaredR {rChoice=String(r)}
        }
        if responsible.isEmpty {responsible=vault.isClinical ? N2ClinicianIdentity.name:"OPERADOR FICTICIO"}
        if operation == .register {expiryChoice=product?.expiryVerified == true ? "update":"pending";reason="Conteo físico inicial confirmado"}
    }
    private func saveInitial() {
        guard valid,let p=selected,let amount,let kind=N2SimpleCountMode(rawValue:mode) else{return}
        onInitial?(N2SimpleProduct(code:p.code,name:p.name,unit:p.unit,mode:kind,quantity:amount,
            expiry:expiryValue ?? "",expiryVerified:expiryChoice=="update"))
        dismiss()
    }
    @MainActor private func save() async {
        guard valid else{return}
        busy=true;defer{busy=false}
        do {
            let now=Int64(Date().timeIntervalSince1970*1000)
            let initial:N2SimpleProduct?=selected.flatMap {p in
                guard operation == .register,let mode=N2SimpleCountMode(rawValue:mode) else{return nil}
                return N2SimpleProduct(code:p.code,name:p.name,unit:p.unit,mode:mode,quantity:amount ?? 0,
                    expiry:expiryValue ?? "",expiryVerified:expiryChoice=="update",lastCountAt:now)
            }
            let request=N2SimpleInventoryCommand(id:eventID,operation:operation,code:code,quantity:amount ?? 0,
                at:now,operatorName:responsible,reason:reason,product:initial,
                expiry:initial==nil ? expiryValue:nil,expiryVerified:expiryValue==nil ? nil:(expiryChoice=="keep" ? product?.expiryVerified:expiryChoice=="update"),
                incidentID:incident?.id,declaredR:Int(rChoice))
            _=try await vault.applySimpleInventoryCommand(request,expectedRevision:context.revision)
            dismiss()
        }catch {self.error=n2SimpleMessage(error)}
    }
}
