"""Target adapter: named Snowflake connection, serial batches, exports/query IDs.

No private truth is read. Reconciliation runs separately under evaluator access.
"""
import argparse
import io
from datetime import datetime,timezone
from pathlib import Path
from common import read_json,write_json,write_csv,sha256,GOLD_COLUMNS
from odcs import registry,registry_fingerprint,objects,identifier
from render_operations_sql import render_operations
from run_snowflake import normalise

def run(public_root,connection,stage,schema,out,through=None):
    import snowflake.connector
    contracts=registry();rendered=out/'rendered_sql';render_operations(public_root,stage,schema,rendered)
    manifests=sorted(((read_json(p),p) for p in public_root.rglob('*.manifest.json')),key=lambda x:x[0]['batch_id'])
    evidence=dict(status='RUNNING',started_at=datetime.now(timezone.utc).isoformat(),queries=[],checkpoints=[])
    con=None
    def execute(path):
        for cur in con.execute_stream(io.StringIO(path.read_text()),remove_comments=True):
            evidence['queries'].append(cur.sfqid);cur.fetchall();cur.close()
    try:
        con=snowflake.connector.connect(connection_name=connection);execute(rendered/'00_setup_odcs.sql')
        for m,path in manifests:
            batch=m['batch_id']
            if through and batch>through:break
            with con.cursor() as cur:
                cur.execute('SELECT release_id,registry_sha256 FROM ODCS_MODEL_IDENTITY');rows=cur.fetchall()
                if rows and rows!=[(m['release_id'],registry_fingerprint(contracts))]:raise ValueError('Schema bound to another release/registry')
                cur.execute('SELECT manifest_sha256,registry_sha256 FROM ODCS_SNAPSHOT_AUDIT WHERE snapshot_id=%s',(batch,));previous=cur.fetchall()
            if previous:
                if previous!=[(sha256(path),registry_fingerprint(contracts))]:raise ValueError('Conflicting checkpoint identity')
            else:
                execute(rendered/f'01_load_{batch}.sql');execute(rendered/f'02_gold_{batch}.sql');execute(rendered/f'03_publish_{batch}.sql')
            for name,columns in GOLD_COLUMNS.items():
                table=objects(contracts['pipeline'])[name]['physicalName']
                with con.cursor() as cur:
                    cur.execute('SELECT '+','.join(map(identifier,columns))+' FROM '+identifier(table)+' WHERE "snapshot_id"=%s',(batch,));evidence['queries'].append(cur.sfqid)
                    results=[dict(zip(columns,[normalise(v) for v in row])) for row in cur.fetchall()]
                # Database booleans and NUMBER types normalize to the same CSV contract.
                for row in results:
                    for key,value in row.items():
                        if isinstance(value,datetime):row[key]=value.isoformat(timespec='seconds')+'Z'
                        elif hasattr(value,'isoformat'):row[key]=value.isoformat()
                results.sort(key=lambda r:tuple(str(r[c]) for c in columns));write_csv(out/batch/(name+'.csv'),results,columns)
            evidence['checkpoints'].append(batch)
        evidence['status']='EXECUTED_RECONCILIATION_REQUIRED'
    except Exception as error:
        if con:con.rollback()
        evidence.update(status='FAILED',error_type=type(error).__name__);raise
    finally:
        if con:con.close()
        evidence['finished_at']=datetime.now(timezone.utc).isoformat();write_json(out/'execution.json',evidence)

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--public-root',type=Path,required=True);p.add_argument('--connection',required=True);p.add_argument('--stage',required=True);p.add_argument('--schema',required=True);p.add_argument('--out',type=Path,required=True);p.add_argument('--through');a=p.parse_args();run(a.public_root,a.connection,a.stage,a.schema,a.out,a.through)
