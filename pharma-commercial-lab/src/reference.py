"""Source-only reference implementation. This module never opens private_evaluator."""
import argparse
import csv
import re
from collections import defaultdict
from datetime import datetime
from decimal import Decimal
from pathlib import Path
from common import read_json, write_results

def stamp(s):
    value=datetime.fromisoformat(s.replace('Z','+00:00'))
    if value.tzinfo is None or value.utcoffset().total_seconds()!=0:
        raise ValueError('Timestamp must carry UTC timezone information')
    return value

def resolve_identity(rows, idcol, providers):
    tokens=defaultdict(set)
    for r in providers:
        if r['active']=='true' and r['link_token']:
            tokens[r['link_token']].add(r['provider_key'])
    candidates=defaultdict(set)
    invalid=set()
    for r in rows:
        matches=tokens.get(r['match_token'],set())
        if len(matches)!=1:invalid.add(r[idcol])
        candidates[r[idcol]].update(matches)
    return {key:next(iter(values)) for key,values in candidates.items() if len(values)==1 and key not in invalid}

def classify_activity(r, as_of, late_days=7):
    if not all(r.get(k) for k in ['activity_key','customer_key','primary_product_code','occurred_at','modified_at']):
        return 'MISSING_REQUIRED'
    try:
        if any(not re.fullmatch(r'-?[0-9]+',str(r.get(field,''))) for field in ['source_version','duration_minutes']):return 'INVALID_TYPE'
        version=int(r['source_version']);duration=int(r['duration_minutes'])
        occurred=stamp(r['occurred_at']);modified=stamp(r['modified_at']);arrival=stamp(r['_available_at'])
    except (ValueError,TypeError,KeyError):return 'INVALID_TYPE'
    if version<1 or duration<0 or occurred>stamp(as_of) or modified>arrival or r['operation'] not in ('UPSERT','DELETE'):
        return 'INVALID_VALUE'
    basis=modified if version>1 else occurred
    if r['_mode']!='bootstrap' and (arrival.date()-basis.date()).days>late_days:return 'LATE_BEYOND_WINDOW'
    return 'ACCEPT'

def rate_status(numerator, denominator, percent):
    return 'NO_DATA' if denominator==0 else ('ALERT' if Decimal(str(numerator))*100>Decimal(str(denominator))*Decimal(str(percent)) else 'PASS')

def latest_territory(rows, as_of):
    current=[r for r in rows if r['effective_from']<=as_of and (not r['effective_to'] or as_of<r['effective_to'])]
    if not current: return '', 'MISSING'
    best=max(r['effective_from'] for r in current)
    codes={r['territory_code'] for r in current if r['effective_from']==best}
    if len(codes)!=1: raise ValueError('DUPLICATE_CURRENT_TERRITORY')
    return codes.pop(), 'ASSIGNED'

def load_sources(public_root, through):
    manifests=sorted(public_root.rglob('*.manifest.json'))
    tables=defaultdict(list);selected=[]
    for path in manifests:
        m=read_json(path)
        if m['batch_id']>through: continue
        selected.append(m)
        for f in m['files']:
            with (public_root/f['key']).open(newline='',encoding='utf-8') as stream:
                for row in csv.DictReader(stream):
                    row.update(_batch_id=m['batch_id'],_available_at=m['available_at'],_mode=m['load_mode'])
                    tables[f['source_entity']].append(row)
    if not selected or selected[-1]['batch_id']!=through: raise ValueError('Requested batch absent')
    return tables, selected[-1]['as_of']

