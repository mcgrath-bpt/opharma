"""Source-only, transactional SQLite hydration for recurring ODCS investigations.

One database is bound to one release and one contract registry fingerprint.
Every batch is atomic: raw ingest, typed canonical model, outputs, quality checks,
consumption and publication ledger commit together. Replays verify identity.
"""
import argparse
import csv
import json
import re
import sqlite3
from collections import defaultdict
from datetime import datetime, timezone
from pathlib import Path
from common import ROOT, read_json, sha256, write_json, write_csv, GOLD_COLUMNS
from odcs import registry, registry_fingerprint, objects, identifier, ddl, insert_rows, quality, validate_binding, extension
from reference import calculate, classify_activity, resolve_identity, stamp
from validate import validate_public

META=['_batch_id','_available_at','_mode']

def initialise(con, contracts):
    con.execute('PRAGMA foreign_keys=ON')
    con.execute('PRAGMA busy_timeout=10000')
    con.executescript('''CREATE TABLE IF NOT EXISTS model_identity (release_id TEXT PRIMARY KEY, contract_registry_sha256 TEXT NOT NULL);
CREATE TABLE IF NOT EXISTS batch_audit (snapshot_id TEXT PRIMARY KEY, release_id TEXT NOT NULL, manifest_sha256 TEXT NOT NULL, as_of TEXT NOT NULL, available_at TEXT NOT NULL, loaded_at TEXT NOT NULL, status TEXT NOT NULL CHECK(status='PUBLISHED'));
CREATE TABLE IF NOT EXISTS file_audit (snapshot_id TEXT NOT NULL, file_key TEXT NOT NULL, sha256 TEXT NOT NULL, rows_loaded INTEGER NOT NULL, PRIMARY KEY(snapshot_id,file_key), FOREIGN KEY(snapshot_id) REFERENCES batch_audit(snapshot_id) DEFERRABLE INITIALLY DEFERRED);
CREATE TABLE IF NOT EXISTS quality_evidence (snapshot_id TEXT NOT NULL, contract_id TEXT NOT NULL, object_name TEXT NOT NULL, rule TEXT NOT NULL, value INTEGER NOT NULL, passed INTEGER NOT NULL);
CREATE TABLE IF NOT EXISTS run_log (attempt_id INTEGER PRIMARY KEY, batch_id TEXT NOT NULL, started_at TEXT NOT NULL, finished_at TEXT NOT NULL, status TEXT NOT NULL, error_type TEXT);
''')
    for obj in contracts['source']['schema']:
        cols=[identifier(p['name'])+' TEXT' for p in obj['properties']]+[identifier(m)+' TEXT NOT NULL' for m in META]
        con.execute('CREATE TABLE IF NOT EXISTS '+identifier(obj['physicalName'])+' ('+','.join(cols)+')')
    for layer in ['canonical','pipeline','consumption','visualization']:con.executescript(ddl(contracts[layer]))
    for layer in ['pipeline','consumption']:
        for obj in contracts[layer]['schema']:
            name=obj['physicalName'];weekly=layer=='consumption' and obj['name']=='s05_campaign'
            predicate=" AND strftime('%w',as_of)='1'" if weekly else ''
            con.execute('CREATE VIEW IF NOT EXISTS '+identifier(name+'_current')+' AS SELECT * FROM '+identifier(name)+" WHERE snapshot_id=(SELECT snapshot_id FROM batch_audit WHERE status='PUBLISHED'"+predicate+' ORDER BY as_of DESC LIMIT 1)')
    con.execute("CREATE VIEW IF NOT EXISTS visualization_scenario_scorecard_current AS SELECT * FROM visualization_scenario_scorecard WHERE snapshot_id=(SELECT snapshot_id FROM batch_audit WHERE status='PUBLISHED' ORDER BY as_of DESC LIMIT 1)")
    con.commit()

