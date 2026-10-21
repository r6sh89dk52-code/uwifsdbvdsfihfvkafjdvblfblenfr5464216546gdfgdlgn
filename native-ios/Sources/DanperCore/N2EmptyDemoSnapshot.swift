import Foundation

/// Canonical zero-record source for the isolated N2 demonstration.
/// It must NEVER contain the five-worker fixture or imported clinical data.
public enum N2EmptyDemoSnapshot {
    public static func make()throws->Data {
        let empty:[String:Any]=[
            "workers":[[String:Any]](),
            "attentions":[[String:Any]](),
            "allergies":[String:Any](),
            "stockLots":[[String:Any]](),
            "stockMovements":[[String:Any]](),
            "catalogMappings":[[String:Any]](),
            "deliveryIncidents":[[String:Any]](),
            "ambulatoryReconciliation":[[String:Any]](),
            "notifications":false
        ]
        let source=try JSONSerialization.data(withJSONObject:empty,
                                               options:[.sortedKeys])
        _=try N1fLosslessFieldGate.inspect(source)
        return source
    }

    /// Narrow, exact-shape exception for displaying an empty DEMO workspace.
    /// This is NOT a valid clinical backup or a real-source import.
    public static func matches(_ data:Data)->Bool {
        guard let root=try? JSONSerialization.jsonObject(with:data) as? [String:Any],
              Set(root.keys)==Set(["workers","attentions","allergies",
                  "stockLots","stockMovements","catalogMappings",
                  "deliveryIncidents","ambulatoryReconciliation","notifications"]),
              root["notifications"] as? Bool == false,
              (root["allergies"] as? [String:Any])?.isEmpty==true else {
            return false
        }
        return ["workers","attentions","stockLots","stockMovements",
                "catalogMappings","deliveryIncidents","ambulatoryReconciliation"]
            .allSatisfy{(root[$0] as? [Any])?.isEmpty==true}
    }
}
