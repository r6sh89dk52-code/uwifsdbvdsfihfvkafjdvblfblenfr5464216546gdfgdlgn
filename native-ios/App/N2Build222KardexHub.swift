import SwiftUI
import DanperCore

/// Build 222 Kardex home screen, rebuilt as native navigation.
/// Navigation never creates inventory movements or changes clinical data.
struct N2Build222KardexHub:View {
    private let options:[(number:String,title:String,detail:String,symbol:String)]=[
        ("1","Inventario físico","Consultar los 98 productos, existencias y lotes","shippingbox.fill"),
        ("2","Entradas y salidas","Registrar lotes, ingresos y conteos comprobados","arrow.left.arrow.right"),
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
                    Text("Control físico de existencias de prueba")
                        .font(.subheadline).foregroundStyle(.secondary)
                }.frame(maxWidth:.infinity,alignment:.leading)

                HStack(spacing:10) {
                    summary(value:"98",label:"Productos oficiales",symbol:"cross.vial")
                    summary(value:"FEFO",label:"Selección por vencimiento",symbol:"calendar.badge.clock")
                }

                DanperPanel {
                    Text("¿Qué necesitas hacer?")
                        .font(.title3.weight(.bold))
                    Text("Elige una opción. Ninguna de estas pantallas registra consumos o movimientos solo por abrirla.")
                        .font(.footnote).foregroundStyle(.secondary)
                    VStack(spacing:10) {
                        route(0){N2NativeInventoryView()}
                        route(1){N2NativeInventoryView()}
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

                Label("Sólo se muestran y editan datos de la bóveda activa. Las salidas físicas deben confirmarse desde su flujo correspondiente.",
                      systemImage:"lock.shield")
                    .font(.caption).foregroundStyle(.secondary)
            }.padding(16)
        }
        .navigationTitle("Kardex")
        .navigationBarTitleDisplayMode(.inline)
        .danperFormChrome()
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
