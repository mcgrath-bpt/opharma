"""ODCS 3.1.0 registry, offline validation, executable schema/quality gates."""
import argparse
import hashlib
import json
import re
from datetime import date, datetime
from pathlib import Path
from common import ROOT, read_json, write_json, sha256

CONTRACT_DIR=ROOT/'contracts/odcs'
LAYERS=('source','canonical','pipeline','consumption','visualization')
SQL_TYPES={'string':'TEXT','integer':'INTEGER','number':'REAL','boolean':'INTEGER','date':'TEXT','timestamp':'TEXT'}
SNOWFLAKE_TYPES={'string':'VARCHAR','integer':'NUMBER(38,0)','number':'NUMBER(18,6)','boolean':'BOOLEAN','date':'DATE','timestamp':'TIMESTAMP_NTZ'}

def identifier(name):
    if not re.fullmatch('[a-z_][a-z0-9_]*',name):raise ValueError('Unsafe contract physical name: '+name)
    return '"'+name+'"'

def extension(contract, name):
    return next(p['value'] for p in contract['customProperties'] if p['property']==name)

def registry(directory=CONTRACT_DIR):
    result={layer:read_json(directory/(layer+'.odcs.json')) for layer in LAYERS}
    schema=read_json(ROOT/'contracts/vendor/odcs-json-schema-v3.1.0.json')
    from jsonschema import Draft202012Validator
    validator=Draft202012Validator(schema)
    for layer,c in result.items():
        validator.validate(c)
        if c['apiVersion']!='v3.1.0' or extension(c,'layer')!=layer:raise ValueError('Contract identity mismatch')
        objects=c['schema']
        if len({o['name'] for o in objects})!=len(objects):raise ValueError('Duplicate schema name')
        for obj in objects:
            identifier(obj['physicalName'])
            if len({p['name'] for p in obj['properties']})!=len(obj['properties']):raise ValueError('Duplicate property')
            for p in obj['properties']:identifier(p['name'])
        lookup={o['name']:o for o in objects}
        for obj in objects:
            expected=relationship_quality(obj,lookup)
            actual={r['name']:r for r in obj.get('quality',[])}
            for rule in expected:
                if actual.get(rule['name'])!=rule:raise ValueError('Relationship quality rule differs from declared ODCS relationship')
    for layer,c in result.items():
        for parent in extension(c,'dependsOn'):
            if parent not in {p['id'] for p in result.values()}:raise ValueError('Unknown dependency')
    return result

def registry_fingerprint(contracts):
    data=json.dumps(contracts,sort_keys=True,separators=(',',':')).encode()
    return hashlib.sha256(data).hexdigest()

def objects(c):return {o['name']:o for o in c['schema']}

def relationship_quality(obj, lookup):
    rules=[]
    for index,rel in enumerate(obj.get('relationships',[]),1):
        left=rel['from'] if isinstance(rel['from'],list) else [rel['from']]
        right=rel['to'] if isinstance(rel['to'],list) else [rel['to']]
        if len(left)!=len(right):raise ValueError('Relationship key widths differ')
        parts=[(a.split('.'),b.split('.')) for a,b in zip(left,right)]
        if any(len(a)!=2 or len(b)!=2 or a[0]!=obj['name'] for a,b in parts):raise ValueError('Use local object.property relationship references')
        parents={b[0] for a,b in parts}
        if len(parents)!=1:raise ValueError('Relationship spans multiple parent objects')
        parent=lookup[next(iter(parents))]
        child_cols={p['name']:p for p in obj['properties']};parent_cols={p['name']:p for p in parent['properties']}
        target_names={b[1] for a,b in parts}
        if target_names!={p['name'] for p in parent['properties'] if p.get('primaryKey')}:raise ValueError('Reference must cover the complete parent key')
        for a,b in parts:
            if child_cols[a[1]]['logicalType']!=parent_cols[b[1]]['logicalType']:raise ValueError('Relationship key types differ')
        join=' AND '.join('c.'+identifier(a[1])+'=p.'+identifier(b[1]) for a,b in parts)
        present=' AND '.join('c.'+identifier(a[1])+' IS NOT NULL' for a,b in parts)
        query='SELECT COUNT(*) FROM ${table} c LEFT JOIN '+identifier(parent['physicalName'])+' p ON '+join+' WHERE c."snapshot_id"=? AND '+present+' AND p.'+identifier(parts[0][1][1])+' IS NULL'
        rules.append({'name':'foreignKey'+str(index),'type':'sql','dimension':'consistency','severity':'error','query':query,'mustBe':0})
    return rules

