import Foundation
#if canImport(FoundationXML)
import FoundationXML
#endif
import ZIPFoundation

public enum N2PersonalImportError:Error,Equatable {
    case invalidFile,missingPersonal,invalidXML,invalidHeaders,tooLarge
    case noValidWorkers,needsReview,staleRevision,sourceNotEmpty
}
public struct N2PersonalWorker:Equatable,Sendable {
    public let dni:String
    public let name:String
    public let area:String
    public let labor:String
    public let sex:String
    public let age:String
    public let ubigeo:String
    public init(dni:String,name:String,area:String="",labor:String="",
                sex:String="",age:String="",ubigeo:String="") {
        self.dni=dni;self.name=name;self.area=area;self.labor=labor
        self.sex=sex;self.age=age;self.ubigeo=ubigeo
    }
}
public struct N2PersonalImportStats:Equatable,Sendable {
    public var total=0
    public var valid=0
    public var invalidDni=0
    public var withoutName=0
    public var duplicates=0
    public var sexMissing=0
    public var sexInvalid=0
    public var sexConflicts=0
    public var nameConflicts=0
    public var canConfirm:Bool {
        valid>0 && invalidDni==0 && withoutName==0 &&
        sexInvalid==0 && sexConflicts==0 && nameConflicts==0
    }
}
public struct N2PersonalImportPreview:Sendable {
    public let workers:[N2PersonalWorker]
    public let stats:N2PersonalImportStats
}

/// Supports Excel OOXML sharedStrings AND inlineStr, as does build 222.
/// No patient/workbook content is written to the filesystem or diagnostics.
/// Only one explicitly selected PERSONAL worksheet is extracted.
public enum N2PersonalWorkbookReader {
    private final class XMLRows:NSObject,XMLParserDelegate {
        enum Mode {case workbook,relationships,sharedStrings,worksheet}
        let mode:Mode
        init(_ mode:Mode){self.mode=mode}
        var personalRelationship=""
        var relationships:[String:String]=[:]
        var strings=[String]()
        var rows=[[String]]()
        var shared=[String]()
        private var inString=false
        private var runningString=""
        private var inText=false
        private var inValue=false
        private var text=""
        private var currentCellColumn:Int?
        private var cellType=""
        private var cellValue=""
        private var cellInline=""
        private var row=[String]()
        private var hasFormula=false
        private var insideCell=false

