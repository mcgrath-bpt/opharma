"""Author the five contract bundles and derived SQL. Run intentionally after edits."""
from common import ROOT, read_json, write_json, GOLD_COLUMNS
from odcs import CONTRACT_DIR, registry, ddl, SNOWFLAKE_TYPES, relationship_quality

IDS={layer:'pharma.commercial.'+layer for layer in ['source','canonical','pipeline','consumption','visualization']}
KEYS={'s01_engagement':['activity_key'],'s02_product_activity':['customer_key','product_code','activity_date'],'s03_customer_territory':['customer_key'],'s04_interaction':['activity_key'],'s05_campaign':['campaign_key','customer_key'],'exceptions':['scenario','record_key','reason'],'dq':['scenario','scope']}
GRAINS={'s01_engagement':'one currently consented approved interaction','s02_product_activity':'one customer/product/activity date','s03_customer_territory':'one active approved customer','s04_interaction':'one accepted latest nondeleted CRM activity','s05_campaign':'one enrolled customer/campaign; explicit zero contact retained','exceptions':'one distinct scenario/record/reason','dq':'one scenario/scope quality rate'}
CANONICAL={
 'organisation':('organisation_key:string,organisation_name:string,country:string','organisation_key'),
 'affiliation':('affiliation_key:string,customer_key:string,organisation_key:string,relationship_type:string,is_primary:boolean,effective_from:date,effective_to:date?','affiliation_key'),
 'representative':('staff_key:string,staff_name:string','staff_key'),
 'customer':('customer_key:string,label:string,speciality:string,country:string,postal_sector:string,active:boolean','customer_key'),
 'product_interval':('product_code:string,valid_from:date,valid_to:date?,brand:string,therapy:string,active:boolean','product_code,valid_from'),
 'territory':('territory_code:string,territory_name:string','territory_code'),
 'interaction_version':('activity_key:string,source_version:integer,crm_customer_key:string,customer_key:string?,staff_key:string?,primary_product_code:string,occurred_at:timestamp,channel:string,approval:string,duration_minutes:integer,modified_at:timestamp,operation:string,delivery_batch:string','activity_key,source_version'),
 'interaction_product':('activity_key:string,source_version:integer,product_code:string','activity_key,source_version,product_code'),
 'consent_event':('preference_key:string,customer_key:string?,contact_key:string,channel:string,purpose:string,status:string,effective_at:timestamp,sequence_no:integer,delivery_batch:string','preference_key'),
 'customer_territory':('assignment_key:string,customer_key:string,territory_code:string,effective_from:date,effective_to:date?','assignment_key'),
 'campaign':('campaign_key:string,product_code:string,start_date:date,end_date_exclusive:date,status:string','campaign_key'),
 'campaign_member':('membership_key:string,campaign_key:string,customer_key:string?,contact_key:string,member_status:string','membership_key'),
 'rx_version':('observation_key:string,version_no:integer,customer_key:string,product_code:string,week_ending:date,trx_count:integer,nrx_count:integer,sales_units:integer','observation_key,version_no')
}

def prop(name,kind='string',required=True):
    return {'name':name,'businessName':name.replace('_',' '),'logicalType':kind,'physicalType':SNOWFLAKE_TYPES[kind],'required':required,'classification':'synthetic','criticalDataElement':name.endswith('_key')}

def object_(name,physical,properties,keys,grain):
    for i,key in enumerate(keys,1):
        p=next(p for p in properties if p['name']==key);p.update(primaryKey=True,primaryKeyPosition=i)
    result={'name':name,'physicalName':physical,'physicalType':'table','logicalType':'object','description':grain,'dataGranularityDescription':grain,'properties':properties}
    if keys and 'snapshot_id' in keys:
        cols=','.join('"'+k+'"' for k in keys)
        result['quality']=[{'name':'uniqueGrain','type':'sql','dimension':'uniqueness','severity':'error','query':'SELECT COUNT(*) FROM (SELECT '+cols+' FROM ${table} WHERE "snapshot_id"=? GROUP BY '+cols+' HAVING COUNT(*)>1)','mustBe':0}]
    return result

