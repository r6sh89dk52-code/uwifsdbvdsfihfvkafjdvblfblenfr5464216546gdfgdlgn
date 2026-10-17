import Foundation
import SwiftUI
import DanperCore

/// Amendments are versioned within one encrypted N2 generation.
/// Clinical diagnosis and procedure metadata can be corrected without
/// changing the original item ID, dispensed quantity or FEFO stock ledger.
struct N2ClinicalCorrectionView:View {
    let visitID:String
    @State private var detail:N2CorrectionDetail?
    @State private var revision:Int?
    @State private var category=""
    @State private var system=""
    @State private var segment=""
    @State private var diagnosis=""
    @State private var permission="NO"
    @State private var permissionTime=""
    @State private var responsible=""
    @State private var responsibleDni=""
    @State private var workStatus=""
    @State private var blueBandage=false
    @State private var returned=false
    @State private var photoSent=false
    @State private var procedures=""
    @State private var itemProcedures=[String:String]()
    @State private var reason=""
    @State private var discrepancy=""
    @State private var operatorName="OPERADOR DANPER"
    @State private var eventID=UUID().uuidString
    @State private var pendingConfirmation=false
    @State private var saving=false
    @State private var saved=false
    @State private var failed=false
    @State private var message="Verificando atención confirmada y su historial…"

    private var ready:Bool {
        detail != nil && revision != nil && !saving && !saved &&
        reason.trimmingCharacters(in:.whitespacesAndNewlines).count>=8 &&
        operatorName.trimmingCharacters(in:.whitespacesAndNewlines).count>=3 &&
        !diagnosis.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty &&
        !category.isEmpty && !system.isEmpty &&
        (permission=="NO" || permissionTime.count==5)
    }

