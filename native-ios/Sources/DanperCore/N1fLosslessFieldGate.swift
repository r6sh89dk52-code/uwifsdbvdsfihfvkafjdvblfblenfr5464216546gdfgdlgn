import Foundation
import CoreFoundation
import Crypto

/// Read-only N1f preservation gate: no restoration, no PII in returned reports.
internal struct N1fFieldReport: Equatable {
    let sourceSHA256: String
    let semanticSHA256: String
    let treeNodes: Int
    let workers: Int
    let attentions: Int
    let saved: Int
    let drafts: Int
    let corrections: Int
    let allergyKnown: Int
    let allergyNone: Int
    let allergyUnknown: Int
    let incompleteKnownAllergies: Int
    let notifications: Bool
}
internal enum N1fFieldError: Error, Equatable {
    case invalidSnapshot, invalidWorker, invalidAttention, invalidAllergy, semanticDataLoss
}
internal enum N1fLosslessFieldGate {
    private static func text(_ x: Any?) -> String? { x as? String }
    private static func numeric(_ x: Any?) -> Double? {
        guard let n = x as? NSNumber, CFGetTypeID(n) != CFBooleanGetTypeID(),
              n.doubleValue.isFinite else { return nil }
        return n.doubleValue
    }
    private static func flag(_ x: Any?) -> Bool? {
        guard let n = x as? NSNumber, CFGetTypeID(n) == CFBooleanGetTypeID() else { return nil }
        return n.boolValue
    }
    private static func dateNumber(_ x: Any?) -> Bool {
        guard let n = numeric(x) else { return false }
        return n >= 0 && n.rounded() == n && n <= 9_007_199_254_740_991
    }
    private static func validDNI(_ dni: String) -> Bool {
        dni.count == 8 && dni.allSatisfy { ("0"..."9").contains($0) }
    }
    private static func hash(_ d: Data) -> String {
        SHA256.hash(data: d).map { String(format: "%02x", $0) }.joined()
    }
    private static func appendFrame(_ kind: UInt8, path: String, value: Data, to d: inout Data) {
        d.append(kind)
        for bytes in [Data(path.utf8), value] {
            var n = UInt64(bytes.count).bigEndian
            withUnsafeBytes(of: &n) { d.append(contentsOf: $0) }
            d.append(bytes)
        }
    }
    private static func escape(_ key: String) -> String {
        key.replacingOccurrences(of: "~", with: "~0")
           .replacingOccurrences(of: "/", with: "~1")
    }
    /// Canonical typed tree hash includes every extension and empty container,
    /// distinguishes missing/null/false/zero and preserves array order.
    private static func walk(_ x: Any, path: String, into d: inout Data, nodes: inout Int) throws {
        nodes += 1
        if let dict = x as? [String: Any] {
            appendFrame(79, path: path, value: Data(), to: &d)
            for key in dict.keys.sorted() {
                try walk(dict[key]!, path: path + "/k:" + escape(key), into: &d, nodes: &nodes)
            }
        } else if let arr = x as? [Any] {
            appendFrame(65, path: path, value: Data(), to: &d)
            for (index, entry) in arr.enumerated() {
                try walk(entry, path: path + "/i:" + String(index), into: &d, nodes: &nodes)
            }
        } else if x is NSNull {
            appendFrame(90, path: path, value: Data(), to: &d)
        } else if let s = x as? String {
            appendFrame(83, path: path, value: Data(s.utf8), to: &d)
        } else if let n = x as? NSNumber {
            if CFGetTypeID(n) == CFBooleanGetTypeID() {
                appendFrame(66, path: path, value: Data((n.boolValue ? "true" : "false").utf8), to: &d)
            } else {
                guard n.doubleValue.isFinite else { throw N1fFieldError.invalidSnapshot }
                appendFrame(78, path: path, value: Data(n.stringValue.utf8), to: &d)
            }
        } else { throw N1fFieldError.invalidSnapshot }
    }
    private static func fingerprint(_ x: [String: Any]) throws -> (String, Int) {
        var bytes = Data(), count = 0
        try walk(x, path: "$", into: &bytes, nodes: &count)
        return (hash(bytes), count)
    }
    static func inspect(_ raw: Data) throws -> N1fFieldReport {
        guard raw.count <= 30 * 1024 * 1024,
              let obj = try? JSONSerialization.jsonObject(with: raw) as? [String: Any],
              let workers = obj["workers"] as? [[String: Any]],
              let visits = obj["attentions"] as? [[String: Any]],
              let allergies = obj["allergies"] as? [String: Any],
              let notifications = flag(obj["notifications"]),
              let lots = obj["stockLots"] as? [Any],
              let movements = obj["stockMovements"] as? [Any],
              let mappings = obj["catalogMappings"] as? [Any],
              let incidents = obj["deliveryIncidents"] as? [Any],
              let reconciliations = obj["ambulatoryReconciliation"] as? [Any],
              workers.count <= 30_000, visits.count <= 100_000,
              lots.count <= 500, movements.count <= 1000,
              mappings.count <= 500, incidents.count <= 500,
              reconciliations.count <= 1200 else {
            throw N1fFieldError.invalidSnapshot
        }
        var dnis = Set<String>()
        for w in workers {
            guard let dni = text(w["dni"]), validDNI(dni),
                  let name = text(w["name"]), !name.trimmingCharacters(in: .whitespaces).isEmpty,
                  dnis.insert(dni).inserted else { throw N1fFieldError.invalidWorker }
            for key in ["area", "labor", "sex", "age", "ubigeo", "site"] {
                if let value = w[key], !(value is String) { throw N1fFieldError.invalidWorker }
            }
            if let source = w["source"] as? String, !["manual", "imported"].contains(source) {
                throw N1fFieldError.invalidWorker
            }
            if w["localCorrectionAt"] != nil && !dateNumber(w["localCorrectionAt"]) {
                throw N1fFieldError.invalidWorker
            }
        }
        var ids = Set<String>(), saved = 0, drafts = 0, corrections = 0
        for v in visits {
            guard let id = text(v["id"]), !id.isEmpty, ids.insert(id).inserted,
                  let status = text(v["status"]), ["saved", "draft"].contains(status),
                  let worker = v["worker"] as? [String: Any],
                  let items = v["items"] as? [[String: Any]] else {
                throw N1fFieldError.invalidAttention
            }
            if let origin = v["originId"] {
                guard status == "draft", let s = origin as? String, !s.isEmpty else {
                    throw N1fFieldError.invalidAttention
                }
                corrections += 1
            }
            for key in ["date","time","diagnosis","category","system","segment",
                        "permission","workStatus","permissionTime","responsible","responsibleDni"] {
                if let v = v[key], !(v is String) { throw N1fFieldError.invalidAttention }
            }
            if let at = v["updatedAt"], !dateNumber(at) { throw N1fFieldError.invalidAttention }
            if let procedures = v["standaloneProcedures"] {
                guard let strings = procedures as? [String], strings.count <= 1000 else {
                    throw N1fFieldError.invalidAttention
                }
            }
            for key in ["blueBandage","returned","photoSent"] {
                if v[key] != nil && flag(v[key]) == nil { throw N1fFieldError.invalidAttention }
            }
            if status == "saved" {
                guard let dni = text(worker["dni"]), validDNI(dni),
                      let name = text(worker["name"]), !name.isEmpty else {
                    throw N1fFieldError.invalidAttention
                }
                saved += 1
            } else { drafts += 1 } // preserve incomplete draft fields
            var itemIDs = Set<String>()
            for item in items {
                guard let id = text(item["id"]), !id.isEmpty, itemIDs.insert(id).inserted else {
                    throw N1fFieldError.invalidAttention
                }
                if status == "saved" {
                    guard let q = numeric(item["quantity"]), q > 0, q.rounded() == q,
                          text(item["code"]) != nil, text(item["name"]) != nil,
                          text(item["unit"]) != nil else { throw N1fFieldError.invalidAttention }
                }
            }
        }
        var known = 0, none = 0, unknown = 0, incomplete = 0
        for (dni, rawValue) in allergies {
            guard validDNI(dni), let record = rawValue as? [String: Any],
                  let status = text(record["status"]), let substances = text(record["substances"]),
                  dateNumber(record["updatedAt"]) else { throw N1fFieldError.invalidAllergy }
            switch status {
            case "known":
                known += 1
                if substances.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { incomplete += 1 }
            case "none": none += 1
            case "unknown": unknown += 1
            default: throw N1fFieldError.invalidAllergy
            }
        }
        let (digest, nodes) = try fingerprint(obj)
        let encoded = try JSONSerialization.data(withJSONObject: obj, options: [.sortedKeys])
        guard let decoded = try JSONSerialization.jsonObject(with: encoded) as? [String: Any]
        else { throw N1fFieldError.semanticDataLoss }
        let (after, afterNodes) = try fingerprint(decoded)
        guard digest == after, nodes == afterNodes else { throw N1fFieldError.semanticDataLoss }
        return N1fFieldReport(sourceSHA256: hash(raw), semanticSHA256: digest, treeNodes: nodes,
                              workers: workers.count, attentions: visits.count,
                              saved: saved, drafts: drafts, corrections: corrections,
                              allergyKnown: known, allergyNone: none, allergyUnknown: unknown,
                              incompleteKnownAllergies: incomplete, notifications: notifications)
    }
    static func verifyUnchanged(original: Data, candidate: Data) throws {
        let a = try inspect(original), b = try inspect(candidate)
        guard a.treeNodes == b.treeNodes, a.semanticSHA256 == b.semanticSHA256
        else { throw N1fFieldError.semanticDataLoss }
    }
}
