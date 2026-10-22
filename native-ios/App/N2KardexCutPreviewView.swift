import Foundation
import SwiftUI
import DanperCore

/// Preview for stock measured *today* and reconciled against the active
/// ninth-day cut. Deliberately read-only: audited history is not auto-assigned
/// to lots or consumed twice.
struct N2KardexCutPreviewView:View {
    @State private var countingDate=Date()
    @State private var materialName=""
    @State private var measured=""
    @State private var approvedUsed=""
    @State private var laterReceipts=""
    @State private var signedAdjustments="0"
    @State private var hasPending=true
    @State private var result:N2KardexCutPreview.Result?
    @State private var message=""
    private func localDay(_ d:Date)->String {
        let formatter=DateFormatter()
        formatter.locale=Locale(identifier:"en_US_POSIX")
        formatter.timeZone=TimeZone(identifier:"America/Lima")
        formatter.dateFormat="yyyy-MM-dd"
        return formatter.string(from:d)
    }
    private var activeCut:N2KardexCutPreview.Period? {
        try? N2KardexCutPreview.period(for:localDay(countingDate))
    }
    private func number(_ value:String)->Double? {
        Double(value.trimmingCharacters(in:.whitespacesAndNewlines)
                     .replacingOccurrences(of:",",with:"."))
    }
    var body:some View {
        DanperScrollView {
            VStack(alignment:.leading,spacing:16) {
                VStack(alignment:.leading,spacing:5) {
                    Text("CONTEO Y CORTE MENSUAL")
                        .font(.caption2.weight(.bold)).tracking(1.2)
                        .foregroundStyle(DanperStyle.red)
                    Text("Reconstruir stock al día 9")
                        .font(.title2.weight(.bold))
                    Text("El corte comprende del día 9 al día 8 del mes siguiente.")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
                DanperPanel("Corte correspondiente") {
                    if let activeCut {
                        LabeledContent("Desde",value:DanperDatePresentation.display(activeCut.start))
                        LabeledContent("Hasta",value:DanperDatePresentation.display(activeCut.end))
                    }
                    Text("El conteo de hoy NO se debe registrar como si se hubiese contado el día 9. Primero hay que reconstruir el saldo de apertura y verificar los movimientos posteriores.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                DanperPanel("Previsualización · no modifica existencias") {
                    DanperField(title:"Producto de referencia") {
                        TextField("Nombre o código del medicamento",text:$materialName)
                    }
                    DanperDateField(title:"Fecha del conteo real",selection:$countingDate)
                    DanperField(title:"Cantidad contada hoy") {
                        TextField("Ej. 5",text:$measured).keyboardType(.decimalPad)
                    }
                    DanperField(title:"Consumos físicos verificados desde el corte") {
                        TextField("Solo cantidades verificadas",text:$approvedUsed)
                            .keyboardType(.decimalPad)
                    }
                    DanperField(title:"Ingresos posteriores al corte") {
                        TextField("Cantidad ingresada después del día 9",text:$laterReceipts)
                            .keyboardType(.decimalPad)
                    }
                    DanperField(title:"Ajustes netos posteriores (+ / −)") {
                        TextField("0 cuando no existan",text:$signedAdjustments)
                            .keyboardType(.numbersAndPunctuation)
                    }
                    DanperCheckRow(selected:$hasPending) {
                        Text("Hay consumos históricos sin conciliar")
                            .font(.subheadline)
                    }
                    Text("Los consumos antiguos sin movimiento físico comprobado NO deben contabilizarse automáticamente, ni asignarse a un lote o descontarse otra vez.")
                        .font(.footnote).foregroundStyle(.secondary)
                    Button {
                        calculate()
                    } label: {
                        Label("Calcular saldo inicial estimado",systemImage:"function")
                            .frame(maxWidth:.infinity)
                    }
                    .buttonStyle(DanperPrimaryButton())
                    .accessibilityIdentifier("kardex-cut-preview-calculate")
                }
                if let result {
                    DanperPanel("Resultado preliminar") {
                        if !materialName.isEmpty {
                            Text(materialName).font(.subheadline.weight(.semibold))
                        }
                        LabeledContent("Corte",value:DanperDatePresentation.display(result.period.start))
                        LabeledContent("Existencia inicial estimada",
                                       value:result.estimatedOpening.formatted())
                        Text("Stock al corte = contado hoy + consumos verificados − ingresos posteriores − ajustes netos.")
                            .font(.footnote).foregroundStyle(.secondary)
                        Label(hasPending
                              ? "No conciliado: quedan consumos anteriores por verificar."
                              : "Cálculo matemático. Debe contrastarse con el Kardex y los registros físicos.",
                              systemImage:"exclamationmark.shield")
                            .font(.footnote).foregroundStyle(.orange)
                        Text("Esta pantalla no genera lotes, no aplica movimientos retrospectivos y no modifica el Excel. El registro definitivo requerirá revisión del historial y confirmación explícita.")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                }
                if !message.isEmpty {
                    Label(message,systemImage:"exclamationmark.circle")
                        .font(.footnote).foregroundStyle(.orange)
                }
            }.padding(16)
        }
        .onChange(of:countingDate){_,_ in result=nil}
        .onChange(of:measured){_,_ in result=nil}
        .onChange(of:approvedUsed){_,_ in result=nil}
        .onChange(of:laterReceipts){_,_ in result=nil}
        .onChange(of:signedAdjustments){_,_ in result=nil}
        .onChange(of:hasPending){_,_ in result=nil}
        .navigationTitle("Corte del día 9")
        .navigationBarTitleDisplayMode(.inline)
        .danperFormChrome()
    }
    private func calculate() {
        guard let measured=number(measured),
              let verified=number(approvedUsed),
              let receipts=number(laterReceipts),
              let adjustments=number(signedAdjustments) else {
            result=nil
            message="Completa las cantidades con números válidos; no se inventarán saldos."
            return
        }
        do {
            result=try N2KardexCutPreview.calculate(
                asOf:localDay(countingDate),measured:measured,
                verifiedUsed:verified,laterReceipts:receipts,
                signedAdjustments:adjustments,pendingHistory:hasPending)
            message=""
        }catch{
            result=nil
            message="No se pudo estimar: revisa las cifras y los ingresos posteriores al corte."
        }
    }
}
