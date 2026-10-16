import Foundation
import CoreFoundation

/// N1r: an isolated, native Swift proof-of-concept XLSX writer.
/// Accepts ONLY a stored/CRC-verified, already sanitized ten-sheet package.
/// Does not read clinical vaults, claim formula/style parity or integrate UI.
internal enum N1rWorkbookError: Error, Equatable {
    case invalidArchive, unsafeArchive, badCRC, invalidTemplate
    case invalidPlan, invalidValue, duplicateRow, invalidXML, oversized
}

internal struct N1rStoredEntry {
    let name: String
    let data: Data
}

internal enum N1rStoredZip {
    private static let maxFiles = 256
    private static let maxExpanded = 40_000_000
    private static let maxMember = 24_000_000

    private static func u16(_ bytes: [UInt8], _ p: Int) throws -> Int {
        guard p >= 0, p <= bytes.count - 2 else {throw N1rWorkbookError.invalidArchive}
        return Int(bytes[p]) | Int(bytes[p + 1]) << 8
    }
    private static func u32(_ bytes: [UInt8], _ p: Int) throws -> Int {
        guard p >= 0, p <= bytes.count - 4 else {throw N1rWorkbookError.invalidArchive}
        return Int(bytes[p]) | Int(bytes[p + 1]) << 8 |
            Int(bytes[p + 2]) << 16 | Int(bytes[p + 3]) << 24
    }
    private static func add16(_ value: Int, _ into: inout Data) {
        into.append(UInt8(truncatingIfNeeded:value))
        into.append(UInt8(truncatingIfNeeded:value >> 8))
    }
    private static func add32(_ value: Int, _ into: inout Data) {
        into.append(UInt8(truncatingIfNeeded:value))
        into.append(UInt8(truncatingIfNeeded:value >> 8))
        into.append(UInt8(truncatingIfNeeded:value >> 16))
        into.append(UInt8(truncatingIfNeeded:value >> 24))
    }
    private static func crc(_ data: Data) -> Int {
        var crc:UInt32=0xffffffff
        for byte in data {
            crc ^= UInt32(byte)
            for _ in 0..<8 {
                crc=(crc >> 1) ^ (crc & 1 == 1 ? 0xedb88320 : 0)
            }
        }
        return Int(crc ^ 0xffffffff)
    }
    private static func acceptable(_ name: String) -> Bool {
        !name.isEmpty && !name.hasPrefix("/") && !name.contains("\\") &&
        !name.contains("..") && !name.contains(":") &&
        !name.unicodeScalars.contains(where: { $0.value < 32 }) &&
        name.utf8.count < 200 && !name.hasSuffix("/")
    }
    static func unpack(_ data:Data) throws -> [N1rStoredEntry] {
        guard data.count >= 22, data.count <= maxExpanded else {
            throw N1rWorkbookError.invalidArchive
        }
        let bytes=[UInt8](data), last=data.count - 22
        let earliest=max(0,data.count - 65557)
        var end:Int?
        if earliest<=last {
            for i in stride(from:last,through:earliest,by:-1) {
                if (try? u32(bytes,i)) == 0x06054b50,
                   let comment=try? u16(bytes,i+20), i + 22 + comment == bytes.count {
                    end=i
                    break
                }
            }
        }
        guard let eocd=end,(try u16(bytes,eocd+4)) == 0,
              (try u16(bytes,eocd+6)) == 0 else {throw N1rWorkbookError.invalidArchive}
        let count=try u16(bytes,eocd+10)
        let diskCount=try u16(bytes,eocd+8)
        let directoryBytes=try u32(bytes,eocd+12)
        let directoryOffset=try u32(bytes,eocd+16)
        guard count>0,count<=maxFiles,count==diskCount,
              directoryOffset <= eocd,directoryBytes==eocd-directoryOffset
        else {throw N1rWorkbookError.invalidArchive}
        var pos=directoryOffset,used=0,seen=Set<String>()
        var entries:[N1rStoredEntry]=[]
        var positions:[(start:Int,end:Int)]=[]
        for _ in 0..<count {
            guard (try u32(bytes,pos)) == 0x02014b50 else {
                throw N1rWorkbookError.invalidArchive
            }
            let flags=try u16(bytes,pos+8),method=try u16(bytes,pos+10)
            let checksum=try u32(bytes,pos+16)
            let compressed=try u32(bytes,pos+20)
            let uncompressed=try u32(bytes,pos+24)
            let length=try u16(bytes,pos+28)
            let extra=try u16(bytes,pos+30)
            let comment=try u16(bytes,pos+32)
            let offset=try u32(bytes,pos+42)
            guard (flags & ~0x0800)==0,method==0,
                  compressed==uncompressed,uncompressed<=maxMember,
                  used<=maxExpanded-uncompressed,
                  pos+46+length+extra+comment<=eocd,
                  length>0 else {throw N1rWorkbookError.unsafeArchive}
            guard let name=String(bytes:bytes[(pos+46)..<(pos+46+length)],
                                  encoding:.utf8),acceptable(name),seen.insert(name).inserted
            else {throw N1rWorkbookError.unsafeArchive}
            guard offset+30<=directoryOffset,
                  (try u32(bytes,offset))==0x04034b50,
                  (try u16(bytes,offset+6))==flags,
                  (try u16(bytes,offset+8))==method else {
                throw N1rWorkbookError.invalidArchive
            }
            let localName=try u16(bytes,offset+26)
            let localExtra=try u16(bytes,offset+28)
            let contentStart=offset+30+localName+localExtra
            guard contentStart<=directoryOffset,compressed<=directoryOffset-contentStart,
                  localName==length,
                  bytes[(offset+30)..<(offset+30+localName)].elementsEqual(
                    bytes[(pos+46)..<(pos+46+length)]) else {
                throw N1rWorkbookError.invalidArchive
            }
            let body=Data(bytes[contentStart..<(contentStart+compressed)])
            guard crc(body)==checksum else {throw N1rWorkbookError.badCRC}
            entries.append(N1rStoredEntry(name:name,data:body))
            positions.append((start:offset,end:contentStart+compressed))
            pos+=46+length+extra+comment
            used+=uncompressed
        }
        guard pos==eocd else {throw N1rWorkbookError.invalidArchive}
        positions.sort{$0.start<$1.start}
        for i in 1..<positions.count {
            guard positions[i].start>=positions[i-1].end else {
                throw N1rWorkbookError.unsafeArchive
            }
        }
        return entries
    }
    static func pack(_ entries:[N1rStoredEntry]) throws -> Data {
        guard !entries.isEmpty,entries.count<=maxFiles else {
            throw N1rWorkbookError.oversized
        }
        var result=Data(),directory=Data(),names=Set<String>()
        var total=0
        for e in entries {
            guard acceptable(e.name),names.insert(e.name).inserted,
                  e.data.count<=maxMember,total<=maxExpanded-e.data.count else {
                throw N1rWorkbookError.unsafeArchive
            }
            total+=e.data.count
            let name=Data(e.name.utf8),offset=result.count,checksum=crc(e.data)
            guard offset<=Int(UInt32.max),name.count<=Int(UInt16.max)
            else {throw N1rWorkbookError.oversized}
            add32(0x04034b50,&result)
            add16(20,&result);add16(0x0800,&result)
            add16(0,&result);add16(0,&result);add16(0,&result)
            add32(checksum,&result);add32(e.data.count,&result);add32(e.data.count,&result)
            add16(name.count,&result);add16(0,&result)
            result.append(name);result.append(e.data)
            add32(0x02014b50,&directory)
            add16(20,&directory);add16(20,&directory)
            add16(0x0800,&directory);add16(0,&directory)
            add16(0,&directory);add16(0,&directory)
            add32(checksum,&directory)
            add32(e.data.count,&directory);add32(e.data.count,&directory)
            add16(name.count,&directory);add16(0,&directory);add16(0,&directory)
            add16(0,&directory);add16(0,&directory)
            add32(0,&directory);add32(offset,&directory)
            directory.append(name)
        }
        let start=result.count
        result.append(directory)
        add32(0x06054b50,&result)
        add16(0,&result);add16(0,&result)
        add16(entries.count,&result);add16(entries.count,&result)
        add32(directory.count,&result);add32(start,&result);add16(0,&result)
        guard result.count<=maxExpanded else {throw N1rWorkbookError.oversized}
        return result
    }
}

