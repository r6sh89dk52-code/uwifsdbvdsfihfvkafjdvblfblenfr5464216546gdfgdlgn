import Foundation

/// Keyboard-first date entry for clinical staff. Accepts pasted DDMMYYYY,
/// DD/MM/YYYY or "DD MM YYYY", showing DD/MM/YYYY automatically.
/// No calendar picker or birth date is guessed from a manually entered age.
public enum N2WorkerBirthDateEntry {
    public static func digits(_ text:String)->String {
        let ascii=text.utf8.filter{(48...57).contains($0)}
        return String(decoding:ascii.prefix(8),as:UTF8.self)
    }

    public static func format(_ input:String)->String {
        let value=digits(input)
        if value.count<=2 {return value}
        let dd=String(value.prefix(2))
        let tail=String(value.dropFirst(2))
        if tail.count<=2 {return dd+"/"+tail}
        return dd+"/"+String(tail.prefix(2))+"/"+String(tail.dropFirst(2))
    }

    public static func isoDate(_ input:String)->String? {
        let value=digits(input)
        guard value.count==8 else{return nil}
        let day=String(value.prefix(2))
        let month=String(value.dropFirst(2).prefix(2))
        let year=String(value.suffix(4))
        return year+"-"+month+"-"+day
    }

    public static func validatedISO(_ input:String,on today:String)->String? {
        guard let iso=isoDate(input),
              N2WorkerAge.years(birthDate:iso,on:today) != nil else{return nil}
        return iso
    }

    /// Age without a known birthday is an estimate at registration. Do not
    /// automatically increment it in later years or create a fictional DOB.
    public static func manualAge(_ input:String)->Int? {
        guard !input.isEmpty,input.count<=3,
              input.utf8.allSatisfy({(48...57).contains($0)}),
              let age=Int(input),(0...120).contains(age) else{return nil}
        return age
    }
}
