import Foundation
import ZIPFoundation

/// Rellena exclusivamente filas PREEXISTENTES vacías de DM2026.
/// No reescribe fórmulas J/K/L ni altera las seis hojas auxiliares.
/// El usuario selecciona el .xlsx original de forma transitoria; nunca se añade al repositorio.
public enum DMExcelWriter {
    public static func export(template:URL,records:[DMCertificate],destination:URL)throws {
        guard records.allSatisfy({$0.isValid}) else{throw DMError.invalidCertificate}
        let source=try Archive(url:template,accessMode:.read)
        guard source["xl/worksheets/sheet1.xml"] != nil,
              source["xl/tables/table1.xml"] != nil,
              source["xl/worksheets/sheet7.xml"] != nil,
              source["xl/workbook.xml"] != nil else {throw DMError.templateMismatch}
        let fm=FileManager.default
        if fm.fileExists(atPath:destination.path){try fm.removeItem(at:destination)}
        let archive=try Archive(url:destination,accessMode:.create)
        var writtenSheet=false
        for entry in source {
            guard entry.type == .file,entry.uncompressedSize < 38_000_000 else {
                throw DMError.templateMismatch
            }
            var contents=Data()
            _=try source.extract(entry){chunk in contents.append(chunk)}
            if entry.path=="xl/worksheets/sheet1.xml" {
                guard let sourceXML=String(data:contents,encoding:.utf8) else{throw DMError.templateMismatch}
                contents=Data(try fill(sourceXML,records).utf8)
                writtenSheet=true
            }
            let data=contents
            try archive.addEntry(with:entry.path,type:.file,
                                 uncompressedSize:UInt32(data.count),
                                 compressionMethod:.deflate,
                                 provider:{position,size in
                                     let first=Int(position)
                                     guard first>=0,first<=data.count,size<=data.count-first else {
                                         throw DMError.templateMismatch
                                     }
                                     return data.subdata(in:first..<(first+size))
                                 })
        }
        guard writtenSheet else{throw DMError.templateMismatch}
    }
    private static func matches(_ pattern:String,_ text:String)throws->[NSTextCheckingResult] {
        let regex=try NSRegularExpression(pattern:pattern,options:[.dotMatchesLineSeparators])
        return regex.matches(in:text,range:NSRange(text.startIndex..<text.endIndex,in:text))
    }
    private static func replaceCell(in row:String,column:String,number:Int,value:String?,
                                    date:Bool=false,formula:Bool=false)throws->String {
        let ref=column+String(number)
        let escaped=NSRegularExpression.escapedPattern(for:ref)
        let hits=try matches(#"<c\b[^>]*\br=""#+escaped+#""[^>]*(?:/>|>.*?</c>)"#,row)
        guard hits.count==1,let range=Range(hits[0].range,in:row) else{throw DMError.templateMismatch}
        let original=String(row[range])
        let style=try matches(#"\bs="(\d+)""#,original).first.flatMap {m -> String? in
            guard let sub=Range(m.range(at:1),in:original) else{return nil}
            return String(original[sub])
        }.map{" s=\""+$0+"\""} ?? ""
        let cell:String
        if formula {
            let expr="IF(AND(O\(number)<>\"\",P\(number)<>\"\"),P\(number)-O\(number)+1,0)"
            cell="<c r=\"\(ref)\"\(style)><f>\(expr.replacingOccurrences(of:"<",with:"&lt;").replacingOccurrences(of:">",with:"&gt;"))</f><v>\(value ?? "0")</v></c>"
        } else if let value,!value.isEmpty {
            if date {
                guard let d=DMDate.parse(value) else{throw DMError.invalidDate}
                var cal=Calendar(identifier:.gregorian);cal.timeZone=TimeZone(secondsFromGMT:0)!
                let base=cal.date(from:DateComponents(year:1899,month:12,day:30))!
                let serial=cal.dateComponents([.day],from:base,to:d).day!
                cell="<c r=\"\(ref)\"\(style)><v>\(serial)</v></c>"
            } else if column=="I",value.first != "0",Int(value) != nil {
                cell="<c r=\"\(ref)\"\(style)><v>\(value)</v></c>"
            } else {
                let safe=value.replacingOccurrences(of:"&",with:"&amp;")
                    .replacingOccurrences(of:"<",with:"&lt;")
                    .replacingOccurrences(of:">",with:"&gt;")
                    .replacingOccurrences(of:"\"",with:"&quot;")
                cell="<c r=\"\(ref)\"\(style) t=\"inlineStr\"><is><t xml:space=\"preserve\">\(safe)</t></is></c>"
            }
        } else {
            // Las celdas sin dato siguen exactamente como en la plantilla.
            return row
        }
        return row.replacingCharacters(in:range,with:cell)
    }
    private static func hasDNI(_ row:String,_ rowNumber:Int)throws->Bool {
        let ref="I"+String(rowNumber)
        let hits=try matches(#"<c\b[^>]*\br=""#+ref+#""[^>]*(?:/>|>.*?</c>)"#,row)
        guard hits.count==1,let range=Range(hits[0].range,in:row) else{throw DMError.templateMismatch}
        let text=String(row[range])
        // Nunca reutilizar una fila que tenga identificador de trabajador.
        if text.contains("<is>"){return true}
        return (try matches(#"<v>\s*[^<\s]+\s*</v>"#,text)).count>0
    }
    private static func fill(_ xml:String,_ records:[DMCertificate])throws->String {
        guard xml.contains(#"<dimension ref="A1:AE4093""#),
              xml.contains("<sheetData>"),xml.contains("</sheetData>") else {
            throw DMError.templateMismatch
        }
        let matches=try matches(#"<row\b[^>]*\br="(\d+)"[^>]*>.*?</row>"#,xml)
        guard matches.count==4093 else{throw DMError.templateMismatch}
        var replacements:[(Range<String.Index>,String)]=[]
        var left=records[...]
        for hit in matches {
            guard !left.isEmpty else{break}
            guard let r=Range(hit.range,in:xml),let n=Range(hit.range(at:1),in:xml),
                  let rowNumber=Int(xml[n]),rowNumber>=2 else{continue}
            let original=String(xml[r])
            guard try !hasDNI(original,rowNumber) else{continue}
            let c=left.removeFirst()
            var row=original
            for (column,value,isDate) in [
                ("F",c.receiptDate,true),("I",c.dni,false),
                ("O",c.startDate,true),("P",c.endDate,true),
                ("R",c.contingency,false),("S",c.issuer,false),
                ("U",c.diagnosis,false),("AA",c.cmp,false),
                ("AC",c.doctor,false)
            ] {
                row=try replaceCell(in:row,column:column,number:rowNumber,value:value,date:isDate)
            }
            row=try replaceCell(in:row,column:"Q",number:rowNumber,
                                value:String(c.calculatedDays ?? 0),formula:true)
            replacements.append((r,row))
        }
        guard left.isEmpty else{throw DMError.capacityExceeded}
        var result=xml
        for (range,row) in replacements.reversed() {
            result.replaceSubrange(range,with:row)
        }
        return result
    }
}