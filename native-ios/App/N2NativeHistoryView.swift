import SwiftUI
import DanperCore

/// Read-only reusable native roster + history viewer.
/// The preview route always uses a bundled synthetic JSON sample. A future
/// real vault must authenticate before handing a snapshot to this view.
struct N2NativeHistoryView: View {
    init(useProtectedVault:Bool=false){self.useProtectedVault=useProtectedVault}
    #if DEBUG
    init(layoutProjection:N2NativeReadModel) {
        layoutOnly=true
        _projection=State(initialValue:layoutProjection)
    }
    #endif
    private var layoutOnly=false
    @Environment(\.n2WorkspaceVault) private var vault
    var useProtectedVault = false
    @State private var projection:N2NativeReadModel?
    @State private var query=""
    @State private var selectedDNI:String?
    @State private var rosterPage=0
    private let pageSize=25
    @State private var hasError=false
    private let accent=Color(red:0.88,green:0.09,blue:0.16)

    var body:some View {
        Group {
            if let projection {
                let matches=projection.findWorkers(query)
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
                    DanperPanel("Historial completo") {
                        Text("\(projection.visits.filter{$0.status=="saved"}.count) atenciones guardadas · \(projection.visits.filter{$0.status=="draft"}.count) borradores")
                            .font(.subheadline)
                        Text("\(projection.pendingClinicalLines) consumo(s) sin confirmación física; nunca se sustituyen por cero.")
                            .font(.footnote).foregroundStyle(.secondary)
                        ForEach(projection.visits) { visit in
                            visitCell(visit)
                                .padding(14).frame(maxWidth:.infinity,alignment:.leading)
                                .background(DanperStyle.canvas,in:RoundedRectangle(cornerRadius:14))
                        }
                    }
                  }.padding(16)
                }
                .searchable(text:$query,prompt:"Buscar DNI, nombres o área")
                .onChange(of:query) {_,_ in
                    rosterPage=0
                    withAnimation(.easeOut(duration:0.18)){
                        proxy.scrollTo("roster-page-top",anchor:.top)
                    }
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
        .navigationTitle("Personal e historial")
        .danperFormChrome()
        .task {await load()}
        .onAppear {
            if projection != nil {Task {await load(force:true)}}
        }
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
    @State private var context:N2FormContext?
    @State private var detail:N2CorrectionDetail?
    @State private var selectedAction:N2HistoryConsumptionAction?
    @State private var failed=false
    @State private var busy=false
    @State private var notice=""

    private var pendingCount:Int {lines.filter{$0.result != "Descontado"}.count}

    var body:some View {
        ScrollView {
            VStack(alignment:.leading,spacing:14) {
                if failed {
                    Label("No se pudieron consultar todos los datos. La atención original no se modificó.",
                          systemImage:"exclamationmark.triangle")
                        .font(.footnote).foregroundStyle(.orange)
                }
                if pendingCount>0 {
                    DanperPanel {
                        Label("\(pendingCount) consumo(s) por revisar",
                              systemImage:"exclamationmark.circle")
                            .font(.subheadline.weight(.semibold))
                        Text("La atención clínica ya está guardada. Los pendientes no tienen salida física confirmada. Registra solo las existencias y aperturas reales.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                ForEach(lines) {line in
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
                        Label(resolution == .reviewChronology
                              ? N2PendingResolution.historicalTitle(forReason:line.result)
                              : resolution.summary,systemImage:resolution == .completed
                              ? "checkmark.circle.fill" : "exclamationmark.circle")
                            .font(.caption)
                            .foregroundStyle(resolution == .completed ? Color.green : Color.orange)
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
                                if context != nil && detail?.medications.contains(where:{$0.id==line.id}) == true {
                                    Button {
                                        selectedAction = .verifyPhysical(line.id)
                                    } label: {
                                        Label(resolution == .verifyPhysicalUse ?
                                              (alreadyLinked && storedResolution == .verifyCorrespondence
                                                  ? "Revisar consumo anterior" : "Revisar lote o apertura")
                                              : "Revisar datos del consumo",
                                              systemImage:"checkmark.shield")
                                    }
                                    .buttonStyle(.bordered)
                                    .accessibilityIdentifier("history-pending-physical-"+line.id)
                                }
                            case .reviewChronology:
                                Text(N2PendingResolution.historicalGuidance(forReason:line.result))
                                    .font(.caption).foregroundStyle(.secondary)
                                Button {
                                    selectedAction = .explainHistorical(line.result)
                                } label: {
                                    Label("Entender este pendiente",systemImage:"info.circle")
                                }
                                .buttonStyle(.bordered)
                                .accessibilityIdentifier("history-pending-chronology-"+line.id)
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
