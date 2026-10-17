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
                List {
                    Section {
                        Label(useProtectedVault ? "BÓVEDA CLÍNICA N2 · SOLO LECTURA" : "SOLO PRUEBA · TRABAJADORES FICTICIOS",
                              systemImage:"lock.shield.fill")
                            .foregroundStyle(.orange)
                        Text(useProtectedVault ? "Datos locales desde la bóveda cifrada N2. No se modifica la build 222." : "Se muestran registros sintéticos. No se leen ni guardan datos clínicos de tu iPhone.")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                    Section("Directorio · \(projection.searchableRoster.count) disponibles") {
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
                    Section("Historial completo") {
                        Text("\(projection.visits.filter{$0.status=="saved"}.count) atenciones guardadas · \(projection.visits.filter{$0.status=="draft"}.count) borradores")
                            .font(.subheadline)
                        Text("\(projection.pendingClinicalLines) consumo(s) sin confirmación física; nunca se sustituyen por cero.")
                            .font(.footnote).foregroundStyle(.secondary)
                        ForEach(projection.visits) { visit in
                            visitCell(visit)
                        }
                    }
                }
                .searchable(text:$query,prompt:"Buscar DNI, nombres o área")
                .navigationDestination(item:$selectedDNI) { dni in
                    N2WorkerHistoryDetail(dni:dni,model:projection,realSource:useProtectedVault)
                }
            } else {
                ContentUnavailableView(
                    hasError ? (useProtectedVault ? "Bóveda clínica no disponible" :
                                "No se pudo verificar la muestra") :
                               "Abriendo historial nativo",
                    systemImage:"lock.doc",
                    description:Text(useProtectedVault ?
                        "Activa una sola fuente clínica N2 cifrada antes de consultar su historial." :
                        "Verificación de registros ficticios."))
            }
        }
        .navigationTitle("Historial nativo N2")
        .task {await load()}
        .tint(accent)
    }

    @ViewBuilder
    private func visitCell(_ visit:N2VisitIndexRow) -> some View {
        VStack(alignment:.leading,spacing:5) {
            HStack {
                Text(visit.workerName).font(.subheadline.weight(.semibold))
                Spacer()
                Text(visit.date+" "+visit.time).font(.caption2).foregroundStyle(.secondary)
            }
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
        List {
            if let worker=model.roster.first(where:{$0.dni==dni}) {
                Section(realSource ? "Trabajador" : "Trabajador ficticio") {
                    LabeledContent("Nombre",value:worker.name)
                    LabeledContent("DNI",value:worker.dni)
                    LabeledContent("Área",value:worker.area)
                    LabeledContent("Ubicación",value:worker.site)
                }
            }
            Section("Atenciones y borradores") {
                ForEach(model.workerHistory(dni)) { visit in
                    VStack(alignment:.leading,spacing:6) {
                        HStack {
                            Text(visit.date+" "+visit.time)
                                .font(.headline)
                            Spacer()
                            if let frequency=visit.frequency {
                                Text(frequency).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        Text(visit.diagnosis.isEmpty ? "Borrador incompleto" : visit.diagnosis)
                        if realSource && visit.status=="saved" {
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
        }
        .navigationTitle(realSource ? "Historia clínica N2" : "Historia · prueba")
    }
}
