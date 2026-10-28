import SwiftUI
import DanperCore

func n2SimpleMessage(_ error:Error)->String {
    if let e=error as? N2SimpleInventoryError {
        switch e {
        case .insufficientStock:return "No hay existencias suficientes. Revisa el conteo antes de registrar la salida."
        case .sourceChanged:return "Los datos cambiaron desde el respaldo. Genera y verifica una copia actual antes de continuar."
        case .missingBackup:return "Guarda y verifica el respaldo cifrado antes de activar el inventario."
        case .alreadyActive:return "El inventario nuevo ya está activo. No se reinició nuevamente."
        case .conflictingClinicalRecord:return "El respaldo contiene registros con el mismo identificador y datos diferentes. No se reemplazó información; revisa el conflicto en la fuente."
        case .invalidDeclaration:return "Indica si abriste una presentación nueva: R=1 o R=0."
        case .invalidQuantity:return "Revisa la cantidad. Las presentaciones completas se cuentan con números enteros."
        case .invalidDate:return "Revisa la fecha de vencimiento de referencia."
        case .confirmationRequired:return "Confirma expresamente la operación para continuar."
        default:return "No se pudo verificar esta operación. Actualiza la pantalla y revisa los datos antes de repetirla."
        }
    }
    if error is N2InventoryBackupCodec.Failure {return "No se verificó el respaldo. Revisa la contraseña y la integridad del archivo."}
    if error is CancellationError {return "Operación interrumpida. Actualiza la pantalla para comprobar el estado antes de repetirla."}
    if error as? N2ProtectedStoreError == .targetNotEmpty {
        return "Esta fuente ya contiene datos. Usa Restaurar historial clínico sin reemplazar inventario."
    }
    return "No se completó la verificación. Actualiza los datos y comprueba el estado antes de repetir la operación."
}
func n2SimpleDateTime(_ at:Int64)->String {
    let f=DateFormatter();f.locale=Locale(identifier:"es_PE");f.timeZone=TimeZone(identifier:"America/Lima")
    f.dateFormat="dd/MM/yyyy HH:mm";return f.string(from:Date(timeIntervalSince1970:Double(at)/1000))
}
func n2SimpleExpiry(_ p:N2SimpleProduct)->String {
    N2InventoryPresentation.expiryText(p)
}
private struct N2SimpleEditorRoute:Identifiable {
    let id=UUID()
    var operation:N2SimpleInventoryCommand.Operation
    var product:N2SimpleProduct?
    var incident:N2SimpleIncident?
}
struct N2SimpleInventoryView:View {
    var layoutContext:N2SimpleInventoryContext?=nil
    var initialOperation:String?=nil
    @Environment(\.n2WorkspaceVault) private var vault
    @State private var context:N2SimpleInventoryContext?
    @State private var loading=true
    @State private var error=""
    @State private var query=""
    @State private var filter:N2InventoryFilter = .all
    @State private var editor:N2SimpleEditorRoute?
    @State private var presentedInitialOperation=false
    var body:some View {
        ScrollView {
            VStack(alignment:.leading,spacing:16) {
                if let context {
                    if let state=context.state {inventory(context,state)}
                    else {N2SimpleMigrationSetup(context:context,onActivated:{Task {await load()}})}
                } else if loading {DanperLoadingState(title:"Verificando inventario…")}
                if !error.isEmpty {DanperErrorState(message:error,retry:{Task {await load()}})}
            }.padding(16)
        }
        .safeAreaInset(edge:.top,spacing:0) {
            if let context,context.state != nil {inventoryControls(context)}
        }
        .navigationTitle("Inventario").navigationBarTitleDisplayMode(.inline).danperFormChrome()
        .task {if let layoutContext {context=layoutContext;loading=false}else{await load()}}.refreshable {await load()}
        .sheet(item:$editor,onDismiss:{Task {await load()}}) {route in
            if let context {
                NavigationStack {N2SimpleProductEditor(context:context,operation:route.operation,
                    product:route.product,incident:route.incident)}
            }
        }
    }
    @ViewBuilder private func inventory(_ context:N2SimpleInventoryContext,_ state:N2SimpleInventoryState)->some View {
        DanperPanel {
            Label("Inventario compartido",systemImage:"shippingbox.fill").font(.title3.bold())
            Text("Fundo y Planta La Venturosa · una existencia por producto y presentación.")
                .font(.footnote).foregroundStyle(.secondary)
            LabeledContent("Productos contados",value:String(state.products.count))
            Text("Último inicio: "+n2SimpleDateTime(state.regime.activatedAt)).font(.caption).foregroundStyle(.secondary)
        }
        Button {editor=N2SimpleEditorRoute(operation:.register)} label:{Label("Registrar inventario",systemImage:"plus")}
            .buttonStyle(DanperPrimaryButton()).accessibilityIdentifier("simple-register-product")
        if state.products.isEmpty {Text("Registra el primer conteo físico. Sin conteo no se presume una existencia comprobada.").foregroundStyle(.secondary)}
        LazyVStack(spacing:12) {
            ForEach(N2InventoryPresentation.products(state.products,catalog:context.catalog,filter:filter,query:query)) {p in
                NavigationLink {
                    N2SimpleProductDetail(code:p.code)
                } label:{N2GlassInventoryRow(product:p,catalog:context.catalog)}.buttonStyle(.plain).accessibilityIdentifier("simple-product-"+p.code)
            }
        }
        if N2InventoryPresentation.products(state.products,catalog:context.catalog,filter:filter,query:query).isEmpty && !state.products.isEmpty {
            DanperEmptyState(title:"No hay productos con estos filtros",symbol:"magnifyingglass")
        }
        if state.products.contains(where:{N2InventoryPresentation.category(code:$0.code,catalog:context.catalog)==nil}) {
            Text("Los productos con clasificación pendiente se muestran en Todos.")
                .font(.caption).foregroundStyle(.secondary)
        }
        if !state.incidents.filter({$0.resolutionEventID==nil}).isEmpty {incidents(context,state)}
        DanperPanel("Kardex y respaldo") {
            NavigationLink {N2SimpleCutView()} label:{Label("Corte mensual · del 9 al 8",systemImage:"calendar")}
            NavigationLink {N2OccupationalVigilanceExportView()} label:{Label("Vigilancia ocupacional",systemImage:"heart.text.square")}
            NavigationLink {N2VerifiedNursingExportView()} label:{Label("Kardex · Excel oficial",systemImage:"tablecells")}
            NavigationLink {N2VerifiedIndicatorExportView()} label:{Label("Excel ambulatorio",systemImage:"chart.bar.doc.horizontal")}
            NavigationLink {N2SimpleRestoreView(kind:.clinical)} label:{Label("Restaurar historial clínico sin reemplazar inventario",systemImage:"clock.arrow.circlepath")}
        }
    }
    private func inventoryControls(_ context:N2SimpleInventoryContext)->some View {
        VStack(spacing:10) {
            Picker("Tipo de producto",selection:$filter) {
                ForEach(N2InventoryFilter.allCases) {Text($0.rawValue).tag($0)}
            }.pickerStyle(.segmented).accessibilityIdentifier("glass-inventory-filter")
            HStack(spacing:10) {
                Image(systemName:"magnifyingglass").foregroundStyle(.secondary).accessibilityHidden(true)
                TextField("Nombre, presentación o código",text:$query,
                    prompt:Text("Nombre, presentación o código").foregroundStyle(.secondary))
                    .font(.subheadline).autocorrectionDisabled()
                    .accessibilityLabel("Buscar medicamento o insumo")
                    .accessibilityIdentifier("simple-inventory-search")
                if !query.isEmpty {
                    Button {query=""} label:{Image(systemName:"xmark.circle.fill")}
                        .accessibilityLabel("Borrar búsqueda").accessibilityIdentifier("glass-inventory-clear-search")
                }
            }.padding(12).danperGlassSurface(cornerRadius:15)
        }.padding(.horizontal,16).padding(.vertical,10)
            .background(.regularMaterial)
            .environment(\.colorScheme,.dark)
    }
    private func incidents(_ context:N2SimpleInventoryContext,_ state:N2SimpleInventoryState)->some View {
        DanperPanel("Salidas por revisar") {
            Text("Las atenciones están conservadas. Resolver una incidencia no repite una salida ya contabilizada.")
                .font(.footnote).foregroundStyle(.secondary)
            ForEach(state.incidents.filter{$0.resolutionEventID==nil}) {i in
                VStack(alignment:.leading,spacing:7) {
                    Text(context.catalog.clinical.first{$0.code==i.code}?.name ?? i.code).font(.headline)
                    Text(i.reason).font(.footnote).foregroundStyle(.orange)
                    if let p=state.products.first(where:{$0.code==i.code && $0.unit==i.unit}) {
                        Button("Revisar declaración") {editor=N2SimpleEditorRoute(operation:.resolveIncident,product:p,incident:i)}
                            .accessibilityIdentifier("simple-resolve-"+i.id)
                    }else {Text("Registra primero el conteo de esta presentación.").font(.caption)}
                    NavigationLink("Ver atención") {N2ClinicalCorrectionView(visitID:i.visitID)}
                }
            }
        }
    }
    @MainActor private func load() async {
        loading=true;defer{loading=false}
        do {
            let result=try await vault.simpleInventoryContext();context=result;error=""
            if result.state != nil,!presentedInitialOperation,initialOperation=="lot" {
                presentedInitialOperation=true;editor=N2SimpleEditorRoute(operation:.register)
            }
        }catch {self.error=n2SimpleMessage(error)}
    }
}

