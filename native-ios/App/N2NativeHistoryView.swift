import SwiftUI
import DanperCore

/// Read-only reusable native roster + history viewer.
/// The preview route always uses a bundled synthetic JSON sample. A future
/// real vault must authenticate before handing a snapshot to this view.
struct N2NativeHistoryView: View {
    var useProtectedVault = false
    @State private var projection:N2NativeReadModel?
    @State private var query=""
    @State private var selectedDNI:String?
    @State private var hasError=false
    private let accent=Color(red:0.88,green:0.09,blue:0.16)

    var body:some View {
        Group {
            if let projection {
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
                        ForEach(projection.findWorkers(query)) { w in
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
                .navigationDestination(item:$selectedDNI) { dni in
                    N2WorkerHistoryDetail(dni:dni,model:projection,realSource:useProtectedVault)
                }
            } else {
                ContentUnavailableView(
                    hasError ? (useProtectedVault ? "Historial no disponible" :
                                "No se pudo verificar la muestra") :
                               "Abriendo historial nativo",
                    systemImage:"lock.doc",
                    description:Text(useProtectedVault ?
                        "Activa el modo de prueba desde Inicio para consultar el historial." :
                        "Verificación de registros ficticios."))
            }
        }
        .navigationTitle("Personal e historial")
        .danperFormChrome()
        .task {await load()}
        .tint(accent)
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

    private func load() async {
        guard projection==nil else {return}
        do {
            if useProtectedVault {
                guard let records=try await N2SyntheticTrialIOSVault.shared.readHistory() else {
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


struct N2VisitDispensingView:View {
    let visitID:String
    @State private var lines=[N2DispensingLine]()
    @State private var failed=false
    var body:some View {
        ScrollView {
          VStack(alignment:.leading,spacing:16) {
            if failed {Text("No se pudo verificar el consumo. Inténtalo de nuevo.")}
            ForEach(lines) { line in
                VStack(alignment:.leading,spacing:7) {
                    Text(line.name).font(.headline)
                    Text(line.code+" · Cantidad clínica: "+line.quantity.formatted()).font(.caption)
                    Label(line.result,systemImage:line.result=="Descontado" ? "checkmark.circle.fill" : "exclamationmark.circle")
                        .font(.footnote).foregroundStyle(line.result=="Descontado" ? Color.green : Color.orange)
                }.padding(14).frame(maxWidth:.infinity,alignment:.leading).background(DanperStyle.surface,in:RoundedRectangle(cornerRadius:16))
            }
            if lines.isEmpty && !failed {Text("Atención sin medicamentos o insumos.").foregroundStyle(.secondary)}
          }.padding(16)
        }
        .navigationTitle("Consumos de la atención").danperFormChrome()
        .task {
            do {lines=try await N2SyntheticTrialIOSVault.shared.dispensingLines(visitID:visitID)}
            catch {failed=true}
        }
    }
}
