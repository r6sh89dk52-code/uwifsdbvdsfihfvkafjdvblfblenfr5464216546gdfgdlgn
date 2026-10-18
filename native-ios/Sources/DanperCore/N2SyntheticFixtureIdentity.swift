import Foundation

/// An exact allowlist for the five synthetic identities bundled by the
/// repository's fixture generator. This is not a general-purpose "looks fake"
/// heuristic: real source admission has its own strict audit.
public enum N2SyntheticFixtureIdentity {
    public static let names:[String:String]=[
        "00000001":"Mariana Torres Salazar",
        "00000002":"Luis Paredes Rojas",
        "00000003":"Daniela Campos Vega",
        "00000004":"Carlos Mendoza Ruiz",
        "00000005":"Valeria Ríos Medina"
    ]
    public static func matches(workers:[[String:Any]],visits:[[String:Any]])->Bool {
        guard workers.count==names.count else{return false}
        let byDNI=Dictionary(workers.compactMap { row -> (String,String)? in
            guard let dni=row["dni"] as? String,
                  let name=row["name"] as? String else{return nil}
            return (dni,name)
        },uniquingKeysWith:{a,_ in a})
        guard byDNI.count==names.count,byDNI==names else{return false}
        return visits.allSatisfy { visit in
            guard let worker=visit["worker"] as? [String:Any],
                  let dni=worker["dni"] as? String,
                  let name=worker["name"] as? String,
                  let expected=names[dni],name==expected else{return false}
            return true
        }
    }
}
