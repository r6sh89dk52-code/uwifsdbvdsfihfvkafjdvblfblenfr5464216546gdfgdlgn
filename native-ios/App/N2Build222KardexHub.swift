import Foundation
import SwiftUI
import DanperCore

/// Build 222 Kardex home screen, rebuilt as native navigation.
/// Navigation never creates inventory movements or changes clinical data.
struct N2Build222KardexHub:View {
    init() {}
    #if DEBUG
    init(layoutLotCount:Int) {
        layoutOnly=true
        _lotCount=State(initialValue:layoutLotCount)
    }
    #endif
    private var layoutOnly=false
    @Environment(\.n2WorkspaceVault) private var vault
    @State private var lotCount:Int?
    private var activePeriod:N2KardexCutPreview.Period? {
        let formatter=DateFormatter()
        formatter.locale=Locale(identifier:"en_US_POSIX")
        formatter.timeZone=TimeZone(identifier:"America/Lima")
        formatter.dateFormat="yyyy-MM-dd"
        return try? N2KardexCutPreview.period(for:formatter.string(from:Date()))
    }
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
                    summary(value:"98",label:"Productos del catálogo",symbol:"cross.vial")
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
                            Text("Producto, lote, unidad, vencimiento opcional y cantidad.")
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

                NavigationLink {
                    N2NativeInventoryView()
                } label: {
                    Label("Ver medicamentos y existencias registradas",
                          systemImage:"shippingbox")
                }
                .buttonStyle(DanperSecondaryButton())

                DanperPanel("Corte mensual · del día 9 al día 8") {
                    if let activePeriod {
                        LabeledContent("Inicio",value:DanperDatePresentation.display(activePeriod.start))
                        LabeledContent("Fin",value:DanperDatePresentation.display(activePeriod.end))
                    }
                    Text("El corte cambia automáticamente cada día 9. Se mantiene un único inventario y se calculan los saldos sin descontar otra vez una atención.")
                        .font(.footnote).foregroundStyle(.secondary)
                    NavigationLink {
                        N2KardexCutPreviewView()
                    } label: {
                        Label("Consultar saldos del corte",
                              systemImage:"calendar.badge.clock")
                            .frame(maxWidth:.infinity,alignment:.leading)
                    }
                    .buttonStyle(DanperSecondaryButton())
                    .accessibilityIdentifier("kardex-ninth-cut-preview")
                }

                DanperPanel("Más opciones") {
                    linkedAction("Registrar ingreso",subtitle:"Agregar cantidad a un lote existente",
                                 symbol:"tray.and.arrow.down",id:"receipt"){
                        N2NativeInventoryView(initialOperation:"receipt")
                    }
                    linkedAction("Conciliar existencias",subtitle:"Actualizar un conteo registrado",
                                 symbol:"checkmark.shield",id:"count"){
                        N2NativeInventoryView(initialOperation:"count")
                    }
                    linkedAction("Kardex de Enfermeras",subtitle:"Excel de 98 productos · diario o semanal",
                                 symbol:"calendar",id:"nursing"){
                        N2VerifiedNursingExportView()
                    }
                    linkedAction("Indicador Ambulatorio",subtitle:"Excel oficial de 10 hojas · corte 9 a 8",
                                 symbol:"tablecells",id:"indicator"){
                        N2VerifiedIndicatorExportView()
                    }
                    linkedAction("Vigilancia ocupacional",
                                 subtitle:"Excel de una hoja · sistema osteomuscular",
                                 symbol:"figure.walk.motion",id:"vigilance"){
                        N2OccupationalVigilanceExportView()
                    }
                }

                Label("Inventario compartido entre ambas sedes. Cada atención terminada registra su consumo automáticamente; los lotes son internos y no se exportan.",
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
        guard !layoutOnly else{return}
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

    private func linkedAction<Destination:View>(_ name:String,subtitle:String,
        symbol:String,id:String,@ViewBuilder destination:()->Destination)->some View {
        NavigationLink(destination:destination) {
            HStack(spacing:12) {
                Image(systemName:symbol)
                    .foregroundStyle(DanperStyle.red)
                    .frame(width:25)
                VStack(alignment:.leading,spacing:4) {
                    Text(name).font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text(subtitle).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName:"chevron.right")
                    .font(.caption).foregroundStyle(.secondary)
            }
            .padding(13)
            .background(DanperStyle.canvas,in:RoundedRectangle(cornerRadius:14))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("kardex-route-"+id)
    }
}