struct N2SimpleProductDetail:View {
    let code:String
    @Environment(\.n2WorkspaceVault) private var vault
    @State private var context:N2SimpleInventoryContext?
    @State private var editor:N2SimpleEditorRoute?
    @State private var error=""
    var body:some View {
        ScrollView {
            VStack(alignment:.leading,spacing:16) {
                if let context,let state=context.state,let p=state.products.first(where:{$0.code==code}) {
                    summary(p)
                    actions(p)
                    DanperPanel("Movimientos") {
                        ForEach(state.movements.filter{$0.code==code}.reversed()) {m in
                            VStack(alignment:.leading,spacing:5) {
                                HStack {
                                    Text(m.kind=="initial" ? "Inventario inicial":(m.kind=="receipt" ? "Ingreso":(m.kind=="count" ? "Conteo físico":"Salida"))).font(.headline)
                                    Spacer();Text(m.delta.formatted()).font(.headline.monospacedDigit())
                                }
                                Text(m.before.formatted()+" → "+m.after.formatted()).font(.subheadline)
                                if let r=m.declaredR {Text("Declaración manual R=\(r)").foregroundStyle(DanperStyle.red)}
                                Text(n2SimpleDateTime(m.at)+" · "+m.operatorName).font(.caption).foregroundStyle(.secondary)
                                Text(m.reason).font(.caption)
                                if let id=m.visitID {NavigationLink("Ver atención") {N2ClinicalCorrectionView(visitID:id)}}
                            }.padding(.vertical,5)
                        }
                    }
                    DanperPanel("Cambios de vencimiento") {
                        ForEach(state.metadataEvents.filter{$0.code==code}.reversed()) {e in
                            Text((e.next.isEmpty ? "Pendiente":DanperDatePresentation.display(e.next))+" · "+(e.verified ? "Referencia verificada":"Por verificar"))
                            Text(n2SimpleDateTime(e.at)+" · "+e.operatorName+" · "+e.reason).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }else if error.isEmpty {DanperLoadingState(title:"Verificando producto…")}
                if !error.isEmpty {DanperErrorState(message:error,retry:{Task {await load()}})}
            }.padding(16)
        }.navigationTitle("Existencias").navigationBarTitleDisplayMode(.inline).danperFormChrome()
            .task {await load()}.refreshable {await load()}
            .sheet(item:$editor,onDismiss:{Task {await load()}}) {route in
                if let context {NavigationStack {N2SimpleProductEditor(context:context,operation:route.operation,product:route.product)}}
            }
    }
    private func summary(_ p:N2SimpleProduct)->some View {
        DanperPanel {
            Text(p.name).font(.title3.bold())
            Text("Presentación original: "+p.unit).font(.footnote).foregroundStyle(.secondary)
            Text(p.quantity.formatted()).font(.largeTitle.bold()).accessibilityIdentifier("simple-stock-"+p.code)
                .accessibilityValue(String(p.quantity))
            Text(p.mode == .presentation ? "Presentaciones físicas":"Unidades: "+p.unit)
            Text(n2SimpleExpiry(p)).foregroundStyle(p.expiryVerified ? Color.secondary:.orange)
            Text("Es una referencia manual. Comprueba físicamente el producto antes de su uso.").font(.caption).foregroundStyle(.secondary)
            Text("Último conteo: "+n2SimpleDateTime(p.lastCountAt)).font(.caption)
        }
    }
    private func actions(_ p:N2SimpleProduct)->some View {
        DanperPanel("Acciones") {
            Button("Registrar ingreso") {editor=N2SimpleEditorRoute(operation:.receipt,product:p)}.accessibilityIdentifier("simple-receipt")
            Button("Registrar salida") {editor=N2SimpleEditorRoute(operation:.outflow,product:p)}.accessibilityIdentifier("simple-outflow")
            Button("Actualizar conteo físico") {editor=N2SimpleEditorRoute(operation:.count,product:p)}.accessibilityIdentifier("simple-count")
            Button("Actualizar vencimiento") {editor=N2SimpleEditorRoute(operation:.expiry,product:p)}.accessibilityIdentifier("simple-expiry")
        }
    }
    @MainActor private func load() async {
        do {context=try await vault.simpleInventoryContext();error=""}catch{self.error=n2SimpleMessage(error)}
    }
}

/// Every value comes from the consolidated v2 projection; expiry is reference
/// metadata, independent of stock (including a zero physical balance).
struct N2GlassInventoryRow:View {
    let product:N2SimpleProduct
    let catalog:N2NativeCatalogIndex
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    private var status:N2InventoryPresentation.Expiry {N2InventoryPresentation.expiry(product)}
    private var statusColor:Color {
        switch status {case .valid:return .green;case .near:return .yellow;case .expired:return .red;case .unverified:return .gray}
    }
    var body:some View {
        let layout=dynamicTypeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment:.leading,spacing:12)):AnyLayout(HStackLayout(alignment:.top,spacing:12))
        layout {
            HStack(alignment:.top,spacing:11) {
                Image(systemName:N2InventoryPresentation.symbol(product,catalog:catalog))
                    .font(.system(size:21,weight:.medium)).foregroundStyle(DanperStyle.red)
                    .frame(width:38,height:44).background(DanperStyle.red.opacity(0.12),in:RoundedRectangle(cornerRadius:13))
                    .accessibilityHidden(true)
                VStack(alignment:.leading,spacing:7) {
                    Text(product.name).font(.subheadline.weight(.semibold)).foregroundStyle(.primary)
                        .fixedSize(horizontal:false,vertical:true)
                    Text("Presentación: "+product.unit).font(.caption).foregroundStyle(.secondary)
                    Label(N2InventoryPresentation.expiryText(product),systemImage:status == .unverified ? "questionmark.circle":"calendar")
                        .font(.caption2.weight(.medium)).foregroundStyle(statusColor)
                        .fixedSize(horizontal:false,vertical:true)
                        .accessibilityIdentifier("glass-expiry-"+product.code)
                    if product.quantity==0 {
                        Text("Sin existencias").font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
                    }
                    if N2InventoryPresentation.category(code:product.code,catalog:catalog)==nil {
                        Text("Clasificación pendiente").font(.caption2).foregroundStyle(.secondary)
                    }
                }
            }.frame(maxWidth:.infinity,alignment:.leading)
            VStack(alignment:.trailing,spacing:3) {
                Text(product.quantity.formatted()).font(.system(.largeTitle,weight:.semibold,design:.rounded))
                    .monospacedDigit().lineLimit(1).minimumScaleFactor(0.6)
                    .accessibilityIdentifier("simple-stock-"+product.code)
                Text(product.unit).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                Image(systemName:"chevron.right").font(.caption2).foregroundStyle(.secondary).padding(.top,5).accessibilityHidden(true)
            }.frame(minWidth:64,maxWidth:95,alignment:.trailing)
        }.padding(14).frame(maxWidth:.infinity,alignment:.leading)
            .danperGlassSurface(cornerRadius:20).environment(\.colorScheme,.dark)
    }
}
