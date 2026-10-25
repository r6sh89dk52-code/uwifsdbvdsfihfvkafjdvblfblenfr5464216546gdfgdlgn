import SwiftUI
import DanperCore

struct N2PendingDispensingView:View {
    let visitID:String
    let medication:N2FormMedication
    let date:String
    let context:N2FormContext
    let historicalAccountingOnly:Bool
    let onSaved:()->Void
    init(visitID:String,medication:N2FormMedication,date:String,
         context:N2FormContext,historicalAccountingOnly:Bool=false,
         onSaved:@escaping ()->Void) {
        self.visitID=visitID
        self.medication=medication
        self.date=date
        self.context=context
        self.historicalAccountingOnly=historicalAccountingOnly
        self.onSaved=onSaved
    }
    @Environment(\.n2WorkspaceVault) private var vault
    @Environment(\.dismiss) private var dismiss
    @State private var lotID=""
    @State private var quantity=""
    @State private var opening=false
    @State private var newContainers=1
    @State private var reason=""
    @State private var consent=false
    @State private var busy=false
    @State private var message=""
    private var isHistorical:Bool {
        let formatter=DateFormatter()
        formatter.locale=Locale(identifier:"en_US_POSIX")
        formatter.timeZone=TimeZone(identifier:"America/Lima")
        formatter.dateFormat="yyyy-MM-dd"
        return historicalAccountingOnly || date<formatter.string(from:Date())
    }
    private var selectedLotIsContainer:Bool {
        guard let lot=context.lots.first(where:{$0.id==lotID}) else{return false}
        return N2ContainerAccounting.isContainer(unit:lot.unit)
    }
    private var selectableLots:[N2FormLot] {
        isHistorical ? context.historicalOptions(for:medication.code,at:date) :
                       context.options(for:medication.code,at:date)
    }
    var body:some View {
        NavigationStack {
            Form {
                Section("Verificar salida pendiente") {
                    Text(context.products.clinical.first{$0.code==medication.code}?.name ?? medication.code)
                    Text(isHistorical
                        ? "La atención original permanece intacta. Esta declaración documenta la apertura antigua en el corte, sin descontar inventario actual."
                        : "Se verificará el lote y la salida física sin crear otra atención.")
                        .font(.footnote)
                    Picker("Lote compatible",selection:$lotID) {
                        Text("Seleccionar").tag("")
                        ForEach(selectableLots) { lot in
                            let balance=N2ContainerAccounting.isContainer(unit:lot.unit) ?
                                "\(lot.sealed) cerrados / \(lot.openContainers) abiertos":"\(lot.total.formatted()) \(lot.unit)"
                            Text("\(lot.name) · \(lot.reference) · \(balance)").tag(lot.id)
                        }
                    }
                    if isHistorical {
                        Text("Si el lote fue registrado después de esta atención, puedes documentar aquí una apertura antigua (R=1) o el uso del mismo envase abierto (R=0), incluso si el saldo actual es cero. Se contabiliza en el corte reconstruido, sin descontar de nuevo las existencias actuales.")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                    if !isHistorical || !selectedLotIsContainer {
                        TextField("Cantidad física realmente utilizada",text:$quantity)
                            .keyboardType(.decimalPad)
                    }
                    if let lot=context.lots.first(where:{$0.id==lotID}) {
                        Text(N2ContainerAccounting.isContainer(unit:lot.unit) ?
                            "Envases cerrados: \(lot.sealed) · Abiertos declarados: \(lot.openContainers). El volumen solo se registra si existe seguimiento interno verificado." :
                            "Existencia individual: \(lot.total.formatted()) \(lot.unit).")
                            .font(.caption)
                    }
                    if isHistorical && selectedLotIsContainer {
                        Picker("¿Abriste un envase en esa atención?",selection:$opening) {
                            Text("No · Kardex 0").tag(false)
                            Text("Sí · Kardex 1").tag(true)
                        }
                        .pickerStyle(.segmented)
                        Text("Marca solo lo que recuerdas o tienes documentado. No declarar una apertura si no está verificada.")
                            .font(.caption).foregroundStyle(.secondary)
                    } else {
                        Toggle("Abrí un nuevo envase (declaración explícita)",isOn:$opening)
                        if opening {
                            Stepper("Envases realmente abiertos: \(newContainers)",
                                    value:$newContainers,in:1...100)
                        }
                        Text("Con envase abierto: Kardex 0. El volumen es opcional; no se inferirán aperturas.")
                            .font(.caption)
                    }
                    LabeledContent("Responsable",value:N2ClinicianIdentity.name)
                        .accessibilityIdentifier("historical-opening-responsible")
                    LabeledContent("DNI del responsable",value:N2ClinicianIdentity.dni)
                    Text("Identificación automática del profesional configurado en DANPER. No necesitas introducirla en cada atención.")
                        .font(.caption).foregroundStyle(.secondary)
                    TextField("Evidencia y motivo",text:$reason,axis:.vertical)
                        .lineLimit(2...4)
                        .accessibilityIdentifier("historical-opening-evidence")
                    Text("Obligatorio: explica qué apertura o reutilización verificaste (mínimo 10 caracteres). Esta declaración no modifica el conteo físico actual.")
                        .font(.caption).foregroundStyle(.secondary)
                    Toggle("Confirmo la cantidad física y la evidencia",isOn:$consent)
                    Button(isHistorical ? "Guardar declaración histórica (R=1/0)" :
                                              "Verificar y conciliar sin duplicar atención") {
                        Task {await save()}
                    }
                        .disabled(busy || !consent || lotID.isEmpty)
                }
                if !message.isEmpty {Text(message).foregroundStyle(.orange)}
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(isHistorical ? "Consumo histórico" : "Verificar consumo")
            .navigationBarTitleDisplayMode(.inline)
            .danperFormChrome()
            .toolbar {Button("Cancelar"){dismiss()}}
        }
    }
    @MainActor private func save() async {
        guard !busy else{return}
        guard !lotID.isEmpty else {
            message="Selecciona el lote compatible con la atención.";return
        }
        let evidenceReason=reason.trimmingCharacters(in:.whitespacesAndNewlines)
        guard evidenceReason.count>=10 else {
            message="Falta evidencia y motivo: describe la apertura o reutilización en al menos 10 caracteres.";return
        }
        guard consent else {
            message="Confirma que la apertura declarada y su evidencia son correctas.";return
        }
        let rawQuantity=quantity.isEmpty ? "0":quantity.replacingOccurrences(of:",",with:".")
        guard let amount=Double(rawQuantity),amount.isFinite,amount>=0,amount<=10_000_000 else {
            message="Ingresa una cantidad física válida para la operación.";return
        }
        busy=true;defer {busy=false}
        message=""
        do {
            let evidence=N2PendingDispensingEvidence(visitID:visitID,itemID:medication.id,lotID:lotID,
                quantity:isHistorical && selectedLotIsContainer ? 0:amount,
                confirmNewContainer:opening,operatorName:N2ClinicianIdentity.name,reason:evidenceReason,
                at:Int64(Date().timeIntervalSince1970*1000),
                newContainers:opening ? (isHistorical && selectedLotIsContainer ? 1:newContainers):0,
                operatorDni:N2ClinicianIdentity.dni)
            _=try await vault.confirmPendingDispensing(evidence,expectedRevision:context.revision)
            onSaved();dismiss()
        } catch N2PendingDispensingEvidence.Failure.invalidEvidence {
            message="La declaración no cumple las validaciones de evidencia, responsable o apertura. Ningún consumo fue confirmado."
        } catch N2PendingDispensingEvidence.Failure.invalidTarget {
            message="La atención o el lote ya no coinciden con los datos actuales. Vuelve a Historial y abre de nuevo el consumo pendiente."
        } catch N2ProtectedStoreError.staleRevision {
            message="El inventario cambió desde que abriste esta pantalla. Cierra y vuelve a abrir el consumo desde Historial; no se duplicó la atención."
        } catch {
            let detail=error as NSError
            message="No se pudo verificar la operación (\(detail.domain), código \(detail.code)). La atención sigue guardada y no debes registrarla otra vez."
        }
    }
}
