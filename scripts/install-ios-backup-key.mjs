import {readFileSync,writeFileSync} from 'node:fs';
export const MARKER='// DANPER_DEVICE_BACKUP_KEY_V0204';
const SWIFT = String.raw`

// DANPER_DEVICE_BACKUP_KEY_V0204
// Device-only Keychain item, requires iOS authentication before every backup
// or recovery. A key bound this way cannot be restored on a new iPhone.
private var danperBackupPluginRegistered = false
extension AppDelegate {
    fileprivate func danperRegisterBackupPlugin(in window: UIWindow) {
        guard !danperBackupPluginRegistered,
              let root = window.rootViewController as? CAPBridgeViewController,
              let bridge = root.bridge else { return }
        bridge.registerPluginInstance(DanperBackupKeyPlugin())
        danperBackupPluginRegistered = true
    }
}

@objc(DanperBackupKeyPlugin)
public class DanperBackupKeyPlugin: CAPPlugin, CAPBridgedPlugin {
    public let identifier = "DanperBackupKeyPlugin"
    public let jsName = "DanperBackupKey"
    public let pluginMethods: [CAPPluginMethod] = [
        CAPPluginMethod(name: "getKey", returnType: CAPPluginReturnPromise)
    ]
    private let service = "com.danper.salud.backup.device.v2"
    private let account = "device-bound-aes256"

    @objc public func getKey(_ call: CAPPluginCall) {
        let allowCreate = call.getBool("create") ?? false
        let context = LAContext()
        context.localizedFallbackTitle = "Usar código del iPhone"
        var availabilityError: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &availabilityError) else {
            call.reject("Para usar el respaldo biométrico configura un código de desbloqueo en el iPhone.")
            return
        }
        context.evaluatePolicy(.deviceOwnerAuthentication,
            localizedReason: "Autoriza el respaldo o restauración local de DANPER Salud Móvil") { [weak self] success, _ in
            guard let self = self else {
                call.reject("No se pudo verificar el acceso al respaldo.")
                return
            }
            guard success else {
                call.reject("Face ID o código cancelado o incorrecto. No se cambió ningún registro.")
                return
            }
            DispatchQueue.global(qos: .userInitiated).async {
                var query: [String: Any] = [
                    kSecClass as String: kSecClassGenericPassword,
                    kSecAttrService as String: self.service,
                    kSecAttrAccount as String: self.account,
                    kSecReturnData as String: true,
                    kSecMatchLimit as String: kSecMatchLimitOne,
                    kSecUseAuthenticationContext as String: context
                ]
                var result: CFTypeRef?
                var status = SecItemCopyMatching(query as CFDictionary, &result)
                if status == errSecItemNotFound && allowCreate {
                    var randomKey = [UInt8](repeating: 0, count: 32)
                    let generated = randomKey.withUnsafeMutableBytes { buffer in
                        SecRandomCopyBytes(kSecRandomDefault, buffer.count, buffer.baseAddress!)
                    }
                    guard generated == errSecSuccess else {
                        call.reject("No se pudo generar una clave cifrada de respaldo.")
                        return
                    }
                    var accessError: Unmanaged<CFError>?
                    guard let acl = SecAccessControlCreateWithFlags(nil,
                        kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly, .userPresence, &accessError) else {
                        call.reject("No se pudo proteger la clave con Face ID o código.")
                        return
                    }
                    let attributes: [String: Any] = [
                        kSecClass as String: kSecClassGenericPassword,
                        kSecAttrService as String: self.service,
                        kSecAttrAccount as String: self.account,
                        kSecAttrAccessControl as String: acl,
                        kSecValueData as String: Data(randomKey)
                    ]
                    let created = SecItemAdd(attributes as CFDictionary, nil)
                    guard created == errSecSuccess || created == errSecDuplicateItem else {
                        call.reject("Keychain no permitió guardar la clave local protegida.")
                        return
                    }
                    randomKey = [UInt8](repeating: 0, count: 32)
                    result = nil
                    status = SecItemCopyMatching(query as CFDictionary, &result)
                }
                guard status == errSecSuccess, let key = result as? Data, key.count == 32 else {
                    call.reject(allowCreate
                        ? "No fue posible desbloquear la clave local con iOS."
                        : "La clave del respaldo ya no existe en este iPhone. No puede restaurarse sin ella.")
                    return
                }
                call.resolve(["key": key.base64EncodedString()])
                query.removeAll()
            }
        }
    }
}

`;
export function installNativeBackupKey(input){
 if(input.includes(MARKER))return input;
 if(!input.includes('import LocalAuthentication')||!input.includes('class AppDelegate:'))throw Error('Primero ejecutar install-ios-access-lock.mjs');
 const signature='@objc private func danperAuthWindowVisible(_ notification: Notification)';
 const start=input.indexOf(signature);
 const needle='danperAddLockOverlay(to: window)';
 const index=input.indexOf(needle,start);
 if(start<0||index<0)throw Error('No se encuentra ciclo de bloqueo del iPhone');
 let output=input.slice(0,index)+'danperRegisterBackupPlugin(in: window)\n        '+input.slice(index);
 if(!output.includes('import Security'))output=output.replace('import LocalAuthentication','import LocalAuthentication\nimport Security');
 return output+'\n'+SWIFT;
}
if(process.argv[1]?.endsWith('install-ios-backup-key.mjs')){
 const path=process.argv[2]||'ios/App/App/AppDelegate.swift';
 const previous=readFileSync(path,'utf8');
 const updated=installNativeBackupKey(previous);
 writeFileSync(path,updated,'utf8');
 console.log(updated===previous?'PASS: llave de respaldo biométrico ya instalada':'PASS: puente biométrico de respaldo iOS instalado');
}