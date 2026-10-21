import Foundation
import SwiftUI
import UIKit
import DanperCore

private struct N2NursingShare:Identifiable {
    let id=UUID()
    let file:URL
}
private struct N2NursingActivity:UIViewControllerRepresentable {
    let file:URL
    func makeUIViewController(context:Context)->UIActivityViewController {
        UIActivityViewController(activityItems:[file],applicationActivities:nil)
    }
    func updateUIViewController(_ controller:UIActivityViewController,context:Context){}
}

/// Uses the encrypted N2 source, not the bundled synthetic test report.
struct N2VerifiedNursingExportView:View {
    @Environment(\.n2WorkspaceVault) private var vault
    @State private var day=Date()
    @State private var reportMode="daily"
    @State private var rangeStart=Date()
    @State private var rangeEnd=Date()
    @State private var site=""
    @State private var responsible="Felipe Azcárate Silva"
    @State private var shift="CONSOLIDADO"
    @State private var busy=false
    @State private var failed=false
    @State private var status="Indica fecha y responsable."
    @State private var share:N2NursingShare?
    @State private var folder:URL?

    private var selectedDay:String {
        let formatter=DateFormatter()
        formatter.timeZone=TimeZone(identifier:"America/Lima")
        formatter.dateFormat="yyyy-MM-dd"
        return formatter.string(from:day)
    }

