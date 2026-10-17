import Foundation

public struct N2ClinicalCatalogProduct:Equatable,Sendable,Identifiable {
    public var id:String{code}
    public let code:String
    public let name:String
    public let unit:String
}
public struct N2NursingCatalogProduct:Equatable,Sendable,Identifiable {
    public let id:String
    public let name:String
    public let group:String
}
public struct N2ApprovedProductLink:Equatable,Sendable {
    public let clinicalCode:String
    public let kardexID:String
}
public enum N2CatalogError:Error,Equatable {
    case invalidClinicalCatalog, invalidNursingCatalog, invalidApprovals
}
public struct N2NativeCatalogIndex:Sendable {
    public let clinical:[N2ClinicalCatalogProduct]
    public let nursing:[N2NursingCatalogProduct]
    public let approvals:[N2ApprovedProductLink]

    public func clinicalMatches(_ query:String)->[N2ClinicalCatalogProduct] {
        let q=query.trimmingCharacters(in:.whitespacesAndNewlines)
        guard !q.isEmpty else{return clinical}
        return clinical.filter{$0.code.localizedStandardContains(q) ||
                               $0.name.localizedStandardContains(q)}
    }
    public func nursingMatches(_ query:String)->[N2NursingCatalogProduct] {
        let q=query.trimmingCharacters(in:.whitespacesAndNewlines)
        guard !q.isEmpty else{return nursing}
        return nursing.filter{$0.id.localizedStandardContains(q) ||
                              $0.name.localizedStandardContains(q) ||
                              $0.group.localizedStandardContains(q)}
    }
    public func authorizedNursingOptions(for clinicalCode:String)->[N2NursingCatalogProduct] {
        let codes=Set(approvals.filter{$0.clinicalCode==clinicalCode}.map{$0.kardexID})
        return nursing.filter{codes.contains($0.id)}
    }
}
public enum N2NativeCatalogLoader {
    public static func load(products:Data,nursing:Data,
                            approvedMappings:Data)throws->N2NativeCatalogIndex {
        guard let p=try? JSONSerialization.jsonObject(with:products) as? [[String:Any]],
              p.count==432 else{throw N2CatalogError.invalidClinicalCatalog}
        var clinical=[N2ClinicalCatalogProduct](),codes=Set<String>()
        for row in p {
            guard let id=row["code"] as? String,
                  !id.isEmpty,id.utf8.allSatisfy({(48...57).contains($0)}),
                  let name=row["name"] as? String,!name.isEmpty,
                  let unit=row["unit"] as? String,!unit.isEmpty,
                  codes.insert(id).inserted else {
                throw N2CatalogError.invalidClinicalCatalog
            }
            clinical.append(N2ClinicalCatalogProduct(code:id,name:name,unit:unit))
        }
        guard let n=try? JSONSerialization.jsonObject(with:nursing) as? [[String:Any]],
              n.count==98 else{throw N2CatalogError.invalidNursingCatalog}
        var supplies=[N2NursingCatalogProduct]()
        for (offset,row) in n.enumerated() {
            guard let id=row["id"] as? String,id=="E-\(offset+1)",
                  let name=row["name"] as? String,!name.isEmpty,
                  let group=row["group"] as? String,!group.isEmpty,
                  row["donated"] as? Bool == false else{
                throw N2CatalogError.invalidNursingCatalog
            }
            supplies.append(N2NursingCatalogProduct(id:id,name:name,group:group))
        }
        guard let a=try? JSONSerialization.jsonObject(with:approvedMappings)
            as? [[String:Any]],a.count==86 else{
            throw N2CatalogError.invalidApprovals
        }
        var unique=Set<String>(),links=[N2ApprovedProductLink]()
        for item in a {
            guard let code=item["clinicalCode"] as? String,
                  let cid=item["kardexCode"] as? String,
                  let source=clinical.first(where:{$0.code==code}),
                  let dest=supplies.first(where:{$0.id==cid}),
                  item["clinicalName"] as? String == source.name,
                  item["clinicalUnit"] as? String == source.unit,
                  item["kardexName"] as? String == dest.name,
                  unique.insert(cid).inserted else {
                throw N2CatalogError.invalidApprovals
            }
            links.append(N2ApprovedProductLink(clinicalCode:code,kardexID:cid))
        }
        guard unique.count==86,!unique.contains("E-68"),
              links.filter{$0.clinicalCode=="16024400"}.count==2 else{
            throw N2CatalogError.invalidApprovals
        }
        return N2NativeCatalogIndex(clinical:clinical,nursing:supplies,
                                    approvals:links)
    }
}
