import Foundation
import SwiftUI
import DanperCore

/// Independent N2 stock operations: register a lot, receive more supplies,
/// and reconcile an explicitly counted lot. No guessed package sizes.
struct N2NativeInventoryView:View {
    @State private var context:N2FormContext?
    @State private var mode="lot"
    @State private var materialCode=""
    @State private var container="unidad"
    @State private var unit="UND"
    @State private var lotNumber=""
    @State private var cap="1"
    @State private var sealed="0"
    @State private var loose="0"
    @State private var opened="0"
    @State private var expiryEnabled=false
    @State private var expiry=Date()
    @State private var lotID=UUID().uuidString
    @State private var movementID=UUID().uuidString
    @State private var movementAt:Int64=0
    @State private var selectedLotID=""
    @State private var reason=""
    @State private var search=""
    @State private var picking=false
    @State private var busy=false
    @State private var failed=false
    @State private var message="Verificando la bóveda y el catálogo oficial…"

    private var material:N2NursingCatalogProduct? {
        context?.products.nursing.first{$0.id==materialCode}
    }
    private var counts:(Int,Double,Double,Int)? {
        guard let number=Int(sealed),(0...10_000_000).contains(number),
              let extra=decimal(loose),(0...10_000_000).contains(extra),
              let openedCount=decimal(opened),(0...10_000_000).contains(openedCount),
              let capacity=Int(cap),(1...10_000_000).contains(capacity) else{return nil}
        return(number,extra,openedCount,capacity)
    }
    private func decimal(_ s:String)->Double? {
        guard let value=Double(s.replacingOccurrences(of:",",with:".")),
              value.isFinite else{return nil}
        return value
    }
    private func localDay(_ day:Date)->String {
        let fmt=DateFormatter()
        fmt.dateFormat="yyyy-MM-dd"
        fmt.timeZone=TimeZone(identifier:"America/Lima")
        return fmt.string(from:day)
    }
    private var valid:Bool {
        guard context != nil,!busy,let values=counts else{return false}
        if mode=="lot"{
            return material != nil && values.2<=Double(values.3)
        }
        guard !selectedLotID.isEmpty &&
              reason.trimmingCharacters(in:.whitespacesAndNewlines).count>=8 else{
            return false
        }
        if mode=="receipt" {
            return values.0>0 || values.1>0
        }
        return values.2<=Double(
            context?.lots.first{$0.id==selectedLotID}?.capacity ?? 0)
    }