def cast(value, prop):
    if value is None or value=='':
        if prop.get('required'):raise ValueError('Required value absent: '+prop['name'])
        return None
    kind=prop['logicalType']
    if kind=='integer':
        if isinstance(value,bool) or not re.fullmatch(r'-?[0-9]+',str(value)):raise ValueError('Invalid integer: '+prop['name'])
        return int(value)
    if kind=='number':return float(value)
    if kind=='boolean':
        if value not in (True,False,0,1,'true','false'):raise ValueError('Invalid boolean: '+prop['name'])
        return int(value in (True,1,'true'))
    if kind=='date':date.fromisoformat(str(value));return str(value)
    if kind=='timestamp':
        dt=datetime.fromisoformat(str(value).replace('Z','+00:00'))
        if dt.tzinfo is None or dt.utcoffset().total_seconds()!=0:raise ValueError('UTC timestamp required')
    return str(value)

def ddl(contract, dialect='sqlite'):
    types=SQL_TYPES if dialect=='sqlite' else SNOWFLAKE_TYPES
    statements=[]
    for obj in contract['schema']:
        columns=[identifier(p['name'])+' '+types[p['logicalType']]+(' NOT NULL' if p.get('required') else '') for p in obj['properties']]
        pk=sorted((p for p in obj['properties'] if p.get('primaryKey')),key=lambda p:p['primaryKeyPosition'])
        if pk:columns.append('PRIMARY KEY ('+','.join(identifier(p['name']) for p in pk)+')')
        statements.append('CREATE TABLE IF NOT EXISTS '+identifier(obj['physicalName'])+' (\n  '+',\n  '.join(columns)+'\n);')
    return '\n\n'.join(statements)+'\n'

def insert_rows(connection, obj, rows):
    columns=[p['name'] for p in obj['properties']]
    values=[]
    for row in rows:
        if set(row)!=set(columns):raise ValueError('Row columns differ: '+obj['name'])
        values.append(tuple(cast(row[p['name']],p) for p in obj['properties']))
    connection.executemany('INSERT INTO '+identifier(obj['physicalName'])+' ('+','.join(map(identifier,columns))+') VALUES ('+','.join('?' for _ in columns)+')',values)

def quality(connection, contract, snapshot):
    evidence=[]
    for obj in contract['schema']:
        for rule in obj.get('quality',[]):
            if rule['type']!='sql':continue
            query=rule['query'].replace('${table}',identifier(obj['physicalName']))
            value=connection.execute(query,(snapshot,)).fetchone()[0]
            passed=value==rule['mustBe']
            evidence.append({'contract_id':contract['id'],'object':obj['name'],'rule':rule['name'],'value':value,'passed':passed})
            if not passed:raise ValueError('Contract quality failed: '+obj['name']+'/'+rule['name'])
    return evidence

def check_evolution(old,new):
    """Conservative compatibility gate; breaking changes require a new major version."""
    breaking=[]
    old_objects=objects(old);new_objects=objects(new)
    for name,obj in old_objects.items():
        if name not in new_objects:breaking.append('removed object '+name);continue
        candidate=new_objects[name]
        if candidate['physicalName']!=obj['physicalName']:breaking.append('renamed physical object '+name)
        if candidate.get('relationships')!=obj.get('relationships'):breaking.append('changed relationships '+name)
        cols={p['name']:p for p in candidate['properties']}
        for p in obj['properties']:
            n=cols.get(p['name'])
            if n is None:breaking.append('removed '+name+'.'+p['name']);continue
            for key in ('logicalType','primaryKey','primaryKeyPosition'):
                if n.get(key)!=p.get(key):breaking.append('changed '+key+' '+name+'.'+p['name'])
            if n.get('required') and not p.get('required'):breaking.append('tightened nullability '+name+'.'+p['name'])
        old_names={p['name'] for p in obj['properties']}
        breaking.extend('added required '+name+'.'+p['name'] for p in candidate['properties'] if p['name'] not in old_names and p.get('required'))
    if breaking and int(new['version'].split('.')[0])<=int(old['version'].split('.')[0]):raise ValueError('Breaking contract change without major version: '+ '; '.join(breaking))
    return breaking

def validate_binding(manifest, contracts):
    source=contracts['source']
    if (manifest.get('contract_id'),manifest.get('contract_version'),manifest.get('contract_sha256'))!=(source['id'],source['version'],sha256(CONTRACT_DIR/'source.odcs.json')):
        raise ValueError('Manifest is not bound to the active source ODCS contract')
    for file in manifest['files']:
        obj=objects(source).get(file['source_entity'])
        if obj is None or file['columns']!=[p['name'] for p in obj['properties']]:raise ValueError('ODCS source schema mismatch')
        schema_version=next(p['value'] for p in obj['customProperties'] if p['property']=='sourceSchemaVersion')
        if file['schema_version']!=schema_version:raise ValueError('ODCS source schema version differs')

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--old',type=Path);p.add_argument('--new',type=Path);a=p.parse_args()
    if a.old and a.new:print(check_evolution(read_json(a.old),read_json(a.new)))
    else:
        c=registry();print(json.dumps({'odcs':'3.1.0','contracts':len(c),'objects':{k:len(v['schema']) for k,v in c.items()},'sha256':registry_fingerprint(c)},indent=2))
