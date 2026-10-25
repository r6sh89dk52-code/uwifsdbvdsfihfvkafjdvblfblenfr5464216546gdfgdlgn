import Foundation

/// Reglas de descansos médicos; no lee ni modifica atenciones ni Kardex.
public enum DMDate {
    public static func parse(_ iso:String)->Date? {
        guard iso.range(of:#"^\d{4}-\d{2}-\d{2}$"#,options:.regularExpression) != nil else {return nil}
        let p=iso.split(separator:"-").compactMap{Int($0)}
        guard p.count==3 else{return nil}
        var c=Calendar(identifier:.gregorian);c.timeZone=TimeZone(secondsFromGMT:0)!
        guard let d=c.date(from:DateComponents(year:p[0],month:p[1],day:p[2])),
              c.component(.year,from:d)==p[0],
              c.component(.month,from:d)==p[1],
              c.component(.day,from:d)==p[2] else{return nil}
        return d
    }
    public static func iso(_ date:Date)->String {
        let f=DateFormatter();f.locale=Locale(identifier:"en_US_POSIX")
        f.timeZone=TimeZone(secondsFromGMT:0)!;f.dateFormat="yyyy-MM-dd"
        return f.string(from:date)
    }
    public static func fromPrinted(_ s:String)->String? {
        let v=s.replacingOccurrences(of:"-",with:"/").split(separator:"/")
        guard v.count==3,let dd=Int(v[0]),let mm=Int(v[1]),let y=Int(v[2]) else{return nil}
        let yyyy=y<100 ? (y>=80 ? 1900+y : 2000+y) : y
        let iso=String(format:"%04d-%02d-%02d",yyyy,mm,dd)
        return parse(iso) == nil ? nil : iso
    }
    public static func days(_ a:String,_ b:String)->Int? {
        guard let x=parse(a),let y=parse(b) else{return nil}
        var c=Calendar(identifier:.gregorian);c.timeZone=TimeZone(secondsFromGMT:0)!
        guard let n=c.dateComponents([.day],from:x,to:y).day,n>=0,n<3660 else{return nil}
        return n+1
    }
    public static func following(_ iso:String)->String? {
        guard let d=parse(iso) else{return nil}
        var c=Calendar(identifier:.gregorian);c.timeZone=TimeZone(secondsFromGMT:0)!
        return c.date(byAdding:.day,value:1,to:d).map{self.iso($0)}
    }
}
public enum DMHospitalization:String,Codable,Sendable,CaseIterable {
    case unknown="Por confirmar",no="No",yes="Sí"
}
public enum DMState:String,Codable,Sendable,CaseIterable {
    case onLeave="En descanso",awaitingClearance="Pendiente de alta"
    case pendingReturn="Pendiente de reincorporación",returned="Reincorporado"
    case extended="Prorrogado",voided="Anulado"
}
public struct DMCertificate:Codable,Equatable,Identifiable,Sendable {
    public var id:UUID=UUID()
    public var dni:String=""
    public var name:String=""
    public var certificateNumber:String=""
    public var receiptDate:String=""
    public var issuedDate:String=""
    public var startDate:String=""
    public var endDate:String=""
    public var documentDays:Int?
    public var accumulatedDays:Int?
    public var issuer:String=""
    public var contingency:String=""
    public var diagnosis:String=""
    public var doctor:String=""
    public var cmp:String=""
    public var site:String=""
    public var area:String=""
    public var labor:String=""
    public var hospitalization:DMHospitalization = .unknown
    public var clearanceVerified:Bool=false
    public var contactChecked:Bool=false
    public var extensionChecked:Bool=false
    public var occupationalReviewChecked:Bool=false
    public var returnedDate:String=""
    public var state:DMState = .onLeave
    public var createdAt:Date=Date()
    public init() {}
    public var calculatedDays:Int?{DMDate.days(startDate,endDate)}
    public var expectedReturn:String?{DMDate.following(endDate)}
    public var needsClearance:Bool{(calculatedDays ?? 0)>=5 || hospitalization == .yes}
    public var discrepancy:Bool {
        guard let documentDays,let actual=calculatedDays else{return false}
        return actual != documentDays
    }
    public var fingerprint:String {
        let num=certificateNumber.uppercased().filter{ $0.isLetter || $0.isNumber }
        return dni+"|"+(num.isEmpty ? startDate+"|"+endDate : num)
    }
    public var isValid:Bool {
        dni.count==8 && dni.allSatisfy{$0.isNumber} &&
        !name.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty &&
        DMDate.parse(receiptDate) != nil && calculatedDays != nil &&
        !discrepancy
    }
    public mutating func markReturned(on date:String)throws {
        guard DMDate.parse(date) != nil else{throw DMError.invalidDate}
        guard !needsClearance || clearanceVerified else{throw DMError.clearanceRequired}
        returnedDate=date;state = .returned
    }
}
public enum DMError:Error,Equatable {
    case invalidDate,invalidCertificate,duplicate,clearanceRequired,templateMismatch,capacityExceeded
}
public struct DMLedger:Codable,Sendable {
    public private(set) var certificates:[DMCertificate]=[]
    public init() {}
    public init(certificates:[DMCertificate]) {self.certificates=certificates}
    public mutating func add(_ certificate:DMCertificate)throws {
        guard certificate.isValid else {throw DMError.invalidCertificate}
        guard !certificates.contains(where:{$0.fingerprint==certificate.fingerprint}) else {throw DMError.duplicate}
        certificates.append(certificate)
    }
    public mutating func update(_ certificate:DMCertificate)throws {
        guard certificate.isValid,let index=certificates.firstIndex(where:{$0.id==certificate.id})
        else{throw DMError.invalidCertificate}
        if certificate.state == .returned {
            guard DMDate.parse(certificate.returnedDate) != nil else{throw DMError.invalidDate}
            guard !certificate.needsClearance || certificate.clearanceVerified else {throw DMError.clearanceRequired}
        }
        guard !certificates.enumerated().contains(where:{$0.offset != index && $0.element.fingerprint==certificate.fingerprint})
        else{throw DMError.duplicate}
        certificates[index]=certificate
    }
    public var active:[DMCertificate] {
        certificates.filter{$0.state != .returned && $0.state != .voided}
    }
    public func requiringClearance()->[DMCertificate] {
        active.filter{$0.needsClearance && !$0.clearanceVerified}
    }
    /// Une certificados contiguos o superpuestos del mismo DNI sin sumar días repetidos.
    public func episodeDays(for dni:String)->Int {
        let ranges=certificates.filter{$0.dni==dni && $0.state != .voided}
            .compactMap{c -> (Date,Date)? in
                guard let a=DMDate.parse(c.startDate),let b=DMDate.parse(c.endDate) else{return nil}
                return(a,b)
            }.sorted{$0.0<$1.0}
        guard let first=ranges.first else{return 0}
        var total=0,lo=first.0,hi=first.1
        var cal=Calendar(identifier:.gregorian);cal.timeZone=TimeZone(secondsFromGMT:0)!
        for item in ranges.dropFirst() {
            let after=cal.date(byAdding:.day,value:1,to:hi)!
            if item.0<=after {if item.1>hi{hi=item.1}}
            else {total += cal.dateComponents([.day],from:lo,to:hi).day!+1;lo=item.0;hi=item.1}
        }
        return total+cal.dateComponents([.day],from:lo,to:hi).day!+1
    }
}
/// Solo devuelve campos explícitos del certificado. Nunca diagnostica ni deduce hospitalización.
public enum DMCITTParser {
    public static func parse(_ raw:String)->DMCertificate {
        let text=raw.folding(options:[.diacriticInsensitive,.caseInsensitive],locale:Locale(identifier:"es_PE"))
            .uppercased().replacingOccurrences(of:"\r",with:"\n")
        var c=DMCertificate()
        func extract(_ p:String)->String {
            guard let re=try? NSRegularExpression(pattern:p,options:[.dotMatchesLineSeparators]),
                  let m=re.firstMatch(in:text,range:NSRange(text.startIndex..<text.endIndex,in:text)),
                  m.numberOfRanges>1,let range=Range(m.range(at:1),in:text) else{return ""}
            return String(text[range]).trimmingCharacters(in:.whitespacesAndNewlines)
        }
        let d=#"(\d{1,2}[/.-]\d{1,2}[/.-]\d{2,4})"#
        c.certificateNumber=extract(#"CITT\s*(?:NO[.:°]*\s*)?([A-Z]-\d{3}-\d{7,}-\d{2})"#)
        c.dni=extract(#"(?:D\.?\s*N\.?\s*I\.?|DOC\.?\s*DE\s*IDENTIDAD)\s*:?\s*(?:D\.?\s*N\.?\s*I\.?\s*)?(\d{8})"#)
        c.name=extract(#"NOMBRE\s+ASEGURADO\s*:?\s*([A-ZÑ ]{5,})"#)
        c.name=c.name.components(separatedBy:"\n")[0].trimmingCharacters(in:.whitespaces)
        c.issuedDate=DMDate.fromPrinted(extract("F\\.?\\s*DE\\s*OTORGAMIENTO\\s*:?\\s*"+d)) ?? ""
        c.startDate=DMDate.fromPrinted(extract("FECHA\\s*DE\\s*INICIO\\s*:?\\s*"+d)) ?? ""
        c.endDate=DMDate.fromPrinted(extract("FECHA\\s*FIN\\s*:?\\s*"+d)) ?? ""
        let days=extract(#"TOTAL\s+DE\s+DIAS\s*:?\s*(\d{1,3})"#)
        c.documentDays=Int(days)
        c.accumulatedDays=Int(extract(#"DIAS\s+DE\s+INCAPACIDAD\s+TEMPORAL\s+ACUMULADO\s*:?\s*(\d{1,4})"#))
        c.contingency=extract(#"CONTINGENCIA\s*:?\s*([A-Z ]+)"#).components(separatedBy:"\n")[0].trimmingCharacters(in:.whitespaces)
        c.issuer=text.contains("ESSALUD") || text.contains("EE.SS") || text.contains("H.I CHEPEN") ? "ESSALUD" : ""
        c.cmp=extract(#"CMP\.?\s*:?\s*(\d{4,8})"#)
        return c
    }
}