import Foundation
import SwiftUI
import DanperCore

/// Build 222 Kardex home screen, rebuilt as native navigation.
/// Navigation never creates inventory movements or changes clinical data.
struct N2Build222KardexHub:View {
    @Environment(\.n2WorkspaceVault) private var vault
    @State private var lotCount:Int?
    private var activePeriod:N2KardexCutPreview.Period? {
        let formatter=DateFormatter()
        formatter.locale=Locale(identifier:"en_US_POSIX")
        formatter.timeZone=TimeZone(identifier:"America/Lima")
        formatter.dateFormat="yyyy-MM-dd"
        return try? N2KardexCutPreview.period(for:formatter.string(from:Date()))
    }
    private let options:[(number:String,title:String,detail:String,symbol:String)]=[
        ("1","Inventario físico","Consultar los 98 productos, existencias y lotes","shippingbox.fill"),
        ("2","Entradas y salidas","Ingresos físicos; salidas de atención en el historial","arrow.left.arrow.right"),
        ("3","Revisar pendientes anteriores","Examinar conciliaciones y movimientos sin confirmar","checkmark.shield"),
        ("4","Exportar Kardex","Generar el Excel de enfermería","doc.richtext")
    ]
    var body:some View {
        ScrollView {
            VStack(alignment:.leading,spacing:16) {
                VStack(alignment:.leading,spacing:5) {
                    Text("GESTIÓN DE EXISTENCIAS")
                        .font(.caption2.weight(.bold))
                        .tracking(1.2).foregroundStyle(DanperStyle.red)
                    Text("Kardex")
                        .font(.system(.largeTitle,design:.rounded,weight:.bold))
                    Text("Registra medicamentos, controla el stock y prepara el corte mensual.")
                        .font(.subheadline).foregroundStyle(.secondary)
                }.frame(maxWidth:.infinity,alignment:.leading)

                HStack(spacing:10) {
                    summary(value:"98",label:"Productos oficiales",symbol:"cross.vial")
                    summary(value:lotCount.map(String.init) ?? "—",label:"Lotes registrados",symbol:"shippingbox")
                }

                NavigationLink {
                    N2NativeInventoryView(initialOperation:"lot")
                } label: {
                    HStack(spacing:14) {
                        VStack(alignment:.leading,spacing:7) {
                            Text("REGISTRAR MEDICAMENTO")
                                .font(.caption2.weight(.bold)).tracking(1.1)
                            Text("Agregar medicamento y stock")
                                .font(.headline.weight(.bold))
                            Text("Selecciona el producto oficial, sede, lote, vencimiento y cantidades contadas.")
                                .font(.caption)
                                .fixedSize(horizontal:false,vertical:true)
                        }
                        Spacer(minLength:4)
                        Image(systemName:"plus.circle.fill").font(.title2)
                    }
                    .foregroundStyle(.white)
                    .padding(18)
                    .frame(maxWidth:.infinity,alignment:.leading)
                    .background(DanperStyle.gradient,
                                in:RoundedRectangle(cornerRadius:19))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("kardex-register-current-stock")

                DanperPanel("Corte mensual · del día 9 al día 8") {
                    if let activePeriod {
                        LabeledContent("Inicio",value:DanperDatePresentation.display(activePeriod.start))
                        LabeledContent("Fin",value:DanperDatePresentation.display(activePeriod.end))
                    }
                    Text("Si cuentas el stock ahora, reconstruir el saldo del día 9 exige sumar los consumos físicos verificados y descontar los ingresos posteriores. No se descontarán dos veces las atenciones.")
                        .font(.footnote).foregroundStyle(.secondary)
                    NavigationLink {
                        N2KardexCutPreviewView()
                    } label: {
                        Label("Previsualizar saldo inicial del día 9",
                              systemImage:"calendar.badge.clock")
                            .frame(maxWidth:.infinity,alignment:.leading)
                    }
                    .buttonStyle(DanperSecondaryButton())
                    .accessibilityIdentifier("kardex-ninth-cut-preview")
                    Text("Cálculo previo: no modifica la bóveda ni asigna lotes retrospectivamente.")
                        .font(.caption2).foregroundStyle(.secondary)
                }

                DanperPanel {
                    Text("Consultar y gestionar")
                        .font(.title3.weight(.bold))
                    Text("Usa Inventario físico para consultar lo registrado; Entradas y salidas para nuevos movimientos; Pendientes para conciliaciones; Exportar Kardex para el Excel oficial.")
                        .font(.footnote).foregroundStyle(.secondary)
                    VStack(spacing:10) {
                        route(0){N2NativeInventoryView()}
                        route(1){N2NativeInventoryView(initialOperation:"receipt")}
                        route(2){N2ReconciliationView()}
                        route(3){N2VerifiedNursingExportView()}
                    }
                }

                DanperPanel("Otros reportes") {
                    DanperToolLink(title:"Indicador ambulatorio · 10 hojas",
                                   symbol:"tablecells") {
                        N2VerifiedIndicatorExportView()
                    }
                    Text("El Indicador tiene su propio corte y conciliación. No sustituye el Excel diario del Kardex.")
                        .font(.caption).foregroundStyle(.secondary)
                }

                Label("Los lotes y vencimientos se usan solo dentro de DANPER para FEFO. El Excel oficial conserva sus columnas y cantidades, sin identificadores de lote. Los movimientos físicos se registran únicamente con confirmación.",
                      systemImage:"lock.shield")
                    .font(.caption).foregroundStyle(.secondary)
            }.padding(16)
        }
        .navigationTitle("Kardex")
        .navigationBarTitleDisplayMode(.inline)
        .danperFormChrome()
        .task {await readLotCount()}
    }

    @MainActor private func readLotCount() async {
        do {
            let context=try await vault.clinicalFormContext()
            lotCount=context.lots.count
        }catch {
            lotCount=nil
        }
    }

    private func summary(value:String,label:String,symbol:String)->some View {
        VStack(alignment:.leading,spacing:7) {
            Image(systemName:symbol)
                .foregroundStyle(DanperStyle.red)
            Text(value).font(.title2.weight(.bold))
            Text(label).font(.caption).foregroundStyle(.secondary)
                .fixedSize(horizontal:false,vertical:true)
        }
        .frame(maxWidth:.infinity,minHeight:105,alignment:.topLeading)
        .padding(13)
        .background(DanperStyle.surface,in:RoundedRectangle(cornerRadius:17))
    }

    private func route<Destination:View>(_ index:Int,
        @ViewBuilder destination:()->Destination)->some View {
        let item=options[index]
        return NavigationLink(destination:destination) {
            HStack(alignment:.center,spacing:13) {
                Text(item.number)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(width:34,height:34)
                    .background(DanperStyle.red,in:RoundedRectangle(cornerRadius:11))
                VStack(alignment:.leading,spacing:5) {
                    Text(item.title).font(.subheadline.weight(.bold))
                        .foregroundStyle(.primary)
                    Text(item.detail).font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal:false,vertical:true)
                }
                Spacer(minLength:4)
                Image(systemName:"chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
            }
            .padding(13)
            .frame(maxWidth:.infinity,minHeight:75,alignment:.leading)
            .background(DanperStyle.canvas,
                        in:RoundedRectangle(cornerRadius:15))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("kardex-route-"+item.number)
    }
}