    var body:some View {
        Form {
            Section("Rectificación clínica · origen conservado") {
                Label("La atención guardada y el Kardex no se reemplazan",
                      systemImage:"lock.shield.fill")
                    .foregroundStyle(.orange)
                if let detail {
                    LabeledContent("Trabajador",value:detail.workerName)
                    LabeledContent("Fecha y hora original",
                                   value:detail.date+" · "+detail.time)
                    LabeledContent("ID original",value:detail.id)
                    LabeledContent("Rectificaciones previas",
                                   value:String(detail.previousCorrections))
                    if detail.pendingMedicationDiscrepancy {
                        Label("Discrepancia de medicamento sin conciliar",
                              systemImage:"exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                    }
                }
                Text(message).font(.footnote)
                    .foregroundStyle(failed ? Color.red : Color.secondary)
            }
            if detail != nil && !saved {
                Section("Campos clínicos rectificables") {
                    TextField("Diagnóstico",text:$diagnosis,axis:.vertical)
                        .lineLimit(2...5)
                    TextField("Tipo de atención",text:$category)
                    TextField("Sistema afectado",text:$system)
                    TextField("Detalle",text:$segment)
                    TextField("Procedimientos (uno por línea)",text:$procedures,
                              axis:.vertical).lineLimit(2...6)
                    Picker("Permiso",selection:$permission) {
                        Text("NO").tag("NO")
                        Text("SI").tag("SI")
                    }
                    if permission=="SI" {
                        TextField("Hora del permiso (HH:mm)",text:$permissionTime)
                    }
                    Toggle("Retornó a labores",isOn:$returned)
                    Toggle("Vendaje azul",isOn:$blueBandage)
                    Toggle("Foto enviada",isOn:$photoSent)
                    TextField("Responsable",text:$responsible)
                    TextField("DNI del responsable",text:$responsibleDni)
                }
                if let detail {
                    Section("Medicamentos y consumos originales") {
                        Text("El código, la cantidad administrada y las salidas FEFO son inmutables. Solo puedes corregir la descripción del procedimiento clínico, sin volver a descontar inventario.")
                            .font(.footnote).foregroundStyle(.secondary)
                        ForEach(detail.medications,id:\.id){ item in
                            VStack(alignment:.leading,spacing:4) {
                                Text(item.name).font(.headline)
                                Text(item.code+" · Cantidad original: "+String(item.quantity))
                                    .font(.caption).foregroundStyle(.secondary)
                                TextField("Procedimiento del ítem",text:Binding(
                                    get:{itemProcedures[item.id] ?? item.procedure},
                                    set:{itemProcedures[item.id]=$0}
                                ))
                            }
                        }
                        TextField("Discrepancia de medicamento / dosis (opcional)",
                                  text:$discrepancy,axis:.vertical)
                            .lineLimit(2...5)
                        Text("Si documentas una discrepancia de medicamento o cantidad, quedará en el historial pero se bloqueará su inclusión en el Excel oficial hasta revisión de inventario. No se simula una devolución ni nueva entrega.")
                            .font(.caption).foregroundStyle(.orange)
                    }
                }
                Section("Auditoría obligatoria") {
                    TextField("Motivo detallado de la rectificación",text:$reason,
                              axis:.vertical).lineLimit(2...5)
                    TextField("Responsable que rectifica",text:$operatorName)
                    Button {
                        pendingConfirmation=true
                    } label: {
                        Label("Confirmar rectificación cifrada",
                              systemImage:"checkmark.shield.fill")
                    }
                    .disabled(!ready)
                    .confirmationDialog(
                        "¿Confirmar una rectificación auditada?",
                        isPresented:$pendingConfirmation,
                        titleVisibility:.visible) {
                        Button("Guardar rectificación") {
                            Task {await confirm()}
                        }
                        Button("Cancelar",role:.cancel){}
                    } message: {
                        Text("La atención original, la fecha, los productos y todas las salidas de stock permanecen intactos.")
                    }
                }
            }else if saved {
                Section {
                    Label("Rectificación confirmada en la bóveda",
                          systemImage:"checkmark.shield.fill")
                        .foregroundStyle(.green)
                    Text("Reabre el historial para consultar el diagnóstico corregido y su trazabilidad.")
                }
            }
        }
        .navigationTitle("Rectificar atención N2")
        .task {await load()}
    }
    @MainActor
    private func load() async {
        do {
            let ctx=try await N2ProtectedClinicalIOSVault.shared.clinicalFormContext()
            let d=try await N2ProtectedClinicalIOSVault.shared
                .readCorrectionDetail(visitID:visitID)
            revision=ctx.revision
            detail=d
            category=d.category
            system=d.system
            segment=d.segment
            diagnosis=d.diagnosis
            permission=d.permission
            permissionTime=d.permissionTime
            responsible=d.responsible
            responsibleDni=d.responsibleDni
            workStatus=d.workStatus
            blueBandage=d.blueBandage
            returned=d.returned
            photoSent=d.photoSent
            procedures=d.procedures.joined(separator:"\n")
            itemProcedures=Dictionary(uniqueKeysWithValues:
                d.medications.map{($0.id,$0.procedure)})
            message="Atención verificada; no se modificarán entregas ni existencias."
            failed=false
        }catch {
            failed=true
            message="No fue posible verificar la atención. Edición bloqueada sin afectar inventario."
        }
    }
    @MainActor
    private func confirm() async {
        guard ready,let d=detail,let revision else{return}
        saving=true
        failed=false
        defer{saving=false}
        do {
            let procedureRows=procedures.split(separator:"\n",
                omittingEmptySubsequences:true).map{
                $0.trimmingCharacters(in:.whitespacesAndNewlines)
            }.filter{!$0.isEmpty}
            let input:[String:Any]=[
                "category":category,"system":system,"segment":segment,
                "diagnosis":diagnosis,"permission":permission,
                "permissionTime":permissionTime,"responsible":responsible,
                "responsibleDni":responsibleDni,
                "workStatus":permission=="SI" ? "PERMISO" : "LABORANDO",
                "blueBandage":blueBandage,"returned":returned,
                "photoSent":photoSent,"standaloneProcedures":procedureRows,
                "itemProcedures":itemProcedures
            ]
            let patch=try JSONSerialization.data(withJSONObject:input)
            let result=try await N2ProtectedClinicalIOSVault.shared
                .saveClinicalCorrection(
                    visitID:visitID,eventID:eventID,changes:patch,
                    reason:reason,operatorName:operatorName,
                    medicationDiscrepancy:discrepancy,
                    expectedEffectiveSHA:d.effectiveSHA256,
                    at:Int64(Date().timeIntervalSince1970*1000),
                    expectedRevision:revision)
            saved=true
            message="Rectificación verificada. Revisión cifrada \(result.revision); sin segundos descuentos de medicamentos."
        }catch {
            failed=true
            message="No se guardó la rectificación. Puede haber cambios recientes o datos incorrectos. Reabre la historia y verifica."
        }
    }
}
