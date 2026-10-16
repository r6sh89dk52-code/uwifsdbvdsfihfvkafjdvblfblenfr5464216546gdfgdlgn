import Foundation

public struct NativeStockLot: Equatable, Sendable {
    public var id: String
    public var code: String
    public var name: String
    public var expires: String // yyyy-MM-dd; empty = unknown expiry, last
    public var catalogUnit: String
    public var container: String
    public var unitsPerContainer: Int
    public var sealedContainers: Int
    public var looseUnits: Double
    public var openedRemaining: Double

    public init(id: String, code: String, name: String, expires: String,
                catalogUnit: String, container: String, unitsPerContainer: Int,
                sealedContainers: Int, looseUnits: Double, openedRemaining: Double) {
        self.id=id; self.code=code; self.name=name; self.expires=expires
        self.catalogUnit=catalogUnit; self.container=container
        self.unitsPerContainer=unitsPerContainer; self.sealedContainers=sealedContainers
        self.looseUnits=looseUnits; self.openedRemaining=openedRemaining
    }
    public var physicalTotal: Double {
        Double(sealedContainers * unitsPerContainer) + looseUnits + openedRemaining
    }
}

public struct PlannedIssue: Equatable, Sendable {
    public let lotID: String
    public let physicalAmount: Double
    public let excelR: Double
    public let openedNewContainer: Bool
}

public struct FEFOPlan: Equatable, Sendable {
    public let issues: [PlannedIssue]
    public let pendingReason: String?
    public var isReady: Bool { pendingReason == nil }
    public var totalR: Double { issues.reduce(0) { $0 + $1.excelR } }
    public static func pending(_ reason: String) -> FEFOPlan {
        FEFOPlan(issues: [], pendingReason: reason)
    }
}

/// Pure read-only predictor. It never changes persistent stock or visits.
/// Variants must first be resolved by the reviewed DANPER catalog mapping.
public enum FEFOPreview {
    private static func rounded(_ amount: Double) -> Double {
        (amount * 1000).rounded() / 1000
    }
    private static func singleUnit(_ unit: String) -> Bool {
        ["UND","TBL","PAR"].contains(unit.uppercased())
    }
    private static func nextRoom(_ lot: NativeStockLot) -> Double {
        if lot.openedRemaining > 0 { return lot.openedRemaining }
        if lot.looseUnits > 0 { return lot.looseUnits }
        if lot.sealedContainers > 0 { return Double(lot.unitsPerContainer) }
        return 0
    }
    public static func plan(lots: [NativeStockLot], kardexCode: String,
                            clinicalUnit: String, physicalQuantity: Double?,
                            atLocalDate: String) -> FEFOPlan {
        guard let amount = physicalQuantity, amount.isFinite, amount > 0,
              amount <= 10_000_000 else {
            return .pending("Cantidad física sin verificar: no se descuenta inventario.")
        }
        guard atLocalDate.count == 10, atLocalDate[atLocalDate.index(atLocalDate.startIndex, offsetBy: 4)] == "-" else {
            return .pending("Fecha local inválida.")
        }
        let individually = singleUnit(clinicalUnit)
        if individually && (amount.rounded() != amount) {
            return .pending("Una salida UND/TBL/PAR requiere unidades completas.")
        }
        let eligible = lots.filter { lot in
            lot.code == kardexCode && lot.unitsPerContainer >= 1 &&
            lot.sealedContainers >= 0 && lot.openedRemaining >= 0 && lot.looseUnits >= 0 &&
            (lot.expires.isEmpty || lot.expires >= atLocalDate)
        }.sorted {
            let first = $0.expires.isEmpty ? "9999-12-31" : $0.expires
            let second = $1.expires.isEmpty ? "9999-12-31" : $1.expires
            return first == second ? $0.id < $1.id : first < second
        }
        guard !eligible.isEmpty else { return .pending("Sin lotes vigentes verificados.") }
        let total = eligible.reduce(0.0) { $0 + $1.physicalTotal }
        if total + 0.00001 < amount {
            return .pending("Saldo físico FEFO insuficiente.")
        }
        var working = eligible
        var remaining = rounded(amount)
        var parts = [PlannedIssue]()
        while remaining > 0.00001 && parts.count < 490 {
            guard let i = working.indices.first(where: { idx in
                let lot = working[idx]
                let stockUnit = lot.catalogUnit.uppercased()
                let compatible = !individually || (clinicalUnit.uppercased() == "PAR"
                    ? stockUnit == "PAR" : ["UND","TBL"].contains(stockUnit))
                let room = nextRoom(lot)
                return compatible && (individually ? floor(room + 0.000001) >= 1 : room > 0)
            }) else { return .pending("No existe un lote con una cantidad física utilizable.") }
            var lot = working[i]
            let capacity = individually ? floor(nextRoom(lot) + 0.000001) : nextRoom(lot)
            let take = rounded(min(remaining, capacity))
            guard take > 0 else { return .pending("No se puede emitir un fragmento físico.") }
            let opened: Bool
            let officialR: Double
            if lot.openedRemaining > 0 {
                lot.openedRemaining = rounded(lot.openedRemaining - take)
                opened = false; officialR = individually ? take : 0
            } else if lot.looseUnits > 0 {
                lot.looseUnits = rounded(lot.looseUnits - take)
                opened = false; officialR = individually ? take : 0
            } else if lot.sealedContainers > 0 {
                lot.sealedContainers -= 1
                lot.openedRemaining = rounded(Double(lot.unitsPerContainer) - take)
                opened = true; officialR = individually ? take : 1
            } else { return .pending("Inconsistencia del remanente físico.") }
            working[i] = lot
            parts.append(PlannedIssue(lotID: lot.id, physicalAmount: take,
                                      excelR: officialR, openedNewContainer: opened))
            remaining = rounded(remaining - take)
        }
        guard remaining <= 0.00001 else { return .pending("Demasiados movimientos FEFO.") }
        return FEFOPlan(issues: parts, pendingReason: nil)
    }
}
