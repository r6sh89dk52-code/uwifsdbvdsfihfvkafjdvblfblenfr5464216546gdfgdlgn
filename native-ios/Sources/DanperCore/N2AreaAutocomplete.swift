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
    /// Operator-provided text examples; none is assigned a guessed organizational code.
    public static let commonFreeTextAreas:[String]=[
        "Fitosanidad",
        "Servicio de Salud",
        "Departamento de Operaciones",
        "Mantenimiento de Sistema de Riego",
        "Producción Agrícola Palto"
    ]
    public static func normalize(_ text:String)->String {
        text.folding(options:[.diacriticInsensitive,.caseInsensitive],
                     locale:Locale(identifier:"es_PE"))
            .trimmingCharacters(in:.whitespacesAndNewlines)
            .split(whereSeparator:{$0.isWhitespace})
            .joined(separator:" ")
    }
    private static func rank(_ candidate:String,needle:String)->Int {
        let normalized=normalize(candidate)
        if normalized==needle {return 0}
        if normalized.hasPrefix(needle) {return 1}
        if normalized.split(separator:" ").contains(where:{$0.hasPrefix(needle)}) {return 2}
        return 3
    }
    public static func suggestions(query:String,site:String,official:[N2OfficialArea],
                                   known:[String],limit:Int=8)->[String] {
        let needle=normalize(query)
        guard !needle.isEmpty,limit>0 else{return []}
        let preferred=official.filter{$0.site==site}.map(\.area)
        let other=official.filter{$0.site != site}.map(\.area)
        let combined=preferred+known+other+commonFreeTextAreas
        var names=[String]()
        var seen=Set<String>()
        for candidate in combined {
            let key=normalize(candidate)
            if !key.isEmpty && seen.insert(key).inserted {names.append(candidate)}
        }
        let matched=names.filter{normalize($0).contains(needle)}
        return matched.sorted {left,right in
            let lhs=rank(left,needle:needle),rhs=rank(right,needle:needle)
            if lhs != rhs {return lhs<rhs}
            return left.localizedStandardCompare(right) == .orderedAscending
        }.prefix(limit).map{$0}
    }
}
