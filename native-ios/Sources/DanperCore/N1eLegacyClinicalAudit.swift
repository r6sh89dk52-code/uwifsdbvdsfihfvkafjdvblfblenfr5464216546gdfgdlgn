import Foundation
import CoreFoundation
import Crypto

/// N1e: strictly read-only structure and Kardex concordance audit.
/// Does not infer missing physical stock, migrate, normalize or save records.
/// Raw patient fields are NEVER returned; R is ordered by saved clinical item.
public struct N1eClinicalParityReport: Equatable, Sendable {
    public let sourceSHA256: String
    public let workers: Int
    public let attentions: Int
    public let savedClinicalItems: Int
    public let linkedClinicalItems: Int
    public let pendingClinicalItems: Int
    public let splitDeliveries: Int
    public let physicalMovements: Int
    public let stockLots: Int
    /// Each array element is one saved item (not one physical movement).
    /// nil = no verified physical movement; 0 = verified package reuse.
    public let consumptionR: [Double?]
}

public enum N1eParityError: Error, Equatable {
    case invalidSnapshot, duplicateWorker, invalidLot, duplicateLot
    case invalidMovement, incompleteFEFOGroup, invalidClinicalLink
    case mismatchClinicalItem, invalidPhysicalDelta, inventoryDiscontinuity
    case incorrectExcelR
}

