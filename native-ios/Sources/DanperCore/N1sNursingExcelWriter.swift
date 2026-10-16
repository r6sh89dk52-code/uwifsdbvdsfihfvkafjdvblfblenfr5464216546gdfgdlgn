import Foundation
import CoreFoundation

/// N1s other official workbook: nursing Kardex with its 98 rows, NOT the
/// 432-material ambulatory Indicator. Isolated from real clinical storage.
internal enum N1sNursingExcelWriter {
    private static func regex(_ pattern:String) throws -> NSRegularExpression {
        try NSRegularExpression(pattern:pattern,options:[.dotMatchesLineSeparators])
    }
    private static func match(_ pattern:String,in text:String) throws -> [NSTextCheckingResult] {
        try regex(pattern).matches(in:text,range:NSRange(text.startIndex..<text.endIndex,in:text))
    }
    private static func firstRange(_ pattern:String,in text:String) throws -> Range<String.Index>? {
        guard let m=try match(pattern,in:text).first else {return nil}
        return Range(m.range,in:text)
    }
    private static func escape(_ text:String) throws -> String {
        guard text.utf16.count<=32767,!text.unicodeScalars.contains(where:{
            $0.value<32 && ![9,10,13].contains($0.value)
        }) else {throw N1sExcelError.invalidRow}
        return text.replacingOccurrences(of:"&",with:"&amp;")
            .replacingOccurrences(of:"<",with:"&lt;")
            .replacingOccurrences(of:">",with:"&gt;")
            .replacingOccurrences(of:"\"",with:"&quot;")
            .replacingOccurrences(of:"'",with:"&apos;")
    }
    private static func numeric(_ input:Any?) -> Double? {
        guard let n=input as? NSNumber,CFGetTypeID(n) != CFBooleanGetTypeID(),
              n.doubleValue.isFinite else{return nil}
        return n.doubleValue
    }
    private static func patch(_ source:String,address:String,
                              value:Any?,formula:String?=nil) throws -> String {
        let rx="<c\\b[^>]*\\br=\"" + NSRegularExpression.escapedPattern(for:address) + "\"[^>]*(?:/>|>.*?</c>)"
        var xml=source
        let current=try firstRange(rx,in:xml)
        var existingStyle=""
        if let current {
            let tag=String(xml[current])
            if let m=try match(#"\bs="([^"]+)""#,in:tag).first,
               let r=Range(m.range(at:1),in:tag) {
                existingStyle=" s=\""+String(tag[r])+"\""
            }
        }
        let head="<c r=\""+address+"\""+existingStyle
        let rendered:String
        if let formula {
            let f=try escape(formula)
            if let num=numeric(value) {
                rendered=head+"><f>"+f+"</f><v>"+String(format:"%.12g",num)+"</v></c>"
            }else {
                rendered=head+"><f>"+f+"</f></c>"
            }
        }else if let num=numeric(value) {
            rendered=head+"><v>"+String(format:"%.12g",num)+"</v></c>"
        }else if let string=value as? String,!string.isEmpty {
            rendered=head+" t=\"inlineStr\"><is><t xml:space=\"preserve\">" + (try escape(string)) + "</t></is></c>"
        }else {
            rendered=head+"/>"
        }
        if let current {
            xml.replaceSubrange(current,with:rendered)
        }else{
            guard let number=Int(address.drop(while:{$0.isLetter})),
                  (1...104).contains(number) else {throw N1sExcelError.invalidTemplate}
            let pattern="<row\\b[^>]*\\br=\""+String(number)+"\"[^>]*>.*?</row>"
            guard let r=try firstRange(pattern,in:xml) else {
                throw N1sExcelError.invalidTemplate
            }
            let old=String(xml[r])
            let changed=old.replacingOccurrences(of:"</row>",with:rendered+"</row>")
            xml.replaceSubrange(r,with:changed)
        }
        return xml
    }
    private static func dateLabel(_ date:String) throws -> String {
        let dateFormat=#"^\d{4}-\d{2}-\d{2}$"#
        guard date.range(of:dateFormat,options:.regularExpression) != nil
        else {throw N1sExcelError.invalidManifest}
        let chunks=date.split(separator:"-")
        return chunks[2]+"/"+chunks[1]+"/"+chunks[0]
    }
    static func export(base:Data,manifest:Data) throws -> N1sExcelResult {
        guard manifest.count<=1_000_000,
              let object=try? JSONSerialization.jsonObject(with:manifest) as? [String:Any],
              let rows=object["rows"] as? [[String:Any]],rows.count==98,
              let date=object["date"] as? String,
              let shift=object["shift"] as? String,
              ["MAÑANA","TARDE","NOCHE","CONSOLIDADO"].contains(shift),
              let responsible=object["responsible"] as? String,
              !responsible.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty
        else {throw N1sExcelError.invalidManifest}
        var entries=try N1rStoredZip.unpack(base)
        guard entries.contains(where:{$0.name=="xl/worksheets/sheet2.xml"}),
              entries.contains(where:{$0.name=="xl/workbook.xml"}),
              entries.contains(where:{$0.name=="xl/sharedStrings.xml"}),
              entries.contains(where:{$0.name=="xl/printerSettings/printerSettings2.bin"}),
              let book=entries.first(where:{$0.name=="xl/workbook.xml"}),
              let workbook=String(data:book.data,encoding:.utf8),
              workbook.contains("KARDEX ENFERMERAS") else {
            throw N1sExcelError.invalidTemplate
        }
        var seen=Set<String>()
        for row in rows {
            guard let code=row["code"] as? String,!code.isEmpty,seen.insert(code).inserted,
                  let name=row["name"] as? String,!name.isEmpty,
                  row["donated"] as? Bool==false,
                  let stockKnown=row["stockKnown"] as? Bool,
                  (!stockKnown ||
                    (numeric(row["initial"]) != nil &&
                     numeric(row["extraordinary"]) != nil &&
                     numeric(row["total"]) != nil &&
                     numeric(row["consumed"]) != nil &&
                     numeric(row["final"]) != nil)) else {
                throw N1sExcelError.invalidManifest
            }
        }
        let dateName=try dateLabel(date)
        guard let offset=entries.firstIndex(where:{$0.name=="xl/worksheets/sheet2.xml"}),
              var sheet=String(data:entries[offset].data,encoding:.utf8),
              sheet.contains("<mergeCells"),sheet.contains("C104") else {
            throw N1sExcelError.invalidTemplate
        }
        sheet=try patch(sheet,address:"A3",value:"TURNO: "+shift)
        sheet=try patch(sheet,address:"A4",value:"RESPONSABLE: "+responsible)
        sheet=try patch(sheet,address:"I3",value:"FECHA: "+dateName)
        for (i,row) in rows.enumerated() {
            let n=String(i+7)
            let known=(row["stockKnown"] as? Bool)==true
            sheet=try patch(sheet,address:"D"+n,value:known ? row["initial"] : nil)
            sheet=try patch(sheet,address:"E"+n,value:known ? row["extraordinary"] : nil)
            sheet=try patch(sheet,address:"F"+n,value:known ? row["total"] : nil,
                            formula:known ? "D"+n+"+E"+n : nil)
            sheet=try patch(sheet,address:"G"+n,value:known ? row["consumed"] : nil)
            sheet=try patch(sheet,address:"H"+n,value:known ? row["final"] : nil,
                            formula:known ? "F"+n+"-G"+n : nil)
            sheet=try patch(sheet,address:"I"+n,value:row["expiry"])
            sheet=try patch(sheet,address:"J"+n,value:row["fs"])
        }
        entries[offset]=N1rStoredEntry(name:entries[offset].name,data:Data(sheet.utf8))
        let output=try N1rStoredZip.pack(entries)
        _=try N1rStoredZip.unpack(output)
        return N1sExcelResult(xlsx:output,sheetCount:1,writtenRows:98)
    }
}
