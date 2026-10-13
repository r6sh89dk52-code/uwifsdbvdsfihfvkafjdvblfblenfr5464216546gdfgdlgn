const assert=require('node:assert/strict');
const fs=require('node:fs'),ts=require('typescript');
const {zipSync,unzipSync,strToU8,strFromU8}=require('fflate');
const {DOMParser,XMLSerializer}=require('@xmldom/xmldom');
const NS='http://schemas.openxmlformats.org/spreadsheetml/2006/main';
const source=fs.readFileSync('src/kardexExcelTemplate.ts','utf8');
const result=ts.transpileModule(source,{compilerOptions:{module:ts.ModuleKind.CommonJS,target:ts.ScriptTarget.ES2022}});
const module={exports:{}};
new Function('require','module','exports','DOMParser','XMLSerializer',result.outputText)
  (name=>name==='fflate'?require('fflate'):{},module,module.exports,DOMParser,XMLSerializer);
const {exportOfficialKardex}=module.exports;
const wrap=(name,inside)=>'<'+name+' xmlns="'+NS+'">'+inside+'</'+name+'>';
const mainRows='<row r="7"><c r="C7" t="s"><v>0</v></c></row><row r="104"><c r="C104" t="s"><v>1</v></c></row>';
const sheet=wrap('worksheet','<dimension ref="A1:J109"/><sheetData>'+mainRows+'</sheetData><mergeCells count="1"><mergeCell ref="A1:J1"/></mergeCells><pageMargins left="0.19685039370078741" right="0" top="0.19685039370078741" bottom="0" header="0" footer="0"/><pageSetup paperSize="9" scale="90" orientation="portrait"/>');
const workbook=wrap('workbook','<bookViews><workbookView activeTab="1"/></bookViews><sheets><sheet name="Hoja1" sheetId="3"/><sheet name="KARDEX ENFERMERAS" sheetId="2"/></sheets><calcPr calcId="191029"/>');
const original={
 '[Content_Types].xml': '<?xml version="1.0"?><Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/><Override PartName="/xl/worksheets/sheet2.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/><Override PartName="/docProps/app.xml" ContentType="application/vnd.openxmlformats-officedocument.extended-properties+xml"/></Types>',
 '_rels/.rels':'<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/extended-properties" Target="docProps/app.xml"/></Relationships>',
 'xl/workbook.xml':workbook,
 'xl/_rels/workbook.xml.rels':'<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/><Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet2.xml"/></Relationships>',
 'xl/worksheets/sheet1.xml':wrap('worksheet','<sheetData><row r="6"><c r="A6" t="s"><v>2</v></c></row></sheetData>'),
 'xl/worksheets/sheet2.xml':sheet,
 'xl/styles.xml':wrap('styleSheet','<cellXfs count="1"><xf numFmtId="0"/></cellXfs>'),
 'xl/sharedStrings.xml':wrap('sst','<si><t>AERO-OM GRAGEAS</t></si><si><t>REPELENTE</t></si><si><t>Azitral 200 15ml</t></si>'),
 'docProps/app.xml':'<Properties>2 sheets Hoja1</Properties>'
};
const fixture=zipSync(Object.fromEntries(Object.entries(original).map(([n,c])=>[n,strToU8(c)])));
const rows=Array.from({length:98},(_,i)=>({code:'E-'+(i+1),name:i===0?'AERO-OM GRAGEAS':i===97?'REPELENTE':'FICTICIO',donated:false,
 stockKnown:i===1,initial:0,extraordinary:0,total:0,consumed:0,final:0,expiry:'',fs:null}));
const report={date:'2026-10-13',rows,exportable:true,warnings:[]};
const out=unzipSync(exportOfficialKardex(fixture,report,'MAÑANA','RESPONSABLE FICTICIO'));
assert(!out['xl/worksheets/sheet1.xml']);
assert(!out['xl/worksheets/_rels/sheet1.xml.rels']);
assert(!out['docProps/app.xml']);
const book=strFromU8(out['xl/workbook.xml']),x=strFromU8(out['xl/worksheets/sheet2.xml']),strings=strFromU8(out['xl/sharedStrings.xml']);
assert(book.includes('KARDEX ENFERMERAS'));assert(!book.includes('Hoja1'));
assert(x.includes('paperSize="9"')&&x.includes('scale="90"')&&x.includes('orientation="portrait"'));
assert(x.includes('mergeCells'));assert(!strings.includes('Azitral'));
const doc=new DOMParser().parseFromString(x,'application/xml');
function cell(ref){return Array.from(doc.getElementsByTagNameNS(NS,'c')).find(c=>c.getAttribute('r')===ref)}
assert.equal(cell('D7')?.getElementsByTagNameNS(NS,'v').length||0,0,'unreported stock remains blank');
assert.equal(cell('D8').getElementsByTagNameNS(NS,'v')[0].textContent,'0','confirmed zero is numeric zero');
assert(cell('C104'),'last main product preserved');
console.log('PASS: Kardex XLSX has only original 98-row print sheet A4 portrait 90%, no donor names, blank unknown stock vs confirmed zero.');
