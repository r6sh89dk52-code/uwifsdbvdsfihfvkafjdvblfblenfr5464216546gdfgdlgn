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
        let controller=UIActivityViewController(activityItems:[file],applicationActivities:nil)
        controller.overrideUserInterfaceStyle=DanperStyle.sharingAppearance
        return controller
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
    @State private var status="Selecciona período y atenciones de ambas sedes."
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
    private func metricValue(_ value:String,_ label:String)->some View {
        VStack(spacing:5) {
            Text(value)
                .font(.title3.weight(.bold)).monospacedDigit()
                .foregroundStyle(.primary)
            Text(label).font(.caption2).foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth:.infinity,minHeight:64)
        .padding(8)
        .background(DanperStyle.canvas,in:RoundedRectangle(cornerRadius:12))
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
                Text("Ambas sedes se incluyen en un libro único y cada atención conserva su origen. El inventario es compartido; el cierre del Excel aún conserva controles históricos que requieren validación.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            DanperPanel {
                N2Build222StageHeading(step:1,title:"Elegir período")
                Text("Corte recomendado del día 9 al día 8. La clasificación por sede corresponde a las atenciones, no a existencias separadas.")
                    .font(.caption).foregroundStyle(.secondary)
                Button("Usar período oficial 9 → 8") {
                    useOfficialCut()
                }
                .buttonStyle(DanperSecondaryButton())
                .accessibilityIdentifier("indicator-official-cut")
                LabeledContent("Ámbito",value:"Fundo y Planta La Venturosa")
                Text("Un solo Indicador y un solo inventario. La sede de cada atención se conserva en su fila del Excel, sin existencias ni cierres separados.")
                    .font(.caption).foregroundStyle(.secondary)
                DanperDateField(title:"Desde",selection:$startDate)
                DanperDateField(title:"Hasta",selection:$endDate)
                Text("Durante un corte abierto se exporta hasta hoy como PROVISIONAL. El libro OFICIAL se certifica únicamente tras finalizar el corte 9–8 con existencias comprobables.")
                    .font(.caption).foregroundStyle(.secondary)
                    .font(.footnote).foregroundStyle(.secondary)
                    .font(.footnote).foregroundStyle(.secondary)
            }
            }
            DanperPanel {
                N2Build222StageHeading(step:2,title:"Comprobar atenciones y existencias")
                Label("Una atención terminada confirma su consumo. Las líneas históricas sin lote conciliado no deben convertirse en saldos inventados.",
                      systemImage:"checkmark.shield")
                    .font(.caption).foregroundStyle(.secondary)
                DanperToolLink(title:"Revisar inventario único y corte 9–8",
                               symbol:"calendar.badge.checkmark") {
                    N2SimpleCutView()
                }
                Text("El cierre es único para Fundo y Planta. DANPER comprobará correspondencias de productos, saldos y consumos del período completo. Si faltan datos, conservará el reporte como provisional sin inventar cantidades.")
                    .font(.caption).foregroundStyle(.secondary)
                HStack(spacing:9) {
                    metricValue("\(selected.count)","Seleccionadas")
                    metricValue("\(inRange.count)","En el período")
                    metricValue("\(inRange.filter{$0.pendingPhysicalLines>0}.count)","Pendientes")
                }
                Text("RESU solo calcula un stock consolidado desde el conteo cuando están seleccionadas TODAS las atenciones del corte, el período ya ocurrió y el producto tiene una correspondencia única con su lote. Con una selección parcial, se dejan vacíos los saldos no justificables.")
                    .font(.caption).foregroundStyle(.secondary)
                Text("Las aperturas históricas R=1/0 declaradas se admiten en el libro PROVISIONAL; no se transforman en salidas físicas retroactivas.")
                    .font(.caption).foregroundStyle(.secondary)
                    .font(.caption).foregroundStyle(.secondary)

                HStack {
                    Text("\(selected.count) elegidas de \(inRange.count) en \(site == "AMBAS" ? "ambas sedes" : "esta sede")")
                    Spacer()
                    Button("Solo confirmadas") {selectConfirmed()}
                    Button("Todas") {selected=Set(inRange.map(\.id))}
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
                                Label("Consumo aún sin lote conciliado: libro provisional",
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
                        Text("Modo provisional").font(.subheadline.weight(.semibold))
                        Text("Libro de prueba del inventario único sin cierre definitivo").font(.caption).foregroundStyle(.secondary)
                    }
                }
                if provisional {
                    Text("BORRADOR: se incluyen también las atenciones pendientes. Una caja o frasco sin apertura acreditada aparece con R VACÍA y una justificación; nunca como R=0 o R=1 inventado. Los materiales individuales pendientes conservan la cantidad clínica declarada. No modifica inventario.")
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
                     ? "Libro provisional: conserva consumos registrados sin inventar lotes ni cierres."
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
        } message: {Text("El libro PROVISIONAL conserva todas las atenciones seleccionadas. Las cajas y frascos sin apertura declarada aparecen con R vacía y con una justificación. Las cantidades individuales pendientes son declaraciones clínicas, no movimientos FEFO. No se modifica el inventario.")}
        .task {if !layoutOnly {await load()}}
        .onChange(of:startDate) {_,_ in selectConfirmed()}
        .onChange(of:endDate) {_,_ in selectConfirmed()}
        .onChange(of:site) {_,_ in selectConfirmed()}
        .onChange(of:provisional) {_,allowed in
            // Never auto-add historical pending items on switching modes.
            if !allowed {selectConfirmed()}
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
                    let cycleEnd=cal.date(byAdding:.day,value:-1,to:next) ?? start
                    // The current month is a to-date draft, not a fictitious
                    // closing count for the following eighth.
                    endDate=min(cycleEnd,now)
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
        if !provisional && local(endDate)>local(Date()) {
            failed=true
            status="El corte todavía no ha terminado. Genera un libro provisional a la fecha; el cierre oficial requiere un conteo posterior al día 8."
            return
        }
        if !provisional && !local(endDate).hasSuffix("-08") {
            failed=true
            status="El Indicador oficial consolida el corte 9–8. Para una revisión parcial del mes utiliza Modo provisional."
            return
        }
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
                ? "PROVISIONAL · \(result.pendingLines) líneas pendientes, con R vacía cuando no hay apertura acreditada. "
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
            return "No se acreditó el cierre ÚNICO del período: deben estar todas las atenciones seleccionadas, el corte 9–8 terminado y los saldos físicos conciliados. No se deben crear cierres por sede."
        case .invalidReconciliation:
            return "No cuadran las existencias del inventario único, el consumo declarado o las correspondencias del catálogo. No se ha inventado stock inicial ni un recuento final."
        case .unverifiedDelivery:
            return "Hay una entrega física contradictoria o una corrección clínica pendiente que debe verificarse antes de exportar. Un consumo simplemente sin lote sí se admite en el PROVISIONAL con R vacía si es caja o frasco; no se inventa FEFO ni movimiento físico."
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

