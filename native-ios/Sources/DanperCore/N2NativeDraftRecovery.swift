import Foundation

/// Native read-only reconstruction of draft records already stored in an
/// authenticated N2 generation. Lossless field validation rejects malformed
/// records rather than silently discarding medications or clinical content.
public struct N2RecoverableDraft:Identifiable,Sendable {
    public let id:String
    public let updatedAt:Int64
    public let workerName:String
    public let form:N2NativeFormDraft
}

public enum N2DraftRecoveryError:Error,Equatable {
    case invalidSnapshot,unsupportedDraft
}

public enum N2NativeDraftRecovery {
    public static func read(_ snapshot:Data)throws->[N2RecoverableDraft] {
        guard (try? N1eLegacyClinicalAudit.inspect(snapshot)) != nil,
              (try? N1fLosslessFieldGate.inspect(snapshot)) != nil,
              let root=try? JSONSerialization.jsonObject(with:snapshot) as? [String:Any],
              let visits=root["attentions"] as? [[String:Any]] else {
            throw N2DraftRecoveryError.invalidSnapshot
        }
        var result=[N2RecoverableDraft]()
        for record in visits where record["status"] as? String == "draft" {
            guard let id=record["id"] as? String,!id.isEmpty,
                  let worker=record["worker"] as? [String:Any],
                  let rows=record["items"] as? [[String:Any]],
                  let timestamp=record["updatedAt"] as? NSNumber,
                  timestamp.int64Value>0 else{
                throw N2DraftRecoveryError.unsupportedDraft
            }
            var draft=N2NativeFormDraft(id:id)
            draft.dni=worker["dni"] as? String ?? ""
            draft.date=record["date"] as? String ?? ""
            draft.time=record["time"] as? String ?? ""
            draft.dispensingSite=record["dispensingSite"] as? String ?? ""
            draft.category=record["category"] as? String ?? ""
            draft.system=record["system"] as? String ?? ""
            draft.segment=record["segment"] as? String ?? ""
            draft.diagnosis=record["diagnosis"] as? String ?? ""
            draft.permission=record["permission"] as? String ?? "NO"
            draft.permissionTime=record["permissionTime"] as? String ?? ""
            draft.photoSent=record["photoSent"] as? Bool ?? false
            draft.photoReviewed=record["photoReviewed"] as? Bool ?? false
            draft.blueBandage=record["blueBandage"] as? Bool ?? false
            draft.returned=record["returned"] as? Bool ?? false
            draft.responsible=record["responsible"] as? String ?? "RESPONSABLE"
            draft.responsibleDni=record["responsibleDni"] as? String ?? ""
            if let procedures=record["standaloneProcedures"] as? [String] {
                draft.procedures=procedures
            }
            var medications=[N2FormMedication]()
            for row in rows {
                guard let itemID=row["id"] as? String,!itemID.isEmpty,
                      let code=row["code"] as? String,!code.isEmpty,
                      let quantity=row["quantity"] as? Int,
                      let procedureName=row["procedure"] as? String else{
                    throw N2DraftRecoveryError.unsupportedDraft
                }
                var med=N2FormMedication(id:itemID,code:code,quantity:quantity,
                                         procedure:procedureName)
                med.procedureConfirmed=row["procedureConfirmed"] as? Bool ?? !procedureName.isEmpty
                med.procedureSource=row["procedureSource"] as? String ?? "manual"
                if let physical=row["physicalUse"] {
                    guard let info=physical as? [String:Any],
                          let lotID=info["lotId"] as? String,
                          let quantity=(info["quantity"] as? NSNumber)?.doubleValue,
                          quantity.isFinite,
                          let consent=info["confirmNewContainer"] as? Bool else{
                        throw N2DraftRecoveryError.unsupportedDraft
                    }
                    med.selectedLotID=lotID
                    med.physicalQuantity=quantity
                    med.approveOpening=consent
                }
                medications.append(med)
            }
            draft.items=medications
            result.append(N2RecoverableDraft(id:id,updatedAt:timestamp.int64Value,
                    workerName:worker["name"] as? String ?? "",
                    form:draft))
        }
        return result.sorted {
            $0.updatedAt == $1.updatedAt ? $0.id<$1.id : $0.updatedAt>$1.updatedAt
        }
    }
}