        func parser(_ parser:XMLParser,didStartElement elementName:String,
                    namespaceURI:String?,qualifiedName qName:String?,
                    attributes attrs:[String:String]) {
            let tag=String(elementName.split(separator:":").last ?? "")
            switch mode {
            case .workbook:
                if tag=="sheet",attrs["name"]?.trimmingCharacters(in:.whitespacesAndNewlines)
                    .uppercased()=="PERSONAL" {
                    personalRelationship=attrs["r:id"] ?? attrs["id"] ?? ""
                }
            case .relationships:
                if tag=="Relationship",let key=attrs["Id"],let target=attrs["Target"] {
                    relationships[key]=target
                }
            case .sharedStrings:
                if tag=="si" {inString=true;runningString=""}
                if tag=="t" && inString {inText=true;text=""}
            case .worksheet:
                if tag=="row" {row=[String]()}
                if tag=="c" {
                    insideCell=true
                    cellType=attrs["t"] ?? ""
                    cellValue="";cellInline="";hasFormula=false
                    currentCellColumn=Self.column(attrs["r"] ?? "")
                }
                if tag=="f" && insideCell {hasFormula=true}
                if tag=="v" && insideCell {inValue=true;text=""}
                if tag=="t" && insideCell {inText=true;text=""}
            }
        }
        func parser(_ parser:XMLParser,foundCharacters string:String) {
            if inText || inValue {text += string}
        }
        func parser(_ parser:XMLParser,didEndElement elementName:String,
                    namespaceURI:String?,qualifiedName qName:String?) {
            let tag=String(elementName.split(separator:":").last ?? "")
            switch mode {
            case .workbook,.relationships:break
            case .sharedStrings:
                if tag=="t" && inText {
                    runningString += text;inText=false;text=""
                }
                if tag=="si" && inString {
                    strings.append(runningString)
                    inString=false;runningString=""
                }
            case .worksheet:
                if tag=="v" && inValue {
                    cellValue=text;inValue=false;text=""
                }
                if tag=="t" && inText {
                    cellInline+=text;inText=false;text=""
                }
                if tag=="c" && insideCell {
                    if let col=currentCellColumn,col>=0,col<=50 {
                        if row.count<=col {
                            row += Array(repeating:"",count:col+1-row.count)
                        }
                        if hasFormula {
                            // Never use possibly stale cached formulas for identity.
                            row[col]=""
                        } else if cellType=="s",let index=Int(cellValue),
                                  shared.indices.contains(index) {
                            row[col]=shared[index]
                        } else if cellType=="inlineStr" {
                            row[col]=cellInline
                        } else if cellType=="str" || cellType=="" || cellType=="n" {
                            row[col]=cellValue
                        } else if cellType=="b" {
                            row[col]=cellValue
                        }
                    }
                    insideCell=false
                    currentCellColumn=nil
                }
                if tag=="row" && rows.count<=31_000 {
                    rows.append(row)
                }
            }
        }
        static func column(_ ref:String)->Int? {
            let letters=String(ref.prefix(while:{$0.isASCII && $0.isLetter}))
                .uppercased()
            guard !letters.isEmpty,letters.count<=3 else{return nil}
            let n=letters.utf8.reduce(0) { $0*26+Int($1)-64 }
            return n-1
        }
        func parse(_ data:Data)throws {
            guard !data.isEmpty,
                let xml=String(data:data,encoding:.utf8),
                xml.range(of:"<!DOCTYPE",options:.caseInsensitive)==nil,
                xml.range(of:"<!ENTITY",options:.caseInsensitive)==nil else {
                throw N2PersonalImportError.invalidXML
            }
            let parser=XMLParser(data:data)
            parser.delegate=self
            parser.shouldResolveExternalEntities=false
            guard parser.parse() else{throw N2PersonalImportError.invalidXML}
            if case .worksheet = mode,rows.count>31_000 {
                throw N2PersonalImportError.tooLarge
            }
        }
    }

