import Foundation

/// Session/view-owned value, never persisted. Fold each row once, rather than
/// re-running locale matching for all 9,648 people on every SwiftUI redraw.
/// Keeps original rows and ordering; it does not modify clinical identities.
public struct N2SearchIndex<Row:Sendable>:Sendable {
    private let rows:[Row]
    private let searchable:[String]
    private let postings:[String:[Int]]
    public init(rows:[Row],fields:(Row)->String) {
        self.rows=rows
        let folded=rows.map{Self.fold(fields($0))}
        searchable=folded
        var buckets=[String:[Int]]()
        for (index,text) in folded.enumerated() {
            for pair in Self.pairs(text) {buckets[pair,default:[]].append(index)}
        }
        postings=buckets
    }
    private static func fold(_ value:String)->String {
        value.folding(options:[.caseInsensitive,.diacriticInsensitive,.widthInsensitive],
                      locale:Locale(identifier:"es_PE"))
    }
    private static func pairs(_ text:String)->Set<String> {
        let characters=Array(text)
        guard characters.count>=2 else{return []}
        return Set((1..<characters.count).map{String(characters[$0-1])+String(characters[$0])})
    }
    public func matches(_ text:String,minimumLength:Int=2,limit:Int?=nil)->[Row] {
        let q=Self.fold(text.trimmingCharacters(in:.whitespacesAndNewlines))
        guard q.count>=minimumLength,limit.map({$0>0}) ?? true else{return []}
        // A full substring must contain each adjacent pair. Start with the
        // rarest posting list, retain source order and verify the entire query.
        // No patient/query cache or index is persisted outside this value.
        var candidates:[Int]?
        for pair in Self.pairs(q) {
            guard let bucket=postings[pair] else{return []}
            if candidates == nil || bucket.count<candidates!.count {candidates=bucket}
        }
        var result=[Row]()
        result.reserveCapacity(min(limit ?? 25,rows.count))
        for index in candidates ?? Array(rows.indices) where searchable[index].contains(q) {
            result.append(rows[index])
            if let limit,result.count>=limit {break}
        }
        return result
    }
}