def visible_sources(con, contracts, batch):
    tables=defaultdict(list)
    for obj in contracts['source']['schema']:
        columns=[p['name'] for p in obj['properties']]+META
        for row in con.execute('SELECT '+','.join(map(identifier,columns))+' FROM '+identifier(obj['physicalName'])+' WHERE _batch_id<=?',(batch,)):
            tables[obj['name']].append(dict(zip(columns,row)))
    return tables

def unique_payload(rows, keys):
    result={}
    for raw in rows:
        r={k:v for k,v in raw.items() if not k.startswith('_')}
        key=tuple(r[k] for k in keys)
        if key in result and result[key]!=r:raise ValueError('Conflicting unversioned source key: '+str(key))
        result[key]=r
    return list(result.values())

def canonicalise(tables, cutoff, late_days=7):
    visible={name:[r for r in rows if r['_available_at']<=cutoff] for name,rows in tables.items()}
    providers=visible['iqvia_like/provider']
    crm=resolve_identity(visible['veeva_like/customer'],'customer_key',providers)
    sf=resolve_identity(visible['salesforce_like/contact'],'contact_key',providers)
    out={}
    out['organisation']=unique_payload(visible['iqvia_like/organisation'],['organisation_key'])
    out['affiliation']=[dict(affiliation_key=r['affiliation_key'],customer_key=r['provider_key'],organisation_key=r['organisation_key'],relationship_type=r['relationship_type'],is_primary=r['is_primary'],effective_from=r['effective_from'],effective_to=r['effective_to']) for r in unique_payload(visible['iqvia_like/affiliation'],['affiliation_key'])]
    out['representative']=unique_payload(visible['veeva_like/staff'],['staff_key'])
    out['customer']=[dict(customer_key=r['provider_key'],label=r['label'],speciality=r['speciality'],country=r['country'],postal_sector=r['postal_sector'],active=r['active']) for r in unique_payload(providers,['provider_key'])]
    out['product_interval']=unique_payload(visible['iqvia_like/product'],['product_code','valid_from'])
    out['territory']=unique_payload(visible['veeva_like/territory'],['territory_code'])
    accepted={}
    for r in visible['veeva_like/activity']:
        if classify_activity(r,cutoff,late_days)!='ACCEPT':continue
        key=(r['activity_key'],int(r['source_version']))
        value=dict(activity_key=r['activity_key'],source_version=int(r['source_version']),crm_customer_key=r['customer_key'],customer_key=crm.get(r['customer_key']),staff_key=r.get('staff_key'),primary_product_code=r['primary_product_code'],occurred_at=r['occurred_at'],channel=r['channel'],approval=r['approval'],duration_minutes=int(r['duration_minutes']),modified_at=r['modified_at'],operation=r['operation'],delivery_batch=r['_batch_id'])
        # Business-payload conflict checking also occurs in calculate().
        if key not in accepted:accepted[key]=value
    out['interaction_version']=list(accepted.values())
    details={}
    for r in visible['veeva_like/activity_product']:
        if not re.fullmatch(r'[0-9]+',str(r['source_version'])):continue
        try:v=int(r['source_version'])
        except ValueError:continue
        if v<1:continue
        if (r['activity_key'],v) in accepted:details[(r['activity_key'],v,r['product_code'])]=dict(activity_key=r['activity_key'],source_version=v,product_code=r['product_code'])
    out['interaction_product']=list(details.values())
    out['consent_event']=[dict(preference_key=r['preference_key'],customer_key=sf.get(r['contact_key']),contact_key=r['contact_key'],channel=r['channel'],purpose=r['purpose'],status=r['status'],effective_at=r['effective_at'],sequence_no=r['sequence_no'],delivery_batch=r['_batch_id']) for r in visible['salesforce_like/consent']]
    out['consent_event']=list({r['preference_key']:r for r in out['consent_event']}.values())
    out['customer_territory']=[dict(assignment_key=r['assignment_key'],customer_key=r['provider_key'],territory_code=r['territory_code'],effective_from=r['effective_from'],effective_to=r['effective_to']) for r in unique_payload(visible['manual/territory_mapping'],['assignment_key'])]
    out['campaign']=unique_payload(visible['salesforce_like/campaign'],['campaign_key'])
    out['campaign_member']=[dict(membership_key=r['membership_key'],campaign_key=r['campaign_key'],customer_key=sf.get(r['contact_key']),contact_key=r['contact_key'],member_status=r['member_status']) for r in unique_payload(visible['salesforce_like/campaign_member'],['membership_key'])]
    out['rx_version']=[dict(observation_key=r['observation_key'],version_no=r['version_no'],customer_key=r['provider_key'],product_code=r['product_code'],week_ending=r['week_ending'],trx_count=r['trx_count'],nrx_count=r['nrx_count'],sales_units=r['sales_units']) for r in unique_payload(visible['iqvia_like/rx_weekly'],['observation_key','version_no'])]
    return out

