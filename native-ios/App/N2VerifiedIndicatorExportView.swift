import Foundation
import SwiftUI
import UIKit
import DanperCore

private struct N2IndicatorShare:Identifiable {
    let id=UUID()
    let file:URL
}
private struct N2IndicatorShareSheet:UIViewControllerRepresentable {
    let file:URL
    func makeUIViewController(context:Context)->UIActivityViewController {
        UIActivityViewController(activityItems:[file],applicationActivities:nil)
    }
    func updateUIViewController(_ controller:UIActivityViewController,context:Context){}
}

/// Entirely native N2 selection screen. The builder refuses pending stock,
/// missing review events, mixed sites, or invented official balances.
struct N2VerifiedIndicatorExportView:View {
    @Environment(\.n2WorkspaceVault) private var vault
    private var layoutOnly=false
    private var layoutSelectionOnly=false
    init() {}
    #if DEBUG
    init(layoutVisits:[N2VisitIndexRow],selectionOnly:Bool=false) {
        layoutSelectionOnly=selectionOnly
        layoutOnly=true
        _visits=State(initialValue:layoutVisits)
        _selected=State(initialValue:Set(layoutVisits.filter{$0.pendingPhysicalLines==0}.map(\.id)))
        let f=DateFormatter();f.dateFormat="yyyy-MM-dd";f.timeZone=TimeZone(identifier:"America/Lima")
        _startDate=State(initialValue:f.date(from:"2026-10-01")!)
        _endDate=State(initialValue:f.date(from:"2026-10-31")!)
    }
    #endif
    @State private var site="AMBAS"
    @State private var startDate=Date()
    @State private var endDate=Date()
    @State private var visits=[N2VisitIndexRow]()
    @State private var selected=Set<String>()
    @State private var ready=false
    @State private var working=false
    @State private var failed=false
    @State private var status="Selecciona período, sede y atenciones."
    @State private var provisional=false
    @State private var confirmProvisional=false
    @State private var share:N2IndicatorShare?
    @State private var folder:URL?

