import SwiftUI
import UniformTypeIdentifiers
import LocalAuthentication
import CryptoKit
import DanperCore

struct N2EncryptedBackupDocument:FileDocument {
    static var readableContentTypes:[UTType]{[.data]}
    var bytes:Data
    init(bytes:Data){self.bytes=bytes}
    init(configuration:ReadConfiguration)throws {
        guard let data=configuration.file.regularFileContents else{throw CocoaError(.fileReadCorruptFile)}
        bytes=data
    }
    func fileWrapper(configuration:WriteConfiguration)throws->FileWrapper {FileWrapper(regularFileWithContents:bytes)}
}
private func n2ReadBackup(_ url:URL) async throws->Data {
    try await N2WorkspaceFileIO.shared.readBackup(url)
}
struct N2SimpleMigrationSetup:View {
    let context:N2SimpleInventoryContext
    let onActivated:()->Void
    @Environment(\.n2WorkspaceVault) private var vault
    @Environment(\.scenePhase) private var scenePhase
    @State private var products=[N2SimpleProduct]()
    @State private var addProduct=false
    @State private var password=""
    @State private var confirmation=""
    @State private var responsible=""
    @State private var backupFilename="DANPER_ANTES_DEL_INVENTARIO_"+UUID().uuidString+".danperbackup"
    @State private var document:N2EncryptedBackupDocument?
    @State private var exportFile=false
    @State private var savedURL:URL?
    @State private var verified:N2SimpleBackupReview?
    @State private var status=""
    @State private var busy=false
    @State private var authorize=false
    @State private var regimeID=UUID().uuidString
    @State private var cycle=UUID()
    @State private var identity:LAContext?
    @State private var work:Task<Void,Never>?
    private var passwordValid:Bool {(14...200).contains(password.count) && !password.contains("\0") && password==confirmation}
    private var canActivate:Bool {!busy && verified != nil && savedURL != nil && !products.isEmpty && !responsible.isEmpty && passwordValid}
    var body:some View {
        VStack(alignment:.leading,spacing:16) {
            introduction
            counts
            backup
            activate
            if !status.isEmpty {Text(status).font(.footnote).foregroundStyle(.secondary).accessibilityIdentifier("simple-migration-status")}
        }
        .onAppear {if responsible.isEmpty {responsible=vault.isClinical ? N2ClinicianIdentity.name:"OPERADOR FICTICIO"}}
        .sheet(isPresented:$addProduct) {
            NavigationStack {N2SimpleProductEditor(context:context,operation:.register,product:nil,onInitial:{p in
                products.removeAll{$0.code==p.code};products.append(p)
            })}
        }
        .fileExporter(isPresented:$exportFile,document:document,contentType:.data,
            defaultFilename:backupFilename) {result in
            switch result {
            case .success(let url):work=Task {await verifySaved(url)}
            case .failure(let error):savedURL=nil;verified=nil;status=n2SimpleMessage(error)
            }
        }
        .confirmationDialog("Activar inventario por conteo físico",isPresented:$authorize,titleVisibility:.visible) {
            Button("Respaldé mis datos y autorizo el reinicio") {work=Task {await activateNow()}}
            Button("Cancelar",role:.cancel){}
        } message:{Text("Se conservarán las atenciones y los borradores. Los lotes, movimientos y pendientes anteriores dejarán de operar. Las nuevas existencias serán exactamente los conteos confirmados. El respaldo guardado no se sobrescribirá.")}
        .onChange(of:password) {_,_ in verified=nil}
        .onChange(of:scenePhase) {_,phase in if phase == .background {clearSecrets()}}
        .onDisappear {clearSecrets()}
    }
    private var introduction:some View {
        DanperPanel("Inventario por conteo físico") {
            Text("Una cantidad total por medicamento o insumo, sin selección de lotes ni seguimiento automático de envases.")
            Text("Se conservarán \(context.clinicalVisits) atenciones clínicas y los borradores válidos.")
                .font(.footnote).foregroundStyle(.secondary)
            Text("Antes de reiniciar, guarda y verifica una copia cifrada completa. La activación requiere tu autorización expresa.")
                .font(.footnote).foregroundStyle(.secondary)
        }
    }
    private var counts:some View {
        DanperPanel("1 · Conteo físico inicial") {
            TextField("Responsable del conteo",text:$responsible).accessibilityIdentifier("simple-migration-operator")
            ForEach(products) {p in
                HStack(alignment:.top) {
                    VStack(alignment:.leading) {
                        Text(p.name).font(.headline)
                        Text(p.quantity.formatted()+" "+(p.mode == .presentation ? "presentaciones":p.unit)).font(.subheadline)
                        Text(n2SimpleExpiry(p)).font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button(role:.destructive){products.removeAll{$0.code==p.code}} label:{Image(systemName:"trash")}
                        .accessibilityLabel("Retirar conteo de "+p.name)
                }
            }
            Button("Agregar medicamento o insumo al conteo") {addProduct=true}.accessibilityIdentifier("simple-migration-add")
            Text("Confirma al menos un producto. Lo que no cuentes permanecerá sin existencia verificada, no como un cero supuesto.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }
    private var backup:some View {
        DanperPanel("2 · Respaldo cifrado previo") {
            DanperField(title:"Contraseña nueva · mínimo 14 caracteres") {
                SecureField("Contraseña nueva",text:$password).textContentType(.newPassword)
                    .accessibilityIdentifier("simple-migration-password")
            }
            DanperField(title:"Repetir contraseña") {
                SecureField("Repetir contraseña",text:$confirmation).textContentType(.newPassword)
                    .accessibilityIdentifier("simple-migration-password-confirm")
            }
            Text("Guarda la contraseña por tu cuenta. No se incluye en el archivo ni se conserva en la app.")
                .font(.caption).foregroundStyle(.secondary)
            Button(busy ? "Verificando…":"Crear respaldo y guardar en Archivos") {work=Task {await createBackup()}}
                .buttonStyle(DanperSecondaryButton()).disabled(!passwordValid || busy)
                .accessibilityIdentifier("simple-migration-create-backup")
            if verified != nil {Label("Respaldo guardado, descifrado y verificado",systemImage:"checkmark.shield.fill").foregroundStyle(.green)}
        }
    }
    private var activate:some View {
        DanperPanel("3 · Inicio del inventario nuevo") {
            Text("El conteo de hoy será el saldo autoritativo. Los períodos anteriores que no puedan verificarse quedarán identificados como no verificables.")
                .font(.footnote).foregroundStyle(.secondary)
            Button {authorize=true} label:{Label("Activar con estos conteos",systemImage:"checkmark.shield")}
                .buttonStyle(DanperPrimaryButton()).disabled(!canActivate).accessibilityIdentifier("simple-migration-activate")
        }
    }
    @MainActor private func createBackup() async {
        guard passwordValid,!busy else{return};busy=true;defer{busy=false}
        let nonce=cycle
        do {
            let id=LAContext();identity=id
            let accepted=try await id.evaluatePolicy(.deviceOwnerAuthentication,localizedReason:"Proteger la historia clínica antes de iniciar el inventario por conteo físico")
            guard accepted,nonce==cycle else{throw CancellationError()}
            let data=try await vault.exportPortableEncryptedBackup(password:password)
            guard nonce==cycle else{throw CancellationError()}
            backupFilename="DANPER_ANTES_DEL_INVENTARIO_"+UUID().uuidString+".danperbackup"
            document=N2EncryptedBackupDocument(bytes:data);savedURL=nil;verified=nil;exportFile=true
            status="Guarda la copia cifrada en un destino que puedas recuperar."
        }catch {status=n2SimpleMessage(error)}
        identity=nil
    }
    @MainActor private func verifySaved(_ url:URL) async {
        busy=true;defer{busy=false};let nonce=cycle
        do {
            let data=try await n2ReadBackup(url)
            let result=try await vault.inspectSimpleBackup(data,password:password)
            guard nonce==cycle else{throw CancellationError()}
            savedURL=url;verified=result;status="Respaldo disponible y verificado. Revisa los conteos antes de autorizar."
        }catch {savedURL=nil;verified=nil;status=n2SimpleMessage(error)}
    }
    @MainActor private func activateNow() async {
        guard canActivate,let url=savedURL else{return};busy=true;defer{busy=false};let nonce=cycle
        do {
            let id=LAContext();identity=id
            let accepted=try await id.evaluatePolicy(.deviceOwnerAuthentication,localizedReason:"Autorizar el inventario nuevo conservando la historia clínica")
            guard accepted,nonce==cycle else{throw CancellationError()}
            // Read the saved destination again. An unavailable/deleted/changed
            // archive never authorizes the reset, even if export once succeeded.
            let archive=try await n2ReadBackup(url)
            guard SHA256.hash(data:archive).map({String(format:"%02x",$0)}).joined()==verified?.archiveSHA256 else {
                throw N2SimpleInventoryError.sourceChanged
            }
            let request=N2SimpleActivation(id:regimeID,at:Int64(Date().timeIntervalSince1970*1000),
                operatorName:responsible,confirmed:true,backupAvailable:true,initialProducts:products)
            _=try await vault.activateSimpleInventory(archive:archive,password:password,request:request,expectedRevision:context.revision)
            guard nonce==cycle else{throw CancellationError()}
            password="";confirmation="";status="Inventario nuevo verificado. Historia clínica conservada."
            onActivated()
        }catch {status=n2SimpleMessage(error)}
        identity=nil
    }
    private func clearSecrets() {
        cycle=UUID();identity?.invalidate();identity=nil;work?.cancel();work=nil
        password="";confirmation="";verified=nil;savedURL=nil;document=nil
    }
}

struct N2SimpleRestoreView:View {
    enum Kind {case clinical,complete}
    let kind:Kind
    var onRestored:()->Void={}
    @Environment(\.n2WorkspaceVault) private var vault
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dismiss) private var dismiss
    @State private var file:URL?
    @State private var chooseFile=false
    @State private var password=""
    @State private var review:N2SimpleBackupReview?
    @State private var revision:Int?
    @State private var responsible=""
    @State private var busy=false
    @State private var confirm=false
    @State private var status=""
    @State private var done=false
    @State private var eventID=UUID().uuidString
    @State private var cycle=UUID()
    @State private var identity:LAContext?
    @State private var work:Task<Void,Never>?
    var body:some View {
        ScrollView {
            VStack(alignment:.leading,spacing:16) {
                DanperPanel(kind == .clinical ? "Restauración clínica selectiva":"Recuperación completa") {
                    Text(kind == .clinical
                        ? "Recupera trabajadores, atenciones y antecedentes sin sustituir las existencias ni reactivar movimientos del inventario anterior."
                        : "Recupera una fuente completa únicamente en una base vacía. Una fuente o inventario ya existente no se sobrescribirá.")
                    Text("El archivo original permanece intacto. La contraseña nunca se almacena.").font(.caption).foregroundStyle(.secondary)
                }
                if done {success}else{form}
                if !status.isEmpty {Text(status).font(.footnote).foregroundStyle(.secondary).accessibilityIdentifier("simple-restore-status")}
            }.padding(16)
        }.navigationTitle(kind == .clinical ? "Restaurar historial":"Recuperación completa")
            .navigationBarTitleDisplayMode(.inline).danperFormChrome()
            .fileImporter(isPresented:$chooseFile,allowedContentTypes:[.data,.item]) {result in
                switch result {
                case .success(let url):file=url;review=nil;status="Archivo seleccionado. Introduce su contraseña para verificarlo."
                case .failure(let error):status=n2SimpleMessage(error)
                }
            }
            .confirmationDialog(kind == .clinical ? "Conservar inventario y restaurar clínica":"Recuperar en fuente vacía",
                isPresented:$confirm,titleVisibility:.visible) {
                    Button(kind == .clinical ? "Restaurar solo historia clínica":"Restaurar fuente completa") {work=Task {await restore()}}
                    Button("Cancelar",role:.cancel){}
                } message:{Text(kind == .clinical ? "No se importarán lotes, saldos FEFO ni conciliaciones pendientes anteriores. Los registros repetidos no se duplicarán; un conflicto no se sobrescribirá.":"Si ya existe una fuente, la recuperación completa se bloqueará. Para conservar inventario usa la restauración clínica selectiva.")}
            .task {
                responsible=vault.isClinical ? N2ClinicianIdentity.name:"OPERADOR FICTICIO"
                if kind == .clinical {
                    do {
                        let context=try await vault.simpleInventoryContext()
                        guard context.state != nil else{throw N2SimpleInventoryError.unsupportedSchema}
                        revision=context.revision
                    }catch {status="Activa primero el inventario por conteo físico para conservarlo durante esta restauración."}
                }
            }
            .onChange(of:password){_,_ in review=nil}
            .onChange(of:scenePhase){_,phase in if phase == .background {clearSecrets()}}
            .onDisappear{clearSecrets()}
    }
    private var form:some View {
        DanperPanel("Archivo cifrado") {
            Button(file == nil ? "Elegir respaldo cifrado":"Cambiar respaldo") {chooseFile=true}
                .accessibilityIdentifier("simple-restore-file")
            SecureField("Contraseña del respaldo",text:$password).textContentType(.password)
                .accessibilityIdentifier("simple-restore-password")
            TextField("Responsable",text:$responsible).accessibilityIdentifier("simple-restore-operator")
            Button(busy ? "Verificando…":"Verificar respaldo") {work=Task {await inspect()}}
                .buttonStyle(DanperSecondaryButton()).disabled(file==nil || password.count<14 || busy)
                .accessibilityIdentifier("simple-restore-verify")
            if let review {
                LabeledContent("Trabajadores",value:String(review.workers))
                LabeledContent("Atenciones",value:String(review.attentions))
                Text("Contraseña, cifrado y estructura verificados.").font(.caption).foregroundStyle(.green)
            }
            Button {confirm=true} label:{Label(kind == .clinical ? "Restaurar historial sin reemplazar inventario":"Recuperar fuente completa",systemImage:"arrow.clockwise")}
                .buttonStyle(DanperPrimaryButton()).disabled(review==nil || busy || responsible.isEmpty || (kind == .clinical && revision==nil))
                .accessibilityIdentifier("simple-restore-apply")
        }
    }
    private var success:some View {
        DanperPanel {
            Label("Restauración verificada",systemImage:"checkmark.shield.fill").font(.headline).foregroundStyle(.green)
            Text(kind == .clinical ? "La historia clínica está disponible y el inventario se conservó.":"La fuente completa está disponible.")
            Button("Continuar") {onRestored();dismiss()}.buttonStyle(DanperPrimaryButton())
        }
    }
    @MainActor private func inspect() async {
        guard let file,!busy else{return};busy=true;defer{busy=false};let nonce=cycle
        do {
            let result=try await vault.inspectSimpleBackup(try await n2ReadBackup(file),password:password)
            guard nonce==cycle else{throw CancellationError()}
            review=result;status="Revisa el alcance antes de confirmar."
        }catch {review=nil;status=n2SimpleMessage(error)}
    }
    @MainActor private func restore() async {
        guard let file,review != nil,!busy else{return};busy=true;defer{busy=false};let nonce=cycle
        do {
            let id=LAContext();identity=id
            let accepted=try await id.evaluatePolicy(.deviceOwnerAuthentication,localizedReason:"Autorizar restauración cifrada de DANPER")
            guard accepted,nonce==cycle else{throw CancellationError()}
            let archive=try await n2ReadBackup(file)
            guard SHA256.hash(data:archive).map({String(format:"%02x",$0)}).joined()==review?.archiveSHA256 else {
                throw N2SimpleInventoryError.sourceChanged
            }
            if kind == .clinical {
                guard let revision else{throw N2SimpleInventoryError.unsupportedSchema}
                _=try await vault.restoreSimpleClinical(archive:archive,password:password,eventID:eventID,
                    operatorName:responsible,at:Int64(Date().timeIntervalSince1970*1000),confirmed:true,expectedRevision:revision)
            }else {
                _=try await vault.recoverPortableSource(archive:archive,password:password,confirmed:true)
            }
            guard nonce==cycle else{throw CancellationError()}
            password="";review=nil;done=true;status=""
        }catch {status=n2SimpleMessage(error)}
        identity=nil
    }
    private func clearSecrets() {
        cycle=UUID();identity?.invalidate();identity=nil;work?.cancel();work=nil;password="";review=nil
    }
}
