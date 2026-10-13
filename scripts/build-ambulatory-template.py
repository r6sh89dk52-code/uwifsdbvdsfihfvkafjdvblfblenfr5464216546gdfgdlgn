"""Maintainer-only extraction of reviewed layout. Never publish the private input.

The runtime exports from this empty approved skeleton, never by copying selected
historical XML. Editing this generator requires a new privacy/layout audit.
"""
import base64, hashlib, json, pathlib, re, sys, zipfile, io
from lxml import etree as E

M = 'http://schemas.openxmlformats.org/spreadsheetml/2006/main'
R = 'http://schemas.openxmlformats.org/officeDocument/2006/relationships'
P = 'http://schemas.openxmlformats.org/package/2006/relationships'
T = 'http://schemas.openxmlformats.org/package/2006/content-types'
ns = {'s': M}
source = pathlib.Path(sys.argv[1])
root = pathlib.Path(__file__).resolve().parents[1]
expected = ['BD MATERIALES','CONTEO','INGRESOS','RESU','CONSUMOS','JUSTIFICACIONES','GUIA','@subuo','BASE TRU','@uo']
parser = E.XMLParser(resolve_entities=False, no_network=True)
z = zipfile.ZipFile(source)
assert len(z.infolist()) < 200 and sum(i.file_size for i in z.infolist()) < 40_000_000
parse = lambda name: E.fromstring(z.read(name), parser)
serialize = lambda doc: E.tostring(doc, encoding='UTF-8', xml_declaration=True)
shared = [''.join(e.itertext()) for e in parse('xl/sharedStrings.xml').findall('s:si', ns)]
def value(c):
    if c.get('t') == 'inlineStr': return ''.join(c.find('s:is',ns).itertext())
    v = c.find('s:v', ns)
    return shared[int(v.text)] if c.get('t') == 's' and v is not None else (v.text or '' if v is not None else '')
def inline(c, text):
    for e in list(c): c.remove(e)
    c.attrib.pop('t',None)
    if text:
        c.set('t','inlineStr')
        t = E.SubElement(E.SubElement(c, '{'+M+'}is'), '{'+M+'}t')
        t.set('{http://www.w3.org/XML/1998/namespace}space','preserve'); t.text=text
def column(ref): return re.match('[A-Z]+',ref)[0]
book = parse('xl/workbook.xml')
assert [s.get('name') for s in book.findall('s:sheets/s:sheet',ns)] == expected
sheets = [parse(f'xl/worksheets/sheet{i}.xml') for i in range(1,11)]
products = json.loads((root/'src/products.json').read_text())
actual = []
for row in sheets[0].findall('s:sheetData/s:row',ns)[1:]:
    cells={column(c.get('r')):value(c) for c in row}
    if re.fullmatch('[0-9]+',cells.get('A','')):
        actual.append({'code':cells['A'],'name':cells['B'],'unit':cells['C']})
assert len(actual)==432
assert sorted((p['code'],p['name'].strip(),p['unit'].strip()) for p in actual)==sorted((p['code'],p['name'].strip(),p['unit'].strip()) for p in products)
headers=[value(c) for c in sheets[4].find('s:sheetData/s:row',ns)]
assert len(headers)==30
# Approved non-personal organization catalogs. Kept in the original cells.
subdivisions=[]
for row in sheets[7].findall('s:sheetData/s:row',ns)[2:]:
    cells={column(c.get('r')):value(c) for c in row}
    if cells.get('A') and cells.get('B'): subdivisions.append([cells['A'],cells['B']])
for doc in sheets+[book]:
    for e in list(doc.iter()):
        if not isinstance(e.tag,str):
            e.getparent().remove(e); continue
        # Preserve only ECMA spreadsheet nodes. Remove extension payloads,
        # revision identities, printer links, hyperlinks and headers/footers.
        if E.QName(e).namespace != M or E.QName(e).localname in ['extLst','hyperlinks','legacyDrawing','drawing','headerFooter','externalReferences','fileVersion']:
            if e is not doc and e.getparent() is not None: e.getparent().remove(e)
            continue
        for key in list(e.attrib):
            if key.startswith('{') and E.QName(key).namespace not in [R,'http://www.w3.org/XML/1998/namespace']:
                del e.attrib[key]
            if E.QName(e).localname=='pageSetup' and key=='{'+R+'}id': del e.attrib[key]
    E.cleanup_namespaces(doc)