    private func local(_ date:Date)->String {
        let f=DateFormatter()
        f.dateFormat="yyyy-MM-dd"
        f.timeZone=TimeZone(identifier:"America/Lima")
        return f.string(from:date)
    }
    private func useOfficialCut() {
        var calendar=Calendar(identifier:.gregorian)
        calendar.timeZone=TimeZone(identifier:"America/Lima")!
        let today=Date()
        let parts=calendar.dateComponents([.year,.month,.day],from:today)
        guard let year=parts.year,let month=parts.month,let day=parts.day,
              let current=calendar.date(from:DateComponents(
                  year:year,month:month,day:9)) else{return}
        let start=day>=9 ? current :
            (calendar.date(byAdding:.month,value:-1,to:current) ?? current)
        guard let next=calendar.date(byAdding:.month,value:1,to:start),
              let end=calendar.date(byAdding:.day,value:-1,to:next) else{return}
        startDate=start
        endDate=end
    }
    private var inRange:[N2VisitIndexRow] {
        let a=local(startDate),b=local(endDate)
        return visits.filter {
            $0.status=="saved" && $0.date>=a && $0.date<=b &&
            (site=="AMBAS" || $0.workerSite.isEmpty || $0.workerSite==site)
        }
    }
    private var enabled:Bool {
        ready && !working && local(startDate)<=local(endDate) &&
        !selected.isEmpty
    }
    var body:some View {
        ScrollView {
          VStack(alignment:.leading,spacing:16) {
            if !layoutSelectionOnly {
            VStack(alignment:.leading,spacing:5) {
                Text("INDICADOR AMBULATORIO").font(.caption2.weight(.bold))
                    .tracking(1.1).foregroundStyle(DanperStyle.red)
                Text("Generar Indicador Ambulatorio")
                    .font(.system(.title2,design:.rounded,weight:.bold))
            }
            N2Build222ExportProgress(titles:["Configurar","Revisar","Compartir"])
            DanperPanel("Excel oficial · 10 hojas") {
                Label("Exportar libro de 10 hojas",systemImage:"doc.richtext")
                    .font(.subheadline.weight(.semibold))
                Text("Puedes exportar Ambas sedes en un libro único. Cada atención conserva su sede; ambos cierres físicos deben estar verificados.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            DanperPanel {
                N2Build222StageHeading(step:1,title:"Elegir período")
                Text("Corte oficial recomendado: del día 9 de un mes al día 8 del siguiente. Puedes ajustarlo para una consulta puntual; la conciliación por sede sigue siendo obligatoria.")
                    .font(.caption).foregroundStyle(.secondary)
                Button("Usar período oficial 9 → 8") {
                    useOfficialCut()
                }
                .buttonStyle(DanperSecondaryButton())
                .accessibilityIdentifier("indicator-official-cut")
                DanperChoiceField(title:"Ámbito del informe",selection:$site,
                                  options:["AMBAS","LA VENTUROSA","PLVENTUROSA"],
                                  labels:["AMBAS":"Ambas sedes (libro conjunto)",
                                          "LA VENTUROSA":"Fundo La Venturosa",
                                          "PLVENTUROSA":"Planta La Venturosa"])
                DanperDateField(title:"Desde",selection:$startDate)
                DanperDateField(title:"Hasta",selection:$endDate)
                Text("Corte mensual sugerido: día 9 al día 8 del siguiente mes. Puedes ajustar las fechas para una revisión puntual.")
                    .font(.footnote).foregroundStyle(.secondary)
                    .font(.footnote).foregroundStyle(.secondary)
            }
            }
            DanperPanel {
                N2Build222StageHeading(step:2,title:"Comprobar atenciones y existencias")
                Label("Las cantidades pendientes no se convierten en movimientos físicos ni en saldos cero.",
                      systemImage:"checkmark.shield")
                    .font(.caption).foregroundStyle(.secondary)
                HStack {
                    Text("\(selected.count) elegidas de \(inRange.count) en \(site == "AMBAS" ? "ambas sedes" : "esta sede")")
                    Spacer()
                    Button("Solo confirmadas") {selectConfirmed()}
                }
                if site=="AMBAS" &&
                   inRange.contains(where:{!["LA VENTUROSA","PLVENTUROSA"].contains($0.workerSite)}) {
                    Label("Hay atenciones sin sede verificada. No se incluirán en el libro oficial hasta corregir su ubicación.",
                          systemImage:"exclamationmark.triangle.fill")
                        .font(.footnote).foregroundStyle(.orange)
                }
                if inRange.isEmpty {
                    Text("Sin atenciones en estas fechas.")
                        .foregroundStyle(.secondary)
                }
                ForEach(inRange) { v in
                    DanperCheckRow(selected:Binding(
                        get:{selected.contains(v.id)},
                        set:{on in
                            if on {selected.insert(v.id)}
                            else {selected.remove(v.id)}
                        }
                    )){
                        VStack(alignment:.leading,spacing:3) {
                            Text(v.workerName).font(.subheadline)
                            Text(v.workerSite.isEmpty ? "Sede sin verificar" : v.workerSite)
                                .font(.caption2)
                                .foregroundStyle(v.workerSite.isEmpty ? Color.orange : Color.secondary)
                            Text(DanperDatePresentation.displayDateTime(v.date,v.time)+" · "+v.diagnosis)
                                .font(.caption).foregroundStyle(.secondary)
                            if v.pendingPhysicalLines>0 {
                                Label("Consumo físico pendiente: requiere libro provisional",
                                      systemImage:"exclamationmark.triangle")
                                    .font(.caption2).foregroundStyle(.orange)
                            }
                        }
                    }
                }
            }
            DanperPanel {
                N2Build222StageHeading(step:3,title:"Crear archivo y compartir")
                Text("El libro conserva las 10 hojas y las fórmulas verificadas. La exportación no modifica lotes, atenciones ni stock.")
                    .font(.caption).foregroundStyle(.secondary)
                DanperCheckRow(selected:$provisional) {
                    VStack(alignment:.leading,spacing:5) {
                        Text("Incluir consumos pendientes").font(.subheadline.weight(.semibold))
                        Text("Genera un libro provisional identificado").font(.caption).foregroundStyle(.secondary)
                    }
                }
                if provisional {
                    Text("BORRADOR: R incluye cantidades clínicas declaradas cuando falta salida física. Para cajas y frascos esto no acredita apertura. No modifica inventario ni acredita cierre.")
                        .font(.footnote).foregroundStyle(.orange)
                }
                Button {
                    if provisional {confirmProvisional=true}
                    else {Task {await export()}}
                } label:{
                    Label(working ? "Generando…" : provisional ? "Generar provisional y compartir" : "Generar Excel oficial y compartir",
                          systemImage:"square.and.arrow.up")
                }.buttonStyle(DanperPrimaryButton()).disabled(!enabled)
                Text(status).font(.footnote)
                    .foregroundStyle(failed ? Color.red : Color.secondary)
                Text(provisional
                     ? "Libro provisional: conserva consumos declarados y no acredita movimientos físicos pendientes."
                     : "Libro oficial: requiere revisión de cierre, stock inicial y recuento final del período.")
                    .font(.caption).foregroundStyle(.secondary)
            }
          }.padding(16)
        }
        .navigationTitle("Indicador ambulatorio")
        .danperFormChrome()
        .sheet(item:$share,onDismiss:cleanup){share in
            N2IndicatorShareSheet(file:share.file)
        }
        .alert("¿Generar un libro provisional?",isPresented:$confirmProvisional) {
            Button("Generar provisional") {Task {await export()}}
            Button("Cancelar",role:.cancel) {}
        } message: {Text("Las cantidades declaradas pendientes no son movimientos físicos de Kardex. El archivo quedará identificado como PROVISIONAL.")}
        .task {if !layoutOnly {await load()}}
        .onChange(of:startDate) {_,_ in selectConfirmed()}
        .onChange(of:endDate) {_,_ in selectConfirmed()}
        .onChange(of:site) {_,_ in selectConfirmed()}
        .onChange(of:provisional) {_,allowed in
            if allowed {selected=Set(inRange.map(\.id))}
            else {selectConfirmed()}
        }
        .onDisappear {if share == nil {cleanup()}}
    }
    @MainActor
    private func load() async {
        do {
            var cal=Calendar(identifier:.gregorian)
            cal.timeZone=TimeZone(identifier:"America/Lima")!
            cal.firstWeekday=2
            let now=Date()
            let parts=cal.dateComponents([.year,.month,.day],from:now)
            if let year=parts.year,let month=parts.month,let day=parts.day,
               let thisMonthNinth=cal.date(from:DateComponents(year:year,month:month,day:9)) {
                let start=day>=9 ? thisMonthNinth :
                    (cal.date(byAdding:.month,value:-1,to:thisMonthNinth) ?? thisMonthNinth)
                startDate=start
                if let next=cal.date(byAdding:.month,value:1,to:start) {
                    endDate=cal.date(byAdding:.day,value:-1,to:next) ?? start
                } else {endDate=start}
            }
            guard let history=try await vault
                    .readHistory() else {
                throw N2VerifiedIndicatorWorkbook.Failure.invalidSnapshot
            }
            visits=history.visits
            ready=true
            selectConfirmed()
            status="Selecciona las atenciones y genera el libro."
        }catch{
            failed=true
            ready=false
            status="No se pudo cargar el historial. No se modificaron datos."
        }
    }
    private func selectConfirmed() {
        selected=Set(inRange.filter{$0.pendingPhysicalLines==0}.map(\.id))
    }
    @MainActor
    private func export() async {
        guard enabled else{return}
        working=true
        failed=false
        status="Comprobando los 30 campos, entregas y cierre del período…"
        defer{working=false}
        do {
            let result=try await vault
                .exportVerifiedIndicatorWorkbook(
                    start:local(startDate),end:local(endDate),
                    subdivision:site,ids:selected,allowPending:provisional)
            cleanup()
            let dir=FileManager.default.temporaryDirectory
                .appendingPathComponent((vault.isClinical ? "danper-n2-clinical-indicator-" :
                                            "danper-n2-demo-indicator-")+UUID().uuidString,
                                        isDirectory:true)
            try FileManager.default.createDirectory(at:dir,
                withIntermediateDirectories:true,
                attributes:[.protectionKey:FileProtectionType.complete])
            folder=dir
            let exportPrefix=result.provisional ? "DANPER_PROVISIONAL_" : "DANPER_INDICADOR_"
            let siteSuffix=site=="AMBAS" ? "AMBAS_" : ""
            let outputName="\(exportPrefix)\(siteSuffix)\(local(startDate))_\(local(endDate)).xlsx"
            let url=dir.appendingPathComponent(outputName)
            try result.xlsx.write(to:url,options:[.atomic,.completeFileProtection])
            let warning=result.provisional
                ? "PROVISIONAL · \(result.pendingLines) consumos pendientes. "
                : ""
            status="\(warning)Generado: \(result.visits) atenciones / \(result.rows) filas. Materiales sin stock inicial: \(result.missingOpening); sin recuento final: \(result.missingClosingCount). Las celdas no conciliadas siguen vacías."
            share=N2IndicatorShare(file:url)
        }catch{
            failed=true
            cleanup()
            status=exportFailureMessage(error)
            #if DEBUG
            print("DANPER Indicador: "+String(reflecting:error))
            #endif
        }
    }
    private func exportFailureMessage(_ error:Error)->String {
        guard let failure=error as? N2VerifiedIndicatorWorkbook.Failure else {
            return "No se pudo generar el Excel. Revisa los datos del período. No se modificaron registros."
        }
        switch failure {
        case .unreviewedPeriod:
            return "Falta revisión de cierre del período. En el libro conjunto se requiere tanto Fundo como Planta. Revísalos por separado desde Conciliación."
        case .invalidReconciliation:
            return "Falta stock inicial o recuento final verificable, o hay un movimiento de conciliación inconsistente. Revisa Conciliación de inventario."
        case .unverifiedDelivery:
            return "Una atención seleccionada tiene un consumo sin entrega confirmada o una corrección pendiente. Desmárcala o usa un libro provisional cuando corresponda."
        case .invalidVisit:
            return "Una atención tiene sede no verificada o datos obligatorios incompletos. Confirma la ubicación en Personal antes de exportar ambas sedes."
        case .invalidPeriod:
            return "El período de fechas no es válido. Comprueba Desde y Hasta."
        case .missingSelection:
            return "No hay atenciones válidas para la sede y las fechas seleccionadas."
        case .ambiguousSite:
            return "Selecciona una sede válida antes de exportar."
        case .invalidCatalog:
            return "No se pudo validar el catálogo oficial. No se generó ningún Excel."
        case .invalidSnapshot:
            return "No se pudo verificar el historial antes de exportar."
        case .invalidWorkbook:
            return "No se pudo preparar el libro Excel de diez hojas. No se cambió ningún registro."
        }
    }
    @MainActor
    private func cleanup() {
        if let folder{try? FileManager.default.removeItem(at:folder)}
        folder=nil
    }
}

