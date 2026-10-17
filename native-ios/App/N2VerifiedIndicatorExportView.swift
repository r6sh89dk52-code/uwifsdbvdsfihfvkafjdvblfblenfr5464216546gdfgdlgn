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
    @State private var site="LA VENTUROSA"
    @State private var startDate=Date()
    @State private var endDate=Date()
    @State private var visits=[N2VisitIndexRow]()
    @State private var selected=Set<String>()
    @State private var ready=false
    @State private var working=false
    @State private var failed=false
    @State private var status="Abriendo la bóveda clínica N2…"
    @State private var share:N2IndicatorShare?
    @State private var folder:URL?

    private func local(_ date:Date)->String {
        let f=DateFormatter()
        f.dateFormat="yyyy-MM-dd"
        f.timeZone=TimeZone(identifier:"America/Lima")
        return f.string(from:date)
    }
    private var inRange:[N2VisitIndexRow] {
        let a=local(startDate),b=local(endDate)
        return visits.filter {
            $0.status=="saved" && $0.date>=a && $0.date<=b
        }
    }
    private var enabled:Bool {
        ready && !working && local(startDate)<=local(endDate) &&
        !selected.isEmpty
    }
    var body:some View {
        Form {
            Section("Indicador Ambulatorio N2 · 10 hojas") {
                Label("Fuente cifrada original, sin datos de demostración",
                      systemImage:"lock.shield.fill")
                Text("Solo atenciones elegidas y consumos enlazados al Kardex. No se rellena stock inicial, ingreso o recuento sin evento revisado.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            Section("Seleccionar período y sede") {
                Picker("Subdivisión",selection:$site) {
                    Text("Fundo La Venturosa").tag("LA VENTUROSA")
                    Text("Planta La Venturosa").tag("PLVENTUROSA")
                }
                DatePicker("Desde",selection:$startDate,displayedComponents:.date)
                DatePicker("Hasta",selection:$endDate,displayedComponents:.date)
                Text("La selección inicial es esta semana (lunes a domingo). Para el corte mensual, elige día 9 a día 8.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            Section("Atenciones seleccionadas") {
                HStack {
                    Text("\(selected.count) elegidas de \(inRange.count)")
                    Spacer()
                    Button("Solo confirmadas") {selectConfirmed()}
                }
                if inRange.isEmpty {
                    Text("Sin atenciones en estas fechas.")
                        .foregroundStyle(.secondary)
                }
                ForEach(inRange) { v in
                    Toggle(isOn:Binding(
                        get:{selected.contains(v.id)},
                        set:{on in
                            if on {selected.insert(v.id)}
                            else {selected.remove(v.id)}
                        }
                    )){
                        VStack(alignment:.leading,spacing:3) {
                            Text(v.workerName).font(.subheadline)
                            Text(v.date+" "+v.time+" · "+v.diagnosis)
                                .font(.caption).foregroundStyle(.secondary)
                            if v.pendingPhysicalLines>0 {
                                Label("Consumo físico pendiente: exportación se bloqueará",
                                      systemImage:"exclamationmark.triangle")
                                    .font(.caption2).foregroundStyle(.orange)
                            }
                        }
                    }
                }
            }
            Section("Exportación y protección") {
                Button {
                    Task {await export()}
                } label:{
                    Label(working ? "Conciliando…" : "Generar Excel oficial y compartir",
                          systemImage:"square.and.arrow.up")
                }.disabled(!enabled)
                Text(status).font(.footnote)
                    .foregroundStyle(failed ? Color.red : Color.secondary)
                Text("Necesita cierres de inventario registrados en el período. Si faltan existencias, se dejan celdas vacías; revisa el resultado en Excel antes de enviarlo.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Indicador N2 · Excel")
        .sheet(item:$share,onDismiss:cleanup){share in
            N2IndicatorShareSheet(file:share.file)
        }
        .task {await load()}
        .onChange(of:startDate) {_,_ in selectConfirmed()}
        .onChange(of:endDate) {_,_ in selectConfirmed()}
        .onDisappear {if share == nil {cleanup()}}
    }
    @MainActor
    private func load() async {
        do {
            var cal=Calendar(identifier:.gregorian)
            cal.timeZone=TimeZone(identifier:"America/Lima")!
            cal.firstWeekday=2
            if let week=cal.dateInterval(of:.weekOfYear,for:Date()) {
                startDate=week.start
                endDate=cal.date(byAdding:.day,value:6,to:week.start) ?? week.start
            }
            guard let history=try await N2ProtectedClinicalIOSVault.shared
                    .readHistory() else {
                throw N2VerifiedIndicatorWorkbook.Failure.invalidSnapshot
            }
            visits=history.visits
            ready=true
            selectConfirmed()
            status="Fuente N2 verificada. Revisa las atenciones y el cierre contable antes de exportar."
        }catch{
            failed=true
            ready=false
            status="Bóveda N2 ausente o no verificable. No se genera ningún libro."
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
            let result=try await N2ProtectedClinicalIOSVault.shared
                .exportVerifiedIndicatorWorkbook(
                    start:local(startDate),end:local(endDate),
                    subdivision:site,ids:selected)
            cleanup()
            let dir=FileManager.default.temporaryDirectory
                .appendingPathComponent("danper-n2-indicator-"+UUID().uuidString,
                                        isDirectory:true)
            try FileManager.default.createDirectory(at:dir,
                withIntermediateDirectories:true,
                attributes:[.protectionKey:FileProtectionType.complete])
            folder=dir
            let url=dir.appendingPathComponent(
                "DANPER_INDICADOR_N2_"+local(startDate)+"_"+local(endDate)+".xlsx")
            try result.xlsx.write(to:url,options:[.atomic,.completeFileProtection])
            status="Generado: \(result.visits) atenciones / \(result.rows) filas. " +
                "Materiales sin stock inicial: \(result.missingOpening); " +
                "sin recuento final: \(result.missingClosingCount). " +
                "Las celdas no conciliadas siguen vacías."
            share=N2IndicatorShare(file:url)
        }catch{
            failed=true
            cleanup()
            status="Exportación rechazada: revisa sede, consumos físicos, fecha y eventos de cierre. No se modificó ningún registro."
        }
    }
    @MainActor
    private func cleanup() {
        if let folder{try? FileManager.default.removeItem(at:folder)}
        folder=nil
    }
}
