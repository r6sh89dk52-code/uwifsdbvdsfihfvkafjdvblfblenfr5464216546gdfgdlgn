import Foundation

/// Session/view-owned value, never persisted. Fold each row once, rather than
/// re-running locale matching for all 9,648 people on every SwiftUI redraw.
/// Keeps original rows and ordering; it does not modify clinical identities.
public struct N2SearchIndex<Row:Sendable>:Sendable {
    private let rows:[Row]
    private let searchable:[String]
    public init(rows:[Row],fields:(Row)->String) {
        self.rows=rows
        searchable=rows.map{Self.fold(fields($0))}
    }
    private static func fold(_ value:String)->String {
        value.folding(options:[.caseInsensitive,.diacriticInsensitive,.widthInsensitive],
                      locale:Locale(identifier:"es_PE"))
    }
    public func matches(_ text:String,minimumLength:Int=2,limit:Int?=nil)->[Row] {
        let q=Self.fold(text.trimmingCharacters(in:.whitespacesAndNewlines))
        guard q.count>=minimumLength,limit.map({$0>0}) ?? true else{return []}
        var result=[Row]()
        for index in rows.indices where searchable[index].contains(q) {
            result.append(rows[index])
            if let limit,result.count>=limit {break}
        }
        return result
    }
}
