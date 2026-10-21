import Foundation
import SwiftUI
import LocalAuthentication
import UniformTypeIdentifiers
import DanperCore

/// Real XLSX PERSONAL is processed entirely on-device. The preview never
/// writes to DEMO, build 222, or the protected clinical journal.
struct N2NativePersonalImportView:View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var authenticated=false
    @State private var busy=false
    @State private var choosing=false
    @State private var confirm=false
    @State private var site=""
    @State private var preview:N2PersonalImportPreview?
    @State private var current:N2ProtectedStoreSummary?
    @State private var comparison:N2PersonalImportResult?
    @State private var imported=false
    @State private var message="Autentícate antes de seleccionar PERSONAL."
    @State private var failed=false
    @State private var fileName=""

    private var siteIsVerified:Bool {
        guard let preview else{return false}
        if site=="DESDE_EXCEL" {
            return preview.stats.sourceSiteColumn &&
                preview.workers.allSatisfy{["LA VENTUROSA","PLVENTUROSA"].contains($0.site)}
        }
        return ["LA VENTUROSA","PLVENTUROSA"].contains(site) &&
            preview.workers.allSatisfy{$0.site.isEmpty || $0.site==site}
    }
    private var canImport:Bool {
        authenticated && preview?.stats.canConfirm == true &&
        siteIsVerified && (current==nil || comparison != nil) &&
        !busy && !failed && scenePhase == .active
    }
    var body:some View {
        ScrollView {
            VStack(alignment:.leading,spacing:16) {
                DanperPanel("Importador nativo de PERSONAL") {
                    Label("Excel PERSONAL · sin conexión a Internet",
                          systemImage:"tablecells")
                        .font(.headline)
                    Text("Lee exclusivamente la hoja PERSONAL del archivo .xlsx original. No importa atenciones, alergias, consumos ni inventario del libro Excel.")
                        .font(.footnote).foregroundStyle(.secondary)
                    Text("Este importador escribe SOLO en la bóveda CLÍNICA cifrada. La demostración y la build 222 permanecen intactas.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                DanperPanel("1 · Autorización") {
                    Label(authenticated ? "Identidad comprobada" :
                          "Acceso restringido",
                          systemImage:authenticated ? "checkmark.shield" : "lock.shield")
                        .foregroundStyle(authenticated ? Color.green : Color.secondary)
                    Button {
                        Task {await authenticate()}
                    } label: {
                        Label("Autenticar con Face ID o código",systemImage:"faceid")
                    }
                    .buttonStyle(DanperSecondaryButton())
                    .disabled(busy)
                }
                if authenticated {
                    DanperPanel("2 · Seleccionar Excel PERSONAL") {
                        Picker("Clasificación de sedes",selection:$site) {
                            Text("Seleccionar criterio de sede").tag("")
                            Text("Todo el archivo: Fundo La Venturosa").tag("LA VENTUROSA")
                            Text("Todo el archivo: Planta La Venturosa").tag("PLVENTUROSA")
                            if preview?.stats.sourceSiteColumn == true {
                                Text("Respetar columna SEDE del Excel").tag("DESDE_EXCEL")
                            }
                        }
                        .pickerStyle(.menu)
                        .accessibilityIdentifier("personal-site-mode")
                        Text("Ninguna sede se asigna por defecto. Si PERSONAL contiene la columna SEDE, puedes respetar la sede de cada DNI. Si no la contiene, selecciona una sola sede únicamente para un padrón previamente verificado. Nunca importes un archivo mixto sin identificar sus sedes.")
                            .font(.caption).foregroundStyle(.secondary)
                        if !siteIsVerified {
                            Label("Selecciona y verifica la sede antes de importar.",systemImage:"exclamationmark.triangle.fill")
                                .font(.footnote).foregroundStyle(.orange)
                        }
                        Button {
                            choosing=true
                        } label: {
                            Label("Seleccionar archivo .xlsx",systemImage:"doc.badge.plus")
                        }
                        .buttonStyle(DanperPrimaryButton())
                        .disabled(busy)
                        .accessibilityIdentifier("select-personal-xlsx")
                        if !fileName.isEmpty {
                            Text("Archivo seleccionado: "+fileName)
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
                if let preview,authenticated {
                    DanperPanel("3 · Revisión antes de importar") {
                        LabeledContent("DNI válidos únicos",value:String(preview.stats.valid))
                        LabeledContent("Filas de origen",value:String(preview.stats.total))
                        LabeledContent("DNI incorrectos",value:String(preview.stats.invalidDni))
                        LabeledContent("Sin nombres",value:String(preview.stats.withoutName))
                        LabeledContent("Duplicados en Excel",value:String(preview.stats.duplicates))
                        LabeledContent("Sexo ausente",value:String(preview.stats.sexMissing))
                        LabeledContent("Sexo fuera de catálogo",value:String(preview.stats.sexInvalid))
                        LabeledContent("Nombres contradictorios",value:String(preview.stats.nameConflicts))
                        LabeledContent("Sexos contradictorios",value:String(preview.stats.sexConflicts))
                        VStack(alignment:.leading,spacing:5) {
                            Text("Muestra de registros reconocidos")
                                .font(.subheadline.weight(.semibold))
                            ForEach(Array(preview.workers.prefix(3)),id:\.dni) {person in
                                Text(person.dni+" · "+person.name)
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        .accessibilityIdentifier("personal-xlsx-import-preview")
                        if preview.stats.sourceSiteColumn {
                            Divider()
                            LabeledContent("Trabajadores de Fundo",value:String(preview.workers.filter{$0.site=="LA VENTUROSA"}.count))
                            LabeledContent("Trabajadores de Planta",value:String(preview.workers.filter{$0.site=="PLVENTUROSA"}.count))
                            LabeledContent("Filas sin sede",value:String(preview.stats.siteMissing))
                            LabeledContent("Sedes sin reconocer",value:String(preview.stats.siteInvalid))
                            LabeledContent("DNI con dos sedes",value:String(preview.stats.siteConflicts))
                        }
                        if let comparison {
                            Divider()
                            LabeledContent("Nuevos trabajadores",value:String(comparison.added))
                            LabeledContent("Ya existentes sin cambios",value:String(comparison.unchanged))
                            LabeledContent("Fichas por actualizar",value:String(comparison.updated))
                            LabeledContent("Correcciones manuales conservadas",
                                           value:String(comparison.preservedManualCorrections))
                        } else if current==nil {
                            Label("Se creará una base clínica nueva, sin pacientes ficticios, atenciones ni stock.",
                                  systemImage:"plus.circle")
                                .font(.footnote).foregroundStyle(.green)
                        }
                        if !preview.stats.canConfirm {
                            Label("Importación bloqueada: corrige los DNI, nombres, sexos o sedes incompletas y contradictorias. Ningún registro ha cambiado.",
                                  systemImage:"exclamationmark.triangle.fill")
                                .font(.footnote).foregroundStyle(.orange)
                        } else if failed {
                            Label("Se detectó una diferencia con el padrón existente. Revisa el archivo antes de continuar.",
                                  systemImage:"exclamationmark.triangle.fill")
                                .font(.footnote).foregroundStyle(.orange)
                        } else {
                            Button {
                                confirm=true
                            } label: {
                                HStack {
                                    if busy {ProgressView().tint(.white)}
                                    Label(current == nil ? "Crear base clínica desde PERSONAL" :
                                          "Confirmar conciliación PERSONAL",
                                          systemImage:"checkmark.shield")
                                }
                            }
                            .buttonStyle(DanperPrimaryButton())
                            .disabled(!canImport)
                            .accessibilityIdentifier("confirm-personal-import")
                        }
                    }
                }
                if imported {
                    DanperPanel {
                        Label("Importación guardada y verificada",
                              systemImage:"checkmark.seal.fill")
                            .foregroundStyle(.green)
                        Text("Los trabajadores están disponibles en el espacio clínico. El inventario y las atenciones se gestionan de forma independiente.")
                            .font(.footnote)
                        NavigationLink {
                            N2ClinicalWorkspaceGateView()
                        } label: {
                            Label("Abrir espacio clínico con el padrón importado",
                                  systemImage:"person.crop.rectangle.stack")
                                .font(.subheadline.weight(.semibold))
                                .frame(maxWidth:.infinity,minHeight:48)
                        }
                        .buttonStyle(DanperPrimaryButton())
                        .accessibilityIdentifier("open-imported-clinical-workspace")
                    }
                }
                Text(message).font(.footnote)
                    .foregroundStyle(failed ? Color.orange : Color.secondary)
                    .fixedSize(horizontal:false,vertical:true)
            }
            .padding(16)
        }
        .navigationTitle("Importar PERSONAL")
        .navigationBarTitleDisplayMode(.inline)
        .danperFormChrome()
        .fileImporter(isPresented:$choosing,
                      allowedContentTypes:[UTType(filenameExtension:"xlsx") ?? .data],
                      allowsMultipleSelection:false) { result in
            switch result {
            case .success(let urls):
                if let first=urls.first {Task {await readFile(first)}}
            case .failure:
                failed=true
                message="No se pudo abrir el archivo seleccionado. No se guardó ningún registro."
            }
        }
        .confirmationDialog("Confirmar importación REAL",
                            isPresented:$confirm,titleVisibility:.visible) {
            Button("Sí, importar PERSONAL") {Task {await save()}}
            Button("Cancelar",role:.cancel) {}
        } message: {
            Text(current==nil ?
                "Se creará la primera fuente clínica cifrada, únicamente con los trabajadores del Excel. No se usarán registros ficticios." :
                "Se actualizará el padrón oficial sin borrar atenciones, borradores, alergias, consumos ni lotes históricos.")
        }
        .onChange(of:site) {_,_ in
            comparison=nil
            failed=false
            if siteIsVerified {Task {await review()}}
        }
        .opacity(scenePhase == .active ? 1 : 0)
        .accessibilityHidden(scenePhase != .active)
        .onChange(of:scenePhase) {_,phase in
            if phase == .background {
                authenticated=false
                preview=nil
                comparison=nil
                fileName=""
                choosing=false
            }
        }
    }

    @MainActor private func authenticate() async {
        guard !busy,scenePhase == .active else{return}
        busy=true
        defer{busy=false}
        do {
            let context=LAContext()
            authenticated=try await context.evaluatePolicy(
                .deviceOwnerAuthentication,
                localizedReason:"Revisar e importar el padrón clínico PERSONAL")
            failed = !authenticated
            if authenticated {
                message="Identidad comprobada. Selecciona la sede y el Excel."
                current=try await N2ProtectedClinicalIOSVault.shared.inspect()
            }
        } catch {
            authenticated=false
            failed=true
            message="Acceso no autorizado. No se leyó ni guardó PERSONAL."
        }
    }

    @MainActor private func readFile(_ url:URL) async {
        guard authenticated,!busy,scenePhase == .active else{return}
        busy=true;failed=false;imported=false
        preview=nil;comparison=nil;fileName=""
        message="Analizando la hoja PERSONAL localmente…"
        let scoped=url.startAccessingSecurityScopedResource()
        defer {if scoped {url.stopAccessingSecurityScopedResource()};busy=false}
        do {
            let result=try await Task.detached(priority:.userInitiated) {
                try N2PersonalWorkbookReader.read(url:url)
            }.value
            guard authenticated,scenePhase == .active else{return}
            fileName=url.lastPathComponent
            site="" // Each new PERSONAL workbook requires a fresh explicit site choice.
            preview=result
            message=result.stats.canConfirm ?
                "Lectura completa. Comprueba los recuentos y confirma." :
                "Se encontraron filas inválidas o diferencias dentro del Excel. No se realizó la importación."
            if result.stats.canConfirm {
                message="Lectura completa. Elige cómo clasificar las sedes y revisa el padrón antes de importar."
            } else {
                failed=true
            }
        } catch {
            failed=true
            message="No se pudo interpretar PERSONAL: \(description(error)). La bóveda clínica se mantiene intacta."
        }
    }

    @MainActor private func review() async {
        guard authenticated,let preview,preview.stats.canConfirm,
              siteIsVerified else{return}
        do {
            let live=try await N2ProtectedClinicalIOSVault.shared.inspect()
            current=live
            if live != nil {
                comparison=try await N2ProtectedClinicalIOSVault.shared
                    .previewPersonalMerge(preview,site:site)
            } else {comparison=nil}
            failed=false
        } catch {
            comparison=nil
            failed=true
            message="Conflicto con trabajadores existentes o fuente no disponible. Verifica nombres, sexo y sede; no se modificó ningún registro."
        }
    }

    @MainActor private func save() async {
        guard canImport,let preview else{return}
        busy=true
        defer {busy=false}
        do {
            let after:N2ProtectedStoreSummary
            if let current {
                _=try await N2ProtectedClinicalIOSVault.shared.mergePersonal(
                    preview,site:site,expectedRevision:current.revision)
                guard let checked=try await N2ProtectedClinicalIOSVault.shared.inspect()
                else {throw N2PersonalImportError.invalidFile}
                after=checked
            } else {
                after=try await N2ProtectedClinicalIOSVault.shared.activateInitialPersonal(
                    preview,site:site,approvedByUser:true)
            }
            guard after.workers>=preview.workers.count else {
                throw N2PersonalImportError.invalidFile
            }
            current=after
            imported=true
            failed=false
            self.preview=nil
            comparison=nil
            message="Padrón PERSONAL guardado en la bóveda clínica. Trabajadores registrados: \(after.workers)."
        } catch {
            imported=false
            failed=true
            message="No se pudo confirmar PERSONAL: \(description(error)). Se conservó la fuente previa. Revisa de nuevo antes de importar."
        }
    }

    private func description(_ error:Error)->String {
        if let problem=error as? N2PersonalImportError {
            switch problem {
            case .missingPersonal:return "falta la hoja PERSONAL"
            case .invalidHeaders:return "faltan encabezados DNI o NOMBRES"
            case .tooLarge:return "archivo o hoja demasiado grande"
            case .noValidWorkers:return "no hay DNI válidos"
            case .needsReview:return "hay datos contradictorios"
            case .invalidXML:return "estructura XML no válida"
            case .invalidFile:return "archivo Excel incompatible"
            case .staleRevision:return "la base cambió"
            case .sourceNotEmpty:return "la base ya contiene registros"
            }
        }
        return "comprueba el archivo o la revisión del padrón"
    }
}
