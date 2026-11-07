import Foundation

/// Date boundaries and balances for the shared, audited physical ledger.
/// The source snapshot is read-only. A count replaces the running balance.
struct N2IndicatorStockObservation {
    struct Period {
        let start: Int64
        let end: Int64
        let observed: Int64
        let endsInFuture: Bool
        private let clock: DateFormatter
        private let days: DateFormatter

        init(start: String, end: String, observedAt: Date) {
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = TimeZone(identifier: "America/Lima")!
            func formatter(_ format: String) -> DateFormatter {
                let value = DateFormatter()
                value.calendar = calendar
                value.timeZone = calendar.timeZone
                value.locale = Locale(identifier: "en_US_POSIX")
                value.dateFormat = format
                return value
            }
            let dayFormatter = formatter("yyyy-MM-dd")
            days = dayFormatter
            clock = formatter("yyyy-MM-dd HH:mm")
            func millis(_ date: Date) -> Int64 { Int64(date.timeIntervalSince1970 * 1000) }
            // The caller has already validated both Gregorian dates.
            self.start = millis(dayFormatter.date(from: start)!)
            let lastDay = dayFormatter.date(from: end)!
            let nextDay = calendar.date(byAdding: .day, value: 1, to: lastDay)!
            observed = millis(observedAt)
            self.end = min(millis(nextDay), observed + 1)
            endsInFuture = end > dayFormatter.string(from: observedAt)
        }

        func visitTime(day: String, time: String) -> Int64? {
            clock.date(from: day + " " + time).map { Int64($0.timeIntervalSince1970 * 1000) }
        }

        func day(_ at: Int64) -> String {
            days.string(from: Date(timeIntervalSince1970: Double(at) / 1000))
        }
    }

    struct Balance {
        let quantity: Double
        let estimated: Bool
    }

    struct Row {
        let opening: Balance?
        let closing: Balance?
        let income: Double?
        let receipts: [[String: Any]]
        let count: Double?
        let difference: Double?
        let completeCoverage: Bool

        var note: String {
            var notes: [String] = []
            if opening == nil { notes.append("Inicial no verificado") }
            if closing == nil { notes.append("Final no verificado") }
            if opening?.estimated == true || closing?.estimated == true {
                let affected = [opening?.estimated == true ? "inicial" : nil,
                                closing?.estimated == true ? "final" : nil].compactMap { $0 }
                notes.append("ESTIMADO (" + affected.joined(separator: " y ") +
                    "): conteo y consumos acreditados. Ingresos y ajustes anteriores al primer conteo sin cobertura")
            }
            if income != nil && !completeCoverage { notes.append("Ingresos registrados, cobertura parcial") }
            if difference != nil { notes.append("Diferencia: saldo previo al conteo menos conteo") }
            return notes.joined(separator: " · ")
        }
    }