    var body:some View {
        Form {
            Section("Inventario nativo · bóveda cifrada N2") {
                Label("Kardex físico de enfermería · 98 materiales",
                      systemImage:"lock.shield.fill")
                Text("Toda alta, ingreso y ajuste se confirma en una sola generación cifrada. No se infiere cuántos mL contiene un frasco o cuántas unidades contiene una caja.")
                    .font(.footnote).foregroundStyle(.secondary)
                Text(message).font(.footnote)
                    .foregroundStyle(failed ? Color.red : Color.secondary)
            }
            Section("Operación") {
                Picker("Acción",selection:$mode) {
                    Text("Registrar lote").tag("lot")
                    Text("Ingreso extraordinario").tag("receipt")
                    Text("Conciliar conteo físico").tag("count")
                }
                .pickerStyle(.segmented)
                if mode=="lot" {
                    Button {picking=true} label:{
                        Label(material.map{$0.name+" · "+$0.id} ??
                              "Seleccionar material oficial",
                              systemImage:"magnifyingglass")
                    }
                    TextField("N.º de lote o referencia",text:$lotNumber)
                    Picker("U.M. del producto",selection:$unit) {
                        ForEach(["UND","TBL","PAR","CJA","PAQ","FCO","LT","ML"],id:\.self){
                            Text($0).tag($0)
                        }
                    }
                    Picker("Presentación física",selection:$container) {
                        Text("Unidad").tag("unidad")
                        Text("Caja").tag("caja")
                        Text("Frasco").tag("frasco")
                        Text("Paquete").tag("paquete")
                        Text("Blíster").tag("blister")
                        Text("Otro").tag("otro")
                    }
                    TextField("Capacidad interna por envase",text:$cap)
                        .keyboardType(.numberPad)
                    Toggle("Registrar fecha de vencimiento",isOn:$expiryEnabled)
                    if expiryEnabled {
                        LabeledContent("Vencimiento",value:DanperDatePresentation.display(localDay(expiry)))
                        DatePicker("Cambiar vencimiento",selection:$expiry,
                                   displayedComponents:.date)
                    }
                }else{
                    Picker("Lote registrado",selection:$selectedLotID) {
                        Text("Seleccionar lote").tag("")
                        if let context {
                            ForEach(context.lots){lot in
                                Text(lot.name+" · "+lot.id).tag(lot.id)
                            }
                        }
                    }
                    if let current=context?.lots.first(where:{$0.id==selectedLotID}) {
                        LabeledContent("Existencia sellada",
                                       value:String(current.sealed))
                        LabeledContent("Contenido abierto",
                                       value:String(current.opened))
                        LabeledContent("Capacidad comprobada",
                                       value:String(current.capacity))
                        if mode=="count" {
                            Text("Introduce el conteo físico total actual. La diferencia se registra como ajuste auditado.")
                                .font(.footnote).foregroundStyle(.secondary)
                        }
                    }
                    TextField("Justificación obligatoria",text:$reason,
                              axis:.vertical).lineLimit(2...4)
                }
            }
            Section(mode=="count" ? "Conteo físico actual" :
                    mode=="receipt" ? "Cantidades adicionales" : "Existencias iniciales") {
                TextField("Envases sellados",text:$sealed)
                    .keyboardType(.numberPad)
                TextField("Unidades sueltas",text:$loose)
                    .keyboardType(.decimalPad)
                if mode != "receipt" {
                    TextField("Contenido de envase abierto",text:$opened)
                        .keyboardType(.decimalPad)
                }
                Text("Distingue envases sellados, material suelto y remanente abierto. La U.M. del Kardex se conserva.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section("Confirmación") {
                Button {
                    Task {await commit()}
                } label: {
                    Label(busy ? "Guardando…" : "Confirmar en inventario N2",
                          systemImage:"checkmark.shield.fill")
                }.disabled(!valid)
            }
            Section("Lotes actuales") {
                if let context {
                    ForEach(context.lots){lot in
                        VStack(alignment:.leading,spacing:4){
                            Text(lot.name+" · "+lot.kardexCode).font(.headline)
                            Text("Sello: \(lot.sealed) · Abierto: \(lot.opened) · Suelto: \(lot.loose)")
                                .font(.caption).foregroundStyle(.secondary)
                            Text("Lote: "+lot.id+" · Vence: "+DanperDatePresentation.display(lot.expires))
                                .font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .navigationTitle("Inventario y lotes")
        .danperFormChrome()
        .sheet(isPresented:$picking){
            NavigationStack {
                List {
                    if let context {
                        ForEach(context.products.nursingMatches(search)) {p in
                            Button {
                                materialCode=p.id
                                picking=false
                                search=""
                            } label:{
                                VStack(alignment:.leading){
                                    Text(p.name).foregroundStyle(.primary)
                                    Text(p.id+" · "+p.group)
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
                .searchable(text:$search,prompt:"Nombre o código E-")
                .navigationTitle("Materiales de enfermería")
                .toolbar{
                    ToolbarItem(placement:.topBarTrailing){
                        Button("Cerrar"){picking=false}
                    }
                }
            }
        }
        .task {await load()}
    }
    @MainActor
    private func load() async {
        do{
            context=try await N2SyntheticTrialIOSVault.shared.clinicalFormContext()
            message="Inventario verificado; lotes: \(context?.lots.count ?? 0)."
            failed=false
        }catch{
            failed=true
            context=nil
            message="No hay fuente clínica N2 verificada; el inventario queda bloqueado."
        }
    }
    @MainActor
    private func commit() async {
        guard valid,let current=context,let values=counts else{return}
        busy=true
        failed=false
        defer{busy=false}
        if movementAt==0 {
            movementAt=Int64(Date().timeIntervalSince1970*1000)
        }
        do{
            let result:N2ProtectedStoreSummary
            switch mode {
            case "lot":
                guard let material else{return}
                let record:[String:Any]=[
                    "id":lotID,"code":material.id,"name":material.name,
                    "catalogUnit":unit,"lot":lotNumber,
                    "expires":expiryEnabled ? localDay(expiry) : "",
                    "container":container,"unitsPerContainer":values.3,
                    "sealedContainers":values.0,"looseUnits":values.1,
                    "openedRemaining":values.2,"updatedAt":movementAt
                ]
                let data=try JSONSerialization.data(withJSONObject:record)
                result=try await N2SyntheticTrialIOSVault.shared.addLot(
                    data,expectedRevision:current.revision)
            case "receipt":
                result=try await N2SyntheticTrialIOSVault.shared.receiveStock(
                    movementID:movementID,lotID:selectedLotID,at:movementAt,
                    sealedAdded:values.0,looseAdded:values.1,
                    reason:reason,expectedRevision:current.revision)
            default:
                result=try await N2SyntheticTrialIOSVault.shared.reconcileCount(
                    movementID:movementID,lotID:selectedLotID,at:movementAt,
                    sealed:values.0,loose:values.1,opened:values.2,
                    reason:reason,expectedRevision:current.revision)
            }
            context=try await N2SyntheticTrialIOSVault.shared.clinicalFormContext()
            // Disable a second tap with stale quantities after a successful
            // receipt or lot creation. Failed writes retain the same ID/clock
            // so an uncertain network/UI retry cannot silently double-count.
            movementID=UUID().uuidString
            lotID=UUID().uuidString
            movementAt=0
            reason=""
            materialCode=""
            selectedLotID=""
            lotNumber=""
            cap="1"
            sealed="0"
            loose="0"
            opened="0"
            expiryEnabled=false
            message="Movimiento o lote cifrado y auditado · revisión \(result.revision)."
        }catch {
            failed=true
            message="Operación no aplicada: verifica materiales, cantidades, lotes y revisión vigente. El identificador se conserva para impedir duplicar un ingreso al reintentar."
        }
    }
}
