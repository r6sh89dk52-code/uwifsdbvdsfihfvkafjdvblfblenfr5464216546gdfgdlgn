import Foundation
import CryptoKit
import Security
import UserNotifications
import DanperCore

/// Almacén exclusivo N4. No abre, edita ni migra la bóveda N2.
struct DMChange:Codable,Sendable,Identifiable {
    var id:UUID=UUID()
    var certificateID:UUID
    var kind:String
    var at:Date=Date()
}
struct DMPersisted:Codable,Sendable {
    var ledger=DMLedger()
    var changes:[DMChange]=[]
    var revision:Int=0
}
actor DMEncryptedStore {
    static let shared=DMEncryptedStore()
    private let service="pe.danper.saludmovil.n4.dm-only.key.v1"
    private let account="dm-secret-aesgcm"
    private let name="dm-snapshot.gcm"
    private func root() throws -> URL {
        let base=try FileManager.default.url(for:.applicationSupportDirectory,
                                             in:.userDomainMask,appropriateFor:nil,create:true)
        let path=base.appendingPathComponent("DANPER-N4-DM-ONLY",isDirectory:true)
        if !FileManager.default.fileExists(atPath:path.path) {
            try FileManager.default.createDirectory(at:path,withIntermediateDirectories:false,
                                                     attributes:[.protectionKey:FileProtectionType.complete])
        }
        return path
    }
    private func key() throws -> SymmetricKey {
        let query:[String:Any]=[
            kSecClass as String:kSecClassGenericPassword,
            kSecAttrService as String:service,
            kSecAttrAccount as String:account,
            kSecReturnData as String:true,
            kSecMatchLimit as String:kSecMatchLimitOne]
        var result:CFTypeRef?
        let status=SecItemCopyMatching(query as CFDictionary,&result)
        if status==errSecSuccess,let bytes=result as? Data,bytes.count==32 {
            return SymmetricKey(data:bytes)
        }
        guard status==errSecItemNotFound else{throw DMStoreFailure.unavailable}
        // Si existe cifrado pero falta la clave, NO sobrescribir ni crear otra.
        if FileManager.default.fileExists(atPath:try root().appendingPathComponent(name).path) {
            throw DMStoreFailure.unavailable
        }
        let secret=SymmetricKey(size:.bits256)
        let bytes=secret.withUnsafeBytes{Data($0)}
        var save=query
        save.removeValue(forKey:kSecReturnData as String)
        save.removeValue(forKey:kSecMatchLimit as String)
        save[kSecValueData as String]=bytes
        save[kSecAttrAccessible as String]=kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        guard SecItemAdd(save as CFDictionary,nil)==errSecSuccess else{throw DMStoreFailure.unavailable}
        return secret
    }
    func read() throws -> DMPersisted {
        let folder=try root()
        let cipher=folder.appendingPathComponent(name)
        guard FileManager.default.fileExists(atPath:cipher.path) else{return DMPersisted()}
        let data=try Data(contentsOf:cipher)
        let secret=try key()
        let box=try AES.GCM.SealedBox(combined:data)
        let plain=try AES.GCM.open(box,using:secret,
                                  authenticating:Data("DANPER_N4_DM_V1".utf8))
        return try JSONDecoder().decode(DMPersisted.self,from:plain)
    }
    private func write(_ content:DMPersisted) throws {
        let bytes=try JSONEncoder().encode(content)
        let seal=try AES.GCM.seal(bytes,using:try key(),
                                 authenticating:Data("DANPER_N4_DM_V1".utf8))
        guard let data=seal.combined else{throw DMStoreFailure.unavailable}
        let destination=try root().appendingPathComponent(name)
        try data.write(to:destination,options:[.atomic,.completeFileProtection])
        // Comprobar escritura; no declarar éxito antes de verificar.
        let verified=try read()
        guard verified.revision==content.revision,
              verified.ledger.certificates.count==content.ledger.certificates.count
        else{throw DMStoreFailure.unavailable}
    }
    func insert(_ certificate:DMCertificate) throws -> DMPersisted {
        var value=try read()
        try value.ledger.add(certificate)
        value.changes.append(DMChange(certificateID:certificate.id,kind:"creado"))
        value.revision += 1
        try write(value);return value
    }
    func replace(_ certificate:DMCertificate) throws -> DMPersisted {
        var value=try read()
        try value.ledger.update(certificate)
        value.changes.append(DMChange(certificateID:certificate.id,kind:"actualizado"))
        value.revision += 1
        try write(value);return value
    }
}
enum DMStoreFailure:Error {case unavailable}

enum DMReturnNotifications {
    private static func id(_ record:DMCertificate,_ suffix:String)->String {
        "danper-n4-dm-"+record.id.uuidString+"-"+suffix
    }
    static func requestPermission() async -> Bool {
        (try? await UNUserNotificationCenter.current()
            .requestAuthorization(options:[.alert,.badge,.sound])) ?? false
    }
    static func update(_ record:DMCertificate) async {
        let center=UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers:[
            id(record,"before"),id(record,"on")
        ])
        guard record.state != .returned,record.state != .voided,
              let iso=record.expectedReturn,let day=DMDate.parse(iso) else{return}
        var cal=Calendar(identifier:.gregorian)
        cal.timeZone=TimeZone(identifier:"America/Lima")!
        for (suffix,offset) in [("before",-1),("on",0)] {
            guard let d=cal.date(byAdding:.day,value:offset,to:day) else{continue}
            var comps=cal.dateComponents([.year,.month,.day],from:d)
            comps.hour=8;comps.minute=0;comps.timeZone=cal.timeZone
            guard let actual=cal.date(from:comps),actual>Date() else{continue}
            let content=UNMutableNotificationContent()
            content.title="DANPER Salud · Seguimiento"
            content.body=record.needsClearance && !record.clearanceVerified
                ? "Revisa el alta médica antes de confirmar una reincorporación."
                : "Tienes una reincorporación por verificar."
            content.sound=.default
            let trigger=UNCalendarNotificationTrigger(dateMatching:comps,repeats:false)
            try? await center.add(UNNotificationRequest(identifier:id(record,suffix),
                                                        content:content,trigger:trigger))
        }
    }
}