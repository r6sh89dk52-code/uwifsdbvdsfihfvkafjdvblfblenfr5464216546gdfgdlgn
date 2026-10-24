import Foundation
import CoreFoundation

/// Only the visible A:Q worksheet from the supplied "03- INDICADOR DE
/// VIGILANCIA OCUPACIONAL.xlsx". No hidden lookup sheets, example patients,
/// clinical diagnoses or fictional organization codes are ever exported.
/// Header strings, column sizes, green/white emphasis and date/DNI styles
/// follow the original visible sheet. Writing is read-only on the vault.
public enum N2OccupationalVigilanceWorkbook {
    public enum Failure:Error,Equatable {
        case invalidSource,invalidDates,invalidAttention,tooManyRows
    }
    public struct Result:Sendable {
        public let xlsx:Data
        public let rows:Int
        public let skippedMissingIdentity:Int
        public let sheetName:String
    }
    private static let sheetName="VIGILACIA OCUPACIONAL"
    private static let headers=[
        "DSUBDIVISION","UNIDAD ORGANIZATIVA","SUBDIVISION",
        "UNIDAD\nORGANIZATIVA","LABOR","PLANILLA","FECHA",
        "HORA DE ATENCION","DNI","APELLIDOS Y NOMBRES","EDAD",
        "SEXO","TIPOS DE AGENTES","RIESGOS","MEDIDAS A TOMAR",
        "DNI DE RESPONSABLE","RESPONSABLE DE LA ATENCION"
    ]
    private static let widths:[Double]=[
        15.140625,31.85546875,14.140625,13.42578125,25,12,
        13.85546875,11.85546875,11.42578125,43,8,9.5703125,
        35,30.42578125,44.28515625,21.28515625,29.5703125
    ]
    private static func string(_ any:Any?)->String {
        any as? String ?? ""
    }
    private static func iso(_ date:String)->Bool {
        guard date.range(of:#"^\d{4}-\d{2}-\d{2}$"#,
                         options:.regularExpression) != nil else{return false}
        var calendar=Calendar(identifier:.gregorian)
        calendar.timeZone=TimeZone(identifier:"America/Lima")!
        let parts=date.split(separator:"-").compactMap{Int($0)}
        guard parts.count==3,
              let day=calendar.date(from:DateComponents(
                year:parts[0],month:parts[1],day:parts[2])),
              calendar.component(.year,from:day)==parts[0],
              calendar.component(.month,from:day)==parts[1],
              calendar.component(.day,from:day)==parts[2] else{return false}
        return true
    }
    private static func excelDay(_ date:String)->Int {
        let p=date.split(separator:"-").compactMap{Int($0)}
        var cal=Calendar(identifier:.gregorian)
        cal.timeZone=TimeZone(secondsFromGMT:0)!
        let d=cal.date(from:DateComponents(year:p[0],month:p[1],day:p[2]))!
        let base=cal.date(from:DateComponents(year:1899,month:12,day:30))!
        return cal.dateComponents([.day],from:base,to:d).day!
    }
    private static func clean(_ value:String)->String {
        let sanitized=String(value.unicodeScalars.filter {
            $0.value>=32 || [9,10,13].contains($0.value)
        })
        return String(sanitized.prefix(32767))
    }
    private static func escape(_ raw:String)->String {
        clean(raw).replacingOccurrences(of:"&",with:"&amp;")
            .replacingOccurrences(of:"<",with:"&lt;")
            .replacingOccurrences(of:">",with:"&gt;")
            .replacingOccurrences(of:"\"",with:"&quot;")
            .replacingOccurrences(of:"'",with:"&apos;")
    }
    private static func cell(_ col:String,_ row:Int,_ text:String,
                             style:Int=3)->String {
        "<c r=\"\(col)\(row)\" s=\"\(style)\" t=\"inlineStr\"><is><t xml:space=\"preserve\">" +
        escape(text) + "</t></is></c>"
    }
    private static func number(_ col:String,_ row:Int,_ value:Int,
                               style:Int)->String {
        "<c r=\"\(col)\(row)\" s=\"\(style)\"><v>\(value)</v></c>"
    }
    private static func record(_ visit:[String:Any],row:Int)->String {
        let worker=visit["worker"] as? [String:Any] ?? [:]
        let date=string(visit["date"])
        let code=string(worker["dni"])
        let age=N2WorkerAge.years(
            birthDate:string(worker["birthDate"]),on:date) ??
            Int(String(describing:worker["age"] ?? ""))
        let responsible=string(visit["responsible"])
        let fields:[String]=[
            string(worker["site"]),string(worker["area"]),
            string(worker["subdivisionCode"]),string(worker["organizationCode"]),
            string(worker["labor"]),string(worker["planilla"]),"",
            string(visit["time"]),code,string(worker["name"]),"",
            string(worker["sex"]),"DISERGONOMICO","Posturas inadecuadas",
            "Capacitacion y ejecucion de pausas activas",
            string(visit["responsibleDni"]),responsible
        ]
        let letters=Array("ABCDEFGHIJKLMNOPQ").map(String.init)
        var cells=[String]()
        for index in 0..<17 {
            let col=letters[index]
            if index==6 {
                cells.append(number(col,row,excelDay(date),style:5))
            } else if index==10,let age,(0...120).contains(age) {
                cells.append(number(col,row,age,style:3))
            } else {
                let style = [2,3].contains(index) ? 4 :
                    [8,15].contains(index) ? 6 : 3
                cells.append(cell(col,row,fields[index],style:style))
            }
        }
        return "<row r=\"\(row)\" spans=\"1:17\" ht=\"18\" customHeight=\"1\">" +
            cells.joined()+"</row>"
    }
    private static func worksheet(_ visits:[[String:Any]])->String {
        let letters=Array("ABCDEFGHIJKLMNOPQ").map(String.init)
        let columns=widths.enumerated().map{index,width in
            "<col min=\"\(index+1)\" max=\"\(index+1)\" width=\"\(width)\" customWidth=\"1\"/>"
        }.joined()
        let header=zip(letters,headers).map{col,label in
            cell(col,1,label,style:["C","D"].contains(col) ? 2:1)
        }.joined()
        let body=visits.enumerated().map{i,visit in
            record(visit,row:i+2)
        }.joined()
        return """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
        <dimension ref="A1:Q\(max(2,visits.count+1))"/>
        <sheetViews><sheetView showGridLines="0" zoomScale="73" workbookViewId="0">
        <selection activeCell="A2" sqref="A2"/></sheetView></sheetViews>
        <sheetFormatPr defaultRowHeight="15"/>
        <cols>\(columns)</cols><sheetData>
        <row r="1" spans="1:17" ht="37.15" customHeight="1">\(header)</row>\(body)
        </sheetData>
        <autoFilter ref="A1:Q\(max(2,visits.count+1))"/>
        <pageMargins left="0.3" right="0.3" top="0.5" bottom="0.5" header="0.2" footer="0.2"/>
        <pageSetup orientation="landscape" fitToWidth="1"/>
        </worksheet>
        """
    }
    /// Colors and typography copied from the visible source sheet:
    /// Calibri 8, green #00B050, white coded headings C/D, thin borders,
    /// and the blue-tinted organizational code columns.
    private static let styles="""
    <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
    <styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
      <numFmts count="2"><numFmt numFmtId="164" formatCode="dd/mm/yyyy"/>
      <numFmt numFmtId="165" formatCode="@"/></numFmts>
      <fonts count="3">
        <font><sz val="11"/><color rgb="FF000000"/><name val="Calibri"/></font>
        <font><b/><sz val="8"/><color rgb="FFFFFFFF"/><name val="Calibri"/></font>
        <font><sz val="8"/><color rgb="FF000000"/><name val="Calibri"/></font>
      </fonts>
      <fills count="4"><fill><patternFill patternType="none"/></fill>
      <fill><patternFill patternType="gray125"/></fill>
      <fill><patternFill patternType="solid"><fgColor rgb="FF00B050"/><bgColor indexed="64"/></patternFill></fill>
      <fill><patternFill patternType="solid"><fgColor rgb="FFDDE8F3"/><bgColor indexed="64"/></patternFill></fill></fills>
      <borders count="2"><border><left/><right/><top/><bottom/><diagonal/></border>
      <border><left style="thin"/><right style="thin"/><top style="thin"/>
      <bottom style="thin"/><diagonal/></border></borders>
      <cellStyleXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0"/></cellStyleXfs>
      <cellXfs count="7">
        <xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/>
        <xf numFmtId="0" fontId="1" fillId="2" borderId="1" xfId="0" applyAlignment="1"><alignment vertical="center" wrapText="1"/></xf>
        <xf numFmtId="0" fontId="2" fillId="0" borderId="1" xfId="0" applyAlignment="1"><alignment horizontal="center" vertical="center" wrapText="1"/></xf>
        <xf numFmtId="0" fontId="2" fillId="0" borderId="1" xfId="0" applyAlignment="1"><alignment horizontal="center" vertical="center"/></xf>
        <xf numFmtId="0" fontId="2" fillId="3" borderId="1" xfId="0" applyAlignment="1"><alignment horizontal="center" vertical="center"/></xf>
        <xf numFmtId="164" fontId="2" fillId="0" borderId="1" xfId="0" applyNumberFormat="1" applyAlignment="1"><alignment horizontal="center" vertical="center"/></xf>
        <xf numFmtId="165" fontId="2" fillId="0" borderId="1" xfId="0" applyNumberFormat="1" applyAlignment="1"><alignment horizontal="center" vertical="center"/></xf>
      </cellXfs><cellStyles count="1"><cellStyle name="Normal" xfId="0" builtinId="0"/></cellStyles>
    </styleSheet>
    """
    private static let types="""
    <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
    <Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
    <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
    <Default Extension="xml" ContentType="application/xml"/>
    <Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>
    <Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>
    <Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>
    </Types>
    """
    private static let relationships="""
    <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
    <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
    <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>
    </Relationships>
    """
    private static let workbook="""
    <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
    <workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"
    xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
    <bookViews><workbookView activeTab="0"/></bookViews>
    <sheets><sheet name="VIGILACIA OCUPACIONAL" sheetId="1" r:id="rId1"/></sheets>
    </workbook>
    """
    private static let workbookRels="""
    <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
    <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
    <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/>
    <Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>
    </Relationships>
    """
    public static func export(snapshot:Data,start:String,end:String)throws->Result {
        guard iso(start),iso(end),start<=end else{throw Failure.invalidDates}
        _=try N1eLegacyClinicalAudit.inspect(snapshot)
        _=try N1fLosslessFieldGate.inspect(snapshot)
        guard let root=try? JSONSerialization.jsonObject(with:snapshot) as? [String:Any],
              let visits=root["attentions"] as? [[String:Any]] else {
            throw Failure.invalidSource
        }
        var unique=Set<String>(),missing=0,selected=[[String:Any]]()
        for visit in visits {
            guard string(visit["status"])=="saved",
                  string(visit["system"]).trimmingCharacters(
                    in:.whitespacesAndNewlines).uppercased()=="OSTEOMUSCULAR",
                  let date=visit["date"] as? String,
                  iso(date),date>=start,date<=end else{continue}
            guard let id=visit["id"] as? String,!id.isEmpty else{
                throw Failure.invalidAttention
            }
            if !unique.insert(id).inserted {throw Failure.invalidAttention}
            let worker=visit["worker"] as? [String:Any] ?? [:]
            if string(worker["dni"]).count != 8 ||
                string(worker["name"]).isEmpty {
                missing+=1
                continue
            }
            selected.append(visit)
            if selected.count>20_000 {throw Failure.tooManyRows}
        }
        selected.sort {
            (string($0["date"]),string($0["time"]),string($0["id"])) <
            (string($1["date"]),string($1["time"]),string($1["id"]))
        }
        let entries:[N1rStoredEntry]=[
            .init(name:"[Content_Types].xml",data:Data(types.utf8)),
            .init(name:"_rels/.rels",data:Data(relationships.utf8)),
            .init(name:"xl/workbook.xml",data:Data(workbook.utf8)),
            .init(name:"xl/_rels/workbook.xml.rels",data:Data(workbookRels.utf8)),
            .init(name:"xl/styles.xml",data:Data(styles.utf8)),
            .init(name:"xl/worksheets/sheet1.xml",data:Data(worksheet(selected).utf8))
        ]
        let output=try N1rStoredZip.pack(entries)
        return Result(xlsx:output,rows:selected.count,
                      skippedMissingIdentity:missing,sheetName:sheetName)
    }
}
