import Foundation
import SwiftUI
import DanperCore

/// One stock for Fondo/Planta. Lot identifiers and FEFO remain internal;
/// care site belongs only to the clinical attention.
struct N2NativeInventoryView:View {
    @Environment(\.n2WorkspaceVault) private var vault
    private var layoutOnly=false

    init(initialOperation:String?=nil) {
        if let initialOperation,["lot","receipt","count"].contains(initialOperation) {
            _workspace=State(initialValue:"edit")
            _mode=State(initialValue:initialOperation)
        }
    }
    #if DEBUG
    init(layoutContext:N2FormContext,operation:String?=nil) {
        layoutOnly=true
        _context=State(initialValue:layoutContext)
        _message=State(initialValue:"\(layoutContext.lots.count) lotes registrados")
        if let operation {
            _workspace=State(initialValue:"edit")
            _mode=State(initialValue:operation)
        }
    }
    #endif

    @State private var context:N2FormContext?
    @State private var workspace="overview"
    @State private var mode="lot"
    @State private var materialCode=""
    @State private var unit="UND"
    @State private var lotNumber=""
    @State private var quantity=""
    @State private var expiryEnabled=false
    @State private var expiryInput=""
    @State private var selectedLotID=""
    @State private var reason=""
    @State private var picking=false
    @State private var busy=false
    @State private var failed=false
    @State private var message="Cargando inventario…"
    @State private var lotID=UUID().uuidString
    @State private var movementID=UUID().uuidString
    @State private var movementAt:Int64=0

    private let availableUnits=["UND","TBL","PAR","FCO","CJA","PAQ","ML","LT"]
    private var material:N2NursingCatalogProduct? {
        context?.products.nursing.first{$0.id==materialCode}
    }
    private var selectedLot:N2FormLot? {
        context?.lots.first{$0.id==selectedLotID}
    }
    private func stockUnits(_ lot:N2FormLot)->Double {
        Double(lot.sealed)*lot.capacity + lot.loose + lot.opened
    }
    private var enteredQuantity:Double? {
        let raw=quantity.trimmingCharacters(in:.whitespacesAndNewlines)
            .replacingOccurrences(of:",",with:".")
        guard let q=Double(raw),q.isFinite,q>0,q<=10_000_000,
              (q*1000).rounded()==q*1000 else{return nil}
        return q
    }
    private var packaged:Bool {
        !["UND","TBL","PAR","ML","LT"].contains(unit)
    }
    private var lotCapacity:Int {
        // Infer only when the official product name actually states a
        // quantity. NEVER assume a bottle contains 100 mL by default.
        guard packaged,let name=material?.name.uppercased(),
              let range=name.range(of:#"\b\d{1,4}\s*(ML|CC)\b"#,
                                   options:.regularExpression) else{return 1}
        let count=String(name[range]).prefix{ $0.isNumber }
        return max(1,Int(count) ?? 1)
    }
    private var expiryISO:String? {
        guard expiryEnabled else{return ""}
        guard expiryInput.count==6,expiryInput.allSatisfy(\.isNumber) else{return nil}
        let part=Array(expiryInput)
        let day=Int(String(part[0...1])) ?? 0
        let month=Int(String(part[2...3])) ?? 0
        let year=2000+(Int(String(part[4...5])) ?? 0)
        var calendar=Calendar(identifier:.gregorian)
        calendar.timeZone=TimeZone(identifier:"America/Lima")!
        guard let date=calendar.date(from:DateComponents(year:year,month:month,day:day)),
              calendar.dateComponents([.year,.month,.day],from:date)
                == DateComponents(year:year,month:month,day:day) else{return nil}
        return String(format:"%04d-%02d-%02d",year,month,day)
    }
    private var valid:Bool {
        guard context != nil,!busy,let amount=enteredQuantity else{return false}
        if mode=="lot" {
            return material != nil && !lotNumber.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty &&
                expiryISO != nil && (!packaged || amount.rounded()==amount)
        }
        guard selectedLot != nil,reason.trimmingCharacters(in:.whitespacesAndNewlines).count>=8
        else{return false}
        let existingPackaged=!["UND","TBL","PAR","ML","LT"].contains(
            selectedLot?.unit.uppercased() ?? "UND")
        return !existingPackaged || amount.rounded()==amount
    }
    private var operationTitle:String {
        switch mode {
        case "receipt":return "Registrar ingreso"
        case "count":return "Actualizar conteo"
        default:return "Registrar medicamento"
        }
    }