    private static func part(_ archive:Archive,_ path:String,
                             max:Int,optional:Bool=false)throws->Data {
        guard let entry=archive[path] else {
            if optional {return Data()}
            throw N2PersonalImportError.invalidFile
        }
        guard entry.type == .file,entry.uncompressedSize<=numericCast(max) else {
            throw N2PersonalImportError.tooLarge
        }
        var result=Data()
        _=try archive.extract(entry) { chunk in
            result.append(chunk)
            if result.count>max {throw N2PersonalImportError.tooLarge}
        }
        return result
    }
    private static func cleaned(_ text:String)->String {
        String(text.trimmingCharacters(in:.whitespacesAndNewlines)
                .split(whereSeparator:{$0.isWhitespace}).joined(separator:" ").prefix(220))
    }
    private static func normalized(_ text:String)->String {
        cleaned(text).folding(options:[.diacriticInsensitive,.caseInsensitive],
                              locale:Locale(identifier:"es_PE")).uppercased()
    }
    private static func cell(_ row:[String],_ col:Int)->String {
        col>=0 && col<row.count ? cleaned(row[col]) : ""
    }
    private static func compile(_ rows:[[String]])throws->N2PersonalImportPreview {
        guard let headings=rows.first else {throw N2PersonalImportError.invalidHeaders}
        let header=headings.map(normalized)
        func index(_ names:String...)->Int {
            header.firstIndex(where:{names.contains($0)}) ?? -1
        }
        let dni=index("DNI")
        let name=index("NOMBRES","APELLIDOS Y NOMBRES","NOMBRE COMPLETO")
        guard dni>=0,name>=0 else{throw N2PersonalImportError.invalidHeaders}
        let manual=index("EDAD MANUAL","EDAD"), auto=index("EDAD AUTOMATIZADA")
        let sex=index("SEXO"),ubi=index("UBIGEO"),area=index("AREA")
        let labor=index("CARGO","LABOR","PUESTO")
        var byDNI=[String:N2PersonalWorker]()
        var order=[String]()
        var sexConflicting=Set<String>()
        var stats=N2PersonalImportStats()
        for row in rows.dropFirst() {
            if row.allSatisfy({cleaned($0).isEmpty}) {continue}
            stats.total+=1
            var key=cell(row,dni)
            if key.hasSuffix(".0"){key=String(key.dropLast(2))}
            guard key.utf8.count==8,
                  key.utf8.allSatisfy({(48...57).contains($0)}) else {
                stats.invalidDni+=1
                continue
            }
            let fullName=cell(row,name)
            guard !fullName.isEmpty else{stats.withoutName+=1;continue}
            let gender=cell(row,sex).uppercased()
            let normalizedSex=["M","F"].contains(gender) ? gender : ""
            if gender.isEmpty {stats.sexMissing+=1}
            else if normalizedSex.isEmpty {stats.sexInvalid+=1}
            let candidateAge=cell(row,manual).isEmpty ? cell(row,auto) : cell(row,manual)
            let validAge=Int(candidateAge).map{(0...120).contains($0)} ?? false
            let age=validAge && candidateAge.utf8.allSatisfy({(48...57).contains($0)})
                ? candidateAge : ""
            let candidate=N2PersonalWorker(
                dni:key,name:fullName,area:cell(row,area),labor:cell(row,labor),
                sex:normalizedSex,age:age,ubigeo:cell(row,ubi))
            if let previous=byDNI[key] {
                stats.duplicates+=1
                if normalized(previous.name) != normalized(candidate.name) {
                    stats.nameConflicts+=1
                }
                if !previous.sex.isEmpty && !candidate.sex.isEmpty &&
                    previous.sex != candidate.sex && !sexConflicting.contains(key) {
                    stats.sexConflicts+=1
                    sexConflicting.insert(key)
                }
                func pick(_ a:String,_ b:String)->String {a.isEmpty ? b : a}
                byDNI[key]=N2PersonalWorker(
                    dni:key,name:previous.name,area:pick(previous.area,candidate.area),
                    labor:pick(previous.labor,candidate.labor),
                    sex:sexConflicting.contains(key) ? "" : pick(previous.sex,candidate.sex),
                    age:pick(previous.age,candidate.age),
                    ubigeo:pick(previous.ubigeo,candidate.ubigeo))
            } else {
                order.append(key)
                byDNI[key]=candidate
            }
        }
        stats.valid=order.count
        guard stats.valid>0 else{throw N2PersonalImportError.noValidWorkers}
        return N2PersonalImportPreview(
            workers:order.compactMap{byDNI[$0]},stats:stats)
    }
    public static func read(url:URL)throws->N2PersonalImportPreview {
        guard url.pathExtension.lowercased()=="xlsx" else {
            throw N2PersonalImportError.invalidFile
        }
        let size=(try url.resourceValues(forKeys:[.fileSizeKey])).fileSize ?? 0
        guard size>0,size<=20*1024*1024 else{throw N2PersonalImportError.tooLarge}
        let archive=try Archive(url:url,accessMode:.read)
        let wb=XMLRows(.workbook)
        try wb.parse(part(archive,"xl/workbook.xml",max:1*1024*1024))
        guard !wb.personalRelationship.isEmpty else {
            throw N2PersonalImportError.missingPersonal
        }
        let rel=XMLRows(.relationships)
        try rel.parse(part(archive,"xl/_rels/workbook.xml.rels",max:1*1024*1024))
        guard let link=rel.relationships[wb.personalRelationship] else {
            throw N2PersonalImportError.invalidFile
        }
        var target=link
        if target.hasPrefix("/xl/") {target=String(target.dropFirst())}
        else {
            if target.hasPrefix("./") {target=String(target.dropFirst(2))}
            if target.hasPrefix("xl/") == false {target="xl/"+target}
        }
        guard target.hasPrefix("xl/worksheets/"),
              target.hasSuffix(".xml"),
              !target.contains(".."),
              !target.contains("\\") else {
            throw N2PersonalImportError.invalidFile
        }
        let strings=XMLRows(.sharedStrings)
        let shared=try part(archive,"xl/sharedStrings.xml",
                            max:12*1024*1024,optional:true)
        if !shared.isEmpty {try strings.parse(shared)}
        let sheet=XMLRows(.worksheet)
        sheet.shared=strings.strings
        try sheet.parse(part(archive,target,max:16*1024*1024))
        return try compile(sheet.rows)
    }
}
