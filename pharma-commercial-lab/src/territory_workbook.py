"""Deterministic narrow XLSX fixture authored with the Python standard library."""
import zipfile
import xml.etree.ElementTree as ET
from pathlib import Path
from xlsx_to_csv import COLS

NS='http://schemas.openxmlformats.org/spreadsheetml/2006/main'

def write_workbook(path,rows):
    sheet=ET.Element('worksheet',xmlns=NS);data=ET.SubElement(sheet,'sheetData')
    for i,values in enumerate([COLS]+[[r[c] for c in COLS] for r in rows],1):
        row=ET.SubElement(data,'row',r=str(i))
        for j,value in enumerate(values):
            cell=ET.SubElement(row,'c',r=chr(65+j)+str(i),t='inlineStr')
            text=ET.SubElement(ET.SubElement(cell,'is'),'t');text.text=str(value)
    files={
      '[Content_Types].xml':'<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="xml" ContentType="application/xml"/><Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/><Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/></Types>',
      '_rels/.rels':'<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/></Relationships>',
      'xl/workbook.xml':'<workbook xmlns="'+NS+'" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><sheets><sheet name="Territory" sheetId="1" r:id="rId1"/></sheets></workbook>',
      'xl/_rels/workbook.xml.rels':'<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/></Relationships>',
      'xl/worksheets/sheet1.xml':ET.tostring(sheet,encoding='utf-8',xml_declaration=True)}
    path.parent.mkdir(parents=True,exist_ok=True)
    with zipfile.ZipFile(path,'w',compression=zipfile.ZIP_STORED) as workbook:
        for name,content in sorted(files.items()):
            info=zipfile.ZipInfo(name,date_time=(1980,1,1,0,0,0));info.compress_type=zipfile.ZIP_STORED
            workbook.writestr(info,content.encode() if isinstance(content,str) else content)
