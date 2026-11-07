import Foundation

/// Read-only evidence alongside the institutional formulas.
struct N2IndicatorStockObservation {
    struct Row {
        let code: String
        let name: String
        let unit: String
        let opening: Double?
        let closing: Double?
        let current: Double?
        let closingStatus: String
        let lastMovement: String?
    }

    let reference: String
    let rows: [Row]

    static func make(inventory: N2SimpleInventoryState, catalogue: [[String: Any]],
                     openings: [String: [String: Any]], visitDayByID: [String: String],
                     end: String, observedAt: Date) -> Self {
        func formatter(_ format: String) -> DateFormatter {
            let result = DateFormatter()
            result.locale = Locale(identifier: "en_US_POSIX")
            result.timeZone = TimeZone(identifier: "America/Lima")
            result.dateFormat = format
            return result
        }
        let dateFormatter = formatter("yyyy-MM-dd")
        let timestamp = formatter("yyyy-MM-dd HH:mm:ss")
        let observationDay = dateFormatter.string(from: observedAt)
        let observedMillis = observedAt.timeIntervalSince1970 * 1000
        func date(_ at: Int64) -> Date { Date(timeIntervalSince1970: Double(at) / 1000) }
        var days: [Int64: String] = [:]
        func day(_ at: Int64) -> String {
            if let known = days[at] { return known }
            let value = dateFormatter.string(from: date(at))
            days[at] = value
            return value
        }
        let products = Dictionary(uniqueKeysWithValues: inventory.products.map { ($0.code, $0) })
        let movements = Dictionary(grouping: inventory.movements, by: \.code)
        let incidents = Dictionary(grouping: inventory.incidents, by: \.code)
        let history = Dictionary(grouping: inventory.historicalUses, by: \.code)
        var materials = catalogue
        let catalogCodes = Set(catalogue.compactMap { $0["code"] as? String })
        materials += inventory.products.filter { !catalogCodes.contains($0.code) }.sorted { $0.code < $1.code }
            .map { ["code": $0.code, "name": $0.name, "unit": $0.unit] }

        func closingEvidence(_ code: String, events: [N2SimpleMovement]) -> (Double?, String) {
            guard end < observationDay else { return (nil, "NO VERIFICADO · día de cierre aún abierto") }
            guard let last = events.lastIndex(where: { day($0.at) <= end }),
                  let anchor = events[...last].last(where: { $0.kind == "initial" || $0.kind == "count" })
            else { return (nil, "NO VERIFICADO · sin ancla al corte") }

            func hasGap(from: String, through: String, fromTime: Int64, toTime: Int64?) -> Bool {
                let hasArchivedUse = (history[code] ?? []).contains { use in
                    guard let date = visitDayByID[use.visitID] else { return true }
                    return date >= from && date <= through
                }
                let hasIncident = (incidents[code] ?? []).contains { incident in
                    incident.clinicalAt >= fromTime && day(incident.clinicalAt) >= from &&
                    day(incident.clinicalAt) <= through && (toTime.map { incident.clinicalAt <= $0 } ?? true)
                }
                return hasArchivedUse || hasIncident
            }
            guard !hasGap(from: day(anchor.at), through: end, fromTime: anchor.at, toTime: nil) else {
                return (nil, "NO VERIFICADO · historial con cobertura incompleta")
            }
            if day(anchor.at) == end && anchor.id == events[last].id {
                return (anchor.after, "Conteo registrado el día del cierre")
            }
            if let countIndex = events.indices.dropFirst(last + 1).first(where: { events[$0].kind == "count" }) {
                let count = events[countIndex]
                // An adjustment with an unknown effective date cannot
                // be reversed across a historical cut.
                let between = events[(last + 1)..<countIndex]
                let covered = count.before == count.after &&
                    between.allSatisfy { $0.kind == "receipt" || $0.kind == "outflow" } &&
                    !hasGap(from: end, through: day(count.at), fromTime: events[last].at, toTime: count.at)
                let calculated = N2SimpleInventory.round(count.after - between.reduce(0.0) { $0 + $1.delta })
                guard covered, calculated == events[last].after else {
                    return (nil, "NO VERIFICADO · recuento posterior sin continuidad acreditada")
                }
                return (calculated, "Verificado por recuento posterior y movimientos")
            }
            return (events[last].after, "Saldo registrado al corte en el Kardex")
        }

        let evidence = materials.map { material -> Row in
            let code = material["code"] as? String ?? ""
            let product = products[code]
            let events = movements[code] ?? []
            let (closing, status) = closingEvidence(code, events: events.filter { Double($0.at) <= observedMillis })
            return Row(code: code, name: product?.name ?? material["name"] as? String ?? "",
                       unit: product?.unit ?? material["unit"] as? String ?? "",
                       opening: openings[code]?["opening"] as? Double,
                       closing: closing, current: product?.quantity, closingStatus: status,
                       lastMovement: events.last.map { timestamp.string(from: date($0.at)) })
        }
        return Self(reference: timestamp.string(from: observedAt), rows: evidence)
    }
}
