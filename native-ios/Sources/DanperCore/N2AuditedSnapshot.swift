import Foundation

/// Internal immutable attestation. There is deliberately no memberwise/raw
/// initializer: obtaining this value requires BOTH complete semantic audits.
/// Sharing its proof never replaces HMAC, AEAD, file reads or revision checks.
struct N2AuditedSnapshot {
    let bytes:Data
    let parity:N1eClinicalParityReport
    let fields:N1fFieldReport
    init(validating bytes:Data)throws {
        guard bytes.count>0,bytes.count<=30*1024*1024 else {
            throw N2EncryptedClinicalJournal.Failure.invalidSnapshot
        }
        parity=try N2VersionedSnapshotAudit.inspect(bytes,
            allowEmptySynthetic:N2EmptyDemoSnapshot.matches(bytes))
        fields=try N1fLosslessFieldGate.inspect(bytes)
        self.bytes=bytes
    }
}
