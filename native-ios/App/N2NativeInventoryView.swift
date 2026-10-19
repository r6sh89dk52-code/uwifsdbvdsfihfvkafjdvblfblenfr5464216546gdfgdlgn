import Foundation
import SwiftUI
import DanperCore

/// Independent N2 stock operations: register a lot, receive more supplies,
/// and reconcile an explicitly counted lot. No guessed package sizes.
struct N2NativeInventoryView:View {
    @Environment(\.n2WorkspaceVault) private var vault
    private var layoutOnly=false
    init() {}
    #if DEBUG
    init(layoutContext:N2FormContext,operation:String?=nil) {
        layoutOnly=true
        _context=State(initialValue:layoutContext)
        _message=State(initialValue:"\(layoutContext.lots.count) lotes disponibles")
        if let operation {_workspace=State(initialValue:"edit");_mode=State(initialValue:operation)}
    }
    #endif
    @State private var context:N2FormContext?
    @State private var workspace="overview"
    @State private var mode="lot"
    @State private var materialCode=""
    @State private var site=""
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
    @State private var message="Cargando inventario…"

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
        guard context != nil,!busy else{return false}
        if mode=="site" {return !selectedLotID.isEmpty && !site.isEmpty && reason.trimmingCharacters(in:.whitespacesAndNewlines).count>=8}
        guard let values=counts else{return false}
        if mode=="lot"{
            return material != nil && !site.isEmpty && values.2<=Double(values.3)
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
        DanperScrollView {
          VStack(alignment:.leading,spacing:16) {
            DanperPanel("Inventario y lotes") {
                Label("Kardex físico de enfermería · 98 materiales",
                      systemImage:"lock.shield.fill")
                Text("Registra existencias y revisa los lotes de cada sede. La capacidad de cajas y frascos se indica al registrar el lote.")
                    .font(.footnote).foregroundStyle(.secondary)
                Text(message).font(.footnote)
                    .foregroundStyle(failed ? Color.red : Color.secondary)
            }
            if workspace=="overview" {
                DanperPanel("Gestionar existencias") {
                    ForEach(["lot","receipt","count"],id:\.self) {action in
                        Button {
                            mode=action;workspace="edit"
                        } label: {
                            HStack {
                                Label(["lot":"Registrar lote","receipt":"Ingreso extraordinario","count":"Conteo físico"][action]!,systemImage:action=="lot" ? "plus.circle" : action=="receipt" ? "tray.and.arrow.down" : "checkmark.shield")
                                Spacer();Image(systemName:"chevron.right")
                            }.padding(14).foregroundStyle(.primary).frame(minHeight:52)
                                .background(DanperStyle.canvas,in:RoundedRectangle(cornerRadius:14))
                        }.buttonStyle(.plain)
                    }
                }
            } else {
            Button {workspace="overview"} label:{Label("Volver al inventario",systemImage:"chevron.left")}.buttonStyle(DanperSecondaryButton())
            if mode=="site" {
                DanperPanel("Verificar sede original del lote") {
                    Text(context?.lots.first{$0.id==selectedLotID}?.name ?? selectedLotID).font(.headline)
                    Text("Confirma la sede a la que pertenecen el lote y su historial. Esta operación no es un traslado ni cambia cantidades.").font(.footnote).foregroundStyle(.secondary)
                    DanperChoiceField(title:"Sede verificada",selection:$site,options:["LA VENTUROSA","PLVENTUROSA"],labels:["LA VENTUROSA":"Fundo La Venturosa","PLVENTUROSA":"Planta La Venturosa"])
                    DanperField(title:"Evidencia de la sede original") {TextField("Justificación (mínimo 8 caracteres)",text:$reason,axis:.vertical)}
                    Button {Task {await commit()}} label:{Label("Confirmar sede original",systemImage:"mappin.and.ellipse")}
                        .buttonStyle(DanperPrimaryButton()).disabled(!valid)
                }
            } else {
            DanperPanel("Operación") {
                DanperChoiceField(title:"Operación",selection:$mode,options:["lot","receipt","count"],
                                  labels:["lot":"Registrar lote","receipt":"Ingreso extraordinario","count":"Conciliar conteo físico"])
                if mode=="lot" {
                    Button {picking.toggle()} label:{
                        Label(material.map{$0.name+" · "+$0.id} ??
                              "Seleccionar material oficial",
                              systemImage:"magnifyingglass")
                    }
                    if picking,let context {
                        DanperInlineSearch(title:"Material oficial de enfermería",placeholder:"Nombre o código E-",
                            options:context.products.nursing.map{DanperSearchOption(id:$0.id,title:$0.name,detail:$0.id+" · "+$0.group)},
                            onSelect:{id in materialCode=id;picking=false},onClose:{picking=false})
                    }
                    DanperChoiceField(title:"Sede del inventario",selection:$site,options:["LA VENTUROSA","PLVENTUROSA"],labels:["LA VENTUROSA":"Fundo La Venturosa","PLVENTUROSA":"Planta La Venturosa"])
                    DanperField(title:"N.º de lote o referencia") {
                    TextField("N.º de lote o referencia",text:$lotNumber)
                }
                    DanperChoiceField(title:"Unidad del catálogo",selection:$unit,options:["UND","TBL","PAR","CJA","PAQ","FCO","LT","ML"],labels:Dictionary(uniqueKeysWithValues:["UND","TBL","PAR","CJA","PAQ","FCO","LT","ML"].map{($0,$0)}))
                    DanperChoiceField(title:"Presentación física",selection:$container,options:["unidad","caja","frasco","paquete","blister","otro"])
                    DanperField(title:"Capacidad interna por envase") {
                    TextField("Capacidad interna por envase",text:$cap)
                        .keyboardType(.numberPad)
                }
                    DanperCheckRow(selected:$expiryEnabled) {Text("Registrar fecha de vencimiento")}
                    if expiryEnabled {
                        DanperDateField(title:"Vencimiento",selection:$expiry)
                    }
                }else{
                    DanperChoiceField(title:"Lote registrado",selection:$selectedLotID,options:context?.lots.map(\.id) ?? [],
                                      labels:Dictionary(uniqueKeysWithValues:(context?.lots ?? []).map{($0.id,$0.name+" · "+$0.id)}))
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
                    DanperField(title:"Justificación obligatoria") {
                    TextField("Justificación obligatoria",text:$reason,
                              axis:.vertical).lineLimit(2...4)
                }
                }
            }
            DanperPanel(mode=="count" ? "Conteo físico actual" :
                    mode=="receipt" ? "Cantidades adicionales" : "Existencias iniciales") {
                DanperField(title:"Envases sellados") {
                    TextField("Envases sellados",text:$sealed)
                    .keyboardType(.numberPad)
                }
                DanperField(title:"Unidades sueltas") {
                    TextField("Unidades sueltas",text:$loose)
                    .keyboardType(.decimalPad)
                }
                if mode != "receipt" {
                    DanperField(title:"Contenido de envase abierto") {
                    TextField("Contenido de envase abierto",text:$opened)
                        .keyboardType(.decimalPad)
                }
                }
                Text("Distingue envases sellados, material suelto y remanente abierto. La U.M. del Kardex se conserva.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            DanperPanel("Confirmación") {
                Button {
                    Task {await commit()}
                } label: {
                    Label(busy ? "Guardando…" : "Guardar movimiento",
                          systemImage:"checkmark.shield.fill")
                }.buttonStyle(DanperPrimaryButton()).disabled(!valid)
            }
            }
            }
            if workspace=="overview" {
            DanperPanel("Lotes actuales") {
                if let context {
                    ForEach(context.lots){lot in
                        VStack(alignment:.leading,spacing:4){
                            Text(lot.name+" · "+lot.kardexCode).font(.headline)
                            Label(lot.site.isEmpty ? "Sede sin verificar" : lot.site,systemImage:lot.site.isEmpty ? "exclamationmark.triangle" : "mappin.and.ellipse")
                                .font(.caption).foregroundStyle(lot.site.isEmpty ? Color.orange : Color.secondary)
                            if lot.site.isEmpty {
                                Button("Verificar sede original") {
                                    selectedLotID=lot.id;site="";reason="";mode="site";workspace="edit"
                                }.buttonStyle(DanperSecondaryButton())
                            }
                            Text("Sello: \(lot.sealed) · Abierto: \(lot.opened) · Suelto: \(lot.loose)")
                                .font(.caption).foregroundStyle(.secondary)
                            Text("Lote: "+lot.id+" · Vence: "+DanperDatePresentation.display(lot.expires))
                                .font(.caption2).foregroundStyle(.secondary)
                        }.padding(14).frame(maxWidth:.infinity,alignment:.leading).background(DanperStyle.canvas,in:RoundedRectangle(cornerRadius:14))
                    }
                }
            }
            }
          }.padding(16)
        }
        .navigationTitle("Inventario y lotes")
        .danperFormChrome()
        .task {if !layoutOnly {await load()}}
    }
    @MainActor
    private func load() async {
        do{
            context=try await vault.clinicalFormContext()
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
        guard valid,let current=context else{return}
        let values=counts ?? (0,0.0,0.0,1)
        busy=true
        failed=false
        defer{busy=false}
        if movementAt==0 {
            movementAt=Int64(Date().timeIntervalSince1970*1000)
        }
        do{
            let result:N2ProtectedStoreSummary
            switch mode {
            case "site":
                result=try await vault.verifyOriginalStockSite(
                    eventID:movementID,lotID:selectedLotID,site:site,reason:reason,
                    at:movementAt,expectedRevision:current.revision)
            case "lot":
                guard let material else{return}
                let record:[String:Any]=[
                    "id":lotID,"code":material.id,"name":material.name,
                    "catalogUnit":unit,"lot":lotNumber,
                    "site":site,
                    "expires":expiryEnabled ? localDay(expiry) : "",
                    "container":container,"unitsPerContainer":values.3,
                    "sealedContainers":values.0,"looseUnits":values.1,
                    "openedRemaining":values.2,"updatedAt":movementAt
                ]
                let data=try JSONSerialization.data(withJSONObject:record)
                result=try await vault.addLot(
                    data,expectedRevision:current.revision)
            case "receipt":
                result=try await vault.receiveStock(
                    movementID:movementID,lotID:selectedLotID,at:movementAt,
                    sealedAdded:values.0,looseAdded:values.1,
                    reason:reason,expectedRevision:current.revision)
            default:
                result=try await vault.reconcileCount(
                    movementID:movementID,lotID:selectedLotID,at:movementAt,
                    sealed:values.0,loose:values.1,opened:values.2,
                    reason:reason,expectedRevision:current.revision)
            }
            _ = result
            context=try await vault.clinicalFormContext()
            // Disable a second tap with stale quantities after a successful
            // receipt or lot creation. Failed writes retain the same ID/clock
            // so an uncertain network/UI retry cannot silently double-count.
            movementID=UUID().uuidString
            lotID=UUID().uuidString
            movementAt=0
            workspace="overview"
            reason=""
            materialCode=""
            selectedLotID=""
            lotNumber=""
            cap="1"
            sealed="0"
            loose="0"
            opened="0"
            expiryEnabled=false
            message=mode=="site" ? "Sede original verificada. Las cantidades y movimientos se conservaron." : "Inventario actualizado correctamente."
        }catch {
            failed=true
            message="Operación no aplicada: verifica materiales, cantidades, lotes y revisión vigente. El identificador se conserva para impedir duplicar un ingreso al reintentar."
        }
    }
}

