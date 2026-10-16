import Foundation

/// In-memory ONLY mock clinical state. All people and clinical choices are fixed,
/// fictional and not externally editable. Never writes to disk, Keychain or stock.
public struct N1gWorker: Identifiable, Equatable, Codable, Sendable {
    public let id: String
    public let name: String
    public let site: String
    public let area: String
}
public enum N1gAllergy: String, CaseIterable, Codable, Sendable {
    case unknown, none, known
}
public enum N1gVisitStatus: String, Codable, Sendable { case draft, saved }
public struct N1gVisit: Identifiable, Equatable, Codable, Sendable {
    public let id: UUID
    public var originID: UUID?
    public var status: N1gVisitStatus
    public var workerID: String?
    public var category: String
    public var diagnosis: String
    public var procedure: String
    public var product: String
    public var quantity: Int
    public var result: String
    public var updatedAt: Int64
    public var detailed: N1hDemoFields
    public var meaningful: Bool {
        workerID != nil || !category.isEmpty || !diagnosis.isEmpty ||
        !procedure.isEmpty || !product.isEmpty
    }
}
public enum N1gChange: Sendable {
    case worker(String), category(String), diagnosis(String), procedure(String),
         product(String), quantity(Int), result(String),
         date(String), time(String), system(String), segment(String),
         permission(String), permissionTime(String),
         photoSent(Bool), blueBandage(Bool), returned(Bool),
         standaloneProcedure(String, Bool)
}
public enum N1gError: Error, Equatable {
    case workerNotFound, demoRosterFull, draftNotFound, savedIsReadOnly,
         invalidChoice, incompleteWorker, incompleteEvaluation,
         allergyNotReviewed, correctionNeedsAudit, invalidQuantity
}
public struct N1gClinic {
    public static let categories = ["ENFERMEDAD","ACCIDENTE COMUN","ACCIDENTE DE TRABAJO","MATERNIDAD"]
    public static let diagnoses = ["CEFALEA FICTICIA","MALESTAR FICTICIO","CONTROL FICTICIO"]
    public static let procedures = ["OBSERVACION","CONTROL","TRATAMIENTO ORAL","CURACION FICTICIA"]
    public static let products = ["","INSUMO FICTICIO A · UND","MATERIAL FICTICIO B · CJA"]
    public static let results = ["LABORANDO","PERMISO FICTICIO"]
    public static let systems = ["RESPIRATORIO","OSTEOMUSCULAR","DIGESTIVO"]
    public static let segments = ["","BRAZO FICTICIO","PIERNA FICTICIA"]
    public static let allowedDates = ["2026-10-14","2026-10-16"]
    public static let allowedTimes = ["08:25","09:15","10:10","11:45","12:30"]
    public static let standaloneDemoProcedures = ["OBSERVACION","CONTROL"]
    private static let names = ["PERSONA FICTICIA UNO","PERSONA FICTICIA DOS",
         "PERSONA FICTICIA TRES","PERSONA FICTICIA CUATRO",
         "PERSONA FICTICIA CINCO","PERSONA FICTICIA SEIS"]
    public private(set) var workers: [N1gWorker]
    public private(set) var visits: [N1gVisit] = []
    public private(set) var allergies: [String:N1gAllergy] = [:]
    public private(set) var activeDraftID: UUID?
    public var physicalMovementsCreated: Int { 0 } // No stock mutation API, ever.