def raw_semantic_gate(tables, projections):
    """Reject malformed reference/history data; activity types are quarantineable."""
    from odcs import cast
    for entity,rows in tables.items():
        if entity in ('veeva_like/activity','veeva_like/activity_product'):continue
        spec=projections[entity]
        unique_payload(rows,spec['key_columns'])
        for row in rows:
            for col,kind in spec['logical_types'].items():
                required=col not in ['effective_to','valid_to','match_token','link_token']
                cast(row[col],dict(name=col,logicalType={'INTEGER':'integer','DATE':'date','TIMESTAMP_UTC':'timestamp','BOOLEAN':'boolean'}.get(kind,'string'),required=required))

def relation_gate(con, snapshot):
    checks={
      'interaction_representative':'SELECT COUNT(*) FROM canonical_interaction_version i LEFT JOIN canonical_representative r ON i.snapshot_id=r.snapshot_id AND i.staff_key=r.staff_key WHERE i.snapshot_id=? AND i.staff_key IS NOT NULL AND r.staff_key IS NULL',
      'affiliation_customer':'SELECT COUNT(*) FROM canonical_affiliation a LEFT JOIN canonical_customer c ON a.snapshot_id=c.snapshot_id AND a.customer_key=c.customer_key WHERE a.snapshot_id=? AND c.customer_key IS NULL',
      'affiliation_organisation':'SELECT COUNT(*) FROM canonical_affiliation a LEFT JOIN canonical_organisation c ON a.snapshot_id=c.snapshot_id AND a.organisation_key=c.organisation_key WHERE a.snapshot_id=? AND c.organisation_key IS NULL',
      'detail_parent':'SELECT COUNT(*) FROM canonical_interaction_product d LEFT JOIN canonical_interaction_version v ON d.snapshot_id=v.snapshot_id AND d.activity_key=v.activity_key AND d.source_version=v.source_version WHERE d.snapshot_id=? AND v.activity_key IS NULL',
      'member_campaign':'SELECT COUNT(*) FROM canonical_campaign_member m LEFT JOIN canonical_campaign c ON m.snapshot_id=c.snapshot_id AND m.campaign_key=c.campaign_key WHERE m.snapshot_id=? AND c.campaign_key IS NULL',
      'territory_reference':'SELECT COUNT(*) FROM canonical_customer_territory a LEFT JOIN canonical_territory t ON a.snapshot_id=t.snapshot_id AND a.territory_code=t.territory_code WHERE a.snapshot_id=? AND t.territory_code IS NULL',
      'rx_measures':'SELECT COUNT(*) FROM canonical_rx_version WHERE snapshot_id=? AND (nrx_count>trx_count OR nrx_count<0 OR trx_count<0 OR sales_units<0)',
      'product_intervals':'SELECT COUNT(*) FROM canonical_product_interval WHERE snapshot_id=? AND valid_to IS NOT NULL AND valid_to<=valid_from',
      'assignment_intervals':'SELECT COUNT(*) FROM canonical_customer_territory WHERE snapshot_id=? AND effective_to IS NOT NULL AND effective_to<=effective_from'
    }
    for name,query in checks.items():
        if con.execute(query,(snapshot,)).fetchone()[0]:raise ValueError('Canonical relationship/measure gate: '+name)