    static func make(inventory: N2SimpleInventoryState, period: Period,
                     visitTimes: [String: Int64]) -> [String: Row] {
        let movements = Dictionary(grouping: inventory.movements.filter { $0.at <= period.observed }, by: \.code)
        let incidents = Dictionary(grouping: inventory.incidents, by: \.code)
        let history = Dictionary(grouping: inventory.historicalUses, by: \.code)
        var result: [String: Row] = [:]
        for product in inventory.products {
            let code = product.code
            let events = movements[code] ?? []
            guard let first = events.first else { continue }
            let byID = Dictionary(uniqueKeysWithValues: events.map { ($0.id, $0) })
            let archived = history[code] ?? []
            let productIncidents = incidents[code] ?? []
            func isCount(_ event: N2SimpleMovement) -> Bool {
                event.kind == "initial" || event.kind == "count"
            }
            func hasGap(from lower: Int64, until upper: Int64) -> Bool {
                archived.contains { use in
                    guard let at = visitTimes[use.visitID] else { return true }
                    return at >= lower && at < upper
                } || productIncidents.contains { incident in
                    guard incident.clinicalAt >= lower && incident.clinicalAt < upper else { return false }
                    // A linked physical outflow within this interval is
                    // already in the ledger. Never add the clinical quantity again.
                    guard let id = incident.resolutionEventID,
                          let event = byID[id], event.kind == "outflow",
                          event.at >= lower, event.at < upper else { return true }
                    return false
                }
            }

            func balance(before boundary: Int64, reconcileLater: Bool) -> Balance? {
                guard boundary <= period.observed + 1 else { return nil }
                guard let last = events.lastIndex(where: { $0.at < boundary }) else {
                    // The first count establishes current stock, but it does
                    // not prove unrecorded receipts or adjustments before it.
                    let use = archived.filter { visitTimes[$0.visitID].map { $0 >= boundary && $0 < first.at } ?? true }
                    guard !use.isEmpty, use.allSatisfy({
                        visitTimes[$0.visitID] != nil && $0.unit == product.unit &&
                        $0.sourceSHA256 == inventory.regime.sourceSHA256 && $0.verifiedR != nil
                    }), !productIncidents.contains(where: { $0.clinicalAt >= boundary && $0.clinicalAt < first.at })
                    else { return nil }
                    let quantity = N2SimpleInventory.round(first.after + use.reduce(0) { $0 + ($1.verifiedR ?? 0) })
                    guard N2SimpleInventory.validQuantity(quantity) else { return nil }
                    return Balance(quantity: quantity, estimated: true)
                }

                guard let anchor = events[...last].last(where: isCount),
                      !hasGap(from: anchor.at, until: boundary) else { return nil }
                let preceding = events[last]
                if reconcileLater, !(isCount(preceding) && period.day(preceding.at) == period.day(boundary - 1)),
                   let later = events.indices.dropFirst(last + 1).first(where: { isCount(events[$0]) }) {
                    let count = events[later]
                    let between = events[(last + 1)..<later]
                    // A discrepancy at a later count cannot be assigned
                    // to one side of the requested boundary.
                    guard count.before == count.after, !hasGap(from: boundary, until: count.at + 1) else { return nil }
                    let quantity = N2SimpleInventory.round(count.after - between.reduce(0) { $0 + $1.delta })
                    guard quantity == preceding.after else { return nil }
                    return Balance(quantity: quantity, estimated: false)
                }
                return Balance(quantity: preceding.after, estimated: false)
            }

            let opening = balance(before: period.start, reconcileLater: false)
            let closing = period.endsInFuture ? nil : balance(before: period.end, reconcileLater: true)
            let within = events.filter { $0.at >= period.start && $0.at < period.end }
            let grouped = Dictionary(grouping: within.filter { $0.kind == "receipt" }, by: { period.day($0.at) })
            let receiptDays = grouped.keys.sorted()
            var receipts: [[String: Any]] = receiptDays.prefix(receiptDays.count > 4 ? 3 : 4).map { day in
                ["date": day, "quantity": N2SimpleInventory.round(grouped[day]!.reduce(0) { $0 + $1.delta }),
                 "document": "KARDEX CONSOLIDADO"]
            }
            if receiptDays.count > 4 {
                let remainder = receiptDays.dropFirst(3)
                let amount = remainder.reduce(0.0) { sum, day in
                    sum + grouped[day]!.reduce(0) { $0 + $1.delta }
                }
                receipts.append(["quantity": N2SimpleInventory.round(amount),
                                 "document": "CONSOLIDADO · \(remainder.count) DÍAS (ver Kardex)"])
            }
            let complete = opening?.estimated == false && !period.endsInFuture &&
                !hasGap(from: period.start, until: period.end)
            let income = complete || !receiptDays.isEmpty
                ? N2SimpleInventory.round(within.filter { $0.kind == "receipt" }.reduce(0) { $0 + $1.delta }) : nil

            var physicalCount: Double?
            var difference: Double?
            if !period.endsInFuture, let last = within.last, isCount(last),
               period.day(last.at) == period.day(period.end - 1),
               !hasGap(from: last.at, until: period.end) {
                physicalCount = last.after
                // An initial registration has no independently known
                // previous balance, even if the stored before is zero.
                if last.kind == "count",
                   let priorCount = events.prefix(while: { $0.id != last.id }).last(where: isCount),
                   !hasGap(from: priorCount.at, until: last.at + 1) {
                    difference = N2SimpleInventory.round(last.before - last.after)
                }
            }
            result[code] = Row(opening: opening, closing: closing, income: income, receipts: receipts,
                               count: physicalCount, difference: difference, completeCoverage: complete)
        }
        return result
    }
}
