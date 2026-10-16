import Foundation

/// Synthetic-only end-to-end atomic attention + FEFO + encrypted revision.
/// The iPhone build222 vault and in-app clinical form are NOT wired here.
internal final class N2AtomicClinicalCoordinator {
    enum Failure:Error,Equatable {case uninitialized,duplicateChangedVisit,invalidRequest}
    struct Commit {
        let revision:Int
        let alreadyCommitted:Bool
        let linked:Int
        let pending:Int
        let addedMovements:Int
    }
    private let store:N2EncryptedClinicalJournal
    init(journal:N2EncryptedClinicalJournal) {self.store=journal}

    func bootstrapFromVerifiedSingleSource(_ source:Data) throws ->Int {
        guard try store.recover()==nil else{throw Failure.invalidRequest}
        return try store.commit(source,expectedRevision:0)
    }
    private func sameJSON(_ a:Any,_ b:Any)->Bool {
        guard let x=try? JSONSerialization.data(withJSONObject:a,options:[.sortedKeys]),
              let y=try? JSONSerialization.data(withJSONObject:b,options:[.sortedKeys])
        else{return false}
        return x==y
    }
    /// If an interruption happened AFTER the atomic pointer, the exact same
    /// saved visit is a safe no-op, not a second physical movement.
    func save(visit:Data,approvedCatalog:Data,at:Int64,
              expectedRevision:Int,
              fault:((N2EncryptedClinicalJournal.Checkpoint)throws->Void)?=nil) throws ->Commit {
        guard let active=try store.recover() else{throw Failure.uninitialized}
        guard let request=try? JSONSerialization.jsonObject(with:visit) as? [String:Any],
              let id=request["id"] as? String,!id.isEmpty,
              let root=try? JSONSerialization.jsonObject(with:active.snapshot) as? [String:Any],
              let visits=root["attentions"] as? [[String:Any]] else {
            throw Failure.invalidRequest
        }
        if let prior=visits.first(where:{$0["id"] as? String==id}) {
            guard sameJSON(prior,request) else{throw Failure.duplicateChangedVisit}
            return Commit(revision:active.revision,alreadyCommitted:true,
                          linked:0,pending:0,addedMovements:0)
        }
        // An old form cannot overwrite a newer encrypted generation.
        guard active.revision==expectedRevision else{
            throw N2EncryptedClinicalJournal.Failure.staleRevision
        }
        let result=try N2NativeClinicalTransaction.appendSavedVisit(
            snapshot:active.snapshot,visit:visit,
            approvedCatalog:approvedCatalog,at:at)
        let next=try store.commit(result.snapshot,expectedRevision:active.revision,fault:fault)
        guard let check=try store.recover(),check.revision==next,
              check.snapshot==result.snapshot else{
            throw N2EncryptedClinicalJournal.Failure.authenticationFailed
        }
        return Commit(revision:next,alreadyCommitted:false,
                      linked:result.linked,pending:result.pending,
                      addedMovements:result.physicalMovementsAdded)
    }
}
