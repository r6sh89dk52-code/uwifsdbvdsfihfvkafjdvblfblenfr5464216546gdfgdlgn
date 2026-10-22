import Foundation
import SwiftUI
import DanperCore

/// Read-only reconstruction of the ninth-day stock from the SAME encrypted
/// nursing/indicator source. No second inventory or per-visit confirmation.
struct N2KardexCutPreviewView:View {
    @Environment(\.n2WorkspaceVault) private var vault
    @State private var accounting:N2AutomaticCutAccounting.Result?
    @State private var selectedCode=""
    @State private var status="Leyendo atenciones e inventario cifrados…"
    @State private var failed=false

    private var selected:N2AutomaticCutAccounting.Row? {
        accounting?.rows.first{$0.code==selectedCode}
    }
    private var calendar:Calendar {
        var cal=Calendar(identifier:.gregorian)
        cal.timeZone=TimeZone(identifier:"America/Lima")!
        return cal
    }
    private func format(_ date:Date)->String {
        let formatter=DateFormatter()
        formatter.locale=Locale(identifier:"en_US_POSIX")
        formatter.timeZone=calendar.timeZone
        formatter.dateFormat="yyyy-MM-dd"
        return formatter.string(from:date)
    }
    private var dailyDates:[String] {
        guard let accounting else{return []}
        let formatter=DateFormatter()
        formatter.locale=Locale(identifier:"en_US_POSIX")
        formatter.timeZone=calendar.timeZone
        formatter.dateFormat="yyyy-MM-dd"
        guard let first=formatter.date(from:accounting.start),
              let last=formatter.date(from:accounting.end) else{return []}
        var dates=[String]()
        var date=first
        while date<=last && dates.count<32 {
            dates.append(formatter.string(from:date))
            guard let next=calendar.date(byAdding:.day,value:1,to:date) else{break}
            date=next
        }
        return dates
    }
    private var titles:[String:String] {
        Dictionary(uniqueKeysWithValues:(accounting?.rows ?? []).map {
            ($0.code,$0.name+" · "+$0.code)
        })
    }
    var body:some View {
        DanperScrollView {
            VStack(alignment:.leading,spacing:16) {
                VStack(alignment:.leading,spacing:5) {
                    Text("KARDEX · UN SOLO INVENTARIO")
                        .font(.caption2.weight(.bold)).tracking(1.2)
                        .foregroundStyle(DanperStyle.red)
                    Text("Stock desde el día 9")
                        .font(.title2.weight(.bold))
                    Text("Los consumos de las atenciones terminadas se cuentan automáticamente, aunque sean de fechas anteriores.")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
                if let accounting {
                    DanperPanel("Corte mensual vigente") {
                        LabeledContent("Desde",value:DanperDatePresentation.display(accounting.start))
                        LabeledContent("Hasta hoy",value:DanperDatePresentation.display(accounting.end))
                        Text("Se utiliza el conteo actualmente registrado para estimar el saldo del día 9. No se crea un segundo Kardex ni se vuelven a descontar atenciones ya registradas.")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                    if !accounting.rows.isEmpty {
                        DanperPanel("Elegir medicamento o insumo") {
                            DanperChoiceField(title:"Producto",selection:$selectedCode,
                                options:accounting.rows.map(\.code),labels:titles)
                            Text("Los lotes siguen siendo internos para FEFO; los informes agrupan por código de medicamento.")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    if let selected {
                        summary(selected)
                        dailyMovements(selected)
                    }else {
                        DanperPanel("Inventario sin movimientos") {
                            Text("No hay existencias ni consumos de productos reconocidos para este corte.")
                                .foregroundStyle(.secondary)
                        }
                    }
                    if accounting.hasUnresolvedHistory {
                        Label("Existen productos o aperturas de frascos/cajas sin equivalencia acreditada. Las atenciones siguen confirmadas, pero no se inventarán cantidades de envases ni lotes históricos.",
                              systemImage:"exclamationmark.triangle")
                            .font(.footnote).foregroundStyle(.orange)
                    }
                }else {
                    DanperPanel("Preparando el cálculo") {
                        if !failed {ProgressView(status)}
                        else {Text(status).foregroundStyle(.orange)}
                    }
                }
                Button("Actualizar desde el inventario y las atenciones") {
                    Task {await reload()}
                }
                .buttonStyle(DanperSecondaryButton())
            }.padding(16)
        }
        .task {await reload()}
        .navigationTitle("Corte del día 9")
        .navigationBarTitleDisplayMode(.inline)
        .danperFormChrome()
    }

    private func summary(_ row:N2AutomaticCutAccounting.Row)->some View {
        DanperPanel("Conciliación calculada") {
            Text(row.name).font(.headline)
            LabeledContent("Existencias registradas hoy",
                           value:row.currentCount?.formatted() ?? "Sin conteo")
            LabeledContent("Consumos del período",value:row.reportedUse.formatted())
            LabeledContent("Ingresos posteriores al corte",value:row.received.formatted())
            LabeledContent("Ajustes netos",value:row.adjusted.formatted())
            Divider()
            LabeledContent("Stock estimado al día 9",
                           value:row.opening?.formatted() ?? "Pendiente de conteo/conciliación")
            if row.unlinkedItems>0 {
                Label("\(row.unlinkedItems) consumos clínicos confirmados aún sin movimiento FEFO asignado. Ya están incluidos una sola vez en el cálculo para unidades; no vuelvas a registrarlos.",
                      systemImage:"checkmark.shield")
                    .font(.caption).foregroundStyle(.secondary)
            }
            if row.unknownContainerOpenings>0 {
                Label("No se puede suponer si se abrió un frasco/caja nuevo. Se conserva el consumo clínico pero el stock de envases requiere su movimiento de apertura.",
                      systemImage:"exclamationmark.triangle")
                    .font(.caption).foregroundStyle(.orange)
            }
            Text("Resultado de lectura, sin escritura: ningún lote o atención se modifica al consultar esta pantalla.")
                .font(.caption2).foregroundStyle(.secondary)
        }
    }

    private func dailyMovements(_ row:N2AutomaticCutAccounting.Row)->some View {
        DanperPanel("Consumos día por día") {
            Text("Cero significa que no existe un consumo computable para ese producto en ese día.")
                .font(.caption).foregroundStyle(.secondary)
            ForEach(dailyDates,id:\.self){date in
                HStack(spacing:10) {
                    Text(DanperDatePresentation.display(date))
                        .font(.subheadline).foregroundStyle(.primary)
                    Spacer()
                    Text((row.usesByDay[date] ?? 0).formatted())
                        .font(.subheadline.weight(.semibold)).monospacedDigit()
                }.frame(minHeight:34)
                Divider().opacity(0.4)
            }
        }
    }
    @MainActor private func reload() async {
        failed=false
        status="Leyendo atenciones e inventario cifrados…"
        do {
            let result=try await vault.automaticCutAccounting(through:format(Date()))
            accounting=result
            if !result.rows.contains(where:{$0.code==selectedCode}) {
                selectedCode=result.rows.first?.code ?? ""
            }
            status=""
        }catch {
            accounting=nil
            failed=true
            status="No se pudo calcular desde la fuente activa. Comprueba que la restauración del respaldo y el catálogo estén completos."
        }
    }
}