    var body:some View {
        DanperScrollView {
            VStack(alignment:.leading,spacing:14) {
                header
                if workspace=="overview" {
                    inventorySummary
                    operationChoices
                    lotList
                }else {
                    entryForm
                }
                if !message.isEmpty {
                    Label(message,systemImage:failed ? "exclamationmark.triangle" : "info.circle")
                        .font(.caption).foregroundStyle(failed ? Color.orange : Color.secondary)
                        .fixedSize(horizontal:false,vertical:true)
                }
            }.padding(16)
        }
        .navigationTitle("Inventario")
        .navigationBarTitleDisplayMode(.inline)
        .danperFormChrome()
        .task {if !layoutOnly {await load()}}
    }

    private var header:some View {
        VStack(alignment:.leading,spacing:5) {
            Text("KARDEX · INVENTARIO ÚNICO")
                .font(.caption2.weight(.bold)).tracking(1.1)
                .foregroundStyle(DanperStyle.red)
            Text(workspace=="overview" ? "Medicamentos y existencias" : operationTitle)
                .font(.title2.weight(.bold))
            Text("Un solo stock para Fundo La Venturosa y PL Venturosa.")
                .font(.footnote).foregroundStyle(.secondary)
        }
        .frame(maxWidth:.infinity,alignment:.leading)
    }
    private var inventorySummary:some View {
        HStack(spacing:10) {
            summary(String(context?.products.nursing.count ?? 98),"Productos oficiales")
            summary(String(context?.lots.count ?? 0),"Lotes registrados")
        }
    }
    private func summary(_ value:String,_ description:String)->some View {
        VStack(alignment:.leading,spacing:6) {
            Text(value).font(.title2.weight(.bold)).foregroundStyle(DanperStyle.red)
            Text(description).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth:.infinity,minHeight:77,alignment:.leading)
        .padding(14)
        .background(DanperStyle.surface,in:RoundedRectangle(cornerRadius:14))
    }
    private var operationChoices:some View {
        DanperPanel("¿Qué deseas hacer?") {
            action("lot","Registrar medicamento","Añadir producto, lote y cantidad disponible","plus.circle.fill")
            action("receipt","Registrar ingreso","Sumar unidades a un lote existente","tray.and.arrow.down")
            action("count","Actualizar conteo","Corregir existencias según lo contado","checkmark.shield")
        }
    }
    private func action(_ kind:String,_ name:String,_ detail:String,_ symbol:String)->some View {
        Button {
            mode=kind
            workspace="edit"
            quantity=""
            reason=""
            selectedLotID=""
            picking=false
        } label: {
            HStack(spacing:11) {
                Image(systemName:symbol).font(.title3).foregroundStyle(DanperStyle.red)
                VStack(alignment:.leading,spacing:3) {
                    Text(name).font(.subheadline.weight(.semibold)).foregroundStyle(.primary)
                    Text(detail).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName:"chevron.right").font(.caption).foregroundStyle(.secondary)
            }
            .padding(12)
            .frame(maxWidth:.infinity,alignment:.leading)
            .background(DanperStyle.canvas,in:RoundedRectangle(cornerRadius:13))
        }
        .buttonStyle(.plain)
    }
    private var entryForm:some View {
        VStack(alignment:.leading,spacing:12) {
            Button {
                workspace="overview"
            } label: {
                Label("Volver al inventario",systemImage:"chevron.left")
            }.buttonStyle(DanperSecondaryButton())

            DanperPanel(operationTitle) {
                if mode=="lot" {
                    medicationSelector
                    DanperField(title:"Número de lote o referencia") {
                        TextField("Número del lote",text:$lotNumber)
                            .textInputAutocapitalization(.characters)
                    }
                    DanperChoiceField(title:"Unidad o presentación",
                                      selection:$unit,options:availableUnits)
                    expiryField
                }else {
                    DanperChoiceField(title:"Medicamento y lote",
                        selection:$selectedLotID,options:context?.lots.map(\.id) ?? [],
                        labels:Dictionary(uniqueKeysWithValues:(context?.lots ?? []).map{
                            ($0.id,$0.name+" · "+$0.id)
                        }))
                    if let selectedLot {
                        LabeledContent("Existencia actual",
                            value:stockUnits(selectedLot).formatted())
                        LabeledContent("Vencimiento",
                            value:DanperDatePresentation.display(selectedLot.expires))
                    }
                    DanperField(title:"Motivo del movimiento") {
                        TextField("Ej. Reposición o conteo realizado",
                                  text:$reason,axis:.vertical)
                            .lineLimit(2...3)
                    }
                }
                DanperField(title:mode=="lot" ? "Cantidad disponible" :
                                   mode=="receipt" ? "Cantidad que ingresa" :
                                   "Cantidad contada") {
                    TextField("Ingresa una cantidad",text:$quantity)
                        .keyboardType(.decimalPad)
                        .accessibilityIdentifier("inventory-single-quantity")
                }
                if mode=="lot" {
                    Text("Registra la cantidad que realmente tienes hoy. No se considerará automáticamente un ingreso adicional.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Button {
                    Task {await commit()}
                } label: {
                    Label(busy ? "Guardando…" : mode=="count" ?
                          "Guardar conteo" : mode=="receipt" ?
                          "Guardar ingreso" : "Registrar stock",
                          systemImage:"checkmark.circle.fill")
                        .frame(maxWidth:.infinity)
                }
                .buttonStyle(DanperPrimaryButton())
                .disabled(!valid)
                .accessibilityIdentifier("inventory-save-"+mode)
            }
        }
    }
    private var medicationSelector:some View {
        VStack(alignment:.leading,spacing:8) {
            Text("Medicamento o insumo").font(.subheadline.weight(.semibold))
            Button {
                picking.toggle()
            } label: {
                HStack {
                    Text(material.map{$0.name+" · "+$0.id} ??
                         "Buscar medicamento o insumo oficial")
                        .foregroundStyle(material == nil ? Color.secondary : Color.primary)
                    Spacer()
                    Image(systemName:"magnifyingglass").foregroundStyle(DanperStyle.red)
                }
                .padding(13)
                .background(DanperStyle.canvas,in:RoundedRectangle(cornerRadius:12))
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("inventory-select-product")
            if picking,let context {
                DanperInlineSearch(title:"Buscar medicamento o insumo",
                    placeholder:"Nombre o código E-",
                    options:context.products.nursing.map{
                        DanperSearchOption(id:$0.id,title:$0.name,
                                           detail:$0.id+" · "+$0.group)
                    },onSelect:{id in
                        materialCode=id
                        picking=false
                    },onClose:{picking=false})
            }
        }
    }
    private var expiryField:some View {
        VStack(alignment:.leading,spacing:7) {
            DanperCheckRow(selected:$expiryEnabled) {
                Text("Tiene fecha de vencimiento").font(.subheadline)
            }
            if expiryEnabled {
                DanperField(title:"Vencimiento · DDMMAA") {
                    TextField("DDMMAA (ej. 311227)",text:$expiryInput)
                        .keyboardType(.numberPad)
                        .onChange(of:expiryInput){_,value in
                            let sanitized=String(value.filter(\.isNumber).prefix(6))
                            if expiryInput != sanitized {expiryInput=sanitized}
                        }
                }
                if expiryISO==nil {
                    Text("Escribe seis dígitos: día, mes y año. No se abre el calendario.")
                        .font(.caption).foregroundStyle(.orange)
                }
            }
        }
    }
    private var lotList:some View {
        DanperPanel("Stock y lotes registrados") {
            if let context, !context.lots.isEmpty {
                ForEach(context.lots){lot in
                    VStack(alignment:.leading,spacing:5) {
                        Text(lot.name).font(.subheadline.weight(.semibold))
                        Text("Lote "+lot.id+" · "+lot.kardexCode)
                            .font(.caption).foregroundStyle(.secondary)
                        let total=stockUnits(lot)
                        Text("Cantidad: \(total.formatted()) · Vence: \(DanperDatePresentation.display(lot.expires))")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    .frame(maxWidth:.infinity,alignment:.leading)
                    Divider()
                }
            } else {
                Text("Todavía no hay medicamentos registrados.")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
        }
    }
    @MainActor private func load() async {
        do {
            context=try await vault.clinicalFormContext()
            failed=false
            message=""
        }catch{
            failed=true
            context=nil
            message="No se pudo leer el inventario. No se modificó ningún registro."
        }
    }
    @MainActor private func commit() async {
        guard valid,let current=context,let qty=enteredQuantity else{return}
        busy=true
        failed=false
        defer{busy=false}
        if movementAt==0 {movementAt=Int64(Date().timeIntervalSince1970*1000)}
        do {
            let result:N2ProtectedStoreSummary
            if mode=="lot" {
                guard let material,let expiryISO else{return}
                let isPack=packaged
                let record:[String:Any]=[
                    "id":lotID,"code":material.id,"name":material.name,
                    "catalogUnit":unit,"lot":lotNumber,
                    "expires":expiryISO,
                    "container":isPack ? (
                        unit=="FCO" ? "frasco" : unit=="CJA" ? "caja" : "paquete"
                    ) : "unidad",
                    "unitsPerContainer":isPack ? lotCapacity : 1,
                    "sealedContainers":isPack ? Int(qty) : 0,
                    "looseUnits":isPack ? 0 : qty,
                    "openedRemaining":0,"updatedAt":movementAt
                ]
                let bytes=try JSONSerialization.data(withJSONObject:record)
                result=try await vault.addLot(bytes,expectedRevision:current.revision)
            }else {
                guard let selectedLot else{return}
                let isPack = !["UND","TBL","PAR","ML","LT"].contains(
                    selectedLot.unit.uppercased())
                if mode=="receipt" {
                    result=try await vault.receiveStock(
                        movementID:movementID,lotID:selectedLot.id,at:movementAt,
                        sealedAdded:isPack ? Int(qty) : 0,
                        looseAdded:isPack ? 0:qty,
                        reason:reason,expectedRevision:current.revision)
                }else {
                    // Preserve opened-bottle remainder when recounting sealed
                    // containers; no artificial opening/consumption.
                    result=try await vault.reconcileCount(
                        movementID:movementID,lotID:selectedLot.id,at:movementAt,
                        sealed:isPack ? Int(qty) : 0,
                        loose:isPack ? selectedLot.loose:qty,
                        opened:isPack ? selectedLot.opened:0,
                        reason:reason,expectedRevision:current.revision)
                }
            }
            _ = result
            context=try await vault.clinicalFormContext()
            movementID=UUID().uuidString
            lotID=UUID().uuidString
            movementAt=0
            workspace="overview"
            materialCode=""
            selectedLotID=""
            quantity=""
            lotNumber=""
            expiryEnabled=false
            expiryInput=""
            reason=""
            message="Existencias registradas correctamente en el Kardex único."
        }catch{
            failed=true
            message="No se guardó la operación. Revisa lote, cantidad y existencias sin crear registros duplicados."
        }
    }
}
