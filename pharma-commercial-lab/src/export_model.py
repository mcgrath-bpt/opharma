"""Inspect a published snapshot as typed-contract CSVs without evaluator access."""
import argparse
import sqlite3
from pathlib import Path
from common import write_csv,write_json,sha256
from odcs import registry,registry_fingerprint,identifier

def export(database, snapshot, out):
    contracts=registry();fingerprint=registry_fingerprint(contracts);files=[]
    if not database.is_file():raise ValueError('Model database does not exist')
    with sqlite3.connect(database.resolve().as_uri()+'?mode=ro',uri=True) as con:
        identity=con.execute('SELECT contract_registry_sha256 FROM model_identity').fetchone()
        if not identity or identity[0]!=fingerprint:raise ValueError('Model registry fingerprint differs')
        checkpoint=con.execute('SELECT as_of FROM batch_audit WHERE snapshot_id=?',(snapshot,)).fetchone()
        if not checkpoint:raise ValueError('Snapshot is not published')
        for layer in ['canonical','pipeline','consumption','visualization']:
            for obj in contracts[layer]['schema']:
                columns=[p['name'] for p in obj['properties']];rows=[]
                for values in con.execute('SELECT '+','.join(map(identifier,columns))+' FROM '+identifier(obj['physicalName'])+' WHERE "snapshot_id"=?',(snapshot,)):
                    row={}
                    for prop,value in zip(obj['properties'],values):
                        row[prop['name']]='' if value is None else ('true' if value else 'false') if prop['logicalType']=='boolean' else value
                    rows.append(row)
                rows.sort(key=lambda r:tuple(str(r[c]) for c in columns))
                target=out/(obj['physicalName']+'.csv');write_csv(target,rows,columns)
                files.append(dict(layer=layer,contract_id=contracts[layer]['id'],contract_version=contracts[layer]['version'],object=obj['name'],path=target.name,rows=len(rows),sha256=sha256(target)))
    write_json(out/'model-export-manifest.json',dict(snapshot_id=snapshot,as_of=checkpoint[0],contract_registry_sha256=fingerprint,files=files))
    return {'snapshot':snapshot,'files':len(files),'rows':sum(f['rows'] for f in files)}

def export_history(database, out):
    """Export every published scorecard checkpoint for the local TMDL history table."""
    contracts=registry();fingerprint=registry_fingerprint(contracts)
    obj=contracts['visualization']['schema'][0];columns=[p['name'] for p in obj['properties']]
    if not database.is_file():raise ValueError('Model database does not exist')
    with sqlite3.connect(database.resolve().as_uri()+'?mode=ro',uri=True) as con:
        identity=con.execute('SELECT contract_registry_sha256 FROM model_identity').fetchone()
        if not identity or identity[0]!=fingerprint:raise ValueError('Model registry fingerprint differs')
        rows=[]
        for values in con.execute('SELECT '+','.join(map(identifier,columns))+' FROM '+identifier(obj['physicalName'])+' ORDER BY snapshot_id,scenario,scope'):
            rows.append({p['name']:('true' if v else 'false') if p['logicalType']=='boolean' else '' if v is None else v for p,v in zip(obj['properties'],values)})
    target=out/(obj['physicalName']+'.csv');write_csv(target,rows,columns)
    write_json(out/'model-export-manifest.json',dict(contract_registry_sha256=fingerprint,
        contract_id=contracts['visualization']['id'],contract_version=contracts['visualization']['version'],
        snapshots=sorted({r['snapshot_id'] for r in rows}),files=[dict(path=target.name,rows=len(rows),sha256=sha256(target))]))
    return {'history':True,'files':1,'rows':len(rows)}

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--db',type=Path,required=True)
    choice=p.add_mutually_exclusive_group(required=True);choice.add_argument('--snapshot');choice.add_argument('--history',action='store_true')
    p.add_argument('--out',type=Path,required=True);a=p.parse_args()
    print(export_history(a.db,a.out) if a.history else export(a.db,a.snapshot,a.out))
