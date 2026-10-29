"""Compile recurring loaders, canonical/published schemas and ODCS quality gates.

Snowflake scripts require STOP-on-error, one loader and an existing external
stage. Remote file fingerprints depend on the validated conditional uploader;
COPY row counts alone cannot authenticate remote bytes.
"""
import argparse
from pathlib import Path
from common import ROOT,read_json,sha256,write_json,GOLD_COLUMNS
from odcs import registry,registry_fingerprint,ddl,objects,identifier,extension,validate_binding
from render_sql import render,safe_identifier,lit
from reference import stamp

SOURCES={
 'organisation':('SRC_IQVIA_LIKE_ORGANISATION s',{},''),
 'affiliation':('SRC_IQVIA_LIKE_AFFILIATION s',{'customer_key':'s.provider_key'},''),
 'representative':('SRC_VEEVA_LIKE_STAFF s',{},''),
 'customer':('SRC_IQVIA_LIKE_PROVIDER s',{'customer_key':'s.provider_key'},''),
 'product_interval':('SRC_IQVIA_LIKE_PRODUCT s',{},''),
 'territory':('SRC_VEEVA_LIKE_TERRITORY s',{},''),
 'interaction_version':('ACTIVITY_CLASSIFIED s LEFT JOIN CRM_MAP m ON s.customer_key=m.customer_key',{'crm_customer_key':'s.customer_key','customer_key':'m.provider_key','delivery_batch':'s._batch_id'}," AND s.disposition='ACCEPT' QUALIFY ROW_NUMBER() OVER(PARTITION BY s.activity_key,s.source_version ORDER BY s._available_at)=1"),
 'interaction_product':("DETAIL s JOIN (SELECT DISTINCT activity_key,source_version FROM ACTIVITY_CLASSIFIED WHERE disposition='ACCEPT') a ON s.activity_key=a.activity_key AND s.source_version=TRY_TO_NUMBER(a.source_version)",{},'DETAIL'),
 'consent_event':('SRC_SALESFORCE_LIKE_CONSENT s LEFT JOIN SF_MAP m ON s.contact_key=m.contact_key',{'customer_key':'m.provider_key','delivery_batch':'s._batch_id'},' QUALIFY ROW_NUMBER() OVER(PARTITION BY s.preference_key ORDER BY s._available_at)=1'),
 'customer_territory':('SRC_MANUAL_TERRITORY_MAPPING s',{'customer_key':'s.provider_key'},''),
 'campaign':('SRC_SALESFORCE_LIKE_CAMPAIGN s',{},''),
 'campaign_member':('SRC_SALESFORCE_LIKE_CAMPAIGN_MEMBER s LEFT JOIN SF_MAP m ON s.contact_key=m.contact_key',{'customer_key':'m.provider_key'},''),
 'rx_version':('SRC_IQVIA_LIKE_RX_WEEKLY s',{'customer_key':'s.provider_key'},'')}

def gate(query, message, expected=0):
    return 'EXECUTE IMMEDIATE $$ DECLARE bad EXCEPTION (-20010, '+lit(message)+'); n NUMBER; BEGIN SELECT COUNT(*) INTO :n FROM ('+query+'); IF (n<>'+str(expected)+') THEN RAISE bad; END IF; END; $$;'

def quality_gate(query,message):
    return 'EXECUTE IMMEDIATE $$ DECLARE bad EXCEPTION (-20011, '+lit(message)+'); n NUMBER; BEGIN '+query.replace('SELECT COUNT(*)','SELECT COUNT(*) INTO :n',1)+'; IF (n<>0) THEN RAISE bad; END IF; END; $$;'

