"""Generate inspectable governance handoffs and Power BI / Analysis Services TMDL; never call vendors."""
from pathlib import Path
from export_powerbi import export as export_powerbi
from common import ROOT,write_json,write_csv
from odcs import registry,extension,registry_fingerprint

CANONICAL_SOURCES={
 'organisation':['iqvia_like/organisation'],'affiliation':['iqvia_like/affiliation'],'representative':['veeva_like/staff'],
 'customer':['iqvia_like/provider'],'product_interval':['iqvia_like/product'],'territory':['veeva_like/territory'],
 'interaction_version':['veeva_like/activity','veeva_like/customer','iqvia_like/provider','veeva_like/staff'],
 'interaction_product':['veeva_like/activity_product','veeva_like/activity'],
 'consent_event':['salesforce_like/consent','salesforce_like/contact','iqvia_like/provider'],
 'customer_territory':['manual/territory_mapping'], 'campaign':['salesforce_like/campaign'],
 'campaign_member':['salesforce_like/campaign_member','salesforce_like/contact','iqvia_like/provider'],'rx_version':['iqvia_like/rx_weekly']}
PIPELINE_SOURCES={
 's01_engagement':['interaction_version','customer','consent_event'],
 's02_product_activity':['interaction_version','interaction_product','customer','product_interval'],
 's03_customer_territory':['customer','customer_territory','territory'],
 's04_interaction':['interaction_version'],
 's05_campaign':['interaction_version','interaction_product','campaign','campaign_member','customer','product_interval'],
 'exceptions':list(CANONICAL_SOURCES),'dq':list(CANONICAL_SOURCES)}

def uid(layer,name):return 'urn:pharma:'+layer+':'+name

def export():
    contracts=registry();root=ROOT/'integrations';assets=[];edges=[];rules=[];policies=[]
    for layer,c in contracts.items():
        for obj in c['schema']:
            assets.append(dict(asset_id=uid(layer,obj['name']),contract_id=c['id'],contract_version=c['version'],layer=layer,name=obj['name'],physical_name=obj['physicalName'],grain=obj['dataGranularityDescription'],owner=c['team']['name'],classification='synthetic',status='proposed',columns=obj['properties']))
            for rule in obj.get('quality',[]):rules.append(dict(asset_id=uid(layer,obj['name']),contract_id=c['id'],contract_version=c['version'],rule=rule,parameter='snapshot_id',enforcement='local gate executed' if rule['type']=='sql' or layer=='source' else 'definition'))
            policies.append(dict(asset_id=uid(layer,obj['name']),classification='synthetic',allowed_role='PHARMA_BUILDER' if layer in ['source','canonical','pipeline'] else 'PHARMA_ANALYST',purpose='commercial synthetic investigation',view=obj['physicalName']+'_current' if layer=='consumption' else obj['physicalName'],implementation_status='tenant binding and enforcement acceptance required'))
            if layer=='canonical':parents=[uid('source',n) for n in CANONICAL_SOURCES[obj['name']]]
            elif layer=='pipeline':parents=[uid('canonical',n) for n in PIPELINE_SOURCES[obj['name']]]
            elif layer=='consumption':parents=[uid('pipeline',obj['name'])]
            elif layer=='visualization':parents=[uid('consumption',n) for n in PIPELINE_SOURCES]
            else:parents=[]
            edges.extend(dict(source=p,target=uid(layer,obj['name']),relation='derivedFrom') for p in parents)
    digest=registry_fingerprint(contracts)
    write_json(root/'collibra/asset-lineage-handoff.json',dict(format='pharma-vendor-neutral-handoff-v1',contract_registry_sha256=digest,assets=assets,lineage=edges,requires=['community/domain IDs','asset/relation type IDs','owner role assignments','tenant importer and access acceptance']))
    cols=['asset_id','contract_id','contract_version','layer','name','physical_name','grain','owner','classification','status']
    write_csv(root/'collibra/assets.csv',[{k:a[k] for k in cols} for a in assets],cols)
    write_json(root/'ataccama/quality-rule-handoff.json',dict(format='pharma-vendor-neutral-handoff-v1',rules=rules,requires=['ONE version-specific rule mappings','Snowflake connection','SQL parameter wrapper','notification routing and execution evidence']))
    write_json(root/'immuta/policy-intent-handoff.json',dict(format='pharma-vendor-neutral-handoff-v1',policies=policies,evaluator_boundary='private_evaluator is never a builder or analyst data source',requires=['Snowflake/Immuta integration','real groups and attributes','tenant-specific policies','positive and negative access tests']))
    semantic = export_powerbi(contracts, root)
    return {'assets':len(assets),'lineage_edges':len(edges),'quality_rules':len(rules),**semantic}

if __name__=='__main__':print(export())
