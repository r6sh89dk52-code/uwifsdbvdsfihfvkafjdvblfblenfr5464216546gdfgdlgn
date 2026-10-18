import Foundation

/// Conservative literal-name match used by build222. A textual match is a
/// warning, NOT a clinical assessment, indication or confirmation of safety.
/// No ingredient equivalence, class allergy or cross-reactivity is inferred.
public enum N2MedicationAllergyTextMatch {
    private static func norm(_ text:String)->String {
        text.folding(options:[.diacriticInsensitive,.caseInsensitive],
                     locale:Locale(identifier:"es_PE"))
            .trimmingCharacters(in:.whitespacesAndNewlines)
    }
    public static func matches(productName:String,substances:String)->[String] {
        let name=norm(productName)
        return substances.components(separatedBy:CharacterSet(charactersIn:",;\n"))
            .map{$0.trimmingCharacters(in:.whitespacesAndNewlines)}
            .filter{$0.count>=3 && name.contains(norm($0))}
    }
}
