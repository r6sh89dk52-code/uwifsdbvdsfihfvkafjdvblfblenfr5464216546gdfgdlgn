import Foundation
import SwiftUI
import DanperCore

/// Compact Build 222 medication line. The view edits the same bound draft
/// medication as before; it never writes inventory or confirms consumption.
struct N2MedicationRowView:View {
    @Binding var medication:N2FormMedication
    let context:N2FormContext
    let visitDate:String
    let dispensingSite:String
    let procedures:[String]
    let allergyWarning:Bool
    @Binding var expandedID:String?
    let onRemove:()->Void
    var onMappingConfirmed:()->Void = {}
    @State private var showMapping=false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var expanded:Bool {
        expandedID==medication.id
    }
    private var productName:String {
        context.products.clinical.first(where:{$0.code==medication.code})?.name
            ?? medication.code
    }
    private var productUnit:String {
        context.products.clinical.first(where:{$0.code==medication.code})?.unit ?? ""
    }
    private var lots:[N2FormLot] {
        context.options(for:medication.code,at:visitDate,site:dispensingSite)
    }
    private var availablePhysicalUnits:Double {
        lots.reduce(0.0) { partial,lot in partial + (N2ContainerAccounting.isContainer(unit:lot.unit) ? Double(lot.sealed):lot.total) }
    }
    private var requiresNewContainer:Bool {
        let available=medication.selectedLotID.isEmpty ? lots : lots.filter{$0.id==medication.selectedLotID}
        return available.contains{N2ContainerAccounting.isContainer(unit:$0.unit)} &&
            !available.contains{$0.openContainers>0}
    }
    private var procedureSelection:Binding<String> {
        Binding(
            get:{medication.procedure},
            set:{newValue in
                medication.procedure=newValue
                medication.procedureConfirmed=true
                medication.procedureSource="manual"
            })
    }
    private var lotSelection:Binding<String> {
        Binding(
            get:{medication.selectedLotID},
            set:{newValue in
                medication.selectedLotID=newValue
                medication.approveOpening=false
                medication.physicalQuantity=0
                if !lots.contains(where:{$0.id==newValue && N2ContainerAccounting.isContainer(unit:$0.unit)}),
                   ["UND","TBL","PAR"].contains(productUnit.uppercased()) {
                    medication.physicalQuantity=Double(medication.quantity)
                }
            })
    }
    private var lotLabels:[String:String] {
        var result=["":"Automático por FEFO / pendiente"]
        for lot in lots {
            result[lot.id]="\(lot.name) · Lote \(lot.id) · Vence \(DanperDatePresentation.display(lot.expires))"
        }
        return result
    }

