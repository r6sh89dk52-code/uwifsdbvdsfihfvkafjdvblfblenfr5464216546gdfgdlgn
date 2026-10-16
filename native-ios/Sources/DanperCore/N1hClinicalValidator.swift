import Foundation

/// N1h port of src/attentionStepValidation.ts, not a clinical decision aid.
/// Inputs are modeled exactly, so TypeScript synthetic fixtures can be checked
/// byte-for-byte at the level of ordered failing field IDs.
public struct N1hWorkerInput: Codable, Sendable {
    public var dni: String
    public var name: String
    public init(dni: String, name: String) { self.dni = dni; self.name = name }
}
public struct N1hItemInput: Codable, Sendable {
    public var quantity: Double
    public var procedure: String
    public init(quantity: Double, procedure: String) {
        self.quantity = quantity; self.procedure = procedure
    }
}
public struct N1hClinicalInput: Codable, Sendable {
    public var worker: N1hWorkerInput
    public var date: String
    public var time: String
    public var category: String
    public var system: String
    public var segment: String
    public var diagnosis: String
    public var items: [N1hItemInput]
    public var permission: String
    public var permissionTime: String
    public init(worker: N1hWorkerInput, date: String, time: String,
                category: String, system: String, segment: String,
                diagnosis: String, items: [N1hItemInput], permission: String,
                permissionTime: String) {
        self.worker = worker; self.date = date; self.time = time
        self.category = category; self.system = system; self.segment = segment
        self.diagnosis = diagnosis; self.items = items
        self.permission = permission; self.permissionTime = permissionTime
    }
}
public struct N1hClinicalContext: Codable, Sendable {
    public var validCategories: [String]
    public var validSystems: [String]
    public var rosterRequired: Bool
    public var workerInRoster: Bool
    public var rosterException: Bool
    public var allergiesReviewed: Bool
    public var allergyStatus: String
    public var allergySubstances: String
    public init(validCategories: [String], validSystems: [String],
                rosterRequired: Bool, workerInRoster: Bool,
                rosterException: Bool, allergiesReviewed: Bool,
                allergyStatus: String, allergySubstances: String) {
        self.validCategories = validCategories
        self.validSystems = validSystems
        self.rosterRequired = rosterRequired
        self.workerInRoster = workerInRoster
        self.rosterException = rosterException
        self.allergiesReviewed = allergiesReviewed
        self.allergyStatus = allergyStatus
        self.allergySubstances = allergySubstances
    }
}

public enum N1hClinicalValidator {
    public static let systemRequired = [
        "ENFERMEDAD","ACCIDENTE COMUN","ACCIDENTE DE TRABAJO","MATERNIDAD"
    ]
    private static func validDate(_ s: String) -> Bool {
        let a = Array(s.utf8)
        guard a.count == 10, a[4] == 45, a[7] == 45 else { return false }
        for i in [0,1,2,3,5,6,8,9] {
            guard (48...57).contains(a[i]) else { return false }
        }
        guard let year = Int(s.prefix(4)), let month = Int(s.dropFirst(5).prefix(2)),
              let day = Int(s.suffix(2)), (1900...2100).contains(year),
              (1...12).contains(month), (1...31).contains(day) else { return false }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let comps = DateComponents(timeZone: calendar.timeZone,
            year: year, month: month, day: day, hour: 12)
        guard let date = calendar.date(from: comps) else { return false }
        let verified = calendar.dateComponents([.year,.month,.day], from: date)
        return verified.year == year && verified.month == month && verified.day == day
    }
    private static func validTime(_ s: String) -> Bool {
        let a = Array(s.utf8)
        guard a.count == 5, a[2] == 58 else { return false }
        for i in [0,1,3,4] { guard (48...57).contains(a[i]) else { return false } }
        let hh = Int(s.prefix(2)) ?? 24, mm = Int(s.suffix(2)) ?? 60
        return hh < 24 && mm < 60
    }
    private static func dni8(_ s: String) -> Bool {
        let a = Array(s.utf8)
        return a.count == 8 && a.allSatisfy { (48...57).contains($0) }
    }
    private static func nonEmpty(_ s: String) -> Bool {
        !s.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    /// Field IDs mirror TS; repeated "treatment-items" are intentional.
    public static func invalidFields(step: Int, form: N1hClinicalInput,
                                     context: N1hClinicalContext) -> [String] {
        var fields: [String] = []
        switch step {
        case 0:
            if !dni8(form.worker.dni) { fields.append("worker-dni") }
            if !nonEmpty(form.worker.name) { fields.append("worker-name") }
            if context.rosterRequired && !context.workerInRoster && !context.rosterException {
                fields.append("worker-dni")
            }
        case 1:
            if !validDate(form.date) { fields.append("clinical-date") }
            if !validTime(form.time) { fields.append("clinical-time") }
            if !context.validCategories.contains(form.category) {
                fields.append("clinical-category")
            } else if systemRequired.contains(form.category) {
                if !context.validSystems.contains(form.system) {
                    fields.append("clinical-system")
                }
                if form.system == "OSTEOMUSCULAR" && !nonEmpty(form.segment) {
                    fields.append("clinical-segment")
                }
            }
            if !nonEmpty(form.diagnosis) { fields.append("clinical-diagnosis") }
            if !context.allergiesReviewed {
                fields.append("allergy-status")
            } else if context.allergyStatus == "known" && !nonEmpty(context.allergySubstances) {
                fields.append("allergy-substances")
            }
        case 2:
            for item in form.items {
                if !item.quantity.isFinite || item.quantity <= 0 ||
                   item.quantity.rounded() != item.quantity {
                    fields.append("treatment-items")
                }
                if !nonEmpty(item.procedure) { fields.append("treatment-items") }
            }
        case 3:
            if form.permission == "SI" && !validTime(form.permissionTime) {
                fields.append("result-permission-time")
            }
        default: break
        }
        return fields
    }
    public static func firstInvalidStage(form: N1hClinicalInput,
                                         context: N1hClinicalContext) -> Int? {
        (0...3).first { !invalidFields(step: $0, form: form, context: context).isEmpty }
    }
}

/// Additional form details for N1g simulation; not a production model.
/// Choices are closed fake demo options and never contain patient narratives.
public struct N1hDemoFields: Equatable, Sendable {
    public var date = "2026-10-16"
    public var time = "08:25"
    public var system = ""
    public var segment = ""
    public var permission = "NO"
    public var permissionTime = ""
    public var blueBandage = false
    public var returned = false
    public var photoSent = false
    public var standaloneProcedures: [String] = []
    public init() {}
}