def render_operations(public_root,stage,schema,out):
    c=registry();schema=safe_identifier(schema,2);render(public_root,stage,schema,out)
    manifests=sorted(((read_json(p),p) for p in public_root.rglob('*.manifest.json')),key=lambda x:x[0]['batch_id'])
    fingerprint=registry_fingerprint(c)
    setup=[f'USE SCHEMA {schema};',"ALTER SESSION SET TIMEZONE='UTC';",
      'CREATE TABLE IF NOT EXISTS ODCS_MODEL_IDENTITY (release_id VARCHAR, registry_sha256 VARCHAR);',
      'CREATE TABLE IF NOT EXISTS ODCS_SNAPSHOT_AUDIT (snapshot_id VARCHAR, release_id VARCHAR, manifest_sha256 VARCHAR, registry_sha256 VARCHAR, as_of TIMESTAMP_NTZ, published_at TIMESTAMP_LTZ, status VARCHAR);']
    for layer in ['canonical','pipeline','consumption','visualization']:setup.append(ddl(c[layer],'snowflake'))
    for layer in ['pipeline','consumption','visualization']:
        for obj in c[layer]['schema']:
            weekly=layer=='consumption' and obj['name']=='s05_campaign'
            predicate=' AND DAYOFWEEKISO(as_of)=1' if weekly else ''
            setup.append('CREATE OR REPLACE VIEW '+identifier(obj['physicalName']+'_current')+' AS SELECT * FROM '+identifier(obj['physicalName'])+' WHERE "snapshot_id"=(SELECT snapshot_id FROM ODCS_SNAPSHOT_AUDIT WHERE status=\'PUBLISHED\''+predicate+' ORDER BY as_of DESC LIMIT 1);')
    (out/'00_setup_odcs.sql').write_text('\n\n'.join(setup)+'\n')
    semantics=extension(c['pipeline'],'scenarioSemantics')
    for index,(m,path) in enumerate(manifests):
        validate_binding(m,c);batch=m['batch_id'];cut=m['as_of'];snapshot=lit(batch)
        hours=(stamp(cut)-stamp(m['available_at'])).total_seconds()/3600
        freshness=next(p['value'] for p in c['source']['slaProperties'] if p['property']=='freshness')
        if hours<0 or hours>float(freshness):raise ValueError('Manifest availability violates source contract freshness')
        gold=(ROOT/'sql/02_reference_gold.sql').read_text().replace("SET AS_OF = '2026-09-15T06:00:00Z';",'SET AS_OF = '+lit(cut)+';')
        gold=gold.replace('duration_minutes,source_version,modified_at,operation,_available_at','staff_key,duration_minutes,source_version,modified_at,operation,_available_at')
        gold=gold.replace('approval,duration_minutes,source_version,modified_at,operation FROM ACTIVITY_VERSION','approval,staff_key,duration_minutes,source_version,modified_at,operation FROM ACTIVITY_VERSION')
        gold=gold.replace(')>7 THEN',')>'+str(int(semantics['S4']['lateArrivalCalendarDays']))+' THEN')
        gold=gold.replace('0.02::NUMBER(3,2)',str(semantics['S1']['matchAlertAbove'])+'::NUMBER(12,6)')
        gold=gold.replace("COUNT(*),0.01 FROM",'COUNT(*),'+str(semantics['S2']['unknownProductAlertAbove'])+' FROM')
        gold=gold.replace('COUNT(cm.contact_key),0.05','COUNT(cm.contact_key),'+str(semantics['S5']['matchAlertAbove']))
        semantic_gates=[]
        for entity,spec in read_json(ROOT/'contracts/source-projections.json').items():
            if entity.startswith('veeva_like/activity'):continue
            table='SRC_'+entity.replace('/','_').upper()
            for column,kind in spec['logical_types'].items():
                allowed_null=column in ['effective_to','valid_to','match_token','link_token']
                predicate=column+' IS NULL' if not allowed_null else 'FALSE'
                if kind=='INTEGER':predicate+=' OR ('+column+" IS NOT NULL AND NOT REGEXP_LIKE("+column+",'-?[0-9]+'))"
                elif kind=='DATE':predicate+=' OR ('+column+' IS NOT NULL AND (TRY_TO_DATE('+column+") IS NULL OR NOT REGEXP_LIKE("+column+",'[0-9]{4}-[0-9]{2}-[0-9]{2}')))"
                elif kind=='TIMESTAMP_UTC':predicate+=' OR ('+column+' IS NOT NULL AND (TRY_TO_TIMESTAMP_NTZ('+column+") IS NULL OR NOT REGEXP_LIKE("+column+",'.*(Z|[+]00:00)$')))"
                elif kind=='BOOLEAN':predicate+=' OR ('+column+" IS NOT NULL AND "+column+" NOT IN ('true','false'))"
                query='SELECT COUNT(*) FROM '+table+' WHERE _available_at<=TO_TIMESTAMP_NTZ($AS_OF) AND ('+predicate+')'
                semantic_gates.append(quality_gate(query,entity+'/'+column+' semantic type'))
            keys=','.join(spec['key_columns']);columns=','.join(spec['columns'])
            query='SELECT COUNT(*) FROM (SELECT '+keys+' FROM (SELECT DISTINCT '+columns+' FROM '+table+' WHERE _available_at<=TO_TIMESTAMP_NTZ($AS_OF)) GROUP BY '+keys+' HAVING COUNT(*)>1)'
            semantic_gates.append(quality_gate(query,entity+' conflicting business key'))
        set_line='SET AS_OF = '+lit(cut)+';'
        aliases=['CREATE OR REPLACE VIEW '+identifier(obj['physicalName'])+' AS SELECT * FROM SRC_'+obj['name'].replace('/','_').upper()+';' for obj in c['source']['schema']]
        gold=gold.replace(set_line,set_line+'\n\n'+'\n\n'.join(aliases+semantic_gates),1)
        (out/f'02_gold_{batch}.sql').write_text(gold)
        script=[f'USE SCHEMA {schema};',
          gate('SELECT * FROM ODCS_MODEL_IDENTITY WHERE release_id<>'+lit(m['release_id'])+' OR registry_sha256<>'+lit(fingerprint),'Schema belongs to another release or registry'),
          gate('SELECT * FROM ODCS_SNAPSHOT_AUDIT WHERE snapshot_id='+snapshot+' AND (manifest_sha256<>'+lit(sha256(path))+' OR registry_sha256<>'+lit(fingerprint)+')','Checkpoint fingerprint differs'),
          gate('SELECT * FROM ODCS_SNAPSHOT_AUDIT WHERE snapshot_id<'+snapshot+' AND status=\'PUBLISHED\'','Missing predecessor checkpoint',index),
          '-- Harness skips publication for an already identical checkpoint. Single writer required.',
          'BEGIN TRANSACTION;',
          'INSERT INTO ODCS_MODEL_IDENTITY SELECT '+lit(m['release_id'])+','+lit(fingerprint)+' WHERE NOT EXISTS (SELECT 1 FROM ODCS_MODEL_IDENTITY);']
        for name,obj in objects(c['canonical']).items():
            source,renames,suffix=SOURCES[name];expr=[]
            for p in obj['properties']:
                if p['name']=='snapshot_id':expr.append(snapshot);continue
                value=renames.get(p['name'],'s.'+p['name'])
                kind=p['logicalType']
                if kind=='integer':value='TO_NUMBER('+value+')'
                elif kind=='boolean':value='TO_BOOLEAN('+value+')'
                elif kind=='date':value='TO_DATE('+value+')'
                elif kind=='timestamp':value='TO_TIMESTAMP_NTZ('+value+')'
                expr.append(value)
            where='' if suffix=='DETAIL' else ' WHERE s._available_at<=TO_TIMESTAMP_NTZ($AS_OF)'+suffix
            script.append('INSERT INTO '+identifier(obj['physicalName'])+' SELECT DISTINCT '+','.join(expr)+' FROM '+source+where+';')
        monday=__import__('datetime').datetime.fromisoformat(cut.replace('Z','+00:00')).weekday()==0
        for layer in ['pipeline','consumption']:
            for name,obj in objects(c[layer]).items():
                if layer=='consumption' and name=='s05_campaign' and not monday:continue
                values=[snapshot,'TO_TIMESTAMP_NTZ($AS_OF)']+[('TO_BOOLEAN('+p['name']+')' if p['logicalType']=='boolean' else p['name']) for p in obj['properties'][2:]]
                script.append('INSERT INTO '+identifier(obj['physicalName'])+' SELECT '+','.join(values)+' FROM GOLD_'+name.upper()+';')
        cases=[]
        for name in GOLD_COLUMNS:
            if not name.startswith('s0'):continue
            sc=name.split('_',1)[0].upper();filter_=' AND "campaign_key"=d.scope' if sc=='S05' else ''
            cases.append('WHEN '+lit(sc)+' THEN (SELECT COUNT(*) FROM '+identifier('pipeline_'+name)+' WHERE "snapshot_id"='+snapshot+filter_+')')
        count='CASE d.scenario '+' '.join(cases)+' END'
        exceptions='(SELECT COUNT(*) FROM "pipeline_exceptions" e WHERE e."snapshot_id"='+snapshot+' AND e."scenario"=d.scenario AND (d.scenario<>\'S05\' OR SPLIT_PART(e."record_key",\'|\',1)=d.scope))'
        script.append('INSERT INTO "visualization_scenario_scorecard" SELECT '+snapshot+',TO_TIMESTAMP_NTZ($AS_OF),d.scenario,d.scope,'+count+','+exceptions+',d.numerator,d.denominator,d.threshold,d.status,IFF(d.scenario=\'S05\',DAYOFWEEKISO(TO_TIMESTAMP_NTZ($AS_OF))=1,TRUE) FROM (SELECT scenario,scope,numerator,denominator,threshold,status FROM GOLD_DQ UNION ALL SELECT \'S03\',\'ALL\',0,0,0,\'DIAGNOSTIC\' UNION ALL SELECT \'S04\',\'ALL\',0,0,0,\'DIAGNOSTIC\') d;')
        for layer in ['canonical','pipeline','consumption','visualization']:
            for obj in c[layer]['schema']:
                for rule in obj.get('quality',[]):
                    if rule['type']=='sql':script.append(quality_gate(rule['query'].replace('${table}',identifier(obj['physicalName'])).replace('?',snapshot),obj['name']+'/'+rule['name']))
        script.extend([
          quality_gate('SELECT COUNT(*) FROM "canonical_rx_version" WHERE "snapshot_id"='+snapshot+' AND ("nrx_count">"trx_count" OR "nrx_count"<0 OR "trx_count"<0 OR "sales_units"<0)','Invalid commercial measures'),
          quality_gate('SELECT COUNT(*) FROM "canonical_customer_territory" a LEFT JOIN "canonical_territory" t ON a."snapshot_id"=t."snapshot_id" AND a."territory_code"=t."territory_code" WHERE a."snapshot_id"='+snapshot+' AND t."territory_code" IS NULL','Unknown territory reference'),
          quality_gate('SELECT COUNT(*) FROM "canonical_campaign_member" m LEFT JOIN "canonical_campaign" c ON m."snapshot_id"=c."snapshot_id" AND m."campaign_key"=c."campaign_key" WHERE m."snapshot_id"='+snapshot+' AND c."campaign_key" IS NULL','Missing campaign parent'),
          quality_gate('SELECT COUNT(*) FROM "canonical_product_interval" WHERE "snapshot_id"='+snapshot+' AND "valid_to" IS NOT NULL AND "valid_to"<= "valid_from"','Invalid product interval'),
          quality_gate('SELECT COUNT(*) FROM "canonical_customer_territory" WHERE "snapshot_id"='+snapshot+' AND "effective_to" IS NOT NULL AND "effective_to"<= "effective_from"','Invalid assignment interval'),
          'INSERT INTO ODCS_SNAPSHOT_AUDIT SELECT '+snapshot+','+lit(m['release_id'])+','+lit(sha256(path))+','+lit(fingerprint)+',TO_TIMESTAMP_NTZ($AS_OF),CURRENT_TIMESTAMP(),\'PUBLISHED\';','COMMIT;'])
        (out/f'03_publish_{batch}.sql').write_text('\n\n'.join(script)+'\n')
    write_json(out/'render-manifest.json',dict(registry_sha256=fingerprint,release_id=manifests[0][0]['release_id'],stage=stage,schema=schema,batches=[m['batch_id'] for m,p in manifests],execution_status='NOT_EXECUTED',run_order='00_setup once; for each batch: 01_load, 02_gold, 03_publish; harness verifies replay identity'))
    return len(manifests)

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--public-root',type=Path,required=True);p.add_argument('--stage',required=True);p.add_argument('--schema',required=True);p.add_argument('--out',type=Path,required=True);a=p.parse_args();print('Rendered',render_operations(a.public_root,a.stage,a.schema,a.out),'checkpoints; not executed against Snowflake')
