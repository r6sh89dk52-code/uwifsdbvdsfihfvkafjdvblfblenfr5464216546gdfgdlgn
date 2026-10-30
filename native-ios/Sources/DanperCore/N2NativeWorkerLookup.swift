import Foundation

/// Uses the persisted clinical roster as the only source of worker identity.
/// Never guesses a worker by an incomplete DNI or creates a clinical record.
public enum N2NativeWorkerLookup {
    public static func numericDNI(_ text:String)->String {
        String(decoding:text.utf8.filter{(48...57).contains($0)}.prefix(8),
               as:UTF8.self)
    }
    public static func exactDNI(_ text:String,in workers:[N2FormWorker])->N2FormWorker? {
        let clean=numericDNI(text)
        guard clean.count==8 else{return nil}
        return workers.first(where:{$0.dni==clean})
    }
    public static func nameMatches(_ text:String,in workers:[N2FormWorker],
                                   limit:Int=5)->[N2FormWorker] {
        let query=text.trimmingCharacters(in:.whitespacesAndNewlines)
        guard query.count>=2,limit>0 else{return []}
        // Stop as soon as enough suggestions exist; do not materialize all
        // matches across the 10k-person directory on every typed character.
        return Array(workers.lazy.filter {
            $0.name.localizedStandardContains(query) ||
            $0.dni.localizedStandardContains(query)
        }.prefix(limit))
    }
}
