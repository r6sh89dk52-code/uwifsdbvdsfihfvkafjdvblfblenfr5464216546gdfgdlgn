import Foundation
import DanperCore

/// Read-only presentation classification. Never writes catalog or inventory.
/// Unknown/conflicting official groups remain visible in Todos, never guessed.
enum N2InventoryFilter:String,CaseIterable,Identifiable {
    case all="Todos",medications="Medicamentos",supplies="Insumos"
    var id:String {rawValue}
}
enum N2InventoryPresentation {
    static func category(code:String,catalog:N2NativeCatalogIndex)->N2InventoryFilter? {
        let options=catalog.authorizedNursingOptions(for:code)
        let categories=Set(options.compactMap { product -> String? in
            switch product.group {
            case "TABLETAS","AMPOLLAS":return N2InventoryFilter.medications.rawValue
            case "JERINGAS","INSUMOS":return N2InventoryFilter.supplies.rawValue
            default:return nil
            }
        })
        guard !options.isEmpty,categories.count==1,
              options.allSatisfy({["TABLETAS","AMPOLLAS","JERINGAS","INSUMOS"].contains($0.group)})
        else{return nil}
        return N2InventoryFilter(rawValue:categories.first!)
    }
    static func products(_ products:[N2SimpleProduct],catalog:N2NativeCatalogIndex,
                         filter:N2InventoryFilter,query:String)->[N2SimpleProduct] {
        let q=query.trimmingCharacters(in:.whitespacesAndNewlines)
        return products.filter { p in
            (filter == .all || category(code:p.code,catalog:catalog)==filter) &&
            (q.isEmpty || [p.name,p.code,p.unit].contains{$0.localizedStandardContains(q)})
        }
    }
    // Same 30-day warning horizon as v2. Reference only, never FEFO or stock logic.
    static let expiryWarningDays=30
    enum Expiry:String {case valid="Vigente",near="Próximo a vencer",expired="Vencido",unverified="Pendiente de verificar"}
    static func expiry(_ product:N2SimpleProduct,now:Date=Date())->Expiry {
        guard product.expiryVerified,!product.expiry.isEmpty else{return .unverified}
        let today=N2SimpleInventory.day(Int64(now.timeIntervalSince1970*1000))
        let horizon=N2SimpleInventory.day(Int64(now.addingTimeInterval(Double(expiryWarningDays)*86400).timeIntervalSince1970*1000))
        if product.expiry<today {return .expired}
        return product.expiry<=horizon ? .near:.valid
    }
    static func expiryText(_ product:N2SimpleProduct,now:Date=Date())->String {
        let state=expiry(product,now:now)
        return state == .unverified ? state.rawValue : state.rawValue+" · "+DanperDatePresentation.display(product.expiry)
    }
    static func symbol(_ product:N2SimpleProduct,catalog:N2NativeCatalogIndex)->String {
        let group=catalog.authorizedNursingOptions(for:product.code).first?.group
        let name=product.name.folding(options:[.diacriticInsensitive,.caseInsensitive],locale:Locale(identifier:"es_PE"))
        // Illustration only. These words never assign a category or unit.
        if group=="TABLETAS" {return "pills.fill"}
        if group=="AMPOLLAS" || group=="JERINGAS" {return "syringe.fill"}
        if group=="INSUMOS" {
            if name.contains("GUANTE") {return "hand.raised.fill"}
            if name.contains("VENDA") || name.contains("GASA") || name.contains("CURITA") {return "bandage.fill"}
            if product.unit=="FCO" {return "waterbottle.fill"}
            return "cross.case.fill"
        }
        return "shippingbox.fill"
    }
}