def bundle(layer,schemas,parents,notes):
    return {'apiVersion':'v3.1.0','kind':'DataContract','id':IDS[layer],'version':'0.2.0','status':'proposed','name':'Pharma commercial '+layer,'domain':'pharma-commercial','dataProduct':'synthetic-pharma-commercial-lab','tags':['synthetic','S1','S2','S3','S4','S5',layer],
      'description':{'purpose':notes,'usage':'Local recurring investigations and Snowflake migration validation.','limitations':'Synthetic data only. Vendor integrations require tenant configuration and acceptance.'},
      'team':{'name':'Pharma commercial data product','description':'Proposed accountable product owner; name the real steward before production approval.'},
      'roles':[{'role':'PHARMA_BUILDER','access':'read public source; write isolated pipeline schemas'},{'role':'PHARMA_ANALYST','access':'read consumption and visualization only'},{'role':'PHARMA_EVALUATOR','access':'read private oracle; never grant to builder'}],
      'servers':[{'server':'local','type':'local','environment':'dev','path':'data/operations/model-v02.sqlite','format':'sqlite'},{'server':'snowflakeTarget','type':'snowflake','environment':'target','account':'CONFIGURE_ACCOUNT','database':'PHARMA_LAB','schema':'PHARMA_MODEL'}],
      'schema':schemas,
      'slaProperties':[{'property':'freshness','value':24,'unit':'hours','driver':'operational','description':'Daily source availability and cutoffs are checked at the logical run time.'},{'property':'schedule','value':'06:00 UTC daily','scheduler':'airflow','schedule':'0 6 * * *'}],
      'customProperties':[{'property':'layer','value':layer},{'property':'dependsOn','value':[IDS[p] for p in parents]},{'property':'runtime','value':{'schemaGate':'src/odcs.py','engine':'python-sqlite','target':'snowflake-sql-python','qualityGate':'fail structural or reconciliation errors; record percentage alerts','timezone':'UTC','majorVersionRequiredForBreakingChanges':True}}]}

