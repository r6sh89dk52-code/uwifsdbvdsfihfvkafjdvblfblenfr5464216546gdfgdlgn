import Foundation
// Synthetic scalar lot, with the same NSNumber/Bool bridging as JSON fixtures.
let fixture = #"{"id":"synthetic-portability","catalogUnit":"FCO","sealedContainers":2,"unitsPerContainer":1,"openedRemaining":1,"looseUnits":0,"declaredOpenContainers":1,"volumeTrackingEnabled":false,"updatedAt":1794160800000}"#
let before = try JSONSerialization.jsonObject(with:Data(fixture.utf8)) as! [String:Any]
var after=before
after["declaredOpenContainers"]=0;after["openedRemaining"]=0;after["looseUnits"]=0
after["updatedAt"]=Int64(1794247200000);after["volumeTrackingEnabled"]=false
for key in ["openedRemaining","looseUnits","declaredOpenContainers","updatedAt","volumeTrackingEnabled"] {
    after[key]=before[key]
}
let canonicalBefore=try JSONSerialization.data(withJSONObject:before,options:.sortedKeys)
let canonicalAfter=try JSONSerialization.data(withJSONObject:after,options:.sortedKeys)
print("SYNTHETIC_PORTABILITY FoundationDictionarySelfEqual=\(NSDictionary(dictionary:before).isEqual(to:before))")
print("SYNTHETIC_PORTABILITY FoundationReconstructedEqual=\(NSDictionary(dictionary:after).isEqual(to:before))")
print("SYNTHETIC_PORTABILITY CanonicalJSONEqual=\(canonicalBefore==canonicalAfter)")
for key in before.keys.sorted() {print("TYPE \(key): \(type(of:before[key]!)) / \(type(of:after[key]!))")}
