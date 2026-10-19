import Foundation
import SwiftUI
import UIKit
import LocalAuthentication
import DanperCore

/// Exports only authenticated ciphertext from the independent N2 clinical vault.
/// No plaintext, patient names or identifiers are written to the shared folder.
private struct N2SecureBackupShare: Identifiable {
    let id=UUID()
    let url:URL
}
private struct N2SecureBackupActivity: UIViewControllerRepresentable {
    let file:URL
    func makeUIViewController(context:Context)->UIActivityViewController {
        UIActivityViewController(activityItems:[file],applicationActivities:nil)
    }
    func updateUIViewController(_ controller:UIActivityViewController,context:Context) {}
}

struct N2NativeBackupExportView:View {
    @Environment(\.n2WorkspaceVault) private var vault
    @State private var password=""
    @State private var confirmation=""
    @State private var summary:N2ProtectedStoreSummary?
    @State private var status="Verificando el respaldo clínico nativo…"
    @State private var busy=false
    @State private var failed=false
    @State private var share:N2SecureBackupShare?
    @State private var temporaryDirectory:URL?

    private var valid:Bool {
        !busy && summary != nil &&
        (14...200).contains(password.count) &&
        !password.contains("\0") && password==confirmation
    }

    var body:some View {
        ScrollView {
          VStack(alignment:.leading,spacing:16) {
            DanperPanel("Respaldo cifrado") {
                Label(vault.isClinical ? "Datos protegidos de la bóveda CLÍNICA" :
                      "Datos protegidos del modo de prueba",
                      systemImage:"lock.shield.fill")
                    .font(.headline)
                if let summary {
                    LabeledContent("Revisión",value:String(summary.revision))
                    LabeledContent("Trabajadores",value:String(summary.workers))
                    LabeledContent("Atenciones",value:String(summary.attentions))
                    LabeledContent("Movimientos físicos",value:String(summary.physicalMovements))
                }else{
                    Text("Primero debe existir una fuente original, única y verificada en la bóveda N2.")
                        .font(.footnote)
                }
                Text("El respaldo se cifra con AES-256-GCM y una clave derivada de tu contraseña. No accede a la app híbrida instalada.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            DanperPanel("Protección del archivo") {
                DanperField(title:"Nueva contraseña (mínimo 14 caracteres)") {
                    SecureField("Nueva contraseña (mínimo 14 caracteres)",text:$password)
                    .textContentType(.newPassword)
                }
                DanperField(title:"Repetir contraseña") {
                    SecureField("Repetir contraseña",text:$confirmation)
                    .textContentType(.newPassword)
                }
                Text("No se almacena tu contraseña. Sin ella no podrás restaurar el archivo. Se solicitará Face ID o código antes de exportar.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            DanperPanel("Generar y compartir") {
                Button {
                    Task {await exportProtected()}
                } label:{
                    Label(busy ? "Verificando…" : "Crear respaldo cifrado y compartir",
                          systemImage:"square.and.arrow.up.on.square")
                }
                .buttonStyle(DanperPrimaryButton()).disabled(!valid)
                Text(status).font(.footnote)
                    .foregroundStyle(failed ? Color.red : Color.secondary)
                Text("El archivo temporal contiene solo datos cifrados. Se elimina de esta carpeta al cerrar Compartir; una copia que guardes en Archivos queda bajo tu control.")
                    .font(.caption).foregroundStyle(.secondary)
            }
          }.padding(16)
        }
        .navigationTitle("Respaldo cifrado")
        .danperFormChrome()
        .sheet(item:$share,onDismiss:clearTemporary){share in
            N2SecureBackupActivity(file:share.url)
        }
        .task {
            do {
                summary=try await vault.inspect()
                status=summary == nil
                    ? "No existe una bóveda activa para esta fuente. No se ha creado ningún respaldo."
                    : "Bóveda verificada. Puedes generar una copia cifrada."
            }catch {
                summary=nil
                failed=true
                status="No se pudo verificar la bóveda. Exportación bloqueada."
            }
        }
        .onDisappear {
            password=""
            confirmation=""
            if share == nil {clearTemporary()}
        }
    }

    @MainActor
    private func exportProtected() async {
        guard valid else{return}
        busy=true
        failed=false
        status="Confirmando identidad y cifrando respaldo…"
        defer {
            busy=false
            password=""
            confirmation=""
        }
        do {
            let identity=LAContext()
            let accepted=try await identity.evaluatePolicy(
                .deviceOwnerAuthentication,
                localizedReason:"Autorizar exportación cifrada de la historia clínica DANPER N2")
            guard accepted else {
                status="No se autorizó exportar los registros."
                failed=true
                return
            }
            let bytes=try await vault
                .exportPortableEncryptedBackup(password:password)
            clearTemporary()
            let folder=FileManager.default.temporaryDirectory
                .appendingPathComponent((vault.isClinical ? "danper-n2-clinical-encrypted-share-" :
                                           "danper-n2-demo-encrypted-share-")+UUID().uuidString,
                                        isDirectory:true)
            try FileManager.default.createDirectory(at:folder,
                withIntermediateDirectories:true,
                attributes:[.protectionKey:FileProtectionType.complete])
            temporaryDirectory=folder
            let fmt=DateFormatter()
            fmt.dateFormat="yyyyMMdd-HHmmss"
            fmt.timeZone=TimeZone(identifier:"America/Lima")
            let prefix=vault.isClinical ? "DANPER_N2_CLINICA_CIFRADO_" :
                                          "DANPER_N2_DEMO_CIFRADO_"
            let backupFilename="\(prefix)\(fmt.string(from:Date())).danperbackup"
            let destination=folder.appendingPathComponent(backupFilename)
            try bytes.write(to:destination,options:[.atomic,.completeFileProtection])
            status="Respaldo cifrado verificado. Abriendo Compartir…"
            share=N2SecureBackupShare(url:destination)
        }catch {
            clearTemporary()
            failed=true
            status="No se exportó: fallo de autenticación, contraseña o verificación. No se modificó la bóveda."
        }
    }

    @MainActor
    private func clearTemporary() {
        if let folder=temporaryDirectory {
            try? FileManager.default.removeItem(at:folder)
        }
        temporaryDirectory=nil
    }
}

