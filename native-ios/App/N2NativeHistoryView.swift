import SwiftUI
import DanperCore

/// Read-only reusable native roster + history viewer.
/// The preview route always uses a bundled synthetic JSON sample. A future
/// real vault must authenticate before handing a snapshot to this view.
struct N2NativeHistoryView: View {
    init(useProtectedVault:Bool=false,showWorkers:Bool=false){
        self.useProtectedVault=useProtectedVault
        self.showWorkers=showWorkers
    }
    #if DEBUG
    init(layoutProjection:N2NativeReadModel) {
        layoutOnly=true
        _projection=State(initialValue:layoutProjection)
    }
    #endif
    private var layoutOnly=false
    @Environment(\.n2WorkspaceVault) private var vault
    var useProtectedVault = false
    private var showWorkers=false
    @State private var projection:N2NativeReadModel?
    @State private var query=""
    @State private var committedQuery=""
    @State private var selectedDNI:String?
    @State private var rosterPage=0
    @State private var visitsPage=0
    private let pageSize=25
    private let visitsPageSize=15
    @State private var hasError=false
    private let accent=Color(red:0.88,green:0.09,blue:0.16)

    var body:some View {
        Group {
            if let projection {
                let matches=showWorkers ? projection.findWorkers(committedQuery) : []
                let savedVisits=projection.visits.filter{
                    $0.status=="saved" &&
                    (committedQuery.isEmpty ||
                     $0.workerName.localizedStandardContains(committedQuery) ||
                     $0.workerDNI.localizedStandardContains(committedQuery) ||
                     $0.diagnosis.localizedStandardContains(committedQuery) ||
                     $0.date.localizedStandardContains(committedQuery))
                }
                let visitPages=max(1,(savedVisits.count+visitsPageSize-1)/visitsPageSize)
                let safeVisitsPage=min(visitsPage,visitPages-1)
                let totalPages=max(1,(matches.count+pageSize-1)/pageSize)
                let safePage=min(rosterPage,totalPages-1)
                ScrollViewReader { proxy in
                ScrollView {
                  VStack(alignment:.leading,spacing:16) {
                    DanperPanel {
                        Label(useProtectedVault ? "Historial de atenciones" : "Historial de ejemplo",
                              systemImage:"lock.shield.fill")
                            .foregroundStyle(.secondary)
                        Text(useProtectedVault ? "Consulta los registros y sus consumos guardados." : "Consulta las atenciones disponibles.")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                    if showWorkers {
                    DanperPanel("Directorio · \(projection.searchableRoster.count) disponibles") {
                        Color.clear.frame(height:1).id("roster-page-top")
                        Text("\(matches.count) resultados · Página \(safePage+1) de \(totalPages)")
                            .font(.caption).foregroundStyle(.secondary)
                        ForEach(Array(matches.dropFirst(safePage*pageSize).prefix(pageSize))) { w in
                            Button {
                                selectedDNI = w.dni
                            } label: {
                                HStack {
                                    VStack(alignment:.leading,spacing:4) {
                                        Text(w.name).font(.headline).foregroundStyle(.primary)
                                        Text(w.dni+" · "+w.area)
                                            .font(.caption).foregroundStyle(.secondary)
                                        if !w.site.isEmpty {
                                            Text(w.site).font(.caption2).foregroundStyle(.secondary)
                                        }
                                    }
                                    Spacer()
                                    Image(systemName:"chevron.right")
                                        .foregroundStyle(.tertiary)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                        if totalPages>1 {
                            HStack {
                                Button("Anterior") {
                                    rosterPage=max(0,safePage-1)
                                    withAnimation(.easeOut(duration:0.18)){
                                        proxy.scrollTo("roster-page-top",anchor:.top)
                                    }
                                }.disabled(safePage==0)
                                Spacer()
                                Text("\(safePage+1) / \(totalPages)")
                                    .font(.caption).monospacedDigit()
                                Spacer()
                                Button("Siguiente") {
                                    rosterPage=min(totalPages-1,safePage+1)
                                    withAnimation(.easeOut(duration:0.18)){
                                        proxy.scrollTo("roster-page-top",anchor:.top)
                                    }
                                }.disabled(safePage==totalPages-1)
                            }.buttonStyle(.bordered)
                        }
                    }
                    }
                    if !showWorkers {
                        DanperPanel("Atenciones registradas") {
                            Color.clear.frame(height:1).id("history-visits-top")
                            Text("\(savedVisits.count) atenciones · Página \(safeVisitsPage+1) de \(visitPages)")
                                .font(.caption).foregroundStyle(.secondary)
                            Text("Toca una atención para ver sus datos, tratamiento, consumos o solicitar una rectificación.")
                                .font(.caption).foregroundStyle(.secondary)
                            ForEach(Array(savedVisits.dropFirst(safeVisitsPage*visitsPageSize).prefix(visitsPageSize))) { visit in
                                NavigationLink {
                                    N2RecordedVisitDetailView(visitID:visit.id,
                                        visit:visit,realSource:useProtectedVault)
                                } label: {
                                    HStack(alignment:.top,spacing:10) {
                                        VStack(alignment:.leading,spacing:5) {
                                            Text(visit.workerName)
                                                .font(.subheadline.weight(.semibold))
                                            Text(DanperDatePresentation.displayDateTime(visit.date,visit.time))
                                                .font(.caption).foregroundStyle(.secondary)
                                            Text(visit.diagnosis.isEmpty ? "Sin diagnóstico":visit.diagnosis)
                                                .font(.footnote).foregroundStyle(.secondary)
                                            if visit.pendingPhysicalLines>0 {
                                                Label("\(visit.pendingPhysicalLines) salida(s) históricas por verificar",
                                                      systemImage:"info.circle")
                                                    .font(.caption2).foregroundStyle(.orange)
                                            }
                                        }
                                        Spacer()
                                        Image(systemName:"chevron.right")
                                            .font(.caption).foregroundStyle(.secondary)
                                    }
                                    .padding(13)
                                    .frame(maxWidth:.infinity,alignment:.leading)
                                    .background(DanperStyle.canvas,in:RoundedRectangle(cornerRadius:13))
                                }
                                .buttonStyle(.plain)
                                .accessibilityIdentifier("history-visit-"+visit.id)
                            }
                            if visitPages>1 {
                                HStack {
                                    Button("Anterior") {
                                        visitsPage=max(0,safeVisitsPage-1)
                                        proxy.scrollTo("history-visits-top",anchor:.top)
                                    }.disabled(safeVisitsPage==0)
                                    Spacer()
                                    Text("\(safeVisitsPage+1)/\(visitPages)")
                                        .font(.caption).monospacedDigit()
                                    Spacer()
                                    Button("Siguiente") {
                                        visitsPage=min(visitPages-1,safeVisitsPage+1)
                                        proxy.scrollTo("history-visits-top",anchor:.top)
                                    }.disabled(safeVisitsPage>=visitPages-1)
                                }.buttonStyle(.bordered)
                            }
                        }
                    }
                  }.padding(16)
                }
                .searchable(text:$query,prompt:showWorkers
                    ? "Buscar DNI, nombres o área"
                    : "Buscar trabajador, DNI, diagnóstico o fecha")
                .task(id:query) {
                    // Do not filter and re-layout 9,648 workers on every
                    // keystroke. A brief cancellable debounce keeps search
                    // responsive without discarding the full roster.
                    do {try await Task.sleep(for:.milliseconds(140))}
                    catch{return}
                    guard !Task.isCancelled else{return}
                    committedQuery=query
                    rosterPage=0
                    visitsPage=0
                    proxy.scrollTo(showWorkers ? "roster-page-top":"history-visits-top",anchor:.top)
                }
                .navigationDestination(item:$selectedDNI) { dni in
                    N2WorkerHistoryDetail(dni:dni,model:projection,realSource:useProtectedVault)
                }
                }
            } else {
                ContentUnavailableView(
                    hasError ? (useProtectedVault ? "Historial no disponible" :
                                "No se pudo verificar la muestra") :
                               "Abriendo historial nativo",
                    systemImage:"lock.doc",
                    description:Text(useProtectedVault ?
                        "No hay un historial verificado disponible para esta bóveda." :
                        "Verificación de registros ficticios."))
            }
        }
        .navigationTitle(showWorkers ? "Personal" : "Historial de atenciones")
        .danperFormChrome()
        .task {await load()}
        .refreshable {await load(force:true)}
        .tint(.primary)
    }

    @ViewBuilder
    private func visitCell(_ visit:N2VisitIndexRow) -> some View {
        VStack(alignment:.leading,spacing:5) {
            HStack {
                Text(visit.workerName).font(.subheadline.weight(.semibold))
                Spacer()

            }
            Text(DanperDatePresentation.displayDateTime(visit.date,visit.time)).font(.caption).foregroundStyle(.secondary)
            Text(visit.diagnosis.isEmpty ? "Borrador sin diagnóstico" : visit.diagnosis)
                .font(.footnote)
            HStack(spacing:10) {
                Text(visit.status=="saved" ? "ATENCIÓN" : "BORRADOR")
                if let frequency=visit.frequency {Text(frequency)}
                if visit.pendingPhysicalLines>0 {
                    Label("\(visit.pendingPhysicalLines) pendiente(s)",systemImage:"exclamationmark.circle")
                }
            }
            .font(.caption2).foregroundStyle(.secondary)
        }
        .padding(.vertical,3)
    }

    private func load(force:Bool=false) async {
        guard !layoutOnly else{return}
        guard force || projection==nil else {return}
        do {
            if useProtectedVault {
                guard let records=try await vault.readHistory() else {
                    hasError=true;return
                }
                projection=records
                return
            }
            guard let file=Bundle.main.url(forResource:"n2-synthetic-clinical",
                       withExtension:"json",subdirectory:"N1sDemoResources") else {
                hasError=true;return
            }
            projection=try N2NativeSnapshotReader.read(Data(contentsOf:file))
        } catch {
            hasError=true
        }
    }
}

/// One-tap access to the saved clinical record; correction is separately
/// confirmed before presenting the authenticated, append-only editor.
private struct N2RecordedVisitDetailView:View {
    let visitID:String
    let visit:N2VisitIndexRow
    let realSource:Bool
    @Environment(\.n2WorkspaceVault) private var vault
    @State private var detail:N2CorrectionDetail?
    @State private var loading=false
    @State private var failed=false
    @State private var askEdit=false
    @State private var editing=false

    var body:some View {
        ScrollView {
            VStack(alignment:.leading,spacing:14) {
                DanperPanel("Atención registrada") {
                    LabeledContent("Trabajador",value:visit.workerName)
                    LabeledContent("DNI",value:visit.workerDNI)
                    LabeledContent("Fecha",value:DanperDatePresentation.displayDateTime(visit.date,visit.time))
                    LabeledContent("Diagnóstico",value:detail?.diagnosis ?? visit.diagnosis)
                    if let d=detail {
                        LabeledContent("Tipo",value:d.category)
                        LabeledContent("Sistema afectado",value:d.system)
                        LabeledContent("Segmento",value:d.segment)
                        LabeledContent("Responsable",value:d.responsible)
                        LabeledContent("Situación al finalizar",value:d.workStatus)
                        LabeledContent("Procedimientos",value:d.procedures.joined(separator:", "))
                    }
                }
                if let d=detail {
                    DanperPanel("Tratamiento y cantidades") {
                        if d.medications.isEmpty {
                            Text("Atención sin medicamentos ni insumos.")
                                .foregroundStyle(.secondary)
                        }
                        ForEach(d.medications,id:\.id) { med in
                            VStack(alignment:.leading,spacing:4) {
                                Text(med.name).font(.subheadline.weight(.semibold))
                                Text("Cantidad clínica: \(med.quantity) · "+med.procedure)
                                    .font(.caption).foregroundStyle(.secondary)
                                if med.quantity != med.originalQuantity {
                                    Label("Original: \(med.originalQuantity). El movimiento físico no se alteró.",
                                          systemImage:"info.circle")
                                        .font(.caption2).foregroundStyle(.orange)
                                }
                            }
                            .frame(maxWidth:.infinity,alignment:.leading)
                            Divider()
                        }
                    }
                }
                if realSource {
                    DanperPanel {
                        NavigationLink {
                            N2VisitDispensingView(visitID:visitID)
                        } label: {
                            Label("Ver consumos y movimientos",systemImage:"pills.fill")
                        }
                        .buttonStyle(DanperSecondaryButton())
                        Button {
                            askEdit=true
                        } label: {
                            Label("Editar atención",systemImage:"square.and.pencil")
                        }
                        .buttonStyle(DanperPrimaryButton())
                        .accessibilityIdentifier("history-request-edit-"+visitID)
                        Text("Antes de modificar se pedirá confirmación. Las rectificaciones conservan la atención y sus movimientos originales.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                if loading {ProgressView("Abriendo atención…")}
                if failed {
                    Label("No se pudieron leer todos los detalles. La atención original está intacta.",
                          systemImage:"exclamationmark.triangle")
                        .foregroundStyle(.orange)
                }
            }.padding(16)
        }
        .navigationTitle("Detalle de atención")
        .navigationBarTitleDisplayMode(.inline)
        .danperFormChrome()
        .task {await load()}
        .confirmationDialog("¿Deseas editar esta atención?",
            isPresented:$askEdit,titleVisibility:.visible) {
            Button("Sí, editar atención"){editing=true}
            Button("No, solo consultar",role:.cancel){}
        } message: {
            Text("Se guardará una rectificación auditada; los movimientos de inventario no se reescribirán automáticamente.")
        }
        .navigationDestination(isPresented:$editing) {
            N2ClinicalCorrectionView(visitID:visitID)
        }
        .onChange(of:editing) { _,isEditing in
            if !isEditing {Task {await load()}}
        }
    }
    @MainActor private func load() async {
        guard realSource else{return}
        loading=true
        defer {loading=false}
        do {
            detail=try await vault.readCorrectionDetail(visitID:visitID)
            failed=false
        } catch {failed=true}
    }
}

private struct N2WorkerHistoryDetail:View {
    let dni:String
    let model:N2NativeReadModel
    let realSource:Bool
    var body:some View {
        ScrollView {
          VStack(alignment:.leading,spacing:16) {
            if let worker=model.roster.first(where:{$0.dni==dni}) {
                DanperPanel("Trabajador") {
                    LabeledContent("Nombre",value:worker.name)
                    LabeledContent("DNI",value:worker.dni)
                    LabeledContent("Área",value:worker.area)
                    LabeledContent("Ubicación",value:worker.site)
                    if realSource {
                        NavigationLink {
                            N2NativeWorkerEditorView(editingDNI:dni)
                        } label: {
                            Label("Editar ficha del trabajador",systemImage:"square.and.pencil")
                        }
                        .buttonStyle(DanperSecondaryButton())
                    }
                }
            }
            DanperPanel("Atenciones y borradores") {
                ForEach(model.workerHistory(dni)) { visit in
                    VStack(alignment:.leading,spacing:6) {
                        HStack {
                            Text(DanperDatePresentation.displayDateTime(visit.date,visit.time))
                                .font(.headline)
                            Spacer()
                            if let frequency=visit.frequency {
                                Text(frequency).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        Text(visit.diagnosis.isEmpty ? "Borrador incompleto" : visit.diagnosis)
                        if realSource && visit.status=="saved" {
                            NavigationLink {N2VisitDispensingView(visitID:visit.id)} label: {
                                Label("Medicamentos y consumos",systemImage:"pills.fill")
                            }
                            NavigationLink {
                                N2ClinicalCorrectionView(visitID:visit.id)
                            } label: {
                                Label("Rectificar con historial auditado",
                                      systemImage:"square.and.pencil")
                            }
                        }
                        if visit.status=="saved" {
                            Text("Ítems clínicos: \(visit.clinicalLines)")
                            Text("Confirmados: \(visit.confirmedPhysicalLines) · Pendientes: \(visit.pendingPhysicalLines)")
                            if !visit.consumptionR.isEmpty {
                                Text("Columna R: "+visit.consumptionR.map{
                                    $0.map{String(format:"%g",$0)} ?? "PENDIENTE"
                                }.joined(separator:" · "))
                            }
                        }else{Text("Sin salida física; borrador")}
                    }
                    .font(.footnote)
                    .padding(.vertical,4)
                }
            }
          }.padding(16)
        }
        .navigationTitle("Historia clínica")
        .danperFormChrome()
    }
}


/// One contextual resolution route per pending line. This view does not
/// change any clinical record by itself; inventory writes stay in the vault.
private enum N2HistoryConsumptionAction:Identifiable {
    case registerStock
    case verifyMapping(String)
    case verifyPhysical(String)
    case explainHistorical(String)

    var id:String {
        switch self {
        case .registerStock:return "stock"
        case .verifyMapping(let id):return "mapping-"+id
        case .verifyPhysical(let id):return "physical-"+id
        case .explainHistorical(let reason):return "historical-"+reason
        }
    }
}

struct N2VisitDispensingView:View {
    @Environment(\.n2WorkspaceVault) private var vault
    @Environment(\.dismiss) private var dismiss
    let visitID:String
    @State private var lines=[N2DispensingLine]()
    @State private var projectedClinicalLines=Set<String>()
    @State private var context:N2FormContext?
    @State private var detail:N2CorrectionDetail?
    @State private var selectedAction:N2HistoryConsumptionAction?
    @State private var failed=false
    @State private var busy=false
    @State private var notice=""

    private var pendingCount:Int {
        lines.filter{$0.result != "Descontado" &&
            !projectedClinicalLines.contains(visitID+"\u{001F}"+$0.id)
        }.count
    }
    private var reconstructedCount:Int {
        lines.filter{$0.result != "Descontado" &&
            projectedClinicalLines.contains(visitID+"\u{001F}"+$0.id)
        }.count
    }

    var body:some View {
        ScrollView {
            VStack(alignment:.leading,spacing:14) {
                if failed {
                    Label("No se pudieron consultar todos los datos. La atención original no se modificó.",
                          systemImage:"exclamationmark.triangle")
                        .font(.footnote).foregroundStyle(.orange)
                }
                if pendingCount>0 || reconstructedCount>0 {
                    DanperPanel {
                        if pendingCount>0 {
                            Label("\(pendingCount) consumo(s) sin salida física confirmada",
                                  systemImage:"exclamationmark.circle")
                                .font(.subheadline.weight(.semibold))
                            Text("La atención está guardada. No se descontará stock antiguo solo por registrar un lote hoy.")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        if reconstructedCount>0 {
                            Label("\(reconstructedCount) consumo(s) ya incluidos en el corte",
                                  systemImage:"checkmark.circle.fill")
                                .foregroundStyle(.green)
                            Text("Contabilizados una sola vez en la reconstrucción 9–8. Esto no equivale a verificar una salida física anterior.")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
                ForEach(lines) {line in
                    let projectedInCut=projectedClinicalLines.contains(
                        visitID+"\u{001F}"+line.id)
                    let storedResolution=N2PendingResolution.forReason(line.result)
                    // Saved reasons can predate a newly confirmed batch link.
                    // The catalog is authoritative for the current UI action.
                    let alreadyLinked=context?.products.authorizedNursingOptions(
                        for:line.code).isEmpty == false ||
                        context?.operationalMappings.contains(where:{
                            $0.clinicalCode==line.code
                        }) == true
                    let resolvedStock=context?.options(
                        for:line.code,at:detail?.date ?? "").isEmpty == false
                    let resolution:N2PendingResolution =
                        storedResolution == .verifyCorrespondence && alreadyLinked
                        ? (resolvedStock ? .verifyPhysicalUse : .registerStock)
                        : storedResolution
                    VStack(alignment:.leading,spacing:9) {
                        Text(line.name).font(.subheadline.weight(.semibold))
                        Text("Cantidad clínica: "+line.quantity.formatted())
                            .font(.caption).foregroundStyle(.secondary)
                        Label(projectedInCut && line.result != "Descontado"
                              ? "Contabilizado en el corte 9–8 · sin salida física verificada"
                              : (resolution == .reviewChronology
                                  ? N2PendingResolution.historicalTitle(forReason:line.result)
                                  : resolution.summary),
                              systemImage:resolution == .completed || projectedInCut
                              ? "checkmark.circle.fill" : "exclamationmark.circle")
                            .font(.caption)
                            .foregroundStyle(resolution == .completed || projectedInCut
                                             ? Color.green : Color.orange)
                        if projectedInCut && line.result != "Descontado" {
                            Label("Registro clínico incorporado una sola vez al cálculo del período. No se está creando un movimiento ni descontando stock actual.",
                                  systemImage:"calendar.badge.checkmark")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        if let quantity=line.kardexQuantity {
                            Text("Kardex R: \(quantity.formatted())" + (quantity == 0 ? " · Uso de envase abierto, sin nueva apertura" : ""))
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        if line.result != "Descontado" {
                            switch resolution {
                            case .registerStock:
                                Text(alreadyLinked && storedResolution == .verifyCorrespondence
                                     ? "Producto ya vinculado al Kardex. Esta atención anterior sigue pendiente: registra únicamente stock físico real y revisa la fecha antes de conciliar."
                                     : "No hay lote compatible con existencias utilizables. Si tienes stock físico, regístralo primero.")
                                    .font(.caption).foregroundStyle(.secondary)
                                if context != nil {
                                    Button {
                                        selectedAction = .registerStock
                                    } label: {
                                        Label("Registrar existencias",systemImage:"shippingbox.fill")
                                    }
                                    .buttonStyle(.bordered)
                                    .accessibilityIdentifier("history-pending-stock-"+line.id)
                                }
                            case .verifyCorrespondence:
                                Text("Este código clínico no tiene correspondencia aprobada ni revisada.")
                                    .font(.caption).foregroundStyle(.secondary)
                                if context != nil {
                                    Button {
                                        selectedAction = .verifyMapping(line.code)
                                    } label: {
                                        Label("Vincular producto",systemImage:"link")
                                    }
                                    .buttonStyle(.bordered)
                                    .accessibilityIdentifier("history-pending-mapping-"+line.id)
                                }
                            case .verifyPhysicalUse, .reviewPending:
                                Text("La atención ya está guardada. Si utilizaste un envase abierto, debe estar registrado como abierto en un lote válido; un lote con existencias cerradas no demuestra una apertura anterior.")
                                    .font(.caption).foregroundStyle(.secondary)
                                if context != nil {
                                    Button {
                                        selectedAction = .registerStock
                                    } label: {
                                        Label("Ir al Kardex · comprobar envase",
                                              systemImage:"shippingbox.fill")
                                    }
                                    .buttonStyle(.bordered)
                                    .accessibilityIdentifier("history-pending-container-stock-"+line.id)
                                }
                            case .reviewChronology:
                                Text(projectedInCut
                                     ? "Este consumo ya participa del saldo reconstruido. No vuelvas a descontarlo al registrar stock actual."
                                     : "La atención es anterior al lote o a la verificación del vínculo. No hay evidencia para descontarla retroactivamente.")
                                    .font(.caption).foregroundStyle(.secondary)
                                if context != nil {
                                    Button {
                                        selectedAction = .registerStock
                                    } label: {
                                        Label("Ir a Kardex · registrar stock físico actual",
                                              systemImage:"shippingbox.fill")
                                    }
                                    .buttonStyle(.bordered)
                                    .accessibilityIdentifier("history-register-actual-stock-"+line.id)
                                }
                                Button {
                                    selectedAction = .explainHistorical(line.result)
                                } label: {
                                    Label("Ver detalle del historial",systemImage:"info.circle")
                                }
                                .buttonStyle(.bordered)
                                .accessibilityIdentifier("history-pending-chronology-"+line.id)
                                if let context,let detail,
                                   detail.medications.contains(where:{$0.id==line.id}) &&
                                   context.historicalOptions(for:line.code,at:detail.date).contains(where:{
                                       N2ContainerAccounting.isContainer(unit:$0.unit)
                                   }) {
                                    Text("Para un frasco o caja de una atención pasada, puedes declarar si realmente abriste uno nuevo (R=1) o reutilizaste uno abierto (R=0). Esta declaración se incluye solo en el corte reconstruido.")
                                        .font(.caption).foregroundStyle(.secondary)
                                    Button {
                                        selectedAction = .verifyPhysical(line.id)
                                    } label: {
                                        Label("Declarar apertura histórica (1/0)",
                                              systemImage:"checkmark.shield")
                                    }
                                    .buttonStyle(.bordered)
                                    .accessibilityIdentifier("history-declare-opening-"+line.id)
                                }
                            case .completed:
                                EmptyView()
                            }
                        }
                    }
                    .frame(maxWidth:.infinity,alignment:.leading)
                    .padding(14)
                    .background(DanperStyle.surface,in:RoundedRectangle(cornerRadius:16))
                }
                if lines.isEmpty && !failed {
                    Text("Esta atención no tiene medicamentos ni insumos registrados.")
                        .foregroundStyle(.secondary)
                }
                if pendingCount>0 && context != nil {
                    Button {
                        Task {await retryPending()}
                    } label: {
                        Label(busy ? "Comprobando…" : "Volver a comprobar pendientes",
                              systemImage:"arrow.clockwise")
                    }
                    .buttonStyle(DanperSecondaryButton())
                    .disabled(busy)
                    Text("La comprobación respeta el historial y no crea otra atención.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                if !notice.isEmpty {
                    Text(notice).font(.footnote).foregroundStyle(.secondary)
                }
            }.padding(16)
        }
        .navigationTitle("Consumos")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement:.topBarLeading) {
                Button {dismiss()} label: {
                    Label("Volver",systemImage:"chevron.left")
                }
                .accessibilityIdentifier("history-consumption-back")
            }
        }
        .danperFormChrome()
        .refreshable {await load()}
        .task {await load()}
        .sheet(item:$selectedAction,onDismiss:{
            Task {await load()}
        }) {action in
            switch action {
            case .registerStock:
                NavigationStack {
                    N2NativeInventoryView(initialOperation:"lot")
                        .toolbar {
                            ToolbarItem(placement:.topBarTrailing) {
                                Button("Cerrar") {selectedAction=nil}
                            }
                        }
                }
            case .verifyMapping(let code):
                if let context {
                    N2OperationalMappingView(code:code,context:context,onSaved:{
                        selectedAction=nil
                        Task {await load()}
                    })
                } else {
                    ContentUnavailableView("Inventario no disponible",
                                           systemImage:"lock.shield")
                }
            case .explainHistorical(let reason):
                NavigationStack {
                    ScrollView {
                        VStack(alignment:.leading,spacing:16) {
                            Label(N2PendingResolution.historicalTitle(forReason:reason),
                                  systemImage:"clock.arrow.circlepath")
                                .font(.headline)
                            Text(N2PendingResolution.historicalGuidance(forReason:reason))
                                .font(.body)
                            Text("La atención ya está guardada. Agregar existencias ahora no demuestra el saldo anterior. Conserva este pendiente hasta disponer de una conciliación documentada; no es necesario crear otra atención.")
                                .font(.footnote).foregroundStyle(.secondary)
                        }
                        .frame(maxWidth:.infinity,alignment:.leading)
                        .padding(20)
                    }
                    .navigationTitle("Revisión histórica")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement:.topBarTrailing) {
                            Button("Cerrar") {selectedAction=nil}
                        }
                    }
                }
            case .verifyPhysical(let itemID):
                if let context, let detail,
                   let med=detail.medications.first(where:{$0.id==itemID}) {
                    N2PendingDispensingView(
                        visitID:visitID,
                        medication:N2FormMedication(id:med.id,code:med.code,
                                                    quantity:med.quantity,
                                                    procedure:med.procedure),
                        date:detail.date,context:context,
                        historicalAccountingOnly:
                            N2PendingResolution.forReason(lines.first(where:{
                                $0.id==itemID
                            })?.result ?? "") == .reviewChronology,
                        onSaved:{
                            selectedAction=nil
                            Task {await load()}
                        })
                } else {
                    ContentUnavailableView("Detalle no disponible",
                                           systemImage:"lock.shield")
                }
            }
        }
    }

    @MainActor
    private func load() async {
        do {
            lines=try await vault.dispensingLines(visitID:visitID)
            failed=false
        } catch {
            failed=true
            notice="No se pudieron consultar los consumos de la atención."
            return
        }
        do {
            context=try await vault.clinicalFormContext()
        } catch {
            context=nil
            notice="Las acciones están temporalmente no disponibles. La atención permanece guardada."
            return
        }
        // Do not turn a period projection into an actual FEFO movement.
        // It only explains which saved clinical lines are already counted.
        do {
            let dateFormatter=DateFormatter()
            dateFormatter.locale=Locale(identifier:"en_US_POSIX")
            dateFormatter.timeZone=TimeZone(identifier:"America/Lima")
            dateFormatter.dateFormat="yyyy-MM-dd"
            let today=dateFormatter.string(from:Date())
            let cut=try await vault.automaticCutAccounting(through:today)
            // Only label a historical line as balanced when a real counted
            // lot yields an opening value. Without it, the line stays pending.
            projectedClinicalLines=Set(lines.compactMap {line -> String? in
                let key=visitID+"\u{001F}"+line.id
                guard cut.projectedClinicalLines.contains(key) else{return nil}
                var codes=Set(context?.products.authorizedNursingOptions(
                    for:line.code).map(\.id) ?? [])
                codes.formUnion(context?.operationalMappings.filter{
                    $0.clinicalCode==line.code
                }.map(\.inventoryID) ?? [])
                return cut.rows.contains(where:{
                    codes.contains($0.code) && $0.opening != nil
                }) ? key : nil
            })
        } catch {
            projectedClinicalLines=[]
        }
        do {
            detail=try await vault.readCorrectionDetail(visitID:visitID)
        } catch {
            detail=nil
            // Correspondence and stock actions still work without the
            // correction detail. Physical reconciliation needs exact item IDs.
        }
    }

    @MainActor
    private func retryPending() async {
        guard !busy else{return}
        busy=true
        defer {busy=false}
        do {
            let current=try await vault.clinicalFormContext()
            _=try await vault.retryDispensing(visitID:visitID,
                                            expectedRevision:current.revision)
            notice="Se verificaron nuevamente los pendientes sin duplicar la atención."
        } catch {
            notice="No se pudo conciliar con los datos actuales. No se modificó la atención original."
        }
        await load()
    }
}
