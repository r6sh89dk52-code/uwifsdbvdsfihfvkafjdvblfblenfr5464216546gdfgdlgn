import SwiftUI
import PhotosUI
import Vision
import VisionKit
import ImageIO
import UniformTypeIdentifiers
import DanperCore

/// Módulo N4: sólo se monta al abrir este destino. No cambia las cuatro pestañas.
struct DMModuleView:View {
    @Environment(\.n2WorkspaceVault) private var clinical
    @State private var snapshot=DMPersisted()
    @State private var receiptDate=Date()
    @State private var certificate=DMCertificate()
    @State private var selectedPhoto:PhotosPickerItem?
    @State private var showCamera=false
    @State private var review=false
    @State private var busy=false
    @State private var message=""
    @State private var nameSource=""
    @State private var showTemplate=false
    @State private var exportFile:URL?
    @State private var selectedFollowup:UUID?
    @State private var notificationApproved=false

    var body:some View {
        ScrollView {
            VStack(alignment:.leading,spacing:16) {
                DanperPanel {
                    Text("DESCANSOS MÉDICOS")
                        .font(.caption.weight(.bold)).foregroundStyle(DanperStyle.red)
                    Text("Recepción y reincorporaciones")
                        .font(.title2.weight(.bold))
                    Text("Los documentos se procesan en el iPhone y no se guardan fotos.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                HStack(spacing:10) {
                    summary("Registrados",snapshot.ledger.certificates.count)
                    summary("Pendientes",snapshot.ledger.active.count)
                    summary("Requieren alta",snapshot.ledger.requiringClearance().count)
                }
                DanperPanel("Registrar un documento") {
                    DatePicker("Recepción física",selection:$receiptDate,displayedComponents:.date)
                        .datePickerStyle(.compact)
                        .accessibilityIdentifier("dm-receipt-date")
                    Text("Esta fecha es la columna F del Excel; no es la fecha de emisión ni de incapacidad.")
                        .font(.caption).foregroundStyle(.secondary)
                    PhotosPicker(selection:$selectedPhoto,matching:.images,
                                 photoLibrary:.shared()) {
                        Label("Importar foto desde galería",systemImage:"photo.on.rectangle")
                    }
                    .buttonStyle(DanperPrimaryButton())
                    .accessibilityIdentifier("dm-import-photo")
                    Button {
                        showCamera=true
                    } label: {
                        Label("Escanear con cámara",systemImage:"doc.viewfinder")
                    }
                    .buttonStyle(DanperSecondaryButton())
                    .disabled(!VNDocumentCameraViewController.isSupported)
                    Button {
                        certificate=DMCertificate()
                        certificate.receiptDate=DMDate.iso(receiptDate)
                        nameSource=""
                        review=true
                    } label: {
                        Label("Registrar sin foto",systemImage:"square.and.pencil")
                    }
                    .buttonStyle(DanperSecondaryButton())
                    Text("En Simulator se utiliza «Importar foto» o «Registrar sin foto». La cámara física se prueba después en iPhone.")
                        .font(.caption2).foregroundStyle(.secondary)
                }
                DanperPanel("Seguimiento") {
                    if snapshot.ledger.certificates.isEmpty {
                        Text("Todavía no se han registrado descansos.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(snapshot.ledger.certificates.sorted(by:{$0.createdAt>$1.createdAt})) { item in
                            VStack(alignment:.leading,spacing:8) {
                                HStack {
                                    VStack(alignment:.leading,spacing:3) {
                                        Text(item.name).font(.headline)
                                        Text("DNI: \(item.dni) · \(item.startDate) al \(item.endDate)")
                                            .font(.caption).foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    if item.needsClearance && !item.clearanceVerified {
                                        Image(systemName:"exclamationmark.shield")
                                            .foregroundStyle(.orange)
                                    }
                                }
                                Text("Retorno previsto: \(item.expectedReturn ?? "Sin fecha")")
                                    .font(.subheadline)
                                if item.state == .returned {
                                    Label("Reincorporación verificada",systemImage:"checkmark.seal")
                                        .foregroundStyle(.green)
                                } else {
                                    Button("Abrir checklist y verificar reincorporación") {
                                        selectedFollowup=item.id
                                    }
                                    .buttonStyle(DanperSecondaryButton())
                                }
                            }
                            .padding(.vertical,5)
                            Divider()
                        }
                    }
                }
                DanperPanel("Indicador Excel · 7 hojas") {
                    Text("Utiliza tu archivo .xlsx como plantilla y rellena únicamente filas vacías del indicador DM2026.")
                        .font(.footnote).foregroundStyle(.secondary)
                    Button {
                        showTemplate=true
                    } label: {
                        Label("Elegir Excel original y generar",systemImage:"tablecells")
                    }
                    .buttonStyle(DanperSecondaryButton())
                    .disabled(busy || snapshot.ledger.certificates.isEmpty)
                    if let exportFile {
                        ShareLink(item:exportFile) {
                            Label("Compartir Excel generado",systemImage:"square.and.arrow.up")
                        }
                    }
                    Text("Google Drive: conexión automática pendiente de autorización OAuth y configuración del servicio de sincronización. No se enviarán datos sin conexión autorizada.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                DanperPanel("Notificaciones") {
                    Button("Autorizar avisos de reincorporación") {
                        Task {
                            notificationApproved=await DMReturnNotifications.requestPermission()
                            if notificationApproved {
                                for c in snapshot.ledger.active {await DMReturnNotifications.update(c)}
                            }
                        }
                    }
                    .buttonStyle(DanperSecondaryButton())
                    Text("Las alertas no muestran nombres, DNI ni diagnósticos en la pantalla bloqueada.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                if !message.isEmpty {
                    Text(message).font(.footnote).foregroundStyle(.secondary)
                        .accessibilityIdentifier("dm-status")
                }
            }.padding(16)
        }
        .navigationTitle("Descansos médicos")
        .danperFormChrome()
        .task {await refresh()}
        .onChange(of:selectedPhoto) {_,new in
            guard let new else{return}
            Task {
                defer{selectedPhoto=nil}
                if let data=try? await new.loadTransferable(type:Data.self) {
                    await recognize(data)
                } else {message="No se pudo leer la imagen seleccionada."}
            }
        }
        .sheet(isPresented:$showCamera) {
            DMCameraSheet { images in
                showCamera=false
                Task {
                    // Un CITT por captura: todas sus páginas se leen juntas, sin archivos.
                    if !images.isEmpty {await recognizePages(images)}
                }
            }
        }
        .sheet(isPresented:$review) {
            NavigationStack {
                Form {
                    Section("Datos del certificado") {
                        TextField("DNI (8 dígitos)",text:$certificate.dni)
                            .keyboardType(.numberPad)
                        TextField("Apellidos y nombres",text:$certificate.name)
                        TextField("Número de CITT",text:$certificate.certificateNumber)
                        TextField("Inicio (AAAA-MM-DD)",text:$certificate.startDate)
                        TextField("Fin (AAAA-MM-DD)",text:$certificate.endDate)
                        TextField("Días del documento",text:Binding(
                            get:{certificate.documentDays.map(String.init) ?? ""},
                            set:{certificate.documentDays=Int($0)}))
                            .keyboardType(.numberPad)
                        TextField("Fecha de otorgamiento",text:$certificate.issuedDate)
                        TextField("Entidad",text:$certificate.issuer)
                        TextField("Contingencia",text:$certificate.contingency)
                        TextField("Diagnóstico (solo si consta)",text:$certificate.diagnosis)
                        TextField("CMP",text:$certificate.cmp)
                        if !nameSource.isEmpty {
                            Text(nameSource).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    Section("Reincorporación") {
                        Picker("Hospitalización confirmada",selection:$certificate.hospitalization) {
                            ForEach(DMHospitalization.allCases,id:\.self) {s in
                                Text(s.rawValue).tag(s)
                            }
                        }
                        if certificate.needsClearance {
                            Label("Debe verificarse alta médica antes del retorno",
                                  systemImage:"exclamationmark.triangle")
                                .foregroundStyle(.orange)
                        }
                        if certificate.discrepancy {
                            Label("Los días declarados no coinciden con las fechas",
                                  systemImage:"exclamationmark.triangle")
                                .foregroundStyle(.red)
                        }
                        Text("Días calculados: \(certificate.calculatedDays.map(String.init) ?? "—")")
                        Text("Recepción: \(DMDate.iso(receiptDate))")
                    }
                    Section {
                        Button("Confirmar y guardar") {Task{await saveRecord()}}
                            .disabled(busy || !canSave)
                            .accessibilityIdentifier("dm-save-certificate")
                    }
                }
                .navigationTitle("Verificar CITT")
                .toolbar {ToolbarItem(placement:.topBarTrailing){
                    Button("Cancelar"){review=false}
                }}
            }
        }
        .sheet(item:Binding<DMSelectedFollowup?>(
            get:{selectedFollowup.map{DMSelectedFollowup(id:$0)}},
            set:{selectedFollowup=$0?.id})) {selection in
            if let item=snapshot.ledger.certificates.first(where:{$0.id==selection.id}) {
                DMFollowupSheet(record:item) {updated in
                    Task {await updateRecord(updated)}
                }
            }
        }
        .fileImporter(isPresented:$showTemplate,
                      allowedContentTypes:[UTType(filenameExtension:"xlsx") ?? .data]) {result in
            guard case .success(let source)=result else {return}
            Task {await export(template:source)}
        }
    }
    private var canSave:Bool {
        var copy=certificate
        copy.receiptDate=DMDate.iso(receiptDate)
        return copy.isValid
    }
    private func summary(_ name:String,_ count:Int)->some View {
        VStack(spacing:5) {
            Text(String(count)).font(.headline.monospacedDigit())
            Text(name).font(.caption2).multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth:.infinity,minHeight:58)
        .padding(6).background(DanperStyle.surface,in:RoundedRectangle(cornerRadius:12))
    }
    @MainActor private func refresh() async {
        do {snapshot=try await DMEncryptedStore.shared.read()}
        catch {message="La bóveda DM no se pudo descifrar. No se ha modificado ningún dato."}
    }
    @MainActor private func recognize(_ data:Data) async {
        await recognizePages([data])
    }
    @MainActor private func recognizePages(_ pages:[Data]) async {
        guard !busy,!pages.isEmpty,pages.count<=10 else{return}
        busy=true;defer{busy=false}
        do {
            var fragments=[String]()
            for data in pages {fragments.append(try await DMOCRService.recognize(data))}
            let text=fragments.joined(separator:"\n")
            var draft=DMCITTParser.parse(text)
            draft.receiptDate=DMDate.iso(receiptDate)
            if !draft.dni.isEmpty,
               let roster=try? await clinical.readHistory(),
               let worker=roster.searchableRoster.first(where:{$0.dni==draft.dni}) {
                draft.name=worker.name;draft.site=worker.site
                draft.area=worker.area;draft.labor=worker.labor
                nameSource="Nombre y área sugeridos desde el padrón; verifica antes de guardar."
            } else {nameSource="Verifica el nombre y DNI manualmente."}
            certificate=draft
            review=true
            message="Texto reconocido. Revisa todos los campos antes de guardar."
        } catch {
            message="No se pudo reconocer la imagen; usa «Registrar sin foto»."
        }
    }
    @MainActor private func saveRecord() async {
        guard !busy else{return}
        busy=true;defer{busy=false}
        var c=certificate
        c.receiptDate=DMDate.iso(receiptDate)
        do {
            snapshot=try await DMEncryptedStore.shared.insert(c)
            await DMReturnNotifications.update(c)
            review=false
            message="Certificado registrado en bóveda cifrada. Pendiente de exportar/sincronizar."
        } catch DMError.duplicate {
            message="Este certificado ya está registrado. No se duplicó."
        } catch {
            message="No se pudo guardar; verifica fechas, DNI y días."
        }
    }
    @MainActor private func updateRecord(_ record:DMCertificate) async {
        do {
            snapshot=try await DMEncryptedStore.shared.replace(record)
            await DMReturnNotifications.update(record)
            selectedFollowup=nil
            message="Seguimiento actualizado y guardado."
        } catch DMError.clearanceRequired {
            message="No se puede confirmar retorno sin verificar el alta médica."
        } catch {
            message="No se pudo guardar el seguimiento."
        }
    }
    @MainActor private func export(template:URL) async {
        guard !busy else{return}
        busy=true;defer{busy=false}
        let accessed=template.startAccessingSecurityScopedResource()
        defer{if accessed{template.stopAccessingSecurityScopedResource()}}
        do {
            let target=FileManager.default.temporaryDirectory
                .appendingPathComponent("DANPER_DM_"+UUID().uuidString+".xlsx")
            let data=snapshot.ledger.certificates
            try await Task.detached(priority:.userInitiated) {
                try DMExcelWriter.export(template:template,records:data,destination:target)
            }.value
            exportFile=target
            message="Excel generado conservando las siete hojas y las filas históricas."
        } catch {
            message="No se exportó: verifica que elegiste el Excel original, tenga filas disponibles y los registros estén completos."
        }
    }
}

private struct DMSelectedFollowup:Identifiable {
    let id:UUID
}
private struct DMFollowupSheet:View {
    @Environment(\.dismiss) private var dismiss
    @State var record:DMCertificate
    let onSave:(DMCertificate)->Void
    var body:some View {
        NavigationStack {
            Form {
                Section("Seguimiento") {
                    Text(record.name)
                    Text("Retorno previsto: \(record.expectedReturn ?? "Pendiente")")
                    Toggle("Contactado / seguimiento realizado",isOn:$record.contactChecked)
                    Toggle("Comprobada posibilidad de ampliación",isOn:$record.extensionChecked)
                    Toggle("Revisión de salud ocupacional",isOn:$record.occupationalReviewChecked)
                    Toggle("Se verificó alta médica",isOn:$record.clearanceVerified)
                    if record.needsClearance && !record.clearanceVerified {
                        Text("No se permite confirmar retorno mientras falta el alta.")
                            .font(.caption).foregroundStyle(.orange)
                    }
                    Picker("Situación",selection:$record.state) {
                        ForEach(DMState.allCases,id:\.self){s in Text(s.rawValue).tag(s)}
                    }
                    if record.state == .returned {
                        TextField("Retorno efectivo (AAAA-MM-DD)",text:$record.returnedDate)
                        if record.returnedDate.isEmpty {
                            Text("Indica la fecha real, no la fecha prevista.")
                                .font(.caption)
                        }
                    }
                }
                Button("Guardar seguimiento") {
                    if record.state == .returned {
                        do {
                            let d=record.returnedDate
                            record.state = .pendingReturn
                            try record.markReturned(on:d)
                        } catch {return}
                    }
                    onSave(record);dismiss()
                }
                .disabled(record.state == .returned &&
                          ((!record.clearanceVerified && record.needsClearance) ||
                           DMDate.parse(record.returnedDate)==nil))
            }
            .navigationTitle("Reincorporación")
            .toolbar {ToolbarItem(placement:.topBarTrailing){
                Button("Cerrar"){dismiss()}
            }}
        }
    }
}

/// OCR totalmente local; retorna texto sólo a memoria volátil.
private enum DMOCRService {
    static func recognize(_ bytes:Data) async throws -> String {
        try await Task.detached(priority:.userInitiated) {
            guard !bytes.isEmpty,bytes.count<=25_000_000,
                  let source=CGImageSourceCreateWithData(bytes as CFData,nil),
                  let image=CGImageSourceCreateImageAtIndex(source,0,nil) else {
                throw DMStoreFailure.unavailable
            }
            let properties=CGImageSourceCopyPropertiesAtIndex(source,0,nil) as? [String:Any]
            let raw=(properties?[kCGImagePropertyOrientation as String] as? NSNumber)?.uint32Value ?? 1
            let orientation=CGImagePropertyOrientation(rawValue:raw) ?? .up
            let request=VNRecognizeTextRequest()
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            request.recognitionLanguages=["es-ES","en-US"]
            let handler=VNImageRequestHandler(cgImage:image,orientation:orientation,options:[:])
            try handler.perform([request])
            return (request.results ?? []).compactMap{$0.topCandidates(1).first?.string}
                .joined(separator:"\n")
        }.value
    }
}
private struct DMCameraSheet:UIViewControllerRepresentable {
    var onFinish:([Data])->Void
    func makeUIViewController(context:Context)->VNDocumentCameraViewController {
        let controller=VNDocumentCameraViewController()
        controller.delegate=context.coordinator
        return controller
    }
    func updateUIViewController(_ vc:VNDocumentCameraViewController,context:Context) {}
    func makeCoordinator()->Coordinator {Coordinator(parent:self)}
    final class Coordinator:NSObject,VNDocumentCameraViewControllerDelegate {
        let parent:DMCameraSheet
        init(parent:DMCameraSheet){self.parent=parent}
        func documentCameraViewController(_ controller:VNDocumentCameraViewController,
                                          didFinishWith scan:VNDocumentCameraScan) {
            var result:[Data]=[]
            for index in 0..<scan.pageCount {
                if let bytes=scan.imageOfPage(at:index).jpegData(compressionQuality:0.9) {
                    result.append(bytes)
                }
            }
            parent.onFinish(result)
        }
        func documentCameraViewControllerDidCancel(_ controller:VNDocumentCameraViewController) {
            parent.onFinish([])
        }
        func documentCameraViewController(_ controller:VNDocumentCameraViewController,
                                          didFailWithError error:Error) {
            parent.onFinish([])
        }
    }
}