    private var selectedPeriod:(start:String,end:String) {
        if reportMode=="daily" {return (selectedDay,selectedDay)}
        if reportMode=="custom" {
            return (formatDay(rangeStart),formatDay(rangeEnd))
        }
        var cal=Calendar(identifier:.gregorian)
        cal.timeZone=TimeZone(identifier:"America/Lima")!
        cal.firstWeekday=2
        let monday=cal.dateInterval(of:.weekOfYear,for:day)?.start ?? day
        let sunday=cal.date(byAdding:.day,value:6,to:monday) ?? monday
        return (formatDay(monday),formatDay(sunday))
    }
    private func formatDay(_ date:Date)->String {
        let formatter=DateFormatter()
        formatter.timeZone=TimeZone(identifier:"America/Lima")
        formatter.dateFormat="yyyy-MM-dd"
        return formatter.string(from:date)
    }
    var body:some View {
        ScrollView {
          VStack(alignment:.leading,spacing:16) {
            VStack(alignment:.leading,spacing:5) {
                Text("REPORTES DE ENFERMERÍA")
                    .font(.caption2.weight(.bold)).tracking(1.1)
                    .foregroundStyle(DanperStyle.red)
                Text("Kardex · Excel oficial")
                    .font(.system(.title2,design:.rounded,weight:.bold))
            }
            N2Build222ExportProgress(titles:["Período","Vista previa","Compartir"])
            DanperPanel("Formato oficial de 98 productos") {
                Label("98 productos de enfermería",systemImage:"lock.shield")
                Text("Los saldos no acreditados se dejan en blanco. No se generan ceros ni se modifican existencias.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            DanperPanel {
                N2Build222StageHeading(step:1,title:"Elegir fechas y modalidad")
                Text("Reporte diario, semanal o por rango. Los saldos se calculan por períodos sin duplicar aperturas.")
                    .font(.caption).foregroundStyle(.secondary)
                DanperChoiceField(title:"Modalidad",selection:$reportMode,
                    options:["daily","weekly","custom"],
                    labels:["daily":"Diario","weekly":"Semanal","custom":"Rango personalizado"])
                DanperChoiceField(title:"Sede del inventario",selection:$site,options:["LA VENTUROSA","PLVENTUROSA"],
                                  labels:["LA VENTUROSA":"Fundo La Venturosa","PLVENTUROSA":"Planta La Venturosa"])
                if reportMode=="daily" {
                    DanperDateField(title:"Fecha de corte",selection:$day)
                    DanperChoiceField(title:"Turno",selection:$shift,
                                      options:["MAÑANA","TARDE","NOCHE","CONSOLIDADO"])
                } else if reportMode=="weekly" {
                    DanperDateField(title:"Semana de referencia",selection:$day)
                    Text("Consolidado semanal: "+selectedPeriod.start+" al "+selectedPeriod.end)
                        .font(.footnote).foregroundStyle(.secondary)
                } else {
                    DanperDateField(title:"Desde",selection:$rangeStart)
                    DanperDateField(title:"Hasta",selection:$rangeEnd)
                }
                DanperField(title:"Responsable") {
                    TextField("Nombre del responsable",text:$responsible).textInputAutocapitalization(.characters)
                }
                Text(reportMode=="daily" ?
                    "Kardex diario de 98 productos." :
                    "Consolidado verificado de 98 productos; el Excel indicará claramente el intervalo y no se presentará como un solo día.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            DanperPanel {
                N2Build222StageHeading(step:2,title:"Revisar el Kardex y recuentos")
                Label("98 productos del catálogo oficial de Enfermería",
                      systemImage:"checkmark.shield")
                    .font(.subheadline.weight(.semibold))
                Text("Comprueba los lotes y recuentos físicos desde Inventario y Conciliación antes de exportar. Los saldos sin acreditar permanecen sin informar.")
                    .font(.caption).foregroundStyle(.secondary)
                NavigationLink {
                    N2NativeInventoryView()
                } label: {
                    Label("Revisar inventario y lotes",systemImage:"shippingbox")
                }
                .buttonStyle(DanperSecondaryButton())
            }
            DanperPanel {
                N2Build222StageHeading(step:3,title:"Exportar Excel oficial")
                Button {
                    Task {await export()}
                } label: {
                    Label(busy ? "Verificando…" : "Exportar Excel y compartir",
                          systemImage:"square.and.arrow.up")
                }
                .buttonStyle(DanperPrimaryButton())
                .disabled(busy || site.isEmpty ||
                    selectedPeriod.start>selectedPeriod.end ||
                    responsible.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty)
                Text(status).font(.footnote)
                    .foregroundStyle(failed ? Color.red : Color.secondary)
                Text("Un Excel compartido puede contener datos del tópico. Envía el archivo solamente a destinatarios autorizados.")
                    .font(.caption).foregroundStyle(.secondary)
            }
          }.padding(16)
        }
        .navigationTitle("Kardex diario")
        .danperFormChrome()
        .sheet(item:$share,onDismiss:cleanup) { item in
            N2NursingActivity(file:item.file)
        }
        .onDisappear {if share == nil {cleanup()}}
    }

    @MainActor
    private func export() async {
        guard !busy else{return}
        busy=true
        failed=false
        status="Comprobando movimientos cifrados y plantilla oficial…"
        defer{busy=false}
        do {
            let result:N2VerifiedNursingWorkbook.Result
            let operatorName=responsible.trimmingCharacters(in:.whitespacesAndNewlines)
            if reportMode=="daily" {
                result=try await vault
                    .exportVerifiedDailyNursingWorkbook(
                        date:selectedDay,shift:shift,
                        responsible:operatorName,site:site)
            } else {
                result=try await vault
                    .exportVerifiedRangeNursingWorkbook(
                        start:selectedPeriod.start,end:selectedPeriod.end,
                        responsible:operatorName,site:site)
            }
            cleanup()
            let dir=FileManager.default.temporaryDirectory
                .appendingPathComponent((vault.isClinical ? "danper-n2-clinical-kardex-" :
                                             "danper-n2-demo-kardex-")+UUID().uuidString,
                                        isDirectory:true)
            try FileManager.default.createDirectory(at:dir,
                withIntermediateDirectories:true,
                attributes:[.protectionKey:FileProtectionType.complete])
            folder=dir
            let suffix=reportMode=="daily" ? "" : "_al_" + selectedPeriod.end
            let name="DANPER_KARDEX_N2_" + selectedPeriod.start + suffix + ".xlsx"
            let output=dir.appendingPathComponent(name)
            try result.xlsx.write(to:output,
                options:[.atomic,.completeFileProtection])
            status="Generado: \(result.stockKnownRows) productos con historial; \(result.stockUnknownRows) sin existencias acreditadas (en blanco)."
            share=N2NursingShare(file:output)
        }catch {
            cleanup()
            failed=true
            status="Bloqueado: falta fuente, fecha válida o existe inventario sin conciliar. El stock no cambió."
        }
    }
    @MainActor
    private func cleanup() {
        if let folder {try? FileManager.default.removeItem(at:folder)}
        folder=nil
    }
}

