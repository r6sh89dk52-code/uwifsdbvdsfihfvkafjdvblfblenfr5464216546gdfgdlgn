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
    @State private var unit=""
    @State private var lotNumber=""
    @State private var quantity=""
    @State private var expiryEnabled=false
    @State private var expiryInput=""
    @State private var capacityInput=""
    @State private var capacityEvidence=""
    @State private var capacityConfirmed=false
    @State private var selectedLotID=""
    @State private var closingLot:N2FormLot?
    @State private var editingLot:N2FormLot?
    @State private var reason=""
    @State private var productSearch=""
    @State private var zeroStockQuery=""
    @FocusState private var productSearchFocused:Bool
    @Environment(\.danperReveal) private var reveal
    @State private var revealTask:Task<Void,Never>?
    @State private var busy=false
    @State private var failed=false
    @State private var message="Cargando inventario…"
    @State private var lotID=UUID().uuidString
    @State private var movementID=UUID().uuidString
    @State private var movementAt:Int64=0
    @State private var showStockBasisAlert=false
    @State private var auxiliaryCode=""
    @State private var showAuxiliaryInventory=false

    /// The exceptional selector offers only official units already
    /// seen in the source catalog. It is not shown for approved matches.
    private var verifiedUnitOptions:[String] {
        let official=Set(context?.products.clinical.map(\.unit) ?? [])
        return official.filter{!["TBL","ML","LT"].contains($0.uppercased())}
            .sorted()
    }
    private var matchingProducts:[N2NursingCatalogProduct] {
        guard let catalog=context?.products.nursing else{return []}
        let q=productSearch.trimmingCharacters(in:.whitespacesAndNewlines)
        guard !q.isEmpty else{return []}
        return Array(catalog.filter{
            $0.name.localizedStandardContains(q)
        }.prefix(15))
    }
    /// Catalog rows without any registered lot are displayed as zero stock,
    /// not inserted into the audited stockLots ledger.
    private var productsWithoutLots:[N2NursingCatalogProduct] {
        guard let context else{return []}
        let registered=Set(context.lots.map(\.kardexCode))
        let query=zeroStockQuery.trimmingCharacters(in:.whitespacesAndNewlines)
        return context.products.nursing.filter { product in
            !registered.contains(product.id) &&
            (query.isEmpty || product.name.localizedStandardContains(query))
        }
    }
    /// The 432-product clinical catalog can contain supplies that are NOT
    /// among the 98 official nursing Kardex rows (e.g. ALGODON 500 GR).
    /// Expose these through a distinct auxiliary ledger, never by inventing
    /// official E- codes or modifying the 98-row workbook.
    private var clinicalOnlyMatches:[N2ClinicalCatalogProduct] {
        guard let context else{return []}
        let query=productSearch.trimmingCharacters(in:.whitespacesAndNewlines)
        guard query.count>=2 else{return []}
        return Array(context.products.clinical.filter { product in
            product.name.localizedStandardContains(query) &&
            context.products.authorizedNursingOptions(for:product.code).isEmpty &&
            !context.operationalMappings.contains(where:{
                $0.clinicalCode==product.code
            })
        }.prefix(12))
    }
    private struct LotGroup:Identifiable {
        var id:String{code}
        let code:String
        let name:String
        let total:Int
        let lots:[N2FormLot]
    }
    private var groupedLots:[LotGroup] {
        guard let context else{return []}
        return Dictionary(grouping:context.lots,by:\.kardexCode).map{code,lots in
            LotGroup(code:code,name:lots.first?.name ?? code,
                total:lots.count,lots:lots.sorted{
                    let a=$0.expires.isEmpty ? "9999-12-31":$0.expires
                    let b=$1.expires.isEmpty ? "9999-12-31":$1.expires
                    return a==b ? $0.reference<$1.reference:a<b
                })
        }.sorted{
            $0.name.localizedStandardCompare($1.name) == .orderedAscending
        }
    }
    private var material:N2NursingCatalogProduct? {
        context?.products.nursing.first{$0.id==materialCode}
    }
    private var selectedLot:N2FormLot? {
        context?.lots.first{$0.id==selectedLotID}
    }
    private func stockUnits(_ lot:N2FormLot)->Double {
        // Show Kardex U.M., not millilitres inside a sealed FCO/CJA.
        let loose=["UND","TBL","PAR","ML","LT"].contains(lot.unit.uppercased())
        return loose ? lot.total : Double(lot.sealed)
    }
    private var enteredQuantity:Double? {
        let raw=quantity.trimmingCharacters(in:.whitespacesAndNewlines)
            .replacingOccurrences(of:",",with:".")
        guard let q=Double(raw),q.isFinite,q>0,q<=10_000_000,
              (q*1000).rounded()==q*1000 else{return nil}
        return q
    }
    private var packaged:Bool {
        !unit.isEmpty && !["UND","TBL","PAR","ML","LT"].contains(unit)
    }
    private var lotCapacity:Int? {
        guard packaged else{return 1}
        if capacityInput.isEmpty {return 1}
        guard let value=Int(capacityInput),value>0,value<=10_000_000,
              capacityConfirmed,capacityEvidence.trimmingCharacters(in:.whitespacesAndNewlines).count>=10 else{return nil}
        return value
    }
    private var expiryISO:String? {
        guard expiryEnabled else{return ""}
        return N2ExpiryEntry.iso(expiryInput)
    }
    private var valid:Bool {
        guard context != nil,!busy,let amount=enteredQuantity else{return false}
        if mode=="lot" {
            return material != nil && !unit.isEmpty &&
                !lotNumber.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty &&
                expiryISO != nil && lotCapacity != nil && (!packaged || amount.rounded()==amount)
        }
        guard selectedLot != nil,reason.trimmingCharacters(in:.whitespacesAndNewlines).count>=8
        else{return false}
        let existingPackaged = !["UND","TBL","PAR","ML","LT"].contains(
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
                    zeroStockList
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
        .sheet(item:$closingLot) {lot in
            N2ContainerStateView(lot:lot,revision:context?.revision ?? 0) {Task {await load()}}
        }
        .sheet(item:$editingLot) {lot in
            N2LotMetadataEditor(lot:lot,onSaved:{Task {await load()}})
        }
        .sheet(isPresented:$showAuxiliaryInventory) {
            if let context,!auxiliaryCode.isEmpty {
                N2AuxiliaryInventoryView(code:auxiliaryCode,context:context,onSaved:{
                    showAuxiliaryInventory=false
                    Task {await load()}
                })
            }
        }
        .alert("¿Qué representa esta cantidad?",
               isPresented:$showStockBasisAlert) {
            Button("Stock inicial del día 9") {
                Task {await commit(basis:.opening)}
            }
            Button("Stock físico que tengo hoy") {
                Task {await commit(basis:.countedNow)}
            }
            Button("Cancelar",role:.cancel) {}
        } message: {
            Text("Inicial: cantidad con la que empezaste este corte; DANPER resta los consumos anteriores para obtener el saldo actual. Actual: cantidad que cuentas hoy; se conserva y se reconstruye el saldo inicial sumando los consumos registrados. No se descuentan dos veces.")
        }
        .onChange(of:materialCode) {_,_ in
            capacityInput="";capacityEvidence="";capacityConfirmed=false
        }
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
            productSearchFocused=false
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
                    if let material {
                        if let verified=material.unit {
                            LabeledContent("Presentación",value:verified)
                                .font(.subheadline)
                                .accessibilityIdentifier("inventory-verified-unit")
                        } else {
                            Text("Este producto no tiene una unidad de medida comprobada. Selecciona su presentación real; DANPER no asignará UND automáticamente.")
                                .font(.caption).foregroundStyle(.orange)
                            DanperChoiceField(title:"Presentación por verificar",
                                selection:$unit,options:verifiedUnitOptions)
                                .accessibilityIdentifier("inventory-unmapped-unit")
                        }
                    }
                    expiryField
                    if packaged {
                        DanperField(title:"Capacidad interna opcional verificada por envase") {
                            TextField("mL o unidades internas por envase",text:$capacityInput)
                                .keyboardType(.numberPad)
                                .accessibilityIdentifier("inventory-container-capacity")
                                .onChange(of:capacityInput) {_,_ in capacityConfirmed=false}
                        }
                        DanperField(title:"Evidencia de capacidad y unidad interna") {
                            TextField("Etiqueta o recuento verificado",text:$capacityEvidence,axis:.vertical)
                                .lineLimit(2...4)
                                .accessibilityIdentifier("inventory-capacity-evidence")
                        }
                        DanperCheckRow(selected:$capacityConfirmed) {
                            Text("Confirmo la capacidad real del envase")
                        }
                        Text("No se presupone una capacidad. Usa la misma unidad interna al registrar la correspondencia y el consumo físico.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }else {
                    DanperChoiceField(title:"Medicamento y lote",
                        selection:$selectedLotID,options:context?.lots.map(\.id) ?? [],
                        labels:Dictionary(uniqueKeysWithValues:(context?.lots ?? []).map{
                            ($0.id,$0.name+" · Lote "+($0.reference.isEmpty ? "sin referencia" : $0.reference))
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
                    Text("Al guardar te preguntaremos si es tu stock inicial del corte (día 9) o la cantidad física que tienes hoy. La elección modifica el cálculo, no es solo una etiqueta.")

                        .font(.caption).foregroundStyle(.secondary)
                }
                Button {
                    if mode=="lot" {
                        showStockBasisAlert=true
                    } else {
                        Task {await commit()}
                    }
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
            Text("Medicamento o insumo")
                .font(.subheadline.weight(.semibold))
            HStack(spacing:10) {
                Image(systemName:"magnifyingglass")
                    .foregroundStyle(DanperStyle.red)
                TextField("Escribe el nombre del medicamento o insumo",
                          text:$productSearch)
                    .focused($productSearchFocused)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .accessibilityIdentifier("inventory-select-product")
                if !productSearch.isEmpty {
                    Button {
                        productSearch=""
                        materialCode=""
                        unit=""
                        productSearchFocused=true
                    } label: {
                        Image(systemName:"xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Borrar búsqueda")
                }
            }
            .padding(13)
            .background(DanperStyle.canvas,
                        in:RoundedRectangle(cornerRadius:12))
            .onChange(of:productSearch){_,query in
                if let chosen=material,query != chosen.name {
                    materialCode=""
                    unit=""
                }
                revealTask?.cancel()
                if productSearchFocused && !query.isEmpty {
                    revealTask=Task { @MainActor in
                        do {try await Task.sleep(for:.milliseconds(220))}catch{return}
                        if productSearchFocused {reveal("inventory-product-results")}
                    }
                }
            }
            if productSearchFocused && !productSearch.isEmpty {
                if matchingProducts.isEmpty && clinicalOnlyMatches.isEmpty {
                    Text("No se encontró ese producto en el Kardex oficial ni en el catálogo clínico.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                if !matchingProducts.isEmpty {
                    ScrollView {
                        LazyVStack(spacing:5) {
                            ForEach(matchingProducts){product in
                                Button {
                                    materialCode=product.id
                                    unit=product.unit ?? ""
                                    productSearch=product.name
                                    productSearchFocused=false
                                } label: {
                                    VStack(alignment:.leading,spacing:3) {
                                        Text(product.name)
                                            .font(.subheadline.weight(.medium))
                                            .foregroundStyle(.primary)
                                        if let unit=product.unit {
                                            Text("Presentación: "+unit)
                                                .font(.caption).foregroundStyle(.secondary)
                                        }
                                    }
                                    .frame(maxWidth:.infinity,alignment:.leading)
                                    .padding(11)
                                    .background(DanperStyle.surface,
                                                in:RoundedRectangle(cornerRadius:10))
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .accessibilityIdentifier("inventory-result-"+product.id)
                            }
                        }
                    }
                    .frame(maxHeight:220)
                    .id("inventory-product-results")
                }
                if !clinicalOnlyMatches.isEmpty {
                    VStack(alignment:.leading,spacing:8) {
                        Text("Catálogo clínico · Inventario auxiliar")
                            .font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                        Text("Estos productos no ocupan filas del Kardex oficial de 98. Regístralos separadamente con su presentación y conteo físico.")
                            .font(.caption).foregroundStyle(.secondary)
                        ForEach(clinicalOnlyMatches){product in
                            Button {
                                auxiliaryCode=product.code
                                productSearchFocused=false
                                showAuxiliaryInventory=true
                            } label: {
                                HStack {
                                    VStack(alignment:.leading,spacing:3) {
                                        Text(product.name).font(.subheadline.weight(.semibold))
                                        Text("Inventario auxiliar · "+product.unit).font(.caption).foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Image(systemName:"arrow.up.right.square")
                                }
                                .frame(maxWidth:.infinity,alignment:.leading)
                                .padding(11)
                                .background(DanperStyle.surface,in:RoundedRectangle(cornerRadius:10))
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("inventory-auxiliary-"+product.code)
                        }
                    }
                }
            }
        }
    }
    private var expiryField:some View {
        VStack(alignment:.leading,spacing:7) {
            DanperCheckRow(selected:$expiryEnabled) {
                Text("Tiene fecha de vencimiento").font(.subheadline)
            }
            if expiryEnabled {
                DanperField(title:"Vencimiento · DD/MM/AA") {
                    N2ExpiryTextField(text:$expiryInput).frame(minHeight:44)
                }
                if expiryISO==nil {
                    Text("Escribe seis dígitos: día, mes y año. No se abre el calendario.")
                        .font(.caption).foregroundStyle(.orange)
                }
            }
        }
    }
    private var zeroStockList:some View {
        DanperPanel {
            DisclosureGroup("Sin lotes registrados · stock 0") {
                Text("El producto sigue en el Kardex aunque no tenga lote. Stock registrado: 0; no equivale a un conteo físico verificado.")
                    .font(.caption).foregroundStyle(.secondary)
                TextField("Buscar producto sin stock",text:$zeroStockQuery)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .accessibilityIdentifier("inventory-zero-stock-search")
                ForEach(productsWithoutLots) {product in
                    HStack {
                        Text(product.name).font(.caption)
                        Spacer(minLength:8)
                        Text("0"+(product.unit.map{" "+$0} ?? ""))
                            .font(.caption.weight(.semibold))
                            .monospacedDigit()
                    }
                    .accessibilityIdentifier("inventory-zero-stock-"+product.id)
                }
            }
        }
    }
    private var lotList:some View {
        DanperPanel("Inventario por medicamento") {
            if !groupedLots.isEmpty {
                Text("\(groupedLots.count) medicamentos · \(context?.lots.count ?? 0) lotes registrados")
                    .font(.caption).foregroundStyle(.secondary)
                ForEach(groupedLots) {group in
                    DisclosureGroup {
                        ForEach(group.lots) {lot in
                            VStack(alignment:.leading,spacing:9) {
                                HStack {
                                    Text("Lote: "+(lot.reference.isEmpty ? "Sin referencia":lot.reference))
                                        .font(.subheadline.weight(.semibold))
                                    Spacer()
                                    Text("\(stockUnits(lot).formatted()) \(lot.unit)")
                                        .font(.subheadline.weight(.semibold))
                                        .monospacedDigit()
                                }
                                Text("Vencimiento: "+DanperDatePresentation.display(lot.expires))
                                    .font(.caption).foregroundStyle(.secondary)
                                if N2ContainerAccounting.isContainer(unit:lot.unit) {
                                    Text("Abiertos: \(lot.openContainers)")
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                                HStack {
                                    Button {
                                        editingLot=lot
                                    } label: {
                                        Label("Editar lote",systemImage:"square.and.pencil")
                                    }.buttonStyle(.bordered)
                                        .accessibilityIdentifier("inventory-edit-lot-"+lot.id)
                                    Button {
                                        selectedLotID=lot.id
                                        mode="count"
                                        workspace="edit"
                                        quantity=""
                                    } label: {
                                        Label("Actualizar conteo",systemImage:"checkmark.shield")
                                    }.buttonStyle(.bordered)
                                }
                                if lot.openContainers>0 &&
                                   N2ContainerAccounting.isContainer(unit:lot.unit) {
                                    Button("Declarar agotado, cerrado o descartado") {
                                        closingLot=lot
                                    }
                                    .font(.caption)
                                }
                                Divider()
                            }
                            .frame(maxWidth:.infinity,alignment:.leading)
                            .accessibilityIdentifier("inventory-lot-"+lot.reference)
                        }
                    } label: {
                        HStack {
                            Text(group.name).font(.subheadline.weight(.semibold))
                            Spacer(minLength:8)
                            Text("\(group.total) lote(s)")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    .accessibilityIdentifier("inventory-group-"+group.code)
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
    @MainActor private func commit(basis:N2StockRegistrationBasis?=nil) async {
        guard valid,let current=context,let qty=enteredQuantity else{return}
        busy=true
        failed=false
        defer{busy=false}
        if movementAt==0 {movementAt=Int64(Date().timeIntervalSince1970*1000)}
        do {
            let result:N2ProtectedStoreSummary
            var cutOpeningEstimate:Double?
            if mode=="lot" {
                guard let material,let expiryISO,let lotCapacity,
                      let basis else{return}
                let isPack=packaged
                let formatter=DateFormatter()
                formatter.locale=Locale(identifier:"en_US_POSIX")
                formatter.timeZone=TimeZone(identifier:"America/Lima")
                formatter.dateFormat="yyyy-MM-dd"
                let registrationDay=formatter.string(from:
                    Date(timeIntervalSince1970:Double(movementAt)/1000))
                let cut=try await vault.automaticCutAccounting(through:registrationDay)
                let period=try N2KardexCutPreview.period(for:registrationDay)
                if basis == .opening &&
                    current.lots.contains(where:{$0.kardexCode==material.id}) {
                    failed=true
                    message="Ya existen lotes de este producto. No puedes registrar otro stock inicial duplicado; usa conteo actual o ingreso adicional."
                    return
                }
                let previous=cut.rows.first{$0.code==material.id}
                let amount:N2StockRegistrationChoice.Resolution
                do {
                    amount=try N2StockRegistrationChoice.resolve(basis,quantity:qty,
                        historical:previous,isContainer:isPack)
                } catch N2StockRegistrationChoice.Failure.ambiguousHistoricalOpenings {
                    failed=true
                    message="Hay frascos o cajas usados sin apertura confirmada. Declara primero sus aperturas (1/0), o registra el stock físico que tienes hoy."
                    return
                } catch N2StockRegistrationChoice.Failure.negativeCurrentStock {
                    failed=true
                    message="El stock inicial indicado es menor que los consumos del período. Revisa la cantidad o elige stock físico actual."
                    return
                }
                cutOpeningEstimate=amount.cutOpening
                var record:[String:Any]=[
                    "id":lotID,"code":material.id,"name":material.name,
                    "catalogUnit":unit,"lot":lotNumber,
                    "expires":expiryISO,
                    "container":isPack ? (
                        unit=="FCO" ? "frasco" : unit=="CJA" ? "caja" : "paquete"
                    ) : "unidad",
                    "unitsPerContainer":isPack ? lotCapacity : 1,
                    "sealedContainers":isPack ? Int(amount.todayPhysical) : 0,
                    "looseUnits":isPack ? 0 : amount.todayPhysical,
                    "openedRemaining":0,"updatedAt":movementAt,
                    "stockRegistrationBasis":basis.rawValue,
                    "stockRegistrationCutStart":period.start,
                    "stockRegistrationEnteredQuantity":qty,
                    "stockRegistrationCurrentQuantity":amount.todayPhysical
                ]
                if isPack {
                    record["declaredOpenContainers"]=0
                    record["volumeTrackingEnabled"] = !capacityInput.isEmpty
                    if !capacityInput.isEmpty {
                        record["capacityEvidence"]=capacityEvidence
                        record["capacityVerifiedAt"]=movementAt
                    }
                }
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
            productSearch=""
            unit=""
            selectedLotID=""
            quantity=""
            lotNumber=""
            expiryEnabled=false
            expiryInput=""
            capacityInput=""
            capacityEvidence=""
            capacityConfirmed=false
            reason=""
            if mode=="lot",let basis {
                if let opening=cutOpeningEstimate {
                    message=(basis == .opening
                        ? "Stock inicial declarado: "
                        : "Stock físico actual registrado. Stock inicial estimado del día 9: ") +
                        opening.formatted() +
                        ". Los consumos anteriores se consideran una sola vez."
                } else {
                    message="Stock físico actual guardado. El saldo inicial del día 9 está pendiente de verificar aperturas o consumos históricos; no se crearon descuentos."
                }
            } else {
                message="Existencias registradas correctamente en el Kardex único."
            }
        }catch{
            failed=true
            message="No se guardó la operación. Revisa lote, cantidad y existencias sin crear registros duplicados."
        }
    }
}


/// Labels and expirations of UNUSED lots may be corrected, never their
/// physical balances. Used-lot changes must go through auditable movements.
private struct N2LotMetadataEditor:View {
    let lot:N2FormLot
    let onSaved:()->Void
    @Environment(\.n2WorkspaceVault) private var vault
    @Environment(\.dismiss) private var dismiss
    @State private var reference:String
    @State private var expiry:String
    @State private var reason=""
    @State private var operatorName=""
    @State private var busy=false
    @State private var error=""
    @State private var confirm=false
    init(lot:N2FormLot,onSaved:@escaping ()->Void) {
        self.lot=lot
        self.onSaved=onSaved
        _reference=State(initialValue:lot.reference)
        let p=lot.expires.split(separator:"-")
        let ddmmyy=p.count==3
            ? "\(p[2])/\(p[1])/\(p[0].suffix(2))":""
        _expiry=State(initialValue:ddmmyy)
    }
    private var expiryISO:String? {
        expiry.isEmpty ? "" : N2ExpiryEntry.iso(expiry)
    }
    private var valid:Bool {
        !busy && !reference.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty &&
        expiryISO != nil &&
        reason.trimmingCharacters(in:.whitespacesAndNewlines).count>=8 &&
        operatorName.trimmingCharacters(in:.whitespacesAndNewlines).count>=3
    }
    var body:some View {
        NavigationStack {
            Form {
                Section("Identificación del lote") {
                    LabeledContent("Medicamento",value:lot.name)
                    TextField("Número de lote",text:$reference)
                    LabeledContent("Cantidad física (solo lectura)",
                                   value:lot.total.formatted()+" "+lot.unit)
                    Text("Para cambiar existencias utiliza «Actualizar conteo». No se modificará ningún consumo.")
                        .font(.caption).foregroundStyle(.secondary)
                    N2ExpiryTextField(text:$expiry).frame(minHeight:44)
                    Text("Lotes con movimientos antiguos no permiten reescribir su fecha o referencia: sus registros históricos deben permanecer intactos.")
                        .font(.caption).foregroundStyle(.orange)
                }
                Section("Rectificación documentada") {
                    TextField("Motivo de la corrección",text:$reason,axis:.vertical)
                        .lineLimit(2...4)
                    TextField("Responsable",text:$operatorName)
                    Button("Guardar corrección del lote") {confirm=true}
                        .disabled(!valid)
                        .confirmationDialog("¿Confirmar la corrección del lote?",
                            isPresented:$confirm,titleVisibility:.visible) {
                            Button("Sí, guardar"){Task{await save()}}
                            Button("No",role:.cancel){}
                        } message: {
                            Text("Solo cambia la referencia y el vencimiento de un lote sin movimientos. Se registra el motivo y responsable.")
                        }
                }
                if !error.isEmpty {
                    Section {Text(error).foregroundStyle(.orange)}
                }
            }
            .navigationTitle("Editar lote")
            .toolbar {
                ToolbarItem(placement:.topBarTrailing) {
                    Button("Cerrar"){dismiss()}
                }
            }
        }
    }
    @MainActor private func save() async {
        guard valid,let expires=expiryISO else{return}
        busy=true
        defer{busy=false}
        do {
            let current=try await vault.clinicalFormContext()
            _=try await vault.correctUnusedLot(lotID:lot.id,
                reference:reference,expires:expires,reason:reason,
                operatorName:operatorName,
                at:Int64(Date().timeIntervalSince1970*1000),
                expectedRevision:current.revision)
            onSaved()
            dismiss()
        } catch {
            self.error="No se pudo modificar. Si el lote ya tuvo movimientos, conserva su referencia histórica y utiliza un movimiento de ajuste para las existencias."
        }
    }
}
