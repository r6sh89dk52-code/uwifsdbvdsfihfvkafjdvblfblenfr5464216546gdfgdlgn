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
    @State private var operatorName=""
    @State private var eventID=UUID().uuidString
    @State private var draftTask:Task<Void,Never>?
    @State private var history=[N2CorrectionHistoryEntry]()
    @State private var confirmDiscard=false
    @State private var suppressAutosave=false
    @Environment(\.dismiss) private var dismiss
    @State private var recovering=false
    @State private var lastDraftAt:Int64=0
    @Environment(\.scenePhase) private var scenePhase
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
                if !history.isEmpty {
                    Text("Rectificaciones anteriores: \(history.count)")
                        .font(.footnote).foregroundStyle(.secondary)
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
                    Button(role:.destructive) {
                        confirmDiscard=true
                    } label: {
                        Label("Descartar rectificación en curso",
                              systemImage:"trash")
                    }
                    .disabled(saving)
                    .confirmationDialog(
                        "¿Descartar el borrador de rectificación?",
                        isPresented:$confirmDiscard,
                        titleVisibility:.visible) {
                        Button("Descartar borrador",role:.destructive) {
                            Task {await discardDraft()}
                        }
                        Button("Cancelar",role:.cancel){}
                    } message: {
                        Text("Elimina solo la corrección aún no confirmada. La atención y el Kardex originales permanecen intactos.")
                    }
                }
            }
            if !history.isEmpty {
                Section("Trazabilidad de rectificaciones") {
                    ForEach(history){event in
                        VStack(alignment:.leading,spacing:5) {
                            Text(event.reason).font(.headline)
                            Text("Responsable: "+event.operatorName)
                                .font(.caption).foregroundStyle(.secondary)
                            Text("Antes: "+event.beforeDiagnosis)
                                .font(.caption2).foregroundStyle(.secondary)
                            Text("Después: "+event.afterDiagnosis)
                                .font(.caption2).foregroundStyle(.secondary)
                            if !event.medicationDiscrepancy.isEmpty {
                                Label(event.medicationDiscrepancy,
                                      systemImage:"exclamationmark.triangle.fill")
                                    .font(.caption).foregroundStyle(.orange)
                            }
                            Text(Date(timeIntervalSince1970:
                                Double(event.recordedAt)/1000)
                                .formatted(date:.numeric,time:.shortened))
                                .font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                }
            }
            if saved {
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
        .onChange(of:autosaveFingerprint) {_,_ in
            queueDraft()
        }
        .onChange(of:scenePhase) {_,phase in
            if phase != .active {queueDraft(immediate:true)}
        }
        .onDisappear {queueDraft(immediate:true)}
    }
    private var autosaveFingerprint:String {
        [
            category,system,segment,diagnosis,permission,permissionTime,
            responsible,responsibleDni,workStatus,blueBandage.description,
            returned.description,photoSent.description,procedures,reason,
            discrepancy,operatorName,
            itemProcedures.keys.sorted().map{
                $0+"="+(itemProcedures[$0] ?? "")
            }.joined(separator:"|")
        ].joined(separator:"\u{001F}")
    }
    private func editPacket()->[String:Any] {
        let procedureRows=procedures.split(separator:"\n",
            omittingEmptySubsequences:true).map{
            $0.trimmingCharacters(in:.whitespacesAndNewlines)
        }.filter{!$0.isEmpty}
        return [
            "category":category,"system":system,"segment":segment,
            "diagnosis":diagnosis,"permission":permission,
            "permissionTime":permissionTime,"responsible":responsible,
            "responsibleDni":responsibleDni,
            "workStatus":permission=="SI" ? "PERMISO" : "LABORANDO",
            "blueBandage":blueBandage,"returned":returned,
            "photoSent":photoSent,"standaloneProcedures":procedureRows,
            "itemProcedures":itemProcedures
        ]
    }
    private func queueDraft(immediate:Bool=false) {
        guard detail != nil,!recovering,!saving,!saved,!failed,
              !suppressAutosave else{return}
        draftTask?.cancel()
        let changes=editPacket()
        let why=reason,op=operatorName,note=discrepancy
        let expected=detail!.effectiveSHA256
        draftTask=Task {@MainActor in
            if !immediate {
                do{try await Task.sleep(for:.milliseconds(650))}
                catch{return}
            }
            guard !Task.isCancelled else{return}
            do {
                let ctx=try await N2ProtectedClinicalIOSVault.shared.clinicalFormContext()
                let millis=max(Int64(Date().timeIntervalSince1970*1000),
                               lastDraftAt+1)
                let raw=try JSONSerialization.data(withJSONObject:changes)
                _=try await N2ProtectedClinicalIOSVault.shared
                    .savePendingClinicalCorrection(
                        visitID:visitID,changes:raw,reason:why,
                        operatorName:op,medicationDiscrepancy:note,
                        expectedEffectiveSHA:expected,at:millis,
                        expectedRevision:ctx.revision)
                lastDraftAt=millis
                message="Rectificación en curso cifrada; aún no confirmada."
            }catch{
                if !Task.isCancelled {
                    failed=true
                    message="No pudo guardarse la rectificación en curso. Reabre la historia; los datos confirmados no cambiaron."
                }
            }
        }
    }
    @MainActor
    private func load() async {
        recovering=true
        defer{recovering=false}
        do {
            let ctx=try await N2ProtectedClinicalIOSVault.shared.clinicalFormContext()
            let d=try await N2ProtectedClinicalIOSVault.shared
                .readCorrectionDetail(visitID:visitID)
            history=try await N2ProtectedClinicalIOSVault.shared
                .readCorrectionHistory(visitID:visitID)
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
            if let pending=try await N2ProtectedClinicalIOSVault.shared
                   .readPendingClinicalCorrection(visitID:visitID),
               let changes=try? JSONSerialization.jsonObject(
                   with:pending.changes) as? [String:Any] {
                category=changes["category"] as? String ?? category
                system=changes["system"] as? String ?? system
                segment=changes["segment"] as? String ?? segment
                diagnosis=changes["diagnosis"] as? String ?? diagnosis
                permission=changes["permission"] as? String ?? permission
                permissionTime=changes["permissionTime"] as? String ?? permissionTime
                responsible=changes["responsible"] as? String ?? responsible
                responsibleDni=changes["responsibleDni"] as? String ?? responsibleDni
                workStatus=changes["workStatus"] as? String ?? workStatus
                blueBandage=changes["blueBandage"] as? Bool ?? blueBandage
                returned=changes["returned"] as? Bool ?? returned
                photoSent=changes["photoSent"] as? Bool ?? photoSent
                procedures=(changes["standaloneProcedures"] as? [String] ?? d.procedures)
                    .joined(separator:"\n")
                itemProcedures=changes["itemProcedures"] as? [String:String]
                    ?? itemProcedures
                reason=pending.reason
                operatorName=pending.operatorName
                discrepancy=pending.medicationDiscrepancy
                lastDraftAt=pending.updatedAt
                message="Rectificación en curso recuperada desde la bóveda cifrada."
            }else {
                message="Atención verificada; no se modificarán entregas ni existencias."
            }

            failed=false
        }catch {
            failed=true
            message="No fue posible verificar la atención. Edición bloqueada sin afectar inventario."
        }
    }
    @MainActor
    private func discardDraft() async {
        guard !saving else{return}
        draftTask?.cancel()
        saving=true
        defer{saving=false}
        do {
            if try await N2ProtectedClinicalIOSVault.shared
                  .readPendingClinicalCorrection(visitID:visitID) != nil {
                let ctx=try await N2ProtectedClinicalIOSVault.shared.clinicalFormContext()
                _=try await N2ProtectedClinicalIOSVault.shared
                    .deletePendingClinicalCorrection(
                        visitID:visitID,expectedRevision:ctx.revision)
            }
            suppressAutosave=true
            dismiss()
        }catch {
            failed=true
            message="No pudo eliminarse el borrador de rectificación; la atención original no cambió."
        }
    }
    @MainActor
    private func confirm() async {
        guard ready,let d=detail else{return}
        draftTask?.cancel()
        saving=true
        failed=false
        defer{saving=false}
        do {
            let input=editPacket()
            let patch=try JSONSerialization.data(withJSONObject:input)
            let latest=try await N2ProtectedClinicalIOSVault.shared
                .clinicalFormContext()
            let result=try await N2ProtectedClinicalIOSVault.shared
                .saveClinicalCorrection(
                    visitID:visitID,eventID:eventID,changes:patch,
                    reason:reason,operatorName:operatorName,
                    medicationDiscrepancy:discrepancy,
                    expectedEffectiveSHA:d.effectiveSHA256,
                    at:Int64(Date().timeIntervalSince1970*1000),
                    expectedRevision:latest.revision)
            saved=true
            message="Rectificación verificada. Revisión cifrada \(result.revision); sin segundos descuentos de medicamentos."
        }catch {
            failed=true
            message="No se guardó la rectificación. Puede haber cambios recientes o datos incorrectos. Reabre la historia y verifica."
        }
    }
}
