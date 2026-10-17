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
    @State private var day=Date()
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

    var body:some View {
        Form {
            Section("Kardex de enfermería") {
                Label("98 productos de enfermería",systemImage:"lock.shield")
                Text("Los saldos no acreditados se dejan en blanco. No se generan ceros ni se modifican existencias.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            Section("Datos del corte diario") {
                Picker("Sede del inventario",selection:$site) {
                    Text("Seleccionar").tag("")
                    Text("Fundo La Venturosa").tag("LA VENTUROSA")
                    Text("Planta La Venturosa").tag("PLVENTUROSA")
                }
                LabeledContent("Fecha de corte",value:DanperDatePresentation.display(selectedDay))
                DatePicker("Cambiar fecha",selection:$day,displayedComponents:.date)
                Picker("Turno",selection:$shift) {
                    ForEach(["MAÑANA","TARDE","NOCHE","CONSOLIDADO"],id:\.self) {
                        Text($0).tag($0)
                    }
                }
                TextField("Responsable",text:$responsible)
                    .textInputAutocapitalization(.characters)
                Text("Un día por libro. Los intervalos aún no son un documento oficial.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section("Generar") {
                Button {
                    Task {await export()}
                } label: {
                    Label(busy ? "Verificando…" : "Exportar Excel y compartir",
                          systemImage:"square.and.arrow.up")
                }
                .buttonStyle(DanperPrimaryButton())
                .disabled(busy || site.isEmpty || responsible.trimmingCharacters(
                    in:.whitespacesAndNewlines).isEmpty)
                Text(status).font(.footnote)
                    .foregroundStyle(failed ? Color.red : Color.secondary)
                Text("Un Excel compartido puede contener datos del tópico. Envía el archivo solamente a destinatarios autorizados.")
                    .font(.caption).foregroundStyle(.secondary)
            }
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
            let result=try await N2SyntheticTrialIOSVault.shared
                .exportVerifiedDailyNursingWorkbook(
                    date:selectedDay,shift:shift,
                    responsible:responsible.trimmingCharacters(
                        in:.whitespacesAndNewlines),site:site)
            cleanup()
            let dir=FileManager.default.temporaryDirectory
                .appendingPathComponent("danper-n2-kardex-"+UUID().uuidString,
                                        isDirectory:true)
            try FileManager.default.createDirectory(at:dir,
                withIntermediateDirectories:true,
                attributes:[.protectionKey:FileProtectionType.complete])
            folder=dir
            let output=dir.appendingPathComponent(
                "DANPER_KARDEX_N2_"+result.day+".xlsx")
            try result.xlsx.write(to:output,
                options:[.atomic,.completeFileProtection])
            status="Generado: \(result.stockKnownRows) productos con historial; " +
                "\(result.stockUnknownRows) sin existencias acreditadas (en blanco)."
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