public enum N1eLegacyClinicalAudit {
    private struct Lot {
        let id: String
        let code: String
        let physical: Double
        let canonical: Data
    }
    private struct Line {
        let code: String
        let name: String
        let unit: String
        let quantity: Int
    }
    private struct Issue {
        let id: String
        let quantity: Double
        let r: Double
        let ref: [String: Any]
    }
    private static func str(_ value: Any?) -> String? {
        guard let s = value as? String, !s.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        return s
    }
    private static func num(_ value: Any?) -> Double? {
        guard let n = value as? NSNumber, CFGetTypeID(n) != CFBooleanGetTypeID(),
              n.doubleValue.isFinite else { return nil }
        return n.doubleValue
    }
    private static func integer(_ value: Any?) -> Int? {
        guard let v = num(value), v >= 0, v <= 9_007_199_254_740_991,
              v.rounded() == v, v <= Double(Int.max) else { return nil }
        return Int(v)
    }
    private static func positive(_ value: Any?) -> Double? {
        guard let v = num(value), v > 0, v <= 10_000_000 else { return nil }
        return v
    }
    private static func three(_ n: Double) -> Double {
        (n * 1000).rounded() / 1000
    }
    private static func canonical(_ json: [String: Any]) throws -> Data {
        try JSONSerialization.data(withJSONObject: json, options: [.sortedKeys])
    }
    private static func parseLot(_ raw: Any?) throws -> Lot {
        guard let l = raw as? [String: Any],
              let id = str(l["id"]), let code = str(l["code"]),
              str(l["name"]) != nil, l["lot"] is String,
              l["catalogUnit"] is String,
              let container = l["container"] as? String,
              ["unidad","caja","frasco","paquete","blister","otro"].contains(container),
              let size = integer(l["unitsPerContainer"]), size >= 1,
              let sealed = integer(l["sealedContainers"]),
              let loose = num(l["looseUnits"]), (0...10_000_000).contains(loose),
              let opened = num(l["openedRemaining"]), (0...Double(size)).contains(opened),
              integer(l["updatedAt"]) != nil,
              let expires = l["expires"] as? String
        else { throw N1eParityError.invalidLot }
        if !expires.isEmpty {
            guard expires.range(of: #"^\d{4}-\d{2}-\d{2}$"#, options: .regularExpression) != nil
            else { throw N1eParityError.invalidLot }
        }
        let total = three(Double(sealed) * Double(size) + loose + opened)
        guard total.isFinite, total >= 0 && total <= 10_000_000_000 else {
            throw N1eParityError.invalidLot
        }
        return Lot(id: id, code: code, physical: total, canonical: try canonical(l))
    }

    /// A successful audit never grants restore authorization; the caller must
    /// still authenticate, stage both encrypted domains, and obtain consent.
    public static func inspect(_ data: Data) throws -> N1eClinicalParityReport {
        guard data.count <= 30 * 1024 * 1024,
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let workers = root["workers"] as? [[String: Any]],
              let attentions = root["attentions"] as? [[String: Any]],
              let rawLots = root["stockLots"] as? [[String: Any]],
              let rawMoves = root["stockMovements"] as? [[String: Any]]
        else { throw N1eParityError.invalidSnapshot }
        // Enforce the exact nine collections from the actual build222 format.
        guard (try? N1BackupAdmission.preview(data: data)) != nil else {
            throw N1eParityError.invalidSnapshot
        }
        var workerIDs = Set<String>()
        for w in workers {
            guard let dni = str(w["dni"]), dni.count == 8,
                  dni.allSatisfy({ $0.isASCII && $0.isNumber }),
                  str(w["name"]) != nil,
                  workerIDs.insert(dni).inserted else {
                throw N1eParityError.duplicateWorker
            }
        }
        var lots = [String: Lot]()
        for item in rawLots {
            let l = try parseLot(item)
            guard lots[l.id] == nil else { throw N1eParityError.duplicateLot }
            lots[l.id] = l
        }
        var clinical = [String: Line]()
        var savedKeys = [String]()
        var visitIDs = Set<String>()
        for a in attentions {
            guard let aid = str(a["id"]), visitIDs.insert(aid).inserted,
                  let status = a["status"] as? String,
                  ["saved", "draft"].contains(status),
                  let items = a["items"] as? [[String: Any]]
            else { throw N1eParityError.invalidSnapshot }
            var itemIDs = Set<String>()
            for i in items {
                guard let iid = str(i["id"]), itemIDs.insert(iid).inserted,
                      let q = integer(i["quantity"]), q > 0,
                      let code = str(i["code"]), let name = str(i["name"]),
                      let unit = str(i["unit"]) else {
                    throw N1eParityError.invalidSnapshot
                }
                if status == "saved" {
                    let key = aid + "\u{001F}" + iid
                    clinical[key] = Line(code: code, name: name, unit: unit, quantity: q)
                    savedKeys.append(key)
                }
            }
        }
        var lastAfter = [String: Data]()
        var groups = [String: [Issue]]()
        var movementIDs = Set<String>()
        for m in rawMoves {
            guard let mid = str(m["id"]), movementIDs.insert(mid).inserted,
                  let lotID = str(m["lotId"]),
                  let product = str(m["code"]),
                  let lot = lots[lotID], lot.code == product,
                  let kind = m["kind"] as? String,
                  ["use","extraordinary","adjustment"].contains(kind),
                  let at = integer(m["at"]), at > 0,
                  let before = try? parseLot(m["before"]),
                  let after = try? parseLot(m["after"]),
                  before.id == lotID, after.id == lotID,
                  before.code == product, after.code == product,
                  let delta = num(m["physicalChange"]),
                  let quantity = num(m["quantity"]),
                  let excel = num(m["excelQuantity"]),
                  (m["openedNewContainer"] as? Bool) != nil
            else { throw N1eParityError.invalidMovement }
            guard three(after.physical - before.physical) == three(delta)
            else { throw N1eParityError.invalidPhysicalDelta }
            if kind == "use" {
                guard quantity > 0, three(delta) == -three(quantity) else {
                    throw N1eParityError.invalidPhysicalDelta
                }
            }
            if let prior = lastAfter[lotID], prior != before.canonical {
                throw N1eParityError.inventoryDiscontinuity
            }
            lastAfter[lotID] = after.canonical
            if let refValue = m["dispenseRef"] {
                guard kind == "use",
                      let ref = refValue as? [String: Any],
                      let aid = str(ref["attentionId"]), let iid = str(ref["itemId"]),
                      let item = clinical[aid + "\u{001F}" + iid],
                      let refCode = str(ref["clinicalCode"]),
                      let refName = str(ref["clinicalName"]),
                      let refUnit = str(ref["clinicalUnit"]),
                      let refQty = integer(ref["clinicalQuantity"]),
                      let confirmed = integer(ref["confirmedAt"]), confirmed == at,
                      refCode == item.code, refName == item.name,
                      refUnit == item.unit, refQty == item.quantity else {
                    throw N1eParityError.invalidClinicalLink
                }
                let perUnit = ["UND","TBL","PAR"].contains(refUnit.uppercased())
                let actualR = perUnit ? quantity : ((m["openedNewContainer"] as? Bool) == true ? 1.0 : 0.0)
                guard three(actualR) == three(excel) else {
                    throw N1eParityError.incorrectExcelR
                }
                if perUnit {
                    guard quantity.rounded() == quantity else { throw N1eParityError.invalidClinicalLink }
                }
                let key = aid + "\u{001F}" + iid
                groups[key, default: []].append(Issue(id: mid, quantity: quantity, r: excel, ref: ref))
            }
        }
        for (id, latest) in lastAfter {
            guard let lot = lots[id], latest == lot.canonical else {
                throw N1eParityError.inventoryDiscontinuity
            }
        }
        var splitDeliveries = 0
        var rByItem = [String: Double]()
        for (key, parts) in groups {
            guard let first = parts.first else { throw N1eParityError.invalidClinicalLink }
            let split = first.ref["partCount"] != nil || first.ref["partIndex"] != nil
            let row = clinical[key]!
            if split {
                guard let expected = integer(first.ref["partCount"]),
                      (2...500).contains(expected), parts.count == expected,
                      let target = positive(first.ref["physicalTotal"]) else {
                    throw N1eParityError.incompleteFEFOGroup
                }
                var indices = Set<Int>()
                for p in parts {
                    guard let idx = integer(p.ref["partIndex"]),
                          (1...expected).contains(idx), indices.insert(idx).inserted,
                          integer(p.ref["partCount"]) == expected,
                          positive(p.ref["physicalTotal"]) == target,
                          p.id == "ATT:" + String(key.split(separator: "\u{001F}")[0]) +
                            ":ITEM:" + String(key.split(separator: "\u{001F}")[1]) +
                            ":PART:" + String(idx),
                          str(p.ref["clinicalCode"]) == row.code,
                          str(p.ref["clinicalName"]) == row.name,
                          str(p.ref["clinicalUnit"]) == row.unit,
                          integer(p.ref["clinicalQuantity"]) == row.quantity,
                          integer(p.ref["confirmedAt"]) == integer(first.ref["confirmedAt"])
                    else { throw N1eParityError.incompleteFEFOGroup }
                }
                guard indices.count == expected,
                      three(parts.reduce(0.0) { $0 + $1.quantity }) == three(target)
                else { throw N1eParityError.incompleteFEFOGroup }
                if ["UND","TBL","PAR"].contains(row.unit.uppercased()) {
                    guard target == Double(row.quantity) else {
                        throw N1eParityError.mismatchClinicalItem
                    }
                }
                splitDeliveries += 1
            } else {
                guard parts.count == 1,
                      first.ref["partIndex"] == nil,
                      first.ref["partCount"] == nil,
                      let aid = str(first.ref["attentionId"]),
                      let iid = str(first.ref["itemId"]),
                      first.id == "ATT:" + aid + ":ITEM:" + iid else {
                    throw N1eParityError.invalidClinicalLink
                }
                if ["UND","TBL","PAR"].contains(row.unit.uppercased()) {
                    guard parts[0].quantity == Double(row.quantity) else {
                        throw N1eParityError.mismatchClinicalItem
                    }
                }
            }
            rByItem[key] = three(parts.reduce(0.0) { $0 + $1.r })
        }
        let rows = savedKeys.map { rByItem[$0] }
        let sourceSHA256 = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        return N1eClinicalParityReport(sourceSHA256: sourceSHA256,
                   workers: workers.count, attentions: attentions.count,
                   savedClinicalItems: savedKeys.count,
                   linkedClinicalItems: groups.count,
                   pendingClinicalItems: savedKeys.count - groups.count,
                   splitDeliveries: splitDeliveries,
                   physicalMovements: rawMoves.count, stockLots: lots.count,
                   consumptionR: rows)
    }
}
