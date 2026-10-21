import SwiftUI

/// Build 222 Kardex entry point. The four existing native modules remain
/// independent, with verified storage and inventory protections unchanged.
/// This screen contains navigation only; it never writes stock movements.
struct N2Build222KardexHub:View {
    var body:some View {
        ScrollView {
            VStack(alignment:.leading,spacing:16) {
                DanperPanel {
                    Label("KARDEX DE ENFERMERÍA",systemImage:"shippingbox.fill")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(DanperStyle.red)
                    Text("Inventario, movimientos y reportes")
                        .font(.title2.weight(.bold))
                    Text("Consulta los lotes, registra operaciones verificadas y genera los informes desde la bóveda cifrada actual.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                DanperPanel("Gestión de existencias") {
                    DanperToolLink(title:"Inventario y lotes",
                                   symbol:"shippingbox") {
                        N2NativeInventoryView()
                    }
                    DanperToolLink(title:"Movimientos y conciliación",
                                   symbol:"arrow.left.arrow.right") {
                        N2ReconciliationView()
                    }
                }
                DanperPanel("Informes") {
                    DanperToolLink(title:"Kardex de enfermería · 98 productos",
                                   symbol:"tablecells") {
                        N2VerifiedNursingExportView()
                    }
                    DanperToolLink(title:"Indicador ambulatorio · 10 hojas",
                                   symbol:"doc.richtext") {
                        N2VerifiedIndicatorExportView()
                    }
                }
                Text("Las operaciones se registran por sede y lote. No se crea una salida física ni se modifica el stock al abrir esta pantalla.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding(16)
        }
        .navigationTitle("Kardex")
        .navigationBarTitleDisplayMode(.inline)
        .danperFormChrome()
    }
}