def calculate(tables, as_of, semantics=None):
    semantics=semantics or {}
    tables={name:list({tuple(sorted(r.items())):r for r in rows if r['_available_at']<=as_of}.values()) for name,rows in tables.items()}
    out=defaultdict(list)
    def exc(sc,key,why): out['exceptions'].append(dict(scenario=sc,record_key=key,reason=why))
    def metric(sc,scope,num,den,limit):
        out['dq'].append(dict(scenario=sc,scope=scope,numerator=num,denominator=den,threshold=limit,status=rate_status(num,den,Decimal(str(limit))*100)))
    day=as_of[:10]
    approved={r['provider_key']:r for r in tables['iqvia_like/provider'] if r['active']=='true'}
    def mapping(entity,idcol):
        return resolve_identity(tables[entity],idcol,tables['iqvia_like/provider'])
    crm=mapping('veeva_like/customer','customer_key');sf=mapping('salesforce_like/contact','contact_key')
    current_products={}
    for r in tables['iqvia_like/product']:
        if r['active']=='true' and r['valid_from']<=day and (not r['valid_to'] or day<r['valid_to']):
            payload=lambda row:{k:v for k,v in row.items() if not k.startswith('_')}
            if r['product_code'] in current_products and payload(current_products[r['product_code']])!=payload(r):
                raise ValueError('AMBIGUOUS_PRODUCT_HIERARCHY')
            current_products[r['product_code']]=r
    versions={};seen={}
    for r in sorted(tables['veeva_like/activity'],key=lambda r:(r['_available_at'],r['_batch_id'])):
        key=r['activity_key']
        disposition=classify_activity(r,as_of,semantics.get('S4',{}).get('lateArrivalCalendarDays',7))
        if not re.fullmatch(r'-?[0-9]+',str(r.get('source_version',''))):exc('S04',key,disposition);continue
        try:v=int(r['source_version'])
        except (ValueError,TypeError):exc('S04',key,'INVALID_TYPE');continue
        pair=(key,v)
        payload={k:x for k,x in r.items() if not k.startswith('_')}
        if pair in seen:
            if seen[pair]!=payload:raise ValueError('CONFLICTING_INTERACTION_VERSION')
            continue
        seen[pair]=payload
        if disposition!='ACCEPT':exc('S04',key,disposition);continue
        if key not in versions or v>int(versions[key]['source_version']):versions[key]=r
    interactions=[r for r in versions.values() if r['operation']!='DELETE']
    for r in interactions:
        out['s04_interaction'].append({k:r[k] for k in ['activity_key','customer_key','primary_product_code','occurred_at','channel','duration_minutes','source_version']})
    details=defaultdict(set)
    for r in tables['veeva_like/activity_product']:
        if not re.fullmatch(r'[0-9]+',str(r['source_version'])):continue
        try:version=int(r['source_version'])
        except (ValueError,TypeError):continue
        if version<1:continue
        details[(r['activity_key'],version)].add(r['product_code'])
    latest_consent={};consent_ranks={}
    for r in tables['salesforce_like/consent']:
        if r['effective_at']>as_of or r['purpose']!='COMMERCIAL':continue
        h=sf.get(r['contact_key'])
        if not h:continue
        key=(h,r['channel']);rank=(r['effective_at'],int(r['sequence_no']))
        identity=(key,rank)
        if identity in consent_ranks and r['status']!=consent_ranks[identity]:
            raise ValueError('CONFLICTING_CONSENT')
        consent_ranks[identity]=r['status']
        if key not in latest_consent or rank>latest_consent[key][0]:latest_consent[key]=(rank,r['status'])
    eligible=[r for r in interactions if r['approval']=='APPROVED']
    num=sum(r['customer_key'] not in crm for r in eligible)
    metric('S01','ALL',num,len(eligible),semantics.get('S1',{}).get('matchAlertAbove',0.02))
    aggregates=defaultdict(set);unknown=0
    for r in eligible:
        aid=r['activity_key'];h=crm.get(r['customer_key']);dt=r['occurred_at'][:10]
        if not h: exc('S01',aid,'UNMATCHED_CUSTOMER')
        else:
            c=latest_consent.get((h,r['channel']))
            if not c: exc('S01',aid,'MISSING_CONSENT')
            elif c[1]!='GRANTED':exc('S01',aid,'WITHDRAWN_OR_UNKNOWN_CONSENT')
            else: out['s01_engagement'].append(dict(activity_key=aid,customer_key=h,activity_date=dt,consent_status=c[1]))
        prods=details[(aid,int(r['source_version']))]
        if not prods or any(p not in current_products for p in prods):
            unknown+=1;exc('S02',aid,'UNKNOWN_PRODUCT')
        if not h:
            exc('S02',aid,'UNMATCHED_CUSTOMER');continue
        for p in prods:
            if p in current_products:aggregates[(h,p,dt)].add(aid)
    metric('S02','ALL',unknown,len(eligible),semantics.get('S2',{}).get('unknownProductAlertAbove',0.01))
    for (h,p,dt),ids in aggregates.items():
        prod=current_products[p]
        out['s02_product_activity'].append(dict(customer_key=h,product_code=p,activity_date=dt,brand=prod['brand'],therapy=prod['therapy'],interaction_count=len(ids)))
    assignments=defaultdict(list)
    for r in tables['manual/territory_mapping']:assignments[r['provider_key']].append(r)
    known_territories={r['territory_code'] for r in tables['veeva_like/territory']}
    for h in approved:
        code,status=latest_territory(assignments[h],day)
        if code and code not in known_territories: raise ValueError('UNKNOWN_TERRITORY')
        out['s03_customer_territory'].append(dict(customer_key=h,territory_code=code,assignment_status=status))
        if status=='MISSING':exc('S03',h,'MISSING_TERRITORY')
    members=defaultdict(set)
    for r in tables['salesforce_like/campaign_member']:
        if r['member_status']=='ENROLLED':members[r['campaign_key']].add(r['contact_key'])
    for c in tables['salesforce_like/campaign']:
        if c['status']=='CANCELLED':continue
        cid=c['campaign_key'];p=c['product_code'];member_ids=members[cid]
        bad=sum(h not in sf for h in member_ids);metric('S05',cid,bad,len(member_ids),semantics.get('S5',{}).get('matchAlertAbove',0.05))
        if p not in current_products:exc('S05',cid,'UNKNOWN_PRODUCT');continue
        for contact in sorted(member_ids):
            h=sf.get(contact)
            if not h:exc('S05',cid+'|'+contact,'UNMATCHED_MEMBER');continue
            hits={r['activity_key'] for r in eligible if crm.get(r['customer_key'])==h and c['start_date']<=r['occurred_at'][:10]<c['end_date_exclusive'] and p in details[(r['activity_key'],int(r['source_version']))]}
            out['s05_campaign'].append(dict(campaign_key=cid,customer_key=h,product_code=p,contacted=str(bool(hits)).lower(),qualifying_interactions=len(hits)))
    # Identical resent rows must not duplicate diagnostic evidence.
    out['exceptions']=[dict(zip(('scenario','record_key','reason'),x)) for x in sorted({(r['scenario'],r['record_key'],r['reason']) for r in out['exceptions']})]
    return out

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--public-root',type=Path,required=True);p.add_argument('--batch',required=True);p.add_argument('--out',type=Path,required=True);a=p.parse_args()
    t,as_of=load_sources(a.public_root,a.batch);result=calculate(t,as_of);write_results(a.out,result)
    print('Source-only reference complete:',a.batch)