parts={}
for i,doc in enumerate(sheets,1):
    data=doc.find('s:sheetData',ns)
    rows=list(data)
    if i in [1,2,3,4,5,6,9]:
        last_header=2 if i in [2,3,4] else 1
        for row in rows:
            n=int(row.get('r'))
            if n>last_header+1: data.remove(row)
            elif n>last_header:
                for c in row: inline(c,'')
            else:
                for c in row: inline(c,value(c))
        # Historical report labels/population must never survive in headings.
        labels={2:{'D1':'INVENTARIO PENDIENTE DE CONCILIACIÓN'},3:{'H1':'INGRESOS PENDIENTES DE CONCILIACIÓN'},4:{'A1':'KARDEX AMBULATORIO · DEMO','D1':'','E1':'PERÍODO POR SELECCIONAR','H1':'','M1':''}}
        for c in doc.findall('.//s:c',ns):
            if c.get('r') in labels.get(i,{}): inline(c,labels[i][c.get('r')])
    else:
        for row in rows:
            for c in row:
                if i==7 and int(row.get('r'))>=2 and column(c.get('r')) in ['T','U']:
                    inline(c,'')
                else: inline(c,value(c))
        if i==10:
            for row in rows[1:]:
                d=next((c for c in row if column(c.get('r'))=='D'),None)
                if d is not None:
                    inline(d,''); n=row.get('r')
                    E.SubElement(d,'{'+M+'}f').text=f'CONCATENATE(A{n},C{n})'
    for e in doc.findall('.//s:sortState',ns): e.getparent().remove(e)
    for e in doc.findall('.//s:dataValidation',ns):
        if any('#REF!' in (f.text or '') for f in e): e.getparent().remove(e)
    dv=doc.find('s:dataValidations',ns)
    if dv is not None:
        dv.set('count',str(len(dv)))
        if not len(dv):doc.remove(dv)
    for e in doc.findall('.//s:cfRule',ns):
        if e.get('type')=='containsText' and e.get('text') not in ['VENCIDO','POR VENCER']:
            # Original free-text CF can reveal diagnoses, so keep style rules
            # only when the literal is an approved generic catalog value.
            allowed={value(c) for c in sheets[6].findall('.//s:c',ns)}
            if e.get('text') not in allowed:e.getparent().remove(e)
    for e in doc.findall('s:conditionalFormatting',ns):
        if not len(e):doc.remove(e)
    if i==1:
        exemplar=data[1]
        for row in list(data)[1:]:data.remove(row)
        for n,p in enumerate(products,2):
            row=E.SubElement(data,'{'+M+'}row',r=str(n))
            for letter,key in [('A','code'),('B','name'),('C','unit')]:
                old=next((c for c in exemplar if column(c.get('r'))==letter),None)
                c=E.SubElement(row,'{'+M+'}c',r=letter+str(n))
                if old is not None and old.get('s'):c.set('s',old.get('s'))
                inline(c,p[key])
        doc.find('s:dimension',ns).set('ref','A1:C433')
    elif i in [2,3,4,5,6,9]:
        last=3 if i in [2,3,4] else 2
        width={2:'H',3:'Y',4:'M',5:'AD',6:'M',9:'F'}[i]
        doc.find('s:dimension',ns).set('ref',f'A1:{width}{last}')
    parts[f'xl/worksheets/sheet{i}.xml']=serialize(doc)
# Names contain only reviewed catalog references, never literal records.
names=book.find('s:definedNames',ns)
for e in list(names):
    if '[' in (e.text or ''):names.remove(e)
    else:
        assert re.fullmatch(r"[A-Za-z0-9_@ '\-]+!\$[A-Z]+\$[0-9]+:\$[A-Z]+\$[0-9]+",e.text or '')
for e in book.findall('s:bookViews/s:workbookView',ns):
    e.attrib.pop('lastEdited',None)
