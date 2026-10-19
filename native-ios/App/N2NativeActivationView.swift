import Foundation
import SwiftUI
import UniformTypeIdentifiers
import LocalAuthentication
import DanperCore

/// Protected, non-destructive compatibility import of an actual build 222
/// .danperbackup. No operation may target the DEMO vault, original build 222
/// sandbox or an existing clinical journal. Never log personal data.
struct N2NativeActivationView:View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var password=""
    @State private var isOriginal=false
    @State private var hasReviewedDemo=false
    @State private var understands=false
    @State private var choosing=false
    @State private var confirming=false
    @State private var busy=false
    @State private var summary:N2ProtectedStoreSummary?
    @State private var review:N2Build222BackupReview?
    @State private var sourceURL:URL?
    @State private var sourceName=""
    @State private var status="Selecciona y revisa tu respaldo original de la build 222."
    @State private var failed=false

    private var canReview:Bool {
        !busy && summary==nil && isOriginal && hasReviewedDemo &&
        understands && (14...200).contains(password.count) &&
        scenePhase == .active
    }
    private var canRestore:Bool {
        canReview && review?.canRestore==true && sourceURL != nil
    }
    var body:some View {
        Form {
            Section("Respaldo completo de la build 222") {
                Label("Restauración cifrada y compatible",
                      systemImage:"lock.shield.fill").font(.headline)
                Text("Se recuperará una sola copia completa: trabajadores, atenciones, borradores, alergias, medicamentos dispensados registrados, lotes, movimientos Kardex y conciliaciones.")
                    .font(.footnote)
                Text("Solo se recuperan los datos presentes en el respaldo. Los consumos históricos sin movimiento físico confirmado continúan PENDIENTES; nunca se descuentan ni se convierten a cero automáticamente.")
                    .font(.footnote).foregroundStyle(.orange)
                Text("IMPORTANTE: restaura el respaldo ANTES de importar un Excel PERSONAL. Las dos opciones crean la primera fuente de la bóveda clínica y no se fusionan automáticamente.")
                    .font(.footnote.weight(.semibold))
                if let summary {
                    Label("Fuente clínica cifrada ya existente",systemImage:"checkmark.shield")
                        .foregroundStyle(.green)
                    LabeledContent("Trabajadores",value:String(summary.workers))
                    LabeledContent("Atenciones",value:String(summary.attentions))
                    LabeledContent("Atenciones guardadas",value:String(summary.saved))
                    LabeledContent("Borradores",value:String(summary.drafts))
                    LabeledContent("Movimientos físicos",value:String(summary.physicalMovements))
                    LabeledContent("Consumos pendientes",value:String(summary.pendingClinicalLines))
                    Text("No se sustituye una base clínica existente. No borres ni desinstales nada para intentar esta restauración.")
                        .font(.footnote).foregroundStyle(.orange)
                }
            }
            if summary == nil {
                Section("Revisión de procedencia") {
                    Toggle("Este es el respaldo original de mi build 222.",isOn:$isOriginal)
                    Toggle("He comprobado si contiene registros ficticios mezclados con reales.",
                           isOn:$hasReviewedDemo)
                    Toggle("Sé que se creará una bóveda clínica independiente, sin borrar mi build 222.",
                           isOn:$understands)
                    Text("Las verificaciones estructurales detectan algunos registros ficticios, pero no pueden certificar por sí solas la procedencia clínica de todos los datos.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Section("1 · Descifrar y comprobar la copia") {
                    SecureField("Contraseña original de la build 222",text:$password)
                        .textContentType(.password)
                    Button {
                        choosing=true
                    } label: {
                        Label(busy ? "Comprobando..." : "Elegir y revisar .danperbackup",
                              systemImage:"doc.text.magnifyingglass")
                    }
                    .buttonStyle(DanperSecondaryButton())
                    .disabled(!canReview)
                    if !sourceName.isEmpty {
                        Text("Copia seleccionada: "+sourceName)
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Text("La revisión lee el archivo local y comprueba el cifrado, su contraseña y la integridad de las colecciones. No escribe datos clínicos.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            if let preview=review,summary==nil {
                Section("2 · Resultados del respaldo") {
                    let audit=preview.audit
                    LabeledContent("Trabajadores",value:String(audit.manifest.workers))
                    LabeledContent("Atenciones",value:String(audit.manifest.attentions))
                    LabeledContent("Guardadas",value:String(audit.saved))
                    LabeledContent("Borradores",value:String(audit.drafts))
                    LabeledContent("Rectificaciones",value:String(audit.corrections))
                    LabeledContent("Alergias documentadas",value:String(audit.allergyKnown))
                    LabeledContent("Alergias negadas",value:String(audit.allergyNone))
                    LabeledContent("Alergias desconocidas",value:String(audit.allergyUnknown))
                    LabeledContent("Lotes",value:String(audit.manifest.lots))
                    LabeledContent("Movimientos físicos",value:String(audit.manifest.movements))
                    LabeledContent("Asociaciones de materiales",value:String(audit.manifest.catalogMappings))
                    LabeledContent("Incidencias de entrega",value:String(audit.manifest.deliveryIncidents))
                    LabeledContent("Conciliaciones ambulatorias",value:String(audit.manifest.ambulatoryReconciliation))
                    LabeledContent("Consumos sin entrega confirmada",
                                   value:String(audit.unresolvedClinicalConsumptions))
                    if preview.canRestore {
                        Label("Copia compatible. Lista para confirmar la restauración en una bóveda clínica vacía.",
                              systemImage:"checkmark.shield.fill")
                            .foregroundStyle(.green).font(.footnote)
                        Button {
                            confirming=true
                        } label: {
                            HStack {
                                if busy {ProgressView()}
                                Label("Confirmar restauración completa",systemImage:"square.and.arrow.down.fill")
                            }
                        }
                        .buttonStyle(DanperPrimaryButton())
                        .disabled(!canRestore)
                        .accessibilityIdentifier("confirm-build222-restore")
                    } else {
                        Label("La copia requiere revisión: se detectaron señales ficticias, referencias clínicas incompletas o problemas de identidad. No se permitirá importarla.",
                              systemImage:"exclamationmark.triangle.fill")
                            .foregroundStyle(.orange).font(.footnote)
                    }
                }
            }
            Section("Estado") {
                Text(status)
                    .font(.footnote)
                    .foregroundStyle(failed ? Color.orange : Color.secondary)
                Text("No se modifica ni elimina el archivo original de respaldo, ni los datos de la build 222. Una restauración completada debe comprobarse desde Personal, Atención y Kardex antes del uso real.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Restaurar build 222")
        .danperFormChrome()
        .fileImporter(isPresented:$choosing,allowedContentTypes:[.item],
                      allowsMultipleSelection:false) { result in
            switch result {
            case .failure:
                review=nil;sourceURL=nil;sourceName=""
                failed=true
                status="No se pudo seleccionar el respaldo. No se modificó la bóveda clínica."
            case .success(let urls):
                if let chosen=urls.first {Task {await inspectBackup(chosen)}}
            }
        }
        .confirmationDialog("¿Importar TODA la copia original?",
                            isPresented:$confirming,titleVisibility:.visible) {
            Button("Sí, restaurar respaldo completo") {
                Task {await restoreBackup()}
            }
            Button("Cancelar",role:.cancel) {}
        } message: {
            Text("Se verificará nuevamente la contraseña y la huella exacta del archivo revisado. Solo se admite una bóveda CLÍNICA vacía. No se sustituirán datos existentes ni se alterará la build 222.")
        }
        .onChange(of:password) {_,_ in
            review=nil
            sourceURL=nil
            sourceName=""
        }
        .onChange(of:scenePhase) {_,phase in
            if phase == .background {
                password=""
                review=nil
                sourceURL=nil
                sourceName=""
                confirming=false
            }
        }
        .task {await checkDestination()}
        .onDisappear {
            password=""
            review=nil
            sourceURL=nil
        }
    }

    @MainActor private func checkDestination() async {
        do {
            summary=try await N2ProtectedClinicalIOSVault.shared.inspect()
            if summary != nil {
                status="La bóveda clínica ya contiene información. No se reemplazará ni fusionará con otro respaldo."
            }
        } catch {
            failed=true
            status="No se puede verificar el almacenamiento clínico. Restauración bloqueada para proteger los registros existentes."
        }
    }

    @MainActor private func inspectBackup(_ url:URL) async {
        guard canReview,!busy else{return}
        busy=true
        failed=false
        review=nil
        sourceURL=nil
        status="Descifrando y auditando el respaldo en el iPhone…"
        defer{busy=false}
        do {
            let permitted=try await LAContext().evaluatePolicy(
                .deviceOwnerAuthentication,
                localizedReason:"Verificar un respaldo clínico de DANPER build 222")
            guard permitted,scenePhase == .active else {
                failed=true
                status="Autenticación cancelada. No se leyó ni importó ninguna historia."
                return
            }
            let pass=password
            let answer=try await Task.detached(priority:.userInitiated) {
                try PortableBackupInspector.review(url:url,password:pass)
            }.value
            guard scenePhase == .active else{return}
            // A second vault check occurs after decryption so another imported
            // source cannot be accidentally overwritten.
            let existing=try await N2ProtectedClinicalIOSVault.shared.inspect()
            guard existing==nil else {
                summary=existing
                throw BackupInspectionError.invalidSnapshot
            }
            review=answer
            sourceURL=url
            sourceName=url.lastPathComponent
            failed = !answer.canRestore
            status=answer.canRestore ?
                "Copia íntegra. Comprueba los recuentos y confirma la restauración." :
                "Revisión clínica requerida. La copia no está autorizada para restaurarse."
        } catch {
            failed=true
            status="No se pudo verificar la copia: \(error.localizedDescription). Ningún registro fue modificado."
        }
    }

    @MainActor private func restoreBackup() async {
        guard canRestore,let review,let url=sourceURL else{return}
        busy=true
        failed=false
        status="Verificando de nuevo la copia e iniciando restauración protegida…"
        defer{busy=false}
        do {
            let permitted=try await LAContext().evaluatePolicy(
                .deviceOwnerAuthentication,
                localizedReason:"Confirmar restauración completa de build 222 en bóveda clínica")
            guard permitted,scenePhase == .active else {
                failed=true
                status="La autenticación no se completó. No se restauró nada."
                return
            }
            let original=review.audit
            let imported=try await PortableBackupInspector.activateProtectedSource(
                url:url,password:password,explicitConsent:true,
                expectedEncryptedSHA256:review.encryptedSHA256)
            guard imported.workers==original.manifest.workers,
                  imported.attentions==original.manifest.attentions,
                  imported.saved==original.saved,
                  imported.drafts==original.drafts,
                  imported.physicalMovements==original.manifest.movements,
                  imported.pendingClinicalLines==original.unresolvedClinicalConsumptions else {
                throw BackupInspectionError.invalidSnapshot
            }
            summary=imported
            self.review=nil
            sourceURL=nil
            sourceName=""
            password=""
            failed=false
            status="Restauración verificada en la bóveda CLÍNICA: \(imported.workers) trabajadores, \(imported.attentions) atenciones, \(imported.physicalMovements) movimientos, \(imported.pendingClinicalLines) consumos pendientes. La build 222 y el archivo original permanecen intactos."
        } catch {
            failed=true
            status="Restauración no confirmada: \(error.localizedDescription). No reintentes borrando la bóveda; primero comprueba si ya existen datos desde Acceso clínico."
            await checkDestination()
        }
    }
}