    public init() {
        workers = [N1gWorker(id:"00000001",name:Self.names[0],
                  site:"LA VENTUROSA",area:"CAMPO FICTICIO"),
                   N1gWorker(id:"00000002",name:Self.names[1],
                  site:"PLVENTUROSA",area:"PLANTA FICTICIA")]
    }
    public var drafts: [N1gVisit] { visits.filter { $0.status == .draft && $0.meaningful } }
    public var saved: [N1gVisit] { visits.filter { $0.status == .saved } }
    public var activeDraft: N1gVisit? { visits.first { $0.id == activeDraftID && $0.status == .draft } }
    public func worker(_ id: String?) -> N1gWorker? { workers.first { $0.id == id } }
    public func search(_ text: String) -> [N1gWorker] {
        let q = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return q.isEmpty ? workers : workers.filter {
            $0.name.localizedStandardContains(q) || $0.id.localizedStandardContains(q) ||
            $0.site.localizedStandardContains(q) || $0.area.localizedStandardContains(q)
        }
    }
    @discardableResult
    public mutating func addFictionalWorker() throws -> N1gWorker {
        let n = workers.count
        guard n < Self.names.count else { throw N1gError.demoRosterFull }
        let w = N1gWorker(id:String(format:"%08d",n+1),name:Self.names[n],
                 site:n.isMultiple(of:2) ? "LA VENTUROSA" : "PLVENTUROSA",area:"AREA FICTICIA")
        workers.append(w)
        return w
    }
    @discardableResult
    public mutating func newDraft(at: Int64) -> UUID {
        if let current = activeDraft { return current.id }
        let v = N1gVisit(id:UUID(),originID:nil,status:.draft,workerID:nil,
                   category:"",diagnosis:"",procedure:"",product:"",quantity:1,
                   result:Self.results[0],updatedAt:at,detailed:N1hDemoFields())
        visits.insert(v,at:0);activeDraftID=v.id
        return v.id
    }
    public mutating func openDraft(_ id: UUID) throws {
        guard visits.contains(where: { $0.id == id && $0.status == .draft })
        else { throw N1gError.draftNotFound }
        activeDraftID=id
    }
    public mutating func edit(_ id: UUID, _ change: N1gChange, at: Int64) throws {
        guard let index = visits.firstIndex(where: { $0.id == id })
        else { throw N1gError.draftNotFound }
        guard visits[index].status == .draft else { throw N1gError.savedIsReadOnly }
        switch change {
        case .worker(let v):
            guard worker(v) != nil else { throw N1gError.workerNotFound }
            visits[index].workerID=v
        case .category(let v):
            guard Self.categories.contains(v) else { throw N1gError.invalidChoice }
            visits[index].category=v
        case .diagnosis(let v):
            guard Self.diagnoses.contains(v) else { throw N1gError.invalidChoice }
            visits[index].diagnosis=v
        case .procedure(let v):
            guard Self.procedures.contains(v) else { throw N1gError.invalidChoice }
            visits[index].procedure=v
        case .product(let v):
            guard Self.products.contains(v) else { throw N1gError.invalidChoice }
            visits[index].product=v
        case .quantity(let v):
            guard (1...20).contains(v) else { throw N1gError.invalidQuantity }
            visits[index].quantity=v
        case .result(let v):
            guard Self.results.contains(v) else { throw N1gError.invalidChoice }
            visits[index].result=v
        case .date(let v):
            guard Self.allowedDates.contains(v) else { throw N1gError.invalidChoice }
            visits[index].detailed.date=v
        case .time(let v):
            guard Self.allowedTimes.contains(v) else { throw N1gError.invalidChoice }
            visits[index].detailed.time=v
        case .system(let v):
            guard Self.systems.contains(v) else { throw N1gError.invalidChoice }
            visits[index].detailed.system=v
        case .segment(let v):
            guard Self.segments.contains(v) else { throw N1gError.invalidChoice }
            visits[index].detailed.segment=v
        case .permission(let v):
            guard ["NO","SI"].contains(v) else { throw N1gError.invalidChoice }
            visits[index].detailed.permission=v
            visits[index].result=v == "SI" ? Self.results[1] : Self.results[0]
            if v == "NO" { visits[index].detailed.permissionTime="" }
        case .permissionTime(let v):
            guard Self.allowedTimes.contains(v) else { throw N1gError.invalidChoice }
            visits[index].detailed.permissionTime=v
        case .photoSent(let v):
            visits[index].detailed.photoSent=v
        case .blueBandage(let v):
            visits[index].detailed.blueBandage=v
            if !v { visits[index].detailed.returned=false }
        case .returned(let v):
            guard !v || visits[index].detailed.blueBandage else { throw N1gError.invalidChoice }
            visits[index].detailed.returned=v
        case .standaloneProcedure(let procedure, let included):
            guard Self.standaloneDemoProcedures.contains(procedure) else {
                throw N1gError.invalidChoice
            }
            visits[index].detailed.standaloneProcedures.removeAll { $0 == procedure }
            if included { visits[index].detailed.standaloneProcedures.append(procedure) }
        }
        visits[index].updatedAt=at
    }
    public mutating func reviewAllergy(_ status:N1gAllergy, for workerID:String) throws {
        guard worker(workerID) != nil else { throw N1gError.workerNotFound }
        allergies[workerID]=status
    }
    /// TS-equivalent stage checks, for the same fixed fictitious form data.
    public func invalidFields(for id: UUID, step: Int) -> [String] {
        guard let v=visits.first(where: { $0.id == id && $0.status == .draft })
        else { return ["draft-not-found"] }
        let w=worker(v.workerID)
        let context=N1hClinicalContext(validCategories:Self.categories,
            validSystems:Self.systems,rosterRequired:true,
            workerInRoster:w != nil,rosterException:false,
            allergiesReviewed:v.workerID.flatMap { allergies[$0] } != nil,
            allergyStatus:v.workerID.flatMap { allergies[$0]?.rawValue } ?? "unknown",
            allergySubstances:v.workerID.flatMap { allergies[$0] } == .known ?
                "SUSTANCIA FICTICIA X" : "")
        let items=[N1hItemInput](v.product.isEmpty ? [] : [
            N1hItemInput(quantity:Double(v.quantity),procedure:v.procedure)])
        let input=N1hClinicalInput(
            worker:N1hWorkerInput(dni:w?.id ?? "",name:w?.name ?? ""),
            date:v.detailed.date,time:v.detailed.time,category:v.category,
            system:v.detailed.system,segment:v.detailed.segment,
            diagnosis:v.diagnosis,items:items,
            permission:v.detailed.permission,permissionTime:v.detailed.permissionTime)
        var fields=N1hClinicalValidator.invalidFields(step:step,form:input,context:context)
        // TS validates procedures attached to items; this mock requires at least
        // one procedure even if no product was selected.
        if step == 2 && v.procedure.isEmpty { fields.append("treatment-items") }
        return fields
    }
    public func firstIncompleteStep(for id: UUID) -> Int? {
        (0...3).first { !invalidFields(for:id,step:$0).isEmpty }
    }
    /// Simulates Save without generating physical stock movements or iOS files.
    public mutating func saveDemo(_ id:UUID, at:Int64) throws {
        guard let i=visits.firstIndex(where: {$0.id==id && $0.status == .draft})
        else { throw N1gError.draftNotFound }
        let v=visits[i]
        guard v.originID == nil else { throw N1gError.correctionNeedsAudit }
        guard let wid=v.workerID, worker(wid) != nil else { throw N1gError.incompleteWorker }
        guard Self.categories.contains(v.category),
              Self.diagnoses.contains(v.diagnosis),
              Self.procedures.contains(v.procedure) else { throw N1gError.incompleteEvaluation }
        guard allergies[wid] != nil else { throw N1gError.allergyNotReviewed }
        guard firstIncompleteStep(for:id) == nil else {
            throw N1gError.incompleteEvaluation
        }
        visits[i].status = .saved
        visits[i].updatedAt = at
        if activeDraftID==id { activeDraftID=nil }
    }
    @discardableResult
    public mutating func correctionDraft(of savedID:UUID, at:Int64) throws -> UUID {
        guard let old=visits.first(where: {$0.id==savedID && $0.status == .saved})
        else { throw N1gError.draftNotFound }
        let copy=N1gVisit(id:UUID(),originID:savedID,status:.draft,
              workerID:old.workerID,category:old.category,diagnosis:old.diagnosis,
              procedure:old.procedure,product:old.product,quantity:old.quantity,
              result:old.result,updatedAt:at,detailed:old.detailed)
        visits.insert(copy,at:0)
        activeDraftID=copy.id
        return copy.id
    }
    public mutating func removeDraft(_ id:UUID) throws {
        guard let v=visits.first(where: {$0.id == id}) else { throw N1gError.draftNotFound }
        guard v.status == .draft else { throw N1gError.savedIsReadOnly }
        visits.removeAll { $0.id == id }
        if activeDraftID == id { activeDraftID=nil }
    }
    public mutating func closeDraft() { activeDraftID=nil }
}
