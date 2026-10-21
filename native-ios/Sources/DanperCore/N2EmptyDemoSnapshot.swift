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
        _=try N1eLegacyClinicalAudit.inspect(source)
        _=try N1fLosslessFieldGate.inspect(source)
        return source
    }
}