def hydrate(public_root, database, batch, exports=None):
    contracts=registry();validate_public(public_root,through=batch)
    entries=sorted(((read_json(p),p) for p in public_root.rglob('*.manifest.json')),key=lambda x:x[0]['batch_id'])
    selected=[(m,p) for m,p in entries if m['batch_id']==batch]
    if len(selected)!=1:raise ValueError('Requested batch absent or repeated')
    manifest,path=selected[0];validate_binding(manifest,contracts)
    cutoff=manifest['as_of'];stamp(cutoff)
    if stamp(manifest['available_at'])>stamp(cutoff):raise ValueError('Delivery not yet available at checkpoint')
    freshness=next(p['value'] for p in contracts['source']['slaProperties'] if p['property']=='freshness')
    if (stamp(cutoff)-stamp(manifest['available_at'])).total_seconds()>float(freshness)*3600:raise ValueError('Source delivery exceeds contract freshness budget')
    digest=sha256(path);fingerprint=registry_fingerprint(contracts)
    database.parent.mkdir(parents=True,exist_ok=True)
    started=datetime.now(timezone.utc).isoformat()
    with sqlite3.connect(database) as con:
        initialise(con,contracts)
        try:
            con.execute('BEGIN IMMEDIATE')
            identity=con.execute('SELECT release_id,contract_registry_sha256 FROM model_identity').fetchone()
            if identity and identity!=(manifest['release_id'],fingerprint):raise ValueError('Database bound to another release/contract; use a new database or reviewed migration')
            old=con.execute('SELECT manifest_sha256 FROM batch_audit WHERE snapshot_id=?',(batch,)).fetchone()
            if old:
                if old[0]!=digest:raise ValueError('Batch already bound to different manifest bytes')
                con.rollback()
                if exports:export_snapshot(con,contracts,batch,exports)
                return {'batch':batch,'status':'IDENTICAL_REPLAY','as_of':cutoff}
            earlier=[m['batch_id'] for m,p in entries if m['batch_id']<batch]
            loaded={r[0] for r in con.execute('SELECT snapshot_id FROM batch_audit')}
            if loaded!=set(earlier):raise ValueError('Hydrate in order; all prior batches must be published')
            if earlier:
                previous=con.execute('SELECT MAX(as_of) FROM batch_audit').fetchone()[0]
                if stamp(cutoff)<=stamp(previous):raise ValueError('Checkpoint time must advance')
            if not identity:con.execute('INSERT INTO model_identity VALUES (?,?)',(manifest['release_id'],fingerprint))
            source_objects=objects(contracts['source'])
            for f in manifest['files']:
                obj=source_objects[f['source_entity']];columns=f['columns']+META
                with (public_root/f['key']).open(encoding='utf-8',newline='') as stream:rows=list(csv.DictReader(stream))
                values=[tuple(r[c] for c in f['columns'])+(batch,manifest['available_at'],manifest['load_mode']) for r in rows]
                con.executemany('INSERT INTO '+identifier(obj['physicalName'])+' ('+','.join(map(identifier,columns))+') VALUES ('+','.join('?' for _ in columns)+')',values)
                con.execute('INSERT INTO file_audit VALUES (?,?,?,?)',(batch,f['key'],f['sha256'],len(rows)))
            tables=visible_sources(con,contracts,batch)
            raw_semantic_gate(tables,read_json(ROOT/'contracts/source-projections.json'))
            semantics=extension(contracts['pipeline'],'scenarioSemantics')
            results=calculate(tables,cutoff,semantics);canonical=canonicalise(tables,cutoff,semantics['S4']['lateArrivalCalendarDays'])
            for name,obj in objects(contracts['canonical']).items():insert_rows(con,obj,[dict(row,snapshot_id=batch) for row in canonical[name]])
            relation_gate(con,batch)
            monday=stamp(cutoff).weekday()==0
            for layer in ['pipeline','consumption']:
                for name,obj in objects(contracts[layer]).items():
                    if layer=='consumption' and name=='s05_campaign' and not monday:continue
                    insert_rows(con,obj,[dict(row,snapshot_id=batch,as_of=cutoff) for row in results.get(name,[])])
            scorecard=[]
            for sc in ['S01','S02','S03','S04','S05']:
                name=next(n for n in GOLD_COLUMNS if n.startswith(sc.lower()+'_'))
                metrics=[r for r in results['dq'] if r['scenario']==sc] or [dict(scope='ALL',numerator=0,denominator=0,threshold=0,status='DIAGNOSTIC')]
                for m in metrics:
                    scoped_rows=[r for r in results.get(name,[]) if sc!='S05' or r['campaign_key']==m['scope']]
                    issues=[r for r in results['exceptions'] if r['scenario']==sc and (sc!='S05' or r['record_key']==m['scope'] or r['record_key'].startswith(m['scope']+'|'))]
                    scorecard.append(dict(snapshot_id=batch,as_of=cutoff,scenario=sc,scope=m['scope'],output_rows=len(scoped_rows),exception_rows=len(issues),numerator=m['numerator'],denominator=m['denominator'],threshold=m['threshold'],status=m['status'],scheduled=sc!='S05' or monday))
            insert_rows(con,contracts['visualization']['schema'][0],scorecard)
            evidence=[dict(contract_id=contracts['source']['id'],object=obj['name'],rule='manifestAndSemanticGate',value=0,passed=True) for obj in contracts['source']['schema']]
            for layer in ['canonical','pipeline','consumption','visualization']:evidence+=quality(con,contracts[layer],batch)
            con.executemany('INSERT INTO quality_evidence VALUES (?,?,?,?,?,?)',[(batch,e['contract_id'],e['object'],e['rule'],e['value'],int(e['passed'])) for e in evidence])
            finished=datetime.now(timezone.utc).isoformat()
            con.execute('INSERT INTO batch_audit VALUES (?,?,?,?,?,?,?)',(batch,manifest['release_id'],digest,cutoff,manifest['available_at'],finished,'PUBLISHED'))
            con.execute('INSERT INTO run_log(batch_id,started_at,finished_at,status) VALUES (?,?,?,?)',(batch,started,finished,'PUBLISHED'))
            con.commit()
            if exports:export_snapshot(con,contracts,batch,exports)
            return {'batch':batch,'as_of':cutoff,'status':'PUBLISHED','s5_weekly_consumption':monday,'quality_rules':len(evidence),'output_rows':{n:len(results.get(n,[])) for n in GOLD_COLUMNS}}
        except Exception as error:
            con.rollback()
            con.execute('INSERT INTO run_log(batch_id,started_at,finished_at,status,error_type) VALUES (?,?,?,?,?)',(batch,started,datetime.now(timezone.utc).isoformat(),'FAILED',type(error).__name__))
            con.commit();raise

def export_snapshot(con,contracts,batch,folder):
    for name,columns in GOLD_COLUMNS.items():
        table=objects(contracts['pipeline'])[name]['physicalName']
        rows=[]
        for row in con.execute('SELECT '+','.join(map(identifier,columns))+' FROM '+identifier(table)+' WHERE snapshot_id=?',(batch,)):
            values=list(row)
            for i,c in enumerate(columns):
                if c=='contacted':values[i]='true' if values[i] else 'false'
                if values[i] is None:values[i]=''
            rows.append(dict(zip(columns,values)))
        rows.sort(key=lambda r:tuple(str(r[c]) for c in columns));write_csv(folder/(name+'.csv'),rows,columns)

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--public-root',type=Path,required=True);p.add_argument('--db',type=Path,required=True);p.add_argument('--batch',required=True);p.add_argument('--exports',type=Path);a=p.parse_args();print(json.dumps(hydrate(a.public_root,a.db,a.batch,a.exports),indent=2))
