import Foundation
import SwiftUI
import UIKit
import DanperCore

private struct N2VigilanceShare:Identifiable {
    let id=UUID()
    let file:URL
}
private struct N2VigilanceActivity:UIViewControllerRepresentable {
    let file:URL
    func makeUIViewController(context:Context)->UIActivityViewController {
        let controller=UIActivityViewController(activityItems:[file],applicationActivities:nil)
        controller.overrideUserInterfaceStyle=DanperStyle.sharingAppearance
        return controller
    }
    func updateUIViewController(_ vc:UIActivityViewController,context:Context){}
}

/// Read-only Excel export: ONLY saved OSTEOMUSCULAR visits and ONLY the
/// visible 17-column "VIGILACIA OCUPACIONAL" worksheet. It never edits care.
struct N2OccupationalVigilanceExportView:View {
    @Environment(\.n2WorkspaceVault) private var vault
    @State private var mode="cut"
    @State private var day=Date()
    @State private var customFrom=Date()
    @State private var customTo=Date()
    @State private var busy=false
    @State private var failed=false
    @State private var status="Selecciona el período a exportar."
    @State private var share:N2VigilanceShare?
    @State private var folder:URL?

    private func dayString(_ value:Date)->String {
        let formatter=DateFormatter()
        formatter.locale=Locale(identifier:"en_US_POSIX")
        formatter.timeZone=TimeZone(identifier:"America/Lima")
        formatter.dateFormat="yyyy-MM-dd"
        return formatter.string(from:value)
    }
    private var range:(start:String,end:String) {
        let date=dayString(day)
        switch mode {
        case "daily":return(date,date)
        case "custom":return(dayString(customFrom),dayString(customTo))
        default:
            let start=(try? N2KardexCutPreview.period(for:date).start) ?? date
            return(start,date)
        }
    }
    var body:some View {
        ScrollView {
            VStack(alignment:.leading,spacing:16) {
                VStack(alignment:.leading,spacing:5) {
                    Text("VIGILANCIA OCUPACIONAL")
                        .font(.caption2.weight(.bold)).tracking(1.1)
                        .foregroundStyle(DanperStyle.red)
                    Text("Generar Excel osteomuscular")
                        .font(.system(.title2,design:.rounded,weight:.bold))
                }
                N2Build222ExportProgress(titles:["Período","Filtrar","Compartir"])
                DanperPanel("Modelo de vigilancia · una hoja") {
                    Label("Solo atenciones con sistema afectado OSTEOMUSCULAR",
                          systemImage:"figure.walk.motion")
                        .font(.subheadline.weight(.semibold))
                    Text("Respeta las 17 columnas A–Q de la plantilla. No incorpora hojas auxiliares, registros antiguos ni atenciones de otros sistemas.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                DanperPanel {
                    N2Build222StageHeading(step:1,title:"Elegir fechas")
                    DanperChoiceField(title:"Período",selection:$mode,
                                      options:["daily","cut","custom"],
                                      labels:["daily":"Día seleccionado",
                                              "cut":"Desde el 9 hasta la fecha",
                                              "custom":"Rango personalizado"])
                    if mode=="custom" {
                        DanperDateField(title:"Desde",selection:$customFrom)
                        DanperDateField(title:"Hasta",selection:$customTo)
                    } else {
                        DanperDateField(title:"Fecha de referencia",selection:$day)
                    }
                    Text("Se exportarán las atenciones guardadas entre \(range.start) y \(range.end).")
                        .font(.caption).foregroundStyle(.secondary)
                }
                DanperPanel {
                    N2Build222StageHeading(step:2,title:"Campos y recomendaciones")
                    Label("Agente: DISERGONOMICO",systemImage:"checkmark.circle")
                    Text("Riesgo del modelo: Posturas inadecuadas")
                    Text("Medida recomendada: Capacitacion y ejecucion de pausas activas")
                    Text("Los códigos C/D se completan desde los catálogos oficiales @subuo/@uo según la sede y el área de cada atención. Si no hay correspondencia acreditada, se deja el código UO pendiente. Planilla conserva su valor registrado.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                DanperPanel {
                    N2Build222StageHeading(step:3,title:"Exportar Excel")
                    Button {
                        Task{await export()}
                    } label: {
                        Label(busy ? "Generando…" : "Generar Excel y compartir",
                              systemImage:"square.and.arrow.up")
                    }
                    .buttonStyle(DanperPrimaryButton())
                    .disabled(busy || range.start>range.end)
                    .accessibilityIdentifier("vigilance-export-xlsx")
                    Text(status)
                        .font(.caption).foregroundStyle(failed ? Color.red : Color.secondary)
                    Text("El archivo contiene datos de salud ocupacional. Compártelo solo con destinatarios autorizados.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }.padding(16)
        }
        .navigationTitle("Vigilancia ocupacional")
        .danperFormChrome()
        .sheet(item:$share,onDismiss:cleanup){ item in
            N2VigilanceActivity(file:item.file)
        }
        .onDisappear{if share == nil{cleanup()}}
    }

    @MainActor private func export() async {
        guard !busy,range.start<=range.end else{return}
        busy=true;failed=false
        status="Leyendo atenciones y generando la hoja de vigilancia…"
        defer{busy=false}
        do {
            let data=try await vault.exportOccupationalVigilance(
                start:range.start,end:range.end)
            cleanup()
            let dir=FileManager.default.temporaryDirectory.appendingPathComponent(
                (vault.isClinical ? "danper-n2-clinical-vigilance-" :
                                    "danper-n2-demo-vigilance-")+UUID().uuidString,
                isDirectory:true)
            try FileManager.default.createDirectory(at:dir,
                withIntermediateDirectories:true,
                attributes:[.protectionKey:FileProtectionType.complete])
            folder=dir
            let file=dir.appendingPathComponent(
                "DANPER_VIGILANCIA_OSTEOMUSCULAR_\(range.start)_\(range.end).xlsx")
            try data.xlsx.write(to:file,options:[.atomic,.completeFileProtection])
            status="Excel generado: \(data.rows) atenciones osteomusculares." +
                (data.skippedMissingIdentity>0
                 ? " \(data.skippedMissingIdentity) registros omitidos por DNI/nombre incompletos."
                 : "")
            if data.unresolvedOrganizationalUnits>0 {
                status+=" \(data.unresolvedOrganizationalUnits) atenciones tienen una unidad organizativa sin código acreditado; revisa el área."
            }
            share=N2VigilanceShare(file:file)
        }catch{
            cleanup()
            failed=true
            status="No se pudo generar el Excel. Revisa el rango y la bóveda de atenciones."
        }
    }
    @MainActor private func cleanup(){
        if let folder{try? FileManager.default.removeItem(at:folder)}
        folder=nil
    }
}