internal struct N1rNativeResult {
    let xlsx:Data
    let rows:Int
    let sheetNames:[String]
    let canActivate:Bool=false
    let supportsFullExcelParity:Bool=false
}

internal enum N1rNativeWorkbookWriter {
    private static let expectedSheets=[
       "BD MATERIALES","CONTEO","INGRESOS","RESU","CONSUMOS",
       "JUSTIFICACIONES","GUIA","@subuo","BASE TRU","@uo"
    ]
    private static func validString(_ string:String) -> Bool {
        string.utf16.count<=32767 && !string.unicodeScalars.contains(where:{
            let c=$0.value
            return c < 32 && c != 9 && c != 10 && c != 13
        })
    }
    private static func escape(_ s:String) -> String {
        var text=s
        text=text.replacingOccurrences(of:"&",with:"&amp;")
        text=text.replacingOccurrences(of:"<",with:"&lt;")
        text=text.replacingOccurrences(of:">",with:"&gt;")
        text=text.replacingOccurrences(of:"\"",with:"&quot;")
        text=text.replacingOccurrences(of:"'",with:"&apos;")
        return text
    }
    private static func replace(_ source:String,pattern:String,
                                with:String) throws -> String {
        let regex=try NSRegularExpression(pattern:pattern,options:[.dotMatchesLineSeparators])
        let range=NSRange(source.startIndex..<source.endIndex,in:source)
        let matches=regex.matches(in:source,range:range)
        guard matches.count==1,let match=matches.first,
              let swiftRange=Range(match.range,in:source) else {
            throw N1rWorkbookError.invalidTemplate
        }
        return source.replacingCharacters(in:swiftRange,with:with)
    }
    private static func attribute(_ text:String,name:String,value:String) throws -> String {
        let pattern="\\b"+NSRegularExpression.escapedPattern(for:name)+"=\"[^\"]*\""
        return try replace(text,pattern:pattern,with:name+"=\""+escape(value)+"\"")
    }
    private static func letter(_ number:Int) -> String {
        var i=number+1,result=""
        while i>0 {
            i-=1;result=String(UnicodeScalar(65+i%26)!)+result;i/=26
        }
        return result
    }
    private static func cell(_ input:Any,col:Int,row:Int) throws -> String {
        let ref=letter(col)+String(row)
        if let value=input as? NSNumber {
            guard CFGetTypeID(value) != CFBooleanGetTypeID(),
                  value.doubleValue.isFinite else {throw N1rWorkbookError.invalidValue}
            return "<c r=\""+ref+"\"><v>"+String(value.doubleValue)+"</v></c>"
        }
        guard let value=input as? String,validString(value) else {
            throw N1rWorkbookError.invalidValue
        }
        if value.isEmpty {return "<c r=\""+ref+"\"/>"}
        return "<c r=\"\(ref)\" t=\"inlineStr\"><is><t xml:space=\"preserve\">\(escape(value))</t></is></c>"
    }
    private static func valueRows(_ manifest:Data) throws -> [[Any]] {
        guard manifest.count<=3_000_000,
              let object=try? JSONSerialization.jsonObject(with:manifest) as? [String:Any],
              let plan=object["plan"] as? [String:Any],
              let lines=plan["lines"] as? [[String:Any]],
              lines.count<=10000 else {throw N1rWorkbookError.invalidPlan}
        var ids=Set<String>(),rows:[[Any]]=[]
        for line in lines {
            guard let id=line["id"] as? String,id.count>0,ids.insert(id).inserted,
                  let cells=line["cells"] as? [Any],cells.count==30 else {
                throw N1rWorkbookError.duplicateRow
            }
            for item in cells {
                if let string=item as? String {
                    guard validString(string) else {throw N1rWorkbookError.invalidValue}
                }else if let num=item as? NSNumber {
                    guard CFGetTypeID(num) != CFBooleanGetTypeID(),
                          num.doubleValue.isFinite else {throw N1rWorkbookError.invalidValue}
                }else{throw N1rWorkbookError.invalidValue}
            }
            // Codes and identity (DNI) must remain strings, even if all digits.
            for i in [7,15,27] {
                guard cells[i] is String else {throw N1rWorkbookError.invalidValue}
            }
            rows.append(cells)
        }
        return rows
    }
    static func export(storedTemplate:Data,syntheticPlan:Data) throws -> N1rNativeResult {
        let rows=try valueRows(syntheticPlan)
        var entries=try N1rStoredZip.unpack(storedTemplate)
        let expected:Set<String>=Set((1...10).map{"xl/worksheets/sheet"+String($0)+".xml"})
        let names=Set(entries.map{$0.name})
        guard expected.isSubset(of:names),names.contains("xl/workbook.xml"),
              names.contains("xl/styles.xml"),
              entries.filter({$0.name.hasPrefix("xl/tables/table")&&$0.name.hasSuffix(".xml")}).count==19
        else {throw N1rWorkbookError.invalidTemplate}
        let book=try String(data:entries.first{$0.name=="xl/workbook.xml"}!.data,
                            encoding:.utf8).unwrapN1r()
        let sheetPattern=try NSRegularExpression(pattern:"<sheet\\b[^>]*\\bname=\"([^\"]+)\"[^>]*/?>")
        let bookRange=NSRange(book.startIndex..<book.endIndex,in:book)
        let found=sheetPattern.matches(in:book,range:bookRange).compactMap{m -> String? in
            guard let range=Range(m.range(at:1),in:book) else {return nil}
            return String(book[range])
        }
        guard found==expectedSheets else {throw N1rWorkbookError.invalidTemplate}
        var countUpdated=0,tableUpdated=0
        let last=max(2,rows.count+1)
        var xmlRows=""
        for (i,values) in rows.enumerated() {
            let n=i+2
            xmlRows += "<row r=\""+String(n)+"\">"
            for (j,value) in values.enumerated() {
                if j==2 {
                    xmlRows += "<c r=\"C\(n)\"><f>IF(A\(n)=&quot;&quot;,&quot;&quot;,IFERROR(VLOOKUP(A\(n),'@subuo'!$A$3:$C$59,2,FALSE),&quot;&quot;))</f></c>"
                }else if j==3 {
                    xmlRows += "<c r=\"D\(n)\"><f>IF(OR(A\(n)=&quot;&quot;,B\(n)=&quot;&quot;),&quot;&quot;,IFERROR(VLOOKUP(CONCATENATE(VLOOKUP(A\(n),'@subuo'!$A$3:$C$59,3,FALSE),B\(n)),'@uo'!$D$2:$E$234,2,FALSE),&quot;&quot;))</f></c>"
                }else{
                    xmlRows += try cell(value,col:j,row:n)
                }
            }
            xmlRows += "</row>"
        }
        if rows.isEmpty {
            xmlRows="<row r=\"2\"><c r=\"A2\"/></row>"
        }
        for i in entries.indices {
            let name=entries[i].name
            guard name=="xl/worksheets/sheet5.xml" ||
                    (name.hasPrefix("xl/tables/table")&&name.hasSuffix(".xml")) else {continue}
            guard var xml=String(data:entries[i].data,encoding:.utf8),
                  !xml.contains("<!DOCTYPE"),!xml.contains("<!ENTITY") else {
                throw N1rWorkbookError.invalidXML
            }
            if name=="xl/worksheets/sheet5.xml" {
                let rowRegex=try NSRegularExpression(pattern:"<row\\b[^>]*\\br=\"1\"[^>]*>.*?</row>",
                                                    options:[.dotMatchesLineSeparators])
                let matches=rowRegex.matches(in:xml,range:NSRange(xml.startIndex..<xml.endIndex,in:xml))
                guard matches.count==1,let headerRange=Range(matches[0].range,in:xml) else {
                    throw N1rWorkbookError.invalidTemplate
                }
                let header=String(xml[headerRange])
                xml=try replace(xml,pattern:"<sheetData(?:\\s[^>]*)?>.*?</sheetData>",
                                with:"<sheetData>"+header+xmlRows+"</sheetData>")
                xml=try replace(xml,pattern:"<dimension\\b[^>]*/>",
                                with:"<dimension ref=\"A1:AD"+String(last)+"\"/>")
                countUpdated+=1
            }else if xml.contains("displayName=\"TB_CONSUMOS\"") {
                let tagRegex=try NSRegularExpression(pattern:"<table\\b[^>]*>")
                guard let m=tagRegex.firstMatch(in:xml,range:NSRange(xml.startIndex..<xml.endIndex,in:xml)),
                      let range=Range(m.range,in:xml) else {throw N1rWorkbookError.invalidTemplate}
                let orig=String(xml[range])
                let changed=try attribute(orig,name:"ref",value:"A1:AD"+String(last))
                xml.replaceSubrange(range,with:changed)
                if xml.contains("<autoFilter ") {
                    let filter=try NSRegularExpression(pattern:"<autoFilter\\b[^>]*/>")
                    guard let match=filter.firstMatch(in:xml,range:NSRange(xml.startIndex..<xml.endIndex,in:xml)),
                          let fr=Range(match.range,in:xml) else {
                        throw N1rWorkbookError.invalidTemplate
                    }
                    let attr=try attribute(String(xml[fr]),name:"ref",
                                           value:"A1:AD"+String(last))
                    xml.replaceSubrange(fr,with:attr)
                }
                tableUpdated+=1
            }
            entries[i]=N1rStoredEntry(name:name,data:Data(xml.utf8))
        }
        guard countUpdated==1,tableUpdated==1 else {
            throw N1rWorkbookError.invalidTemplate
        }
        let xlsx=try N1rStoredZip.pack(entries)
        _=try N1rStoredZip.unpack(xlsx) // immediate CRC/central-directory roundtrip
        return N1rNativeResult(xlsx:xlsx,rows:rows.count,sheetNames:found)
    }
}

private extension Optional where Wrapped==String {
    func unwrapN1r() throws -> String {
        guard let self else {throw N1rWorkbookError.invalidXML}
        return self
    }
}
