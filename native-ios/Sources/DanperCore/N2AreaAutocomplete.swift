import Foundation

public struct N2OfficialArea: Codable, Equatable, Sendable {
    public let site:String
    public let area:String
    public let code:String
    public init(site:String,area:String,code:String) {
        self.site=site;self.area=area;self.code=code
    }
}

public enum N2AreaAutocomplete {
    public static let expectedOfficialCounts:[String:Int]=[
        "LA VENTUROSA":31,
        "PLVENTUROSA":124
    ]
    /// Friendly operator terms, not official codes. Each site has its own text suggestions.
    /// These names are never treated as an approved organization code unless they
    /// separately match an official area for the selected site.
    private static let additionalFundoAreas=[
        "Fitosanidad",
        "Servicio de Salud",
        "Departamento de Operaciones",
        "Mantenimiento de Sistema de Riego",
        "Producción Agrícola Palto"
    ]
    private static let additionalPlantAreas=[
        "Empaque",
        "Operaciones Fresco"
    ]
    public static func normalize(_ text:String)->String {
        text.folding(options:[.diacriticInsensitive,.caseInsensitive],
                     locale:Locale(identifier:"es_PE"))
            .trimmingCharacters(in:.whitespacesAndNewlines)
            .split(whereSeparator:{$0.isWhitespace})
            .joined(separator:" ")
    }
    public static func officialCount(site:String,official:[N2OfficialArea])->Int {
        official.filter{$0.site==site}.count
    }
    public static func isComplete(official:[N2OfficialArea])->Bool {
        expectedOfficialCounts.allSatisfy{site,count in
            officialCount(site:site,official:official)==count
        }
    }
    private static func rank(_ candidate:String,needle:String)->Int {
        let normalized=normalize(candidate)
        if normalized==needle {return 0}
        if normalized.hasPrefix(needle) {return 1}
        if normalized.split(separator:" ").contains(where:{$0.hasPrefix(needle)}) {return 2}
        return 3
    }
    /// Full, site-scoped directory. A blank query lists every area at that site;
    /// callers can use a LazyVStack to browse all 31 / 124 entries.
    public static func suggestions(query:String,site:String,official:[N2OfficialArea],
                                   known:[String],limit:Int=250)->[String] {
        guard expectedOfficialCounts[site] != nil,limit>0 else{return []}
        let needle=normalize(query)
        let preferred=official.filter{$0.site==site}.map(\.area)
        let additional=site=="PLVENTUROSA" ? additionalPlantAreas : additionalFundoAreas
        let combined=preferred+known+additional
        var candidates=[(name:String,sourceRank:Int)]()
        var seen=Set<String>()
        for (index,item) in combined.enumerated() {
            let key=normalize(item)
            if !key.isEmpty && seen.insert(key).inserted {
                candidates.append((item,index<preferred.count ? 0 : 1))
            }
        }
        let matches=candidates.filter {
            needle.isEmpty || normalize($0.name).contains(needle)
        }
        return matches.sorted{a,b in
            let lhs=needle.isEmpty ? 0:rank(a.name,needle:needle)
            let rhs=needle.isEmpty ? 0:rank(b.name,needle:needle)
            if lhs != rhs{return lhs<rhs}
            if a.sourceRank != b.sourceRank{return a.sourceRank<b.sourceRank}
            return a.name.localizedStandardCompare(b.name) == ComparisonResult.orderedAscending
        }.prefix(limit).map(\.name)
    }
}