    var body:some View {
        VStack(alignment:.leading,spacing:9) {
            Button {
                withAnimation(reduceMotion ? nil : DanperStyle.animation) {
                    expandedID=expandedID==medication.id ? nil : medication.id
                }
            } label: {
                HStack(alignment:.top,spacing:9) {
                    Image(systemName:"cross.vial.fill")
                        .foregroundStyle(DanperStyle.red)
                        .frame(width:22)
                    VStack(alignment:.leading,spacing:5) {
                        Text(productName)
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(.primary)
                        Text("Cantidad \(medication.quantity) · \(medication.procedure.isEmpty ? "Procedimiento pendiente" : medication.procedure.capitalized)")
                            .font(.caption).foregroundStyle(.secondary)
                        if medication.procedure.isEmpty {
                            Label("Revisar procedimiento",systemImage:"exclamationmark.circle.fill")
                                .font(.caption).foregroundStyle(.orange)
                        }
                        if allergyWarning {
                            Label("Revisar posible coincidencia de alergia",
                                  systemImage:"exclamationmark.triangle.fill")
                                .font(.caption).foregroundStyle(.orange)
                        }
                    }
                    .frame(maxWidth:.infinity,alignment:.leading)
                    Image(systemName:expanded ? "chevron.up" : "chevron.down")
                        .font(.caption.weight(.bold)).foregroundStyle(.secondary)
                }
                .frame(maxWidth:.infinity,alignment:.leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("medication-row-"+medication.id)
            if expanded {
                Divider()
                editorFields
            }
        }
        .padding(11)
        .background(DanperStyle.canvas,
                    in:RoundedRectangle(cornerRadius:14))
        .sheet(isPresented:$showMapping) {
            N2OperationalMappingView(code:medication.code,context:context,onSaved:onMappingConfirmed)
        }
    }

    private var editorFields:some View {
        VStack(alignment:.leading,spacing:11) {
            Text(medication.code+" · "+productUnit)
                .font(.caption).foregroundStyle(.secondary)
            quantityControl
            procedureControl
            lotControl
            if context.operationalMappings.contains(where:{$0.clinicalCode==medication.code}) {
                Label("Correspondencia operativa verificada",systemImage:"checkmark.shield")
                    .font(.caption)
            } else {
                Button("Verificar correspondencia o presentación") {showMapping=true}
                    .font(.caption)
            }
            Button(role:.destructive,action:onRemove) {
                Label("Quitar producto",systemImage:"trash")
                    .font(.caption.weight(.semibold))
            }
            .buttonStyle(.plain)
        }
    }

    private var quantityControl:some View {
        DanperField(title:"Cantidad clínica") {
            HStack(spacing:12) {
                Button {
                    if medication.quantity>1 {medication.quantity-=1}
                } label: {
                    Image(systemName:"minus.circle").frame(width:44,height:44)
                }
                .disabled(medication.quantity<=1)
                TextField("Cantidad",value:$medication.quantity,format:.number)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.center)
                    .accessibilityLabel("Cantidad clínica")
                    .accessibilityIdentifier("clinical-quantity-"+medication.code)
                Button {
                    medication.quantity+=1
                } label: {
                    Image(systemName:"plus.circle").frame(width:44,height:44)
                }
            }
            .buttonStyle(.plain)
            .font(.title3)
            .foregroundStyle(.primary)
        }
    }

    private var procedureControl:some View {
        VStack(alignment:.leading,spacing:7) {
            DanperChoiceField(title:"Procedimiento",
                              selection:procedureSelection,options:procedures)
            Text(procedureExplanation)
                .font(.caption).foregroundStyle(.secondary)
            if !medication.procedureConfirmed && !medication.procedure.isEmpty {
                Button {
                    medication.procedureConfirmed=true
                } label: {
                    Label("Confirmar sugerencia",systemImage:"checkmark")
                }
                .buttonStyle(DanperSecondaryButton())
            }
        }
    }
    private var procedureExplanation:String {
        if medication.procedureConfirmed{return "Elección confirmada"}
        switch medication.procedureSource {
        case "presentation":return "Sugerido por la presentación del producto"
        case "context":return "Sugerido por el contexto de la atención"
        default:return "Selecciona el procedimiento utilizado"
        }
    }

    @ViewBuilder private var lotControl:some View {
        DanperChoiceField(title:"Existencia física",selection:lotSelection,
                          options:[""]+lots.map(\.id),labels:lotLabels)
        if let first=lots.first {
            Text("FEFO: \(first.id) · Disponible: \(availablePhysicalUnits.formatted())")
                .font(.caption).foregroundStyle(.secondary)
        }else {
            Label("Sin existencia aprobada vigente. Se registrará como consumo pendiente.",
                  systemImage:"exclamationmark.triangle")
                .font(.caption).foregroundStyle(.secondary)
        }
        if !lots.isEmpty {
            if let selected=lots.first(where:{$0.id==medication.selectedLotID}) {
                Text(N2ContainerAccounting.isContainer(unit:selected.unit) ?
                    "Cerrados: \(selected.sealed) · Abiertos declarados: \(selected.openContainers)" : "Existencia: \(selected.total.formatted())")
                    .font(.caption).foregroundStyle(.secondary)
            }
            DanperField(title:"Volumen interno opcional / unidades individuales usadas") {
                TextField("Cantidad física",value:$medication.physicalQuantity,
                          format:.number).keyboardType(.decimalPad)
            }
            if lots.contains(where:{N2ContainerAccounting.isContainer(unit:$0.unit)}) {
                Text(requiresNewContainer ? "Sin envase abierto: confirma la apertura para dispensar." :
                    "Se utilizará el envase abierto. Kardex: 0, salvo nueva apertura declarada.")
                    .font(.caption).foregroundStyle(.secondary)
                DanperCheckRow(selected:$medication.approveOpening) {
                    Text("Abrir nuevo envase · apertura realmente realizada")
                        .font(.subheadline)
                }
                if medication.approveOpening {
                    Stepper("Envases abiertos: \(medication.newContainers)",value:$medication.newContainers,in:1...100)
                }
                Text("El volumen es opcional e independiente del Kardex; no determina aperturas ni agotamientos.").font(.caption)
            } else if lots.contains(where:{$0.capacity>1 && $0.sealed>0}) {
                DanperCheckRow(selected:$medication.approveOpening) {
                    Text("Confirmo la apertura física para extraer unidades individuales; el Kardex conserva su unidad individual.")
                        .font(.subheadline)
                }
            }
        }
    }
}
