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
    /// Excel numeric values are locale-independent XML: omit a trailing .0
    /// for exact integral quantities while retaining fractions when needed.
    private static func xlsxNumber(_ value:Double) -> String {
        if value.rounded(.towardZero)==value && abs(value)<1_000_000_000_000 {
            return String(Int64(value))
        }
        return String(value)
    }
    /// Scope every mutation to ONE Excel row. Searching globally for <c>
    /// can overrun a self-closing cell and accidentally consume adjacent rows.
    private static func patch(_ source:String,address:String,
                              value:Any?,formula:String?=nil,
                              dateStyle:Int?=nil) throws -> String {
        guard let number=Int(address.drop(while:{$0.isLetter})),
              (1...104).contains(number) else {throw N1sExcelError.invalidTemplate}
        let prefix=String(address.prefix(while:{$0.isLetter}))
        let rowPattern="<row\\b[^>]*\\br=\""+String(number)+"\"[^>]*>.*?</row>"
        let rowMatches=try match(rowPattern,in:source)
        guard rowMatches.count<=1 else {throw N1sExcelError.invalidTemplate}
        let originalRow:String
        var replaceRange:Range<String.Index>?
        if let rowMatch=rowMatches.first,let range=Range(rowMatch.range,in:source) {
            originalRow=String(source[range])
            replaceRange=range
        }else {
            originalRow="<row r=\"\(number)\"></row>"
            replaceRange=nil
        }
        let cellPattern=#"<c\b[^>]*\br="([A-Z]+[0-9]+)"[^>]*(?:/>|>.*?</c>)"#
        let existing=try match(cellPattern,in:originalRow)
        var positions:[(reference:String,range:Range<String.Index>)]=[]
        for match in existing {
            guard let full=Range(match.range,in:originalRow),
                  let capture=Range(match.range(at:1),in:originalRow) else {
                throw N1sExcelError.invalidTemplate
            }
            positions.append((reference:String(originalRow[capture]),range:full))
        }
        let hit=positions.filter{$0.reference==address}
        guard hit.count<=1 else {throw N1sExcelError.invalidTemplate}
        var preservedStyle=""
        if let old=hit.first {
            let tag=String(originalRow[old.range])
            if let m=try match(#"\bs="([^"]+)""#,in:tag).first,
               let range=Range(m.range(at:1),in:tag) {
                preservedStyle=" s=\""+String(tag[range])+"\""
            }
        }
        if let dateStyle {preservedStyle=" s=\"\(dateStyle)\""}
        let head="<c r=\"\(address)\""+preservedStyle
        let rendered:String
        if let formula {
            let f=try escape(formula)
            if let num=numeric(value) {
                rendered=head+"><f>"+f+"</f><v>"+xlsxNumber(num)+"</v></c>"
            }else {
                rendered=head+"><f>"+f+"</f></c>"
            }
        }else if let num=numeric(value) {
            rendered=head+"><v>"+xlsxNumber(num)+"</v></c>"
        }else if let string=value as? String,!string.isEmpty {
            rendered=head+" t=\"inlineStr\"><is><t xml:space=\"preserve\">" + (try escape(string)) + "</t></is></c>"
        }else {
            rendered=head+"/>"
        }
        var updated=originalRow
        if let old=hit.first {
            updated.replaceSubrange(old.range,with:rendered)
        }else {
            // Official workbook may omit completely blank cells: keep ordering
            // and never steal characters from another row.
            let targetColumn=prefix.unicodeScalars.reduce(0){$0*26+Int($1.value)-64}
            var insert: String.Index?
            for candidate in positions {
                let p=String(candidate.reference.prefix(while:{$0.isLetter}))
                let n=p.unicodeScalars.reduce(0){$0*26+Int($1.value)-64}
                if n>targetColumn {
                    insert=candidate.range.lowerBound
                    break
                }
            }
            if insert==nil {
                insert=updated.range(of:"</row>",options:.backwards)?.lowerBound
            }
            guard let at=insert else {throw N1sExcelError.invalidTemplate}
            updated.insert(contentsOf:rendered,at:at)
        }
        var xml=source
        if let replaceRange {
            xml.replaceSubrange(replaceRange,with:updated)
        }else {
            // Insert a genuinely missing blank row in numeric order.
            let rowStartPattern=#"<row\b[^>]*\br="([0-9]+)""#
            let existingRows=try match(rowStartPattern,in:xml)
            var target: String.Index?
            for entry in existingRows {
                guard let valueRange=Range(entry.range(at:1),in:xml),
                      let n=Int(xml[valueRange]) else {continue}
                if n>number {
                    target=Range(entry.range,in:xml)?.lowerBound
                    break
                }
            }
            if target==nil {target=xml.range(of:"</sheetData>")?.lowerBound}
            guard let at=target else {throw N1sExcelError.invalidTemplate}
            xml.insert(contentsOf:updated,at:at)
        }
        return xml
    }
    /// Create ONE Excel number format, keeping the official template's other
    /// style indexes unchanged. Date cells stay numeric and sortable in Excel.
    private static func appendPeruvianDateStyle(_ source:String)throws -> (String,Int) {
        var xml=source
        let used=try match(#"<numFmt\b[^>]*\bnumFmtId=\"([0-9]+)\""#,in:xml)
            .compactMap {m -> Int? in
                guard let r=Range(m.range(at:1),in:xml) else{return nil}
                return Int(xml[r])
            }
        var formatID=164
        while used.contains(formatID) {formatID+=1}
        guard formatID<1000 else{throw N1sExcelError.invalidTemplate}
        let dateElement="<numFmt numFmtId=\"\(formatID)\" formatCode=\"dd/mm/yyyy\"/>"
        let openNum=try match(#"<numFmts\b[^>]*\bcount=\"([0-9]+)\"[^>]*>"#,in:xml)
        if let entry=openNum.first,
           let tagRange=Range(entry.range,in:xml),
           let countRange=Range(entry.range(at:1),in:xml),
           let count=Int(xml[countRange]),
           let close=xml.range(of:"</numFmts>") {
            let old=String(xml[tagRange])
            let updated=old.replacingOccurrences(
                of:#"count=\"[0-9]+\""#,with:"count=\"\(count+1)\"",
                options:.regularExpression)
            xml.replaceSubrange(tagRange,with:updated)
            guard let newClose=xml.range(of:"</numFmts>") else{
                throw N1sExcelError.invalidTemplate
            }
            _=close
            xml.insert(contentsOf:dateElement,at:newClose.lowerBound)
        }else if let selfClose=try firstRange(#"<numFmts\b[^>]*/>"#,in:xml) {
            xml.replaceSubrange(selfClose,with:
                "<numFmts count=\"1\">"+dateElement+"</numFmts>")
        }else {
            guard let header=try firstRange(#"<styleSheet\b[^>]*>"#,in:xml) else {
                throw N1sExcelError.invalidTemplate
            }
            xml.insert(contentsOf:"<numFmts count=\"1\">"+dateElement+"</numFmts>",
                        at:header.upperBound)
        }
        let matches=try match(#"<cellXfs\b[^>]*\bcount=\"([0-9]+)\"[^>]*>"#,in:xml)
        guard matches.count==1,let entry=matches.first,
              let tagRange=Range(entry.range,in:xml),
              let countRange=Range(entry.range(at:1),in:xml),
              let count=Int(xml[countRange]),count>=1,
              xml.contains("</cellXfs>") else {
            throw N1sExcelError.invalidTemplate
        }
        let old=String(xml[tagRange])
        let updated=old.replacingOccurrences(
            of:#"count=\"[0-9]+\""#,with:"count=\"\(count+1)\"",
            options:.regularExpression)
        xml.replaceSubrange(tagRange,with:updated)
        guard let end=xml.range(of:"</cellXfs>") else {
            throw N1sExcelError.invalidTemplate
        }
        xml.insert(contentsOf:
            "<xf numFmtId=\"\(formatID)\" fontId=\"0\" fillId=\"0\" borderId=\"0\" xfId=\"0\" applyNumberFormat=\"1\"/>",
            at:end.lowerBound)
        return(xml,count)
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
        guard let styleEntry=entries.firstIndex(where:{$0.name=="xl/styles.xml"}),
              let styles=String(data:entries[styleEntry].data,encoding:.utf8)
        else{throw N1sExcelError.invalidTemplate}
        let (updatedStyles,dateStyle)=try appendPeruvianDateStyle(styles)
        entries[styleEntry]=N1rStoredEntry(
            name:entries[styleEntry].name,data:Data(updatedStyles.utf8))
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
            let expiry=(row["expiry"] as? String) ?? ""
            let numericExpiry:Double?
            if expiry.isEmpty {
                numericExpiry=nil
            }else{
                guard let serial=DanperDatePresentation.numericExcelDate(expiry)
                else{throw N1sExcelError.invalidManifest}
                numericExpiry=serial
            }
            sheet=try patch(sheet,address:"I"+n,value:numericExpiry,
                            dateStyle:dateStyle)
            sheet=try patch(sheet,address:"J"+n,value:row["fs"])
        }
        entries[offset]=N1rStoredEntry(name:entries[offset].name,data:Data(sheet.utf8))
        let output=try N1rStoredZip.pack(entries)
        _=try N1rStoredZip.unpack(output)
        return N1sExcelResult(xlsx:output,sheetCount:1,writtenRows:98)
    }
}
