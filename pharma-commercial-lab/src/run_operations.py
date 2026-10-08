"""Evaluator-side local release acceptance: replay every delivery against the oracle."""
import argparse
import json
import sqlite3
from pathlib import Path
from common import ROOT, read_json, write_json
from generate_operations import create
from hydrate_operations import hydrate
from validate import reconcile

def run(data,database,through=None):
    if not data.exists():create(read_json(ROOT/'config/operations.json'),data)
    manifests=sorted((read_json(p) for p in (data/'public_s3').rglob('*.manifest.json')),key=lambda m:m['batch_id'])
    report={'release_id':manifests[0]['release_id'],'database':str(database),'odcs_version':'3.1.0','engine':'sqlite-python','snowflake':'NOT_EXECUTED','checkpoints':{}}
    for m in manifests:
        batch=m['batch_id']
        if through and batch>through:break
        folder=data/'evidence/actual'/batch
        status=hydrate(data/'public_s3',database,batch,folder)
        comparison=reconcile(data/'private_evaluator/expected'/batch,folder)
        report['checkpoints'][batch]={'hydration':status,'reconciliation':comparison}
        if not comparison['passed']:raise ValueError('Independent reconciliation failed: '+batch)
    report['passed']=all(v['reconciliation']['passed'] for v in report['checkpoints'].values())
    write_json(data/'evidence/operations-report.json',report)
    return report

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--data',type=Path,default=ROOT/'data/operations-release');p.add_argument('--db',type=Path,default=ROOT/'data/operations/model-v02.sqlite');p.add_argument('--through');a=p.parse_args();r=run(a.data,a.db,a.through);print(json.dumps({'passed':r['passed'],'checkpoints':len(r['checkpoints']),'database':str(a.db)},indent=2))