def build():
    projection=read_json(ROOT/'contracts/source-projections.json')
    # Projection file is a map keyed by source entity.
    source=[]
    for name,spec in projection.items():
        if not isinstance(spec,dict) or 'columns' not in spec:continue
        columns=spec['columns']
        if isinstance(columns,dict):columns=list(columns)
        if name=='veeva_like/activity':columns=columns+['staff_key']
        logical=spec.get('logical_types',{})
        properties=[prop(c,{'INTEGER':'integer','DATE':'date','TIMESTAMP_UTC':'timestamp','BOOLEAN':'boolean'}.get(logical.get(c),'string'),c not in ['effective_to','valid_to','match_token']) for c in columns]
        # CSV bronze preserves original text so invalid rows can be quarantined downstream.
        for p in properties:p['physicalType']='VARCHAR';p['logicalType']='string';p['required']=False
        obj=object_(name,'raw_'+name.replace('/','_'),properties,[],spec.get('delivery','source delivery row; duplicates retained for replay tests'))
        obj['customProperties']=[{'property':'sourceSchemaVersion','value':'2.0' if name=='veeva_like/activity' else spec['schema_version']},{'property':'semanticTypes','value':{**spec['logical_types'],**({'staff_key':'TEXT'} if name=='veeva_like/activity' else {})}},{'property':'businessKeys','value':spec['key_columns']},{'property':'invalidTypeHandling','value':'quarantine' if name.startswith('veeva_like/activity') else 'fail batch'}]
        obj['quality']=[{'name':'manifestAndSemanticGate','type':'custom','engine':'pharma-local','implementation':{'manifest':'src/validate.py:validate_public','binding':'src/odcs.py:validate_binding','types':'src/hydrate_operations.py:raw_semantic_gate'},'dimension':'conformity','severity':'error'}]
        source.append(obj)
    if not source:raise ValueError('Source projection structure changed')
    canonical=[]
    for name,(spec,keystr) in CANONICAL.items():
        props=[prop('snapshot_id')]
        for field in spec.split(','):
            n,t=field.split(':');props.append(prop(n,t.rstrip('?'),not t.endswith('?')))
        canonical.append(object_(name,'canonical_'+name,props,['snapshot_id']+keystr.split(','),'one public-source-derived '+name.replace('_',' ')+' version or interval per snapshot'))
    refs={
      'affiliation':[(['customer_key'],'customer',['customer_key']),(['organisation_key'],'organisation',['organisation_key'])],
      'interaction_version':[(['customer_key'],'customer',['customer_key']),(['staff_key'],'representative',['staff_key'])],
      'interaction_product':[(['activity_key','source_version'],'interaction_version',['activity_key','source_version'])],
      'consent_event':[(['customer_key'],'customer',['customer_key'])],
      'customer_territory':[(['customer_key'],'customer',['customer_key']),(['territory_code'],'territory',['territory_code'])],
      'campaign_member':[(['campaign_key'],'campaign',['campaign_key']),(['customer_key'],'customer',['customer_key'])],
      'rx_version':[(['customer_key'],'customer',['customer_key'])]}
    lookup={o['name']:o for o in canonical}
    for obj in canonical:
        relationships=[]
        for columns,parent,parent_columns in refs.get(obj['name'],[]):
            relationships.append({'type':'foreignKey','from':[obj['name']+'.snapshot_id']+[obj['name']+'.'+col for col in columns],'to':[parent+'.snapshot_id']+[parent+'.'+col for col in parent_columns]})
        if relationships:
            obj['relationships']=relationships
            obj['quality']+=relationship_quality(obj,lookup)
    pipeline=[];consumption=[]
    for name,cols in GOLD_COLUMNS.items():
        fields=[prop('snapshot_id'),prop('as_of','timestamp')]
        for col in cols:
            kind='integer' if col in ['interaction_count','duration_minutes','source_version','qualifying_interactions','numerator','denominator'] else 'number' if col=='threshold' else 'boolean' if col=='contacted' else 'date' if col=='activity_date' else 'timestamp' if col=='occurred_at' else 'string'
            fields.append(prop(col,kind,col!='territory_code'))
        for layer,dest in [('pipeline',pipeline),('consumption',consumption)]:
            dest.append(object_(name,layer+'_'+name,[dict(p) for p in fields],['snapshot_id']+KEYS[name],GRAINS[name]+' per reporting snapshot'))
    visual=[object_('scenario_scorecard','visualization_scenario_scorecard',[prop('snapshot_id'),prop('as_of','timestamp'),prop('scenario'),prop('scope'),prop('output_rows','integer'),prop('exception_rows','integer'),prop('numerator','integer'),prop('denominator','integer'),prop('threshold','number'),prop('status'),prop('scheduled','boolean')],['snapshot_id','scenario','scope'],'one scenario/scope scorecard per logical checkpoint; ratio counts retained')]
    contracts={
      'source':bundle('source',source,[],'Immutable CSV deliveries, exact manifest fingerprints, public identity evidence and completion markers.'),
      'canonical':bundle('canonical',canonical,['source'],'Typed public-source model with accepted interaction versions, effective intervals, explicit nullable unresolved identity and complete product replacement.'),
      'pipeline':bundle('pipeline',pipeline,['source','canonical'],'S1–S5 business transformations plus exception and DQ evidence. Full snapshot reconciliation gates publication.'),
      'consumption':bundle('consumption',consumption,['pipeline'],'Stable snapshot grains for analyst access. S5 consumption publishes Mondays; other scenario views follow the latest complete daily snapshot.'),
      'visualization':bundle('visualization',visual,['consumption'],'Power BI and Analysis Services TMDL semantic model handoff. Visualization must preserve customer/product/date grain and ratios of summed counts.')}
    contracts['pipeline']['customProperties'].append({'property':'scenarioSemantics','value':{'S1':{'consent':'current at cutoff','matchAlertAbove':0.02,'deadlineUtc':'07:00'},'S2':{'hierarchy':'current at cutoff','unknownProductAlertAbove':0.01,'deadlineUtc':'06:30'},'S3':{'interval':'half open; latest effective assignment wins; equal-date conflict fails'},'S4':{'latest':'highest accepted version','lateArrivalCalendarDays':7,'delete':'tombstone suppresses all downstream scenarios'},'S5':{'window':'campaign start inclusive/end exclusive','matchAlertAbove':0.05,'schedule':'Monday; daily diagnostic calculations'}}})
    contracts['source']['customProperties'].append({'property':'deliverySemantics','value':{'files':'immutable exact keys; SHA256 verified','reference':'initial snapshots plus explicit intervals/events','activity':'daily versioned append; raw invalid fields retained for quarantine','rx':'weekly replacement versions','territory':'monthly plus explicit realignment deliveries','readyMarker':'manifest SHA256; visibility committed only after all gates pass'}})
    contracts['visualization']['version']='0.2.1'
    contracts['visualization']['customProperties'].append({'property':'tmdl','value':{'meaning':'Tabular Model Definition Language for Power BI and Analysis Services','path':'integrations/powerbi/PharmaCommercial.SemanticModel/definition','status':'generated definitions; requires Microsoft TOM parsing, DAX compilation and refresh acceptance','aggregation':'DIVIDE(SUM(numerator), SUM(denominator)) within one snapshot/scenario/scope; never average rates','thresholdUnits':'fraction; 0.02 displays as 2%','defaultView':'latest complete daily snapshots; S5 latest Monday; history requires a single snapshot','localSource':'typed modeled CSV exports','targetSource':'Snowflake published views; Import mode'}})
    for layer,c in contracts.items():write_json(CONTRACT_DIR/(layer+'.odcs.json'),c)
    registry()
    for dialect,folder in [('sqlite','sql/local'),('snowflake','sql/odcs')]:
        dest=ROOT/folder;dest.mkdir(parents=True,exist_ok=True)
        for layer in ['canonical','pipeline','consumption','visualization']:(dest/(layer+'.sql')).write_text(ddl(contracts[layer],dialect))
    return contracts

if __name__=='__main__':build()
