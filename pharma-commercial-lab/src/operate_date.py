"""Select exactly one complete daily manifest by logical date for cron/Airflow."""
import argparse
import json
from pathlib import Path
from common import read_json
from hydrate_operations import hydrate

def select(public_root,logical_date):
    selected=[m for p in public_root.rglob('*.manifest.json') if (m:=read_json(p))['as_of'][:10]==logical_date]
    if len(selected)!=1:raise ValueError('Expected exactly one manifest for '+logical_date)
    return selected[0]['batch_id']

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--date',required=True);p.add_argument('--public-root',type=Path,required=True);p.add_argument('--db',type=Path,required=True);p.add_argument('--engine',choices=['local','snowflake'],default='local');p.add_argument('--connection');p.add_argument('--stage');p.add_argument('--schema');p.add_argument('--out',type=Path);a=p.parse_args();batch=select(a.public_root,a.date)
    if a.engine=='local':print(json.dumps(hydrate(a.public_root,a.db,batch)))
    else:
        if not all([a.connection,a.stage,a.schema,a.out]):p.error('Snowflake requires --connection, --stage, --schema and --out')
        from run_operations_snowflake import run
        run(a.public_root,a.connection,a.stage,a.schema,a.out,batch)