parts['xl/workbook.xml']=serialize(book)
parts['xl/styles.xml']=z.read('xl/styles.xml')
parts['xl/theme/theme1.xml']=z.read('xl/theme/theme1.xml')
for name in z.namelist():
    if re.fullmatch(r'xl/tables/table\d+\.xml',name):
        doc=parse(name)
        for e in list(doc.iter()):
            if E.QName(e).localname in ['calculatedColumnFormula','totalsRowFormula','sortState','filterColumn','extLst']:
                if e.getparent() is not None:e.getparent().remove(e)
            for key in list(e.attrib):
                if key.startswith('{'):del e.attrib[key]
        refs={'Tabla21':'A1:C433','Tabla17':'A2:M3','TB_CONSUMOS':'A1:AD2','Tabla13':'A1:F2','Tabla14':'T1:U2'}
        if doc.get('name') in refs:
            doc.set('ref',refs[doc.get('name')])
            af=doc.find('s:autoFilter',ns)
            if af is not None:af.set('ref',doc.get('ref'))
        E.cleanup_namespaces(doc);parts[name]=serialize(doc)
    if name.endswith('.rels') and name.startswith('xl/worksheets/'):
        rels=parse(name)
        for e in list(rels):
            if not e.get('Type','').endswith('/table'):rels.remove(e)
        if len(rels):parts[name]=serialize(rels)
# Rebuild package relationships/types rather than retain arbitrary metadata.
rels=E.Element('{'+P+'}Relationships',nsmap={None:P})
E.SubElement(rels,'{'+P+'}Relationship',Id='rId1',Type=R+'/officeDocument',Target='xl/workbook.xml')
parts['_rels/.rels']=serialize(rels)
rels=parse('xl/_rels/workbook.xml.rels')
for e in list(rels):
    if not any(e.get('Type','').endswith('/'+kind) for kind in ['worksheet','styles','theme']):rels.remove(e)
parts['xl/_rels/workbook.xml.rels']=serialize(rels)
types=parse('[Content_Types].xml')
for e in list(types):
    if E.QName(e).localname=='Override' and e.get('PartName','').lstrip('/') not in parts:types.remove(e)
    if E.QName(e).localname=='Default' and e.get('Extension') not in ['xml','rels']:types.remove(e)
parts['[Content_Types].xml']=serialize(types)
buffer=io.BytesIO()
with zipfile.ZipFile(buffer,'w',zipfile.ZIP_DEFLATED) as out:
    for name,content in parts.items():out.writestr(name,content)
output=buffer.getvalue()
# Independent full-package historical identity scan before committing fixtures.
forbidden=set()
for i,cols in [(5,['H','I','AB','AC']),(6,['F','G','M']),(9,['A','B']),(7,['T','U'])]:
    original=parse(f'xl/worksheets/sheet{i}.xml')
    for row in original.findall('s:sheetData/s:row',ns)[1:]:
        for c in row:
            if column(c.get('r')) in cols:
                v=value(c)
                if len(v)>=5:forbidden.add(v)
joined=b'\n'.join(parts.values()).decode('utf8')
leaks=[v for v in forbidden if v in joined]
assert not leaks, f'Historical identities detected: {len(leaks)} (values withheld)'
metadata={'sourceSha256':hashlib.sha256(source.read_bytes()).hexdigest(),'sheets':expected,'headers':headers,'tableHeaders':[c.get('name') for c in parse('xl/tables/table3.xml').findall('s:tableColumns/s:tableColumn',ns)],'subdivisions':subdivisions,'zipBase64':base64.b64encode(output).decode(),'historicalIdentityTokensChecked':len(forbidden)}
(root/'src/ambulatoryTemplate.json').write_text(json.dumps(metadata,ensure_ascii=False,separators=(',',':'))+'\n')
(root/'scripts/fixtures').mkdir(exist_ok=True)
(root/'scripts/fixtures/ambulatory-empty.xlsx').write_bytes(output)
print(json.dumps({'sheets':len(sheets),'tables':19,'materials':432,'historicalIdentityTokensChecked':len(forbidden),'leaks':len(leaks),'bytes':len(output)}))
