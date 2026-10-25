// Optional integration source. Add only to an isolated iOS validation target
// linked with FirebaseAuth, FirebaseFirestore and DanperCloudBridge.
#if canImport(FirebaseAuth) && canImport(FirebaseFirestore)
import Foundation
import FirebaseAuth
import FirebaseFirestore
import DanperCloudBridge

public final class FirebaseCloudTransport: CloudTransport, @unchecked Sendable {
    private let db: Firestore
    private let uid: String
    public init(db: Firestore, authorizedUID: String) { self.db = db; self.uid = authorizedUID }
    private func authorize() throws {
        guard Auth.auth().currentUser?.uid == uid else { throw CloudFailure.disabled }
    }
    public func commit(_ operation: CloudOperation) async throws {
        try authorize()
        let base = db.collection("accounts").document(uid)
        let payload = try JSONSerialization.jsonObject(with: JSONEncoder().encode(operation)) as! [String: Any]
        let changes = payload["changes"] as! [[String: Any]]
        do {
            _ = try await db.runTransaction { tx, errorPointer -> Any? in
                do {
                    let receipt = base.collection("operations").document(operation.id)
                    if try tx.getDocument(receipt).exists { return nil }
                    let clock = base.collection("syncMeta").document("clock")
                    let oldClock = try tx.getDocument(clock)
                    let sequence = (oldClock.data()?["sequence"] as? Int ?? 0) + 1
                    let refs = operation.changes.map { base.collection($0.collection).document($0.id) }
                    let snapshots = try refs.map { try tx.getDocument($0) }
                    for (index, change) in operation.changes.enumerated() {
                        guard (snapshots[index].data()?["revision"] as? Int ?? 0) == change.expectedRevision else { throw CloudFailure.revisionConflict }
                    }
                    for (index, change) in operation.changes.enumerated() {
                        tx.setData(["key":change.collection+":"+change.id,"collection":change.collection,"id":change.id,"revision":change.expectedRevision+1,"data":changes[index]["data"]!,"operationId":operation.id,"sequence":sequence], forDocument: refs[index])
                    }
                    let keys = operation.changes.map { $0.collection + ":" + $0.id }
                    tx.setData(["id":operation.id,"deviceId":operation.deviceId,"createdAt":operation.createdAt,"sequence":sequence,"keys":keys], forDocument: receipt)
                    tx.setData(["sequence":sequence,"operationId":operation.id,"keys":operation.changes.map{["collection":$0.collection,"id":$0.id]}], forDocument: base.collection("changes").document(String(format:"%012d",sequence)))
                    tx.setData(["sequence":sequence], forDocument: clock)
                    return nil
                } catch {
                    errorPointer?.pointee = NSError(domain:"DanperCloudBridge",code:error as? CloudFailure == .revisionConflict ? 409:400)
                    return nil
                }
            }
        } catch { if (error as NSError).domain == "DanperCloudBridge", (error as NSError).code == 409 { throw CloudFailure.revisionConflict }; throw error }
    }
    public func changes(after cursor: Int) async throws -> CloudPage {
        try authorize()
        let base = db.collection("accounts").document(uid)
        let changes = try await base.collection("changes").whereField("sequence", isGreaterThan: cursor).order(by:"sequence").limit(to:25).getDocuments(source:.server)
        var entities = [CloudEntity](), next = cursor
        for record in changes.documents {
            guard let sequence = record.data()["sequence"] as? Int,
                  let keys = record.data()["keys"] as? [[String:String]] else { throw CloudFailure.invalidOperation }
            for key in keys {
                guard let collection = key["collection"], let id = key["id"] else { throw CloudFailure.invalidOperation }
                let doc = try await base.collection(collection).document(id).getDocument(source:.server)
                guard let data = doc.data() else { throw CloudFailure.invalidOperation }
                entities.append(try JSONDecoder().decode(CloudEntity.self, from: JSONSerialization.data(withJSONObject:data)))
            }
            next = sequence
        }
        return CloudPage(entities:entities,cursor:next)
    }
}
#endif
