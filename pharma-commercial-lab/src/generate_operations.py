"""Deterministic recurring fixture, public deliveries and independent canonical truth.

Bootstrap retains legacy S1–S5 edge cases. Subsequent daily batches introduce
explicit events/intervals and versions. No existing delivery is overwritten.
"""
import argparse
import copy
import hashlib
import re
from collections import defaultdict
from datetime import date, datetime, timedelta
from pathlib import Path
from common import ROOT, read_json, read_csv, write_json, write_csv, sha256, write_results
from generate import generate
from odcs import registry, CONTRACT_DIR
from oracle import expected
from validate import validate_public

def shift(value, days):
    if isinstance(value,dict):return {k:shift(v,days) for k,v in value.items()}
    if isinstance(value,list):return [shift(v,days) for v in value]
    if isinstance(value,str) and re.fullmatch(r'\d{4}-\d{2}-\d{2}(T\d{2}:\d{2}:\d{2}Z)?',value):
        return (date.fromisoformat(value[:10])+timedelta(days=days)).isoformat()+value[10:]
    return value

def create(config,dest):
    if not 10<=config['delivery_count']<=90:raise ValueError('Use 10–90 daily deliveries to include every investigation event')
    if not 1<=config['daily_interactions']<=1000:raise ValueError('daily_interactions must be 1–1000')
    start=date.fromisoformat(config['start_date'])
    contracts=registry();cfg=read_json(ROOT/'config/crawl.json');cfg['release_id']=config['release_id'];cfg['seed']=config['seed']
    if config['source_contract_version']!=contracts['source']['version']:raise ValueError('Config source contract version differs from registry')
    world=generate(cfg,dest)
    offset=(start-date(2026,9,14)).days
    world=shift(world,offset);cfg=shift(cfg,offset)
    ledger=read_json(dest/'private_evaluator/projection-ledger.json');decisions=ledger['decisions']
    control=dest/'public_s3'/f"synthetic/pharma/{config['release_id']}/control"
    source=defaultdict(dict)
    for path in sorted(control.glob('*.manifest.json')):
        m=read_json(path)
        for f in m['files']:source[m['batch_id']][f['source_entity']]=shift(read_csv(dest/'public_s3'/f['key']),offset)
    # Configure time-of-day once for every batch; subsequent cutoffs use the same schedule.
    for index,b in enumerate(cfg['batches']):
        day=(start+timedelta(days=index)).isoformat()
        b.update(available_at=day+'T'+config['schedule_utc']+':00Z',as_of=day+'T'+config['cutoff_utc']+':00Z')
        if b['available_at']>b['as_of']:raise ValueError('Availability must precede the cutoff')
    ids={(r['entity_type'],r['canonical_id'],r['source']):r['source_id'] for r in world['source_identity']}
    def cid(kind,index):return f'{kind.upper()}-{index:06}'
    def sid(kind,value,system):
        key=(kind,value,system)
        if key not in ids:
            index=int(value.rsplit('-',1)[1]);value_id=system[:2].upper()+'_'+hashlib.sha256(f"{cfg['seed']}|{kind}|{index}|{system}".encode()).hexdigest()[:14]
            ids[key]=value_id
            world['source_identity'].append(dict(entity_type=kind,canonical_id=value,source=system,source_id=value_id,link_token='SYN_'+hashlib.sha256(f"LINK|{cfg['seed']}|{kind}|{index}".encode()).hexdigest()[:16]))
        return ids[key]
    def add(batch,entity,row):source[batch].setdefault(entity,[]).append(row)
    def event(index,hcp,product,occurred,batch,modified=None,version=1,operation='UPSERT',decision='ACCEPT'):
        value=dict(interaction_id=cid('interaction',index),version_no=version,hcp_id=cid('hcp',hcp),rep_id=cid('representative',(index-1)%8+1),primary_product_id=cid('product',product),occurred_at=occurred,channel='EMAIL',approval='APPROVED',duration_minutes=10+index%20,modified_at=modified or occurred,operation=operation,delivery_batch=batch)
        world['interaction'].append(value)
        detail=dict(interaction_id=value['interaction_id'],version_no=version,product_id=value['primary_product_id'],detail_rank=1)
        world['interaction_product'].append(detail)
        decisions[value['interaction_id']+'|'+str(version)]=decision
        aid=sid('interaction',value['interaction_id'],'veeva')
        raw=dict(activity_key=aid,customer_key=sid('hcp',value['hcp_id'],'veeva'),primary_product_code=sid('product',value['primary_product_id'],'iqvia'),occurred_at=occurred,channel='EMAIL',approval='APPROVED',duration_minutes=value['duration_minutes'],source_version=str(version),modified_at=value['modified_at'],operation=operation)
        if decision=='INVALID_TYPE':raw['source_version']='invalid'
        if decision=='MISSING_REQUIRED':raw['occurred_at']=''
        add(batch,'veeva_like/activity',raw)
        add(batch,'veeva_like/activity_product',dict(activity_key=aid,source_version=str(version),product_code=raw['primary_product_code'],detail_rank=1))
        return value
    # Announced future hierarchy interval. This uses initial interval history, not
    # contradictory updates to an unversioned reference key.
    change=(start+timedelta(days=8)).isoformat()
    for row in world['product_hierarchy']:
        if row['product_id']==cid('product',1) and not row['effective_to']:row['effective_to']=change
    for row in source['b001']['iqvia_like/product']:
        if row['product_code']==sid('product',cid('product',1),'iqvia') and not row['valid_to']:row['valid_to']=change
    # Active campaign spans the recurring operations window.
    campaign_id=cid('campaign',5);campaign_key=sid('campaign',campaign_id,'salesforce')
    world['campaign'].append(dict(campaign_id=campaign_id,product_id=cid('product',1),start_date=start.isoformat(),end_date_exclusive=(start+timedelta(days=100)).isoformat(),status='ACTIVE'))
    add('b001','salesforce_like/campaign',dict(campaign_key=campaign_key,product_code=sid('product',cid('product',1),'iqvia'),start_date=start.isoformat(),end_date_exclusive=(start+timedelta(days=100)).isoformat(),status='ACTIVE'))
    for h in list(range(1,21))+[100]:
        membership=f'MEM-5-{h}';world['campaign_member'].append(dict(membership_id=membership,campaign_id=campaign_id,hcp_id=cid('hcp',h),member_status='ENROLLED'))
        add('b001','salesforce_like/campaign_member',dict(membership_key=membership,campaign_key=campaign_key,contact_key=sid('hcp',cid('hcp',h),'salesforce'),member_status='ENROLLED'))
    annotations=[];last_daily=None;next_index=305
    for day_index in range(2,config['delivery_count']):
        day=start+timedelta(days=day_index);batch=f'b{day_index+1:03}'
        cfg['batches'].append(dict(id=batch,available_at=day.isoformat()+'T'+config['schedule_utc']+':00Z',as_of=day.isoformat()+'T'+config['cutoff_utc']+':00Z',mode='incremental'))
        for j in range(config['daily_interactions']):
            h=(day_index*config['daily_interactions']+j)%100+1;p=(j+day_index)%4+1
            last=event(next_index,h,p,(day-timedelta(days=1)).isoformat()+'T12:00:00Z',batch);next_index+=1
            if j==0:first=last
        if last_daily:
            index=int(last_daily['interaction_id'].rsplit('-',1)[1]);h=int(last_daily['hcp_id'].rsplit('-',1)[1]);p=int(last_daily['primary_product_id'].rsplit('-',1)[1])%4+1
            event(index,h,p,last_daily['occurred_at'],batch,modified=day.isoformat()+'T04:00:00Z',version=2,operation='DELETE' if day_index%4==0 else 'UPSERT')
            annotations.append(dict(batch=batch,event='tombstone' if day_index%4==0 else 'correction',interaction_id=last_daily['interaction_id']))
        last_daily=first
        if day_index in [3,7]:
            status='WITHDRAWN' if day_index==3 else 'GRANTED';consent_id='OPS-CONSENT-'+str(day_index)
            effective=(day-timedelta(days=1)).isoformat()+'T16:00:00Z'
            world['consent_event'].append(dict(consent_id=consent_id,hcp_id=cid('hcp',1),channel='EMAIL',purpose='COMMERCIAL',status=status,effective_at=effective,sequence_no=day_index,delivery_batch=batch))
            add(batch,'salesforce_like/consent',dict(preference_key=consent_id,contact_key=sid('hcp',cid('hcp',1),'salesforce'),channel='EMAIL',purpose='COMMERCIAL',status=status,effective_at=effective,sequence_no=day_index))
            annotations.append(dict(batch=batch,event='consent_'+status.lower(),effective_at=effective))
        if day_index==4:
            add(batch,'iqvia_like/product',copy.deepcopy(source['b001']['iqvia_like/product'][1]))
            annotations.append(dict(batch=batch,event='identical_product_redelivery'))
        if day_index==6:
            effective=(day-timedelta(days=1)).isoformat();assignment='OPS-REALIGN'
            world['hcp_territory'].append(dict(assignment_id=assignment,hcp_id=cid('hcp',5),territory_id=cid('territory',4),effective_from=effective,effective_to=''))
            add(batch,'manual/territory_mapping',dict(assignment_key=assignment,provider_key=sid('hcp',cid('hcp',5),'iqvia'),territory_code=sid('territory',cid('territory',4),'veeva'),effective_from=effective,effective_to=''))
            annotations.append(dict(batch=batch,event='late_territory_realignment',effective_from=effective))
        if day_index==8:
            row=dict(product_id=cid('product',1),effective_from=change,effective_to='',brand='SYNTH_BRAND_1_OPERATIONS',therapy='SYNTH_THERAPY_A');world['product_hierarchy'].append(row)
            add(batch,'iqvia_like/product',dict(product_code=sid('product',row['product_id'],'iqvia'),brand=row['brand'],therapy=row['therapy'],valid_from=change,valid_to='',active='true'))
            event(next_index,6,2,(day-timedelta(days=8)).isoformat()+'T12:00:00Z',batch,decision='LATE_BEYOND_WINDOW');next_index+=1
            annotations.append(dict(batch=batch,event='hierarchy_restatement_and_eight_day_late_event'))
        if day_index==9:
            event(next_index,7,3,(day-timedelta(days=1)).isoformat()+'T12:00:00Z',batch,decision='INVALID_TYPE');next_index+=1
            event(next_index,8,4,(day-timedelta(days=1)).isoformat()+'T12:00:00Z',batch,decision='MISSING_REQUIRED');next_index+=1
            annotations.append(dict(batch=batch,event='malformed_version_and_missing_date'))
        if day.weekday()==0:
            old=world['rx_sales'][0];v=max(r['version_no'] for r in world['rx_sales'] if r['observation_id']==old['observation_id'])+1
            rx=dict(old,version_no=v,trx_count=50+day_index,nrx_count=10,sales_units=100+day_index*2);world['rx_sales'].append(rx)
            add(batch,'iqvia_like/rx_weekly',dict(observation_key=rx['observation_id'],provider_key=sid('hcp',rx['hcp_id'],'iqvia'),product_code=sid('product',rx['product_id'],'iqvia'),week_ending=rx['week_ending'],trx_count=rx['trx_count'],nrx_count=rx['nrx_count'],sales_units=rx['sales_units'],version_no=v))
    source_contracts=read_json(control/'source-contracts.json')
    source_contracts['veeva_like/activity']['columns'].append('staff_key')
    source_contracts['veeva_like/activity']['schema_version']='2.0'
    source_contracts['veeva_like/activity']['logical_types']['staff_key']='TEXT'
    # Public rep attribution is new in v0.2; retain it at interaction/version grain.
    world_by_activity={(sid('interaction',r['interaction_id'],'veeva'),str(r['version_no'])):r for r in world['interaction']}
    for batch_sources in source.values():
        for row in batch_sources.get('veeva_like/activity',[]):
            key=(row['activity_key'],row['source_version'])
            if row['source_version']=='invalid':key=(row['activity_key'],'1')
            canonical_row=world_by_activity[key]
            row['staff_key']=sid('representative',canonical_row['rep_id'],'veeva')
    write_json(control/'source-contracts.json',source_contracts)
    source_id=contracts['source']['id'];source_version=contracts['source']['version'];source_digest=sha256(CONTRACT_DIR/'source.odcs.json')
    for batch in cfg['batches']:
        files=[]
        for entity,rows in sorted(source[batch['id']].items()):
            key=f"synthetic/pharma/{config['release_id']}/sources/{entity}/batch={batch['id']}/part-00001.csv";path=dest/'public_s3'/key
            columns=source_contracts[entity]['columns'];write_csv(path,rows,columns)
            files.append(dict(key=key,source_entity=entity,schema_version=source_contracts[entity]['schema_version'],columns=columns,row_count=len(rows),byte_count=path.stat().st_size,sha256=sha256(path),format='CSV',encoding='UTF-8',delimiter=',',header=True))
        manifest=dict(manifest_version='1.0',release_id=config['release_id'],batch_id=batch['id'],available_at=batch['available_at'],as_of=batch['as_of'],load_mode=batch['mode'],files=files,contract_id=source_id,contract_version=source_version,contract_sha256=source_digest)
        mp=control/(batch['id']+'.manifest.json');write_json(mp,manifest);write_json(control/(batch['id']+'.ready.json'),dict(batch_id=batch['id'],manifest_sha256=sha256(mp)))
    write_json(dest/'private_evaluator/world.json',world)
    write_json(dest/'private_evaluator/projection-ledger.json',dict(decisions=decisions,config=cfg,reference_deliveries={'hcp_territory':{'OPS-REALIGN':'b007'}}))
    from model import definitions
    for name,rows in world.items():write_csv(dest/'private_evaluator/canonical'/f'{name}.csv',rows,[c['name'] for c in definitions()[name]['columns']])
    write_json(dest/'private_evaluator/canonical-manifest.json',dict(manifest_version='1.0',release_id=config['release_id'],classification='EVALUATOR_ONLY',files=[dict(entity=name,path=f'canonical/{name}.csv',row_count=len(rows),sha256=sha256(dest/'private_evaluator/canonical'/f'{name}.csv'),columns=[c['name'] for c in definitions()[name]['columns']]) for name,rows in world.items()]))
    for batch in cfg['batches']:write_results(dest/'private_evaluator/expected'/batch['id'],expected(dest/'private_evaluator',batch['id']))
    write_json(dest/'operations-input.json',config);write_json(dest/'scenario-events.json',annotations)
    from territory_workbook import write_workbook
    from xlsx_to_csv import convert
    workbook_key=f"synthetic/pharma/{config['release_id']}/business_files/territory/territory_mapping_{start.strftime('%Y%m')}.xlsx"
    workbook=dest/'public_s3'/workbook_key;write_workbook(workbook,source['b001']['manual/territory_mapping'])
    adapted=dest/'territory-adapter.csv';receipt=convert(workbook,adapted)
    territory_key=f"synthetic/pharma/{config['release_id']}/sources/manual/territory_mapping/batch=b001/part-00001.csv"
    if adapted.read_bytes()!=(dest/'public_s3'/territory_key).read_bytes():raise ValueError('Workbook roundtrip differs')
    receipt.update(input_key=workbook_key,output_key=territory_key)
    write_json(control/'territory-adapter.receipt.json',receipt)
    adapted.unlink();Path(str(adapted)+'.receipt.json').unlink()
    validate_public(dest/'public_s3')
    return {'deliveries':len(cfg['batches']),'canonical_rows':sum(map(len,world.values())),'start_date':start.isoformat(),'end_date':(start+timedelta(days=config['delivery_count']-1)).isoformat()}

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--config',type=Path,default=ROOT/'config/operations.json');p.add_argument('--out',type=Path,required=True);a=p.parse_args();print(create(read_json(a.config),a.out))
