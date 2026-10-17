import Foundation
import CoreFoundation

/// N1s: independent native OOXML writer for ALL writable ten-sheet DANPER
/// Indicator areas, plus the separately templated 98-item nursing Kardex.
/// Only accepts a caller-supplied sanitized embedded template and synthetic
/// verified export plan. Production/user data access is deliberately absent.
internal enum N1sExcelError: Error, Equatable {
    case invalidManifest, invalidTemplate, invalidMaterial, invalidRow
    case missingVerifiedQuantity, unreviewedOfficial, ambiguousSource
}
internal struct N1sExcelResult {
    let xlsx: Data
    let sheetCount: Int
    let writtenRows: Int
    let canUseClinicalData: Bool = false
}

internal enum N1sFullExcelWriter {
    private static let sheets = [
        "BD MATERIALES","CONTEO","INGRESOS","RESU","CONSUMOS",
        "JUSTIFICACIONES","GUIA","@subuo","BASE TRU","@uo"
    ]
    private static let formulas:[Int:[String]]=[
        2:["H"],
        3:["D","E","F","G","X"],
        4:["E","F","G","H","I","J","L"]
    ]
    private static func matcher(_ regex:String) throws -> NSRegularExpression {
        try NSRegularExpression(pattern:regex,options:[.dotMatchesLineSeparators])
    }
    private static func matches(_ regex:String,in source:String) throws -> [NSTextCheckingResult] {
        try matcher(regex).matches(in:source,
                    range:NSRange(source.startIndex..<source.endIndex,in:source))
    }
    private static func replaceExactly(_ regex:String,in source:String,with replacement:String) throws -> String {
        let hits=try matches(regex,in:source)
        guard hits.count==1,let range=Range(hits[0].range,in:source) else {
            throw N1sExcelError.invalidTemplate
        }
        return source.replacingCharacters(in:range,with:replacement)
    }
    private static func string(_ input:Any?) -> String? {input as? String}
    private static func number(_ input:Any?) -> Double? {
        guard let x=input as? NSNumber,CFGetTypeID(x) != CFBooleanGetTypeID(),
              x.doubleValue.isFinite else {return nil}
        return x.doubleValue
    }
    private static func int(_ input:Any?) -> Int? {
        guard let x=number(input),x.rounded()==x,x>=0,x<=10_000_000 else {return nil}
        return Int(x)
    }
    private static func bool(_ input:Any?) -> Bool? {
        guard let x=input as? NSNumber,CFGetTypeID(x)==CFBooleanGetTypeID() else{return nil}
        return x.boolValue
    }
    private static func escaped(_ source:String) throws -> String {
        guard source.utf16.count<=32767,
              !source.unicodeScalars.contains(where: {
                  $0.value<32 && ![9,10,13].contains($0.value)
              }) else {throw N1sExcelError.invalidRow}
        return source.replacingOccurrences(of:"&",with:"&amp;")
            .replacingOccurrences(of:"<",with:"&lt;")
            .replacingOccurrences(of:">",with:"&gt;")
            .replacingOccurrences(of:"\"",with:"&quot;")
            .replacingOccurrences(of:"'",with:"&apos;")
    }
    private static func column(_ number:Int) -> String {
        var number=number+1,letters=""
        while number>0 {
            number-=1
            letters=String(UnicodeScalar(65+number%26)!)+letters
            number/=26
        }
        return letters
    }
    private static func attrs(_ element:String,name:String) -> String? {
        let p="\\b"+NSRegularExpression.escapedPattern(for:name)+"=\"([^\"]*)\""
        guard let m=try? matches(p,in:element).first,
              let r=Range(m.range(at:1),in:element) else {return nil}
        return String(element[r])
    }
    private static func cellStyle(_ xml:String,ref:String) -> String? {
        guard let m=try? matches(#"<c\b[^>]*\br=""#+NSRegularExpression.escapedPattern(for:ref)+#""[^>]*(?:/?>)"#,in:xml).first,
              let r=Range(m.range,in:xml) else {return nil}
        return attrs(String(xml[r]),name:"s")
    }
    private static func xmlCell(_ ref:String,_ value:Any?,
                                template:String?=nil,formula:String?=nil) throws -> String {
        let s=template.map{" s=\""+$0+"\""} ?? ""
        let head="<c r=\""+ref+"\""+s
        if let formula {
            return head+"><f>"+(try escaped(formula))+"</f></c>"
        }
        guard let value,!(value is NSNull) else {return head+"/>"}
        if let x=number(value) {
            return head+"><v>"+(x.rounded()==x && abs(x)<1_000_000_000_000 ? String(Int64(x)) : String(x))+"</v></c>"
        }
        guard let t=value as? String else {throw N1sExcelError.invalidRow}
        if t.isEmpty{return head+"/>"}
        return head+" t=\"inlineStr\"><is><t xml:space=\"preserve\">" + (try escaped(t)) + "</t></is></c>"
    }
    private static func numericDate(_ s:String) throws -> Double {
        guard s.range(of:#"^\d{4}-\d{2}-\d{2}$"#,
                      options:.regularExpression) != nil,
              let y=Int(s.prefix(4)),let m=Int(s.dropFirst(5).prefix(2)),
              let d=Int(s.suffix(2)) else {throw N1sExcelError.invalidManifest}
        var c=Calendar(identifier:.gregorian)
        c.timeZone=TimeZone(secondsFromGMT:0)!
        guard let x=c.date(from:DateComponents(year:y,month:m,day:d)),
              c.component(.year,from:x)==y,c.component(.month,from:x)==m,
              c.component(.day,from:x)==d else {throw N1sExcelError.invalidManifest}
        return Double(Int(x.timeIntervalSince1970/86400)+25569)
    }
    private static func formula(_ sheet:Int,_ col:String,_ row:Int,reviewed:Bool) -> String? {
        let n=String(row)
        switch sheet {
        case 2:
            return col=="H" ? "IF(COUNTA(D\(n):G\(n))=0,\"\",SUM(D\(n):G\(n)))" : nil
        case 3:
            let expiry=["D":"J","E":"N","F":"R","G":"V"]
            if let source=expiry[col] {
                return "IF(\(source)\(n)=\"\",\"\",IF(\(source)\(n)-TODAY()<=90,1,0))"
            }
            return col=="X" && reviewed ?
                "IF(COUNTA(H\(n),L\(n),P\(n),T\(n))=0,0,SUM(H\(n),L\(n),P\(n),T\(n)))" : nil
        case 4:
            switch col {
            case "E":return "IF(COUNT(INGRESOS!X\(n))=0,\"\",INGRESOS!X\(n))"
            case "F":return "SUMIF(TB_CONSUMOS[CÓDIGO],A\(n),TB_CONSUMOS[CANTIDAD])"
            case "G":return "IF(OR(D\(n)=\"\",E\(n)=\"\"),\"\",SUM(D\(n):E\(n))-F\(n))"
            case "H":return "IF(COUNT(CONTEO!D\(n))=0,\"\",CONTEO!D\(n))"
            case "I":return "IF(OR(G\(n)=\"\",H\(n)=\"\"),\"\",G\(n)-H\(n))"
            case "J":return "IF(I\(n)=\"\",\"\",IF(I\(n)<0,\"SOBRANTE\",IF(I\(n)=0,\"-\",\"FALTANTE\")))"
            case "L":return "IF(OR(K\(n)=\"\",G\(n)=\"\"),\"\",K\(n)-G\(n))"
            default:return nil
            }
        default:return nil
        }
    }
    private static func organization(_ column:Int,_ n:Int) -> String {
        if column==2 {
            return "IF(A\(n)=\"\",\"\",IFERROR(VLOOKUP(A\(n),'@subuo'!$A$3:$C$59,2,FALSE),\"\"))"
        }
        return "IF(OR(A\(n)=\"\",B\(n)=\"\"),\"\",IFERROR(VLOOKUP(CONCATENATE(VLOOKUP(A\(n),'@subuo'!$A$3:$C$59,3,FALSE),B\(n)),'@uo'!$D$2:$E$234,2,FALSE),\"\"))"
    }
    private static func existingRow(_ xml:String,_ number:Int) throws -> String {
        let regex="<row\\b[^>]*\\br=\""+String(number)+"\"[^>]*>.*?</row>"
        let m=try matches(regex,in:xml)
        guard m.count==1,let r=Range(m[0].range,in:xml)
        else {throw N1sExcelError.invalidTemplate}
        return String(xml[r])
    }
    private static func sheetData(_ xml:String,headerRows:Int,rows:[[Any?]],
                                  width:Int,reviewed:Bool,sheet:Int,
                                  dateStyle:Int) throws -> String {
        var preserved=""
        for index in 1...headerRows {preserved += try existingRow(xml,index)}
        let prototype=try existingRow(xml,headerRows+1)
        var style:[String:String]=[:]
        for col in 0..<width {
            let address=column(col)+String(headerRows+1)
            if let s=cellStyle(prototype,ref:address){style[column(col)]=s}
        }
        var inserted=""
        let nRows=max(1,rows.count)
        for i in 0..<nRows {
            let row=headerRows+i+1
            inserted+="<row r=\"\(row)\">"
            for col in 0..<width {
                let label=column(col),reference=label+String(row)
                let formulaText: String?
                if sheet==5 && (col==2 || col==3) {
                    formulaText=organization(col,row)
                }else {
                    formulaText=formula(sheet,label,row,reviewed:reviewed)
                }
                let input:Any?=i<rows.count ? rows[i][col] : nil
                // Explicit numeric date style: do not depend on a template
                // row accidentally configured as General or displaying ISO.
                let isDate=(sheet==5 && col==5) ||
                    (sheet==3 && [8,9,12,13,16,17,20,21].contains(col))
                inserted += try xmlCell(reference,input,
                    template:isDate ? String(dateStyle) : style[label],
                    formula:formulaText)
            }
            inserted+="</row>"
        }
        let dim="A1:"+column(width-1)+String(headerRows+nRows)
        var replaced=try replaceExactly("<sheetData(?:\\s[^>]*)?>.*?</sheetData>",
                                        in:xml,with:"<sheetData>"+preserved+inserted+"</sheetData>")
        replaced=try replaceExactly(#"<dimension\b[^>]*/>"#,in:replaced,
                                    with:"<dimension ref=\""+dim+"\"/>")
        return replaced
    }
    private static func rows(_ json:[String:Any]) throws -> [[Any]] {
        guard let plan=json["plan"] as? [String:Any],
              let elements=plan["lines"] as? [[String:Any]],elements.count<=10000
        else {throw N1sExcelError.invalidManifest}
        var ids=Set<String>()
        return try elements.map { line in
            guard let id=line["id"] as? String,!id.isEmpty,
                  ids.insert(id).inserted,
                  let values=line["cells"] as? [Any],values.count==30
            else {throw N1sExcelError.invalidManifest}
            for v in values {
                guard v is String || number(v) != nil else {
                    throw N1sExcelError.invalidRow
                }
            }
            for i in [7,15,27] {
                guard values[i] is String else {throw N1sExcelError.invalidRow}
            }
            return values
        }
    }
    private static func updateTable(_ xml:String,range:String) throws -> String {
        var changed=try replaceExactly(#"<table\b[^>]*>"#,in:xml,with:{
            let m=try matches(#"<table\b[^>]*>"#,in:xml)[0]
            let r=Range(m.range,in:xml)!
            let tag=String(xml[r])
            return try replaceExactly(#"\bref="[^"]*""#,in:tag,with:"ref=\""+range+"\"")
        }())
        if let m=try matches(#"<autoFilter\b[^>]*/>"#,in:changed).first,
           let r=Range(m.range,in:changed) {
            let tag=String(changed[r])
            let value=try replaceExactly(#"\bref="[^"]*""#,in:tag,
                                         with:"ref=\""+range+"\"")
            changed.replaceSubrange(r,with:value)
        }
        return changed
    }
    private static func adjustWorkbook(_ xml:String) throws -> String {
        if let m=try matches(#"<calcPr\b[^>]*/>"#,in:xml).first,
           let r=Range(m.range,in:xml) {
            var tag=String(xml[r])
            for (name,val) in [("calcMode","auto"),("fullCalcOnLoad","1"),
                               ("forceFullCalc","1")] {
                if attrs(tag,name:name) != nil {
                    tag=try replaceExactly("\\b"+name+"=\"[^\"]*\"",in:tag,
                                          with:name+"=\""+val+"\"")
                }else {
                    tag=tag.replacingOccurrences(of:"/>",with:" "+name+"=\""+val+"\"/>")
                }
            }
            var output=xml
            output.replaceSubrange(r,with:tag)
            return output
        }
        return xml.replacingOccurrences(of:"</workbook>",
            with:"<calcPr calcMode=\"auto\" fullCalcOnLoad=\"1\" forceFullCalc=\"1\"/></workbook>")
    }
    static func exportIndicator(base:Data,manifest:Data) throws -> N1sExcelResult {
        guard manifest.count<4_000_000,
              let root=try? JSONSerialization.jsonObject(with:manifest) as? [String:Any],
              let catalog=root["catalog"] as? [[String:Any]],catalog.count==432,
              let reconciliation=root["byCode"] as? [String:[String:Any]],
              let reviewed=bool(root["reviewed"]),
              let provisional=bool(root["provisional"]),
              let start=string(root["start"]),let end=string(root["end"]),start<=end,
              ["LA VENTUROSA","PLVENTUROSA"].contains(string(root["subdivision"]) ?? ""),
              let rowsExpected=root["rows"] as? Int else {
            throw N1sExcelError.invalidManifest
        }
        let selected=try rows(root)
        guard selected.count==rowsExpected,Set(catalog.compactMap{string($0["code"])}).count==432,
              Set(reconciliation.keys)==Set(catalog.compactMap{string($0["code"])}),
              !(provisional && reviewed) else {throw N1sExcelError.invalidManifest}
        let pending=selected.contains{line in line[15] as? String != "" && !(line[17] is NSNumber)}
        guard !pending else {throw N1sExcelError.missingVerifiedQuantity}
        if !reviewed {
            // Protect official filenames/claimed ready state; reconciliation
            // may still be exported as a visibly nonfinal DRAFT only.
            guard provisional else {throw N1sExcelError.unreviewedOfficial}
        }
        var archive=try N1rStoredZip.unpack(base)
        guard let stylesIndex=archive.firstIndex(where:{$0.name=="xl/styles.xml"}),
              let stylesXML=String(data:archive[stylesIndex].data,encoding:.utf8)
        else{throw N1sExcelError.invalidTemplate}
        let (updatedStyles,peruDateStyle)=try N1sNursingExcelWriter
            .appendPeruvianDateStyle(stylesXML)
        archive[stylesIndex]=N1rStoredEntry(
            name:archive[stylesIndex].name,data:Data(updatedStyles.utf8))
        let listed=Set(archive.map{$0.name})
        guard (1...10).allSatisfy({listed.contains("xl/worksheets/sheet\($0).xml")}),
              listed.contains("xl/workbook.xml"),
              archive.filter({$0.name.hasPrefix("xl/tables/table")&&$0.name.hasSuffix(".xml")}).count==19
        else {throw N1sExcelError.invalidTemplate}
        guard let bookData=archive.first(where:{$0.name=="xl/workbook.xml"})?.data,
              let book=String(data:bookData,encoding:.utf8) else {
            throw N1sExcelError.invalidTemplate
        }
        let sheetNamePattern=try matcher(#"<sheet\b[^>]*\bname="([^"]+)""#)
        let actual=sheetNamePattern.matches(in:book,range:NSRange(book.startIndex..<book.endIndex,in:book))
          .compactMap {m -> String? in
              guard let r=Range(m.range(at:1),in:book) else{return nil}
              return String(book[r])
          }
        guard actual==sheets else {throw N1sExcelError.invalidTemplate}
        let productCodes=catalog.map{string($0["code"]) ?? ""}
        var sheetRows:[Int:[[Any?]]]=[:]
        for (offset,product) in catalog.enumerated() {
            guard let code=string(product["code"]),!code.isEmpty,
                  let name=string(product["name"]),let unit=string(product["unit"]),
                  let material=reconciliation[code] else {throw N1sExcelError.invalidMaterial}
            let count=material["count"],opening=material["opening"],
                entries=material["receiptDetails"] as? [[String:Any]] ?? []
            guard entries.count<=4 else {throw N1sExcelError.invalidMaterial}
            let lineCount:[Any?]=[code,name,unit,count,nil,nil,nil,nil]
            var income:[Any?]=Array(repeating:nil,count:25)
            income[0]=code;income[1]=name;income[2]=unit
            for (i,event) in entries.enumerated() {
                guard let qty=int(event["quantity"]),
                      let date=string(event["date"]),
                      let document=string(event["document"]),document.count>=3 else {
                    throw N1sExcelError.invalidMaterial
                }
                let col=7+i*4
                income[col]=qty
                income[col+1]=try numericDate(date)
                if let expiry=string(event["expires"]),!expiry.isEmpty {
                    income[col+2]=try numericDate(expiry)
                }
                income[col+3]=document
            }
            // Unreviewed has blank X (not zero), but verified review enables formula X.
            var summary:[Any?]=Array(repeating:nil,count:13)
            summary[0]=code;summary[1]=name;summary[2]=unit;summary[3]=opening
            sheetRows[2,default:[]].append(lineCount)
            sheetRows[3,default:[]].append(income)
            sheetRows[4,default:[]].append(summary)
            _=offset
        }
        guard productCodes.count==432 else {throw N1sExcelError.invalidMaterial}
        sheetRows[5]=selected.map{$0.map{Optional($0)}}
        let formulasWritten=reviewed
        let plans:[Int:(Int,Int)]=[2:(2,8),3:(2,25),4:(2,13),5:(1,30)]
        for i in archive.indices {
            let path=archive[i].name
            if path=="xl/workbook.xml" {
                archive[i]=N1rStoredEntry(name:path,data:Data(try adjustWorkbook(book).utf8))
                continue
            }
            if path.hasPrefix("xl/worksheets/sheet"),path.hasSuffix(".xml"),
               let no=Int(path.replacingOccurrences(of:"xl/worksheets/sheet",with:"")
                    .replacingOccurrences(of:".xml",with:"")),
               let (header,width)=plans[no] {
                guard let xml=String(data:archive[i].data,encoding:.utf8) else {
                    throw N1sExcelError.invalidTemplate
                }
                let rebuilt=try sheetData(xml,headerRows:header,rows:sheetRows[no] ?? [],
                                          width:width,reviewed:formulasWritten,sheet:no,
                                          dateStyle:peruDateStyle)
                archive[i]=N1rStoredEntry(name:path,data:Data(rebuilt.utf8))
                continue
            }
            if path.hasPrefix("xl/tables/table"),path.hasSuffix(".xml"),
               let xml=String(data:archive[i].data,encoding:.utf8) {
                let range:String?
                if xml.contains("displayName=\"TB_CONSUMOS\"") {
                    range="A1:AD"+String(max(2,selected.count+1))
                }else if xml.contains("displayName=\"Tabla17\"") {
                    range="A2:M434"
                }else if xml.contains("displayName=\"Tabla21\"") {
                    range="A1:C433"
                }else {range=nil}
                if let range {
                    archive[i]=N1rStoredEntry(name:path,
                        data:Data(try updateTable(xml,range:range).utf8))
                }
            }
        }
        let result=try N1rStoredZip.pack(archive)
        _=try N1rStoredZip.unpack(result)
        return N1sExcelResult(xlsx:result,sheetCount:10,writtenRows:selected.count)
    }
}

/// Native physical stock per container opening, not per clinical encounter.
/// Never equate capacity (100 mL) to number of uses without confirmed dose.
internal struct N1sContainerUse: Equatable {
    let remaining:Double
    let sealed:Int
    let containerSize:Double
    let quantityPerVisit:Double
    let quantityVerified:Bool
    let openingApproved:Bool
}
internal struct N1sContainerDecision:Equatable {
    let nextRemaining:Double
    let nextSealed:Int
    let openingCount:Int
    let excelR:Int
    let requiresOpeningConsent:Bool
}
internal enum N1sContainerRuleError:Error,Equatable {
    case invalidCapacity, unverifiedUse, insufficientStock, needsOpeningApproval
}
internal enum N1sContainerUseRule {
    static func consume(_ source:N1sContainerUse) throws -> N1sContainerDecision {
        guard source.containerSize>0,source.containerSize.isFinite,
              source.quantityPerVisit>0,source.quantityPerVisit.isFinite,
              source.remaining>=0,source.remaining.isFinite,
              source.remaining<source.containerSize+0.0001,source.sealed>=0 else {
            throw N1sContainerRuleError.invalidCapacity
        }
        guard source.quantityVerified else {throw N1sContainerRuleError.unverifiedUse}
        let needed=max(0,source.quantityPerVisit-source.remaining)
        let opens=needed==0 ? 0:Int(ceil((needed-0.0000001)/source.containerSize))
        guard opens<=source.sealed else {throw N1sContainerRuleError.insufficientStock}
        if opens>0 && !source.openingApproved {
            return N1sContainerDecision(nextRemaining:source.remaining,
                nextSealed:source.sealed,openingCount:0,excelR:0,
                requiresOpeningConsent:true)
        }
        let remaining=source.remaining+Double(opens)*source.containerSize-source.quantityPerVisit
        return N1sContainerDecision(nextRemaining:max(0,(remaining*1000).rounded()/1000),
            nextSealed:source.sealed-opens,openingCount:opens,excelR:opens,
            requiresOpeningConsent:false)
    }
}
