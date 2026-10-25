import Foundation

/// User-reviewed links from the 2026-10-23 batch matrix.
/// These never modify the 86 original, separately approved associations.
/// They do not create stock, infer clinical equivalence or authorize
/// unknown physical conversions.
public enum N2UserReviewedKardexLinks {
    public struct Link:Sendable,Equatable {
        public let kardexID:String
        public let kardexName:String
        public let clinicalCode:String
        public let clinicalName:String
        public let clinicalUnit:String
        /// Different source labels require physical presentation verification.
        public let requiresPhysicalReview:Bool
    }
    public static let links:[Link]=[
        Link(kardexID:"E-20",kardexName:"OMEPRAZOL TAB",
             clinicalCode:"16025008",clinicalName:"OMEPRAZOL CAPSULA 20MG",
             clinicalUnit:"UND",requiresPhysicalReview:true),
        Link(kardexID:"E-68",kardexName:"NYLON AZUL 3/0",
             clinicalCode:"16000178",clinicalName:"NYLON AGUJA 3/0 PUNTA CORTANTE UNILENE",
             clinicalUnit:"UND",requiresPhysicalReview:true),
        Link(kardexID:"E-86",kardexName:"ALCOHOL 1 LT",
             clinicalCode:"16000019",clinicalName:"ALCOHOL 96º (USO TOPICO)",
             clinicalUnit:"LT",requiresPhysicalReview:false),
        Link(kardexID:"E-94",kardexName:"GUANTES LIMPIOS M",
             clinicalCode:"10000929",clinicalName:"GUANTE CRANBERRY QUIRURGICO TA M X100UN",
             clinicalUnit:"UND",requiresPhysicalReview:true),
        Link(kardexID:"E-95",kardexName:"GUANTES LIMPIOS S",
             clinicalCode:"16000127",clinicalName:"GUANTE CRANBERRY QUIRURGICO TA S X100UND",
             clinicalUnit:"CJA",requiresPhysicalReview:true),
        Link(kardexID:"E-97",kardexName:"PROTECTOR SOLAR SPF 110GR",
             clinicalCode:"16021493",clinicalName:"BLOQUEADOR SOLAR SPF 60 BAHIA 110GR",
             clinicalUnit:"UND",requiresPhysicalReview:true)
    ]
    /// Explicitly marked NO CORRESPONDE; all remain in the 98-row ledger.
    public static let unmatched:Set<String>=["E-25","E-81","E-82","E-84","E-85","E-98"]

    public static func validate(clinical:[N2ClinicalCatalogProduct],
                                nursing:[N2NursingCatalogProduct],
                                approvals:[N2ApprovedProductLink]) throws {
        let byClinical=Dictionary(uniqueKeysWithValues:clinical.map{($0.code,$0)})
        let byNursing=Dictionary(uniqueKeysWithValues:nursing.map{($0.id,$0)})
        guard links.count==6,unmatched.count==6,
              Set(links.map(\.kardexID)).count==links.count,
              Set(links.map(\.clinicalCode)).count==links.count,
              Set(links.map(\.kardexID)).isDisjoint(with:unmatched),
              links.allSatisfy({entry in
                  byClinical[entry.clinicalCode]?.name==entry.clinicalName &&
                  byClinical[entry.clinicalCode]?.unit==entry.clinicalUnit &&
                  byNursing[entry.kardexID]?.name==entry.kardexName &&
                  !approvals.contains(where:{
                      $0.kardexID==entry.kardexID ||
                      $0.clinicalCode==entry.clinicalCode
                  })
              }),
              unmatched.allSatisfy({ id in
                  byNursing[id] != nil &&
                  !approvals.contains(where:{$0.kardexID==id})
              })
        else {throw N2CatalogError.invalidApprovals}
    }
    public static func candidates(for clinicalCode:String)->[Link] {
        links.filter{$0.clinicalCode==clinicalCode}
    }
}
