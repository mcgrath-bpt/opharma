"""Fail-closed public delivery validation and evaluator-side multiset reconciliation."""
import argparse
import csv
import re
from collections import Counter
from pathlib import Path
from common import read_json, read_csv, sha256, GOLD_COLUMNS

def validate_public(root, through=None):
    root=Path(root).resolve();manifests=sorted(root.rglob('*.manifest.json'))
    if not manifests:raise ValueError('No manifests')
    keys=set();batches=set();total=0
    for path in manifests:
        m=read_json(path)
        if through and m['batch_id']>through:continue
        required={'manifest_version','release_id','batch_id','available_at','as_of','load_mode','files'}
        if not required.issubset(m) or set(m)-required-{'contract_id','contract_version','contract_sha256'}:raise ValueError('Manifest fields differ')
        binding={'contract_id','contract_version','contract_sha256'}
        if set(m)&binding and not binding.issubset(m):raise ValueError('Incomplete contract binding')
        if m['manifest_version']!='1.0' or m['load_mode'] not in ('bootstrap','incremental'):raise ValueError('Unsupported manifest')
        if not re.fullmatch(r'b\d{3}',m['batch_id']) or m['batch_id'] in batches:raise ValueError('Batch identity invalid/duplicate')
        batches.add(m['batch_id'])
        ready=read_json(path.with_name(m['batch_id']+'.ready.json'))
        if ready!={'batch_id':m['batch_id'],'manifest_sha256':sha256(path)}:raise ValueError('Ready marker does not authenticate manifest bytes')
        contracts=read_json(path.parent/'source-contracts.json')
        receipt_path=path.parent/'territory-adapter.receipt.json'
        if receipt_path.exists():
            receipt=read_json(receipt_path)
            if 'input_key' in receipt:
                workbook=(root/receipt['input_key']).resolve();output=(root/receipt['output_key']).resolve()
                if not workbook.is_relative_to(root) or not output.is_relative_to(root):raise ValueError('Unsafe workbook receipt key')
                if sha256(workbook)!=receipt['input_sha256'] or sha256(output)!=receipt['output_sha256']:raise ValueError('Workbook adapter fingerprint mismatch')
        for f in m['files']:
            key=f['key'];local=(root/key).resolve()
            if not local.is_relative_to(root) or key.startswith('/') or '..' in Path(key).parts:raise ValueError('Unsafe key')
            if key in keys:raise ValueError('Duplicate file entry')
            keys.add(key)
            if not key.endswith('.csv') or f['format']!='CSV' or f['encoding']!='UTF-8' or f['delimiter']!=',' or f['header'] is not True:raise ValueError('Unsupported file contract')
            if local.stat().st_size!=f['byte_count'] or sha256(local)!=f['sha256']:raise ValueError('File fingerprint mismatch: '+key)
            with local.open(encoding='utf-8',newline='') as stream:
                rows=list(csv.reader(stream,strict=True))
            if not rows or rows[0]!=f['columns'] or rows[0]!=contracts[f['source_entity']]['columns']:raise ValueError('Header mismatch: '+key)
            if len(rows)-1!=f['row_count']:raise ValueError('Row count mismatch')
            if any(len(r)!=len(rows[0]) for r in rows[1:]):raise ValueError('Column count mismatch')
            total+=f['row_count']
    return {'batches':len(batches),'files':len(keys),'rows':total}

def reconcile(expected,actual):
    result={};passed=True
    for name,columns in GOLD_COLUMNS.items():
        def values(folder):
            p=Path(folder)/(name+'.csv')
            with p.open(newline='',encoding='utf-8') as stream:
                reader=csv.DictReader(stream)
                if reader.fieldnames!=columns:raise ValueError('Output columns differ: '+str(p))
                rows=list(reader)
                if any(None in r or any(r[c] is None for c in columns) for r in rows):raise ValueError('Output row width differs: '+str(p))
                return Counter(tuple(r[c] for c in columns) for r in rows)
        e,a=values(expected),values(actual)
        missing=sum((e-a).values());unexpected=sum((a-e).values())
        result[name]={'expected_rows':sum(e.values()),'actual_rows':sum(a.values()),'missing_rows':missing,'unexpected_rows':unexpected}
        passed=passed and missing==unexpected==0
    return {'passed':passed,'tables':result}

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--public-root',type=Path);p.add_argument('--expected',type=Path);p.add_argument('--actual',type=Path);a=p.parse_args()
    if a.public_root:print(validate_public(a.public_root))
    if a.expected and a.actual:
        report=reconcile(a.expected,a.actual);print(report)
        if not report['passed']:raise SystemExit(1)

