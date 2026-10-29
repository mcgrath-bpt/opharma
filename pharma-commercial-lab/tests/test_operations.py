import copy
import json
import sqlite3
import sys
import tempfile
import unittest
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'src'))
from common import ROOT,read_json,write_json,read_csv,write_csv,sha256,write_results
from odcs import registry,check_evolution,validate_binding,extension
from generate_operations import create
from run_operations import run
from hydrate_operations import hydrate
from reference import load_sources,calculate,rate_status
from validate import reconcile,validate_public
from xlsx_to_csv import convert

class OperationTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.tmp=tempfile.TemporaryDirectory();cls.base=Path(cls.tmp.name);cls.data=cls.base/'fixture';cls.db=cls.base/'model.sqlite'
        cls.config=read_json(ROOT/'config/operations.json');create(cls.config,cls.data)
        cls.report=run(cls.data,cls.db)
    @classmethod
    def tearDownClass(cls):cls.tmp.cleanup()
    def test_five_official_odcs_contracts_and_breaking_schema_gate(self):
        c=registry();self.assertEqual(len(c),5)
        old=c['consumption'];changed=copy.deepcopy(old)
        changed['schema'][0]['properties'][0]['logicalType']='integer'
        with self.assertRaisesRegex(ValueError,'Breaking'):check_evolution(old,changed)
        changed['version']='1.0.0';self.assertTrue(check_evolution(old,changed))
        directory=self.base/'invalid-contracts';directory.mkdir()
        for layer,value in c.items():write_json(directory/(layer+'.odcs.json'),value)
        invalid=copy.deepcopy(c['canonical']);invalid['schema'][0]['unexpected']=True;write_json(directory/'canonical.odcs.json',invalid)
        from jsonschema import ValidationError
        with self.assertRaises(ValidationError):registry(directory)
    def test_all_daily_checkpoints_match_independent_oracle(self):
        self.assertTrue(self.report['passed']);self.assertEqual(len(self.report['checkpoints']),14)
        for row in self.report['checkpoints'].values():self.assertTrue(row['reconciliation']['passed'])
    def test_identical_replay_is_nonadditive_and_rejects_changed_identity(self):
        with sqlite3.connect(self.db) as con:
            before=con.execute('SELECT COUNT(*) FROM raw_veeva_like_activity').fetchone()[0]
        self.assertEqual(hydrate(self.data/'public_s3',self.db,'b003')['status'],'IDENTICAL_REPLAY')
        with sqlite3.connect(self.db) as con:self.assertEqual(con.execute('SELECT COUNT(*) FROM raw_veeva_like_activity').fetchone()[0],before)
        manifest=read_json(next((self.data/'public_s3').rglob('b003.manifest.json')));manifest['contract_sha256']='0'*64
        with self.assertRaisesRegex(ValueError,'bound'):validate_binding(manifest,registry())
    def test_daily_and_monday_consumption_have_distinct_current_snapshots(self):
        with sqlite3.connect(self.db) as con:
            daily=con.execute('SELECT DISTINCT snapshot_id FROM consumption_s04_interaction_current').fetchall()
            weekly=con.execute('SELECT DISTINCT snapshot_id FROM consumption_s05_campaign_current').fetchall()
            published=con.execute('SELECT DISTINCT snapshot_id FROM consumption_s05_campaign ORDER BY snapshot_id').fetchall()
        self.assertEqual(daily,[('b014',)]);self.assertEqual(weekly,[('b012',)]);self.assertEqual(published,[('b005',),('b012',)])
    def test_late_territory_visibility_and_hierarchy_change(self):
        with sqlite3.connect(self.db) as con:
            changed=con.execute("SELECT customer_key,territory_code FROM canonical_customer_territory WHERE assignment_key='OPS-REALIGN' AND snapshot_id='b007'").fetchone()
            old=con.execute("SELECT territory_code FROM pipeline_s03_customer_territory WHERE snapshot_id='b006' AND customer_key=?",(changed[0],)).fetchone()[0]
            current=con.execute("SELECT territory_code FROM pipeline_s03_customer_territory WHERE snapshot_id='b007' AND customer_key=?",(changed[0],)).fetchone()[0]
            brands=con.execute("SELECT DISTINCT brand FROM pipeline_s02_product_activity WHERE snapshot_id='b009'").fetchall()
        self.assertNotEqual(old,current);self.assertEqual(current,changed[1]);self.assertIn(('SYNTH_BRAND_1_OPERATIONS',),brands)
    def test_canonical_model_and_s5_scorecard_scope(self):
        with sqlite3.connect(self.db) as con:
            self.assertEqual(con.execute("SELECT COUNT(*) FROM canonical_customer WHERE snapshot_id='b014'").fetchone()[0],100)
            self.assertEqual(con.execute("SELECT COUNT(*) FROM canonical_organisation WHERE snapshot_id='b014'").fetchone()[0],12)
            self.assertEqual(con.execute("SELECT COUNT(*) FROM canonical_interaction_version WHERE snapshot_id='b014' AND staff_key IS NULL").fetchone()[0],0)
            self.assertEqual(con.execute("SELECT SUM(output_rows) FROM visualization_scenario_scorecard WHERE snapshot_id='b014' AND scenario='S05'").fetchone()[0],con.execute("SELECT COUNT(*) FROM pipeline_s05_campaign WHERE snapshot_id='b014'").fetchone()[0])
    def test_source_key_ambiguity_is_unmatched_in_both_orders(self):
        tables,cut=load_sources(self.data/'public_s3','b002');first,second=tables['veeva_like/customer'][:2]
        conflict=dict(first,match_token=second['match_token']);aid=tables['veeva_like/activity'][0]['activity_key']
        for rows in [[first,conflict],[conflict,first]]:
            t=copy.deepcopy(tables);t['veeva_like/customer']=rows
            self.assertFalse(any(r['activity_key']==aid for r in calculate(t,cut)['s01_engagement']))
    def test_malformed_version_and_timezone_are_quarantined(self):
        tables,cut=load_sources(self.data/'public_s3','b002')
        for field,value in [('source_version','invalid'),('source_version',''),('source_version','+1'),('duration_minutes','1.5'),('occurred_at','2026-10-01T12:00:00')]:
            t=copy.deepcopy(tables);r=dict(t['veeva_like/activity'][0],activity_key='INVALID_TEST');r[field]=value;t['veeva_like/activity'].append(r)
            self.assertIn(dict(scenario='S04',record_key='INVALID_TEST',reason='INVALID_TYPE'),calculate(t,cut)['exceptions'])
    def test_late_identical_activity_redelivery_preserves_outputs_and_diagnostics(self):
        tables,cut=load_sources(self.data/'public_s3','b002');original=calculate(tables,cut)
        resend=dict(tables['veeva_like/activity'][0],_batch_id='b002',_available_at='2026-10-02T05:00:00Z',_mode='incremental')
        tables['veeva_like/activity'].insert(0,resend)
        actual=calculate(tables,cut)
        normal=lambda rows:sorted(tuple(sorted(row.items())) for row in rows)
        for name in original:self.assertEqual(normal(original[name]),normal(actual[name]),name)
    def test_historical_consent_conflicts_fail_regardless_of_order(self):
        tables,cut=load_sources(self.data/'public_s3','b002');rows=tables['salesforce_like/consent']
        original=next(r for r in rows if r['preference_key']=='CONSENT-000003');latest=next(r for r in rows if r['preference_key']=='WITHDRAW-3');conflict=dict(original,preference_key='CONFLICT',status='WITHDRAWN')
        for ordered in [[original,conflict,latest],[latest,original,conflict]]:
            t=copy.deepcopy(tables);t['salesforce_like/consent']=ordered
            with self.assertRaisesRegex(ValueError,'CONFLICTING_CONSENT'):calculate(t,cut)
    def test_active_contract_threshold_drives_alert_status(self):
        tables,cut=load_sources(self.data/'public_s3','b002');semantics=copy.deepcopy(extension(registry()['pipeline'],'scenarioSemantics'));semantics['S1']['matchAlertAbove']=0
        out=calculate(tables,cut,semantics)
        self.assertEqual(next(r for r in out['dq'] if r['scenario']=='S01')['status'],'ALERT')
        self.assertEqual(rate_status(1,40,2.5),'PASS');self.assertEqual(rate_status(1,39,2.5),'ALERT')
    def test_output_extra_cells_fail_reconciliation(self):
        folder=self.base/'malformed-output';out=calculate(*load_sources(self.data/'public_s3','b002'));write_results(folder,out)
        p=folder/'s04_interaction.csv';lines=p.read_text().splitlines();lines[1]+=',extra';p.write_text('\n'.join(lines)+'\n')
        with self.assertRaisesRegex(ValueError,'width'):reconcile(self.data/'private_evaluator/expected/b002',folder)
    def test_workbook_roundtrip_and_reproducibility(self):
        workbook=next((self.data/'public_s3').rglob('*.xlsx'));output=self.base/'adapted.csv';convert(workbook,output)
        original=next((self.data/'public_s3').rglob('territory_mapping/batch=b001/part-00001.csv'))
        self.assertEqual(output.read_bytes(),original.read_bytes())
        from territory_workbook import write_workbook
        recreated=self.base/'recreated.xlsx';write_workbook(recreated,read_csv(original));self.assertEqual(sha256(recreated),sha256(workbook))
    def test_failed_batch_rolls_back_and_repaired_retry_succeeds(self):
        data=self.base/'failure';create(self.config,data);database=self.base/'failure.sqlite';public=data/'public_s3'
        hydrate(public,database,'b001');mp=next(public.rglob('b002.manifest.json'));original_manifest=mp.read_bytes();m=read_json(mp)
        f=next(f for f in m['files'] if f['source_entity']=='iqvia_like/rx_weekly');path=public/f['key'];original_bytes=path.read_bytes();rows=read_csv(path);rows[0]['nrx_count']='9999';write_csv(path,rows,f['columns']);f.update(byte_count=path.stat().st_size,sha256=sha256(path));write_json(mp,m);write_json(mp.with_name('b002.ready.json'),dict(batch_id='b002',manifest_sha256=sha256(mp)))
        with self.assertRaisesRegex(ValueError,'rx_measures'):hydrate(public,database,'b002')
        with sqlite3.connect(database) as con:
            self.assertEqual(con.execute('SELECT COUNT(*) FROM batch_audit').fetchone()[0],1)
            self.assertEqual(con.execute("SELECT COUNT(*) FROM raw_veeva_like_activity WHERE _batch_id='b002'").fetchone()[0],0)
            self.assertEqual(con.execute("SELECT status FROM run_log ORDER BY attempt_id DESC LIMIT 1").fetchone()[0],'FAILED')
        path.write_bytes(original_bytes);mp.write_bytes(original_manifest);write_json(mp.with_name('b002.ready.json'),dict(batch_id='b002',manifest_sha256=sha256(mp)))
        self.assertEqual(hydrate(public,database,'b002')['status'],'PUBLISHED')
    def test_missing_predecessor_is_rejected(self):
        with self.assertRaisesRegex(ValueError,'in order'):hydrate(self.data/'public_s3',self.base/'out-of-order.sqlite','b002')
    def test_snowflake_rendering_covers_every_checkpoint_and_contract_gate(self):
        from render_operations_sql import render_operations
        out=self.base/'snowflake'
        self.assertEqual(render_operations(self.data/'public_s3','DB.INGEST.STAGE','DB.PHARMA_MODEL',out),14)
        self.assertEqual(len(list(out.glob('03_publish_*.sql'))),14)
        gold=(out/'02_gold_b010.sql').read_text();publish=(out/'03_publish_b010.sql').read_text()
        self.assertIn('staff_key,duration_minutes',gold);self.assertIn('TRY_TO_NUMBER(source_version)',gold)
        self.assertIn('semantic type',gold);self.assertIn('"snapshot_id"=',publish)
        self.assertIn('BEGIN TRANSACTION',publish);self.assertIn('uniqueGrain',publish)
        self.assertNotIn('${table}',publish)
    def test_logical_date_selection_and_manifest_source_edition(self):
        from operate_date import select
        self.assertEqual(select(self.data/'public_s3','2026-10-01'),'b001')
        m=read_json(next((self.data/'public_s3').rglob('b001.manifest.json')))
        f=next(f for f in m['files'] if f['source_entity']=='veeva_like/activity')
        self.assertEqual(f['schema_version'],'2.0');self.assertEqual(f['columns'][-1],'staff_key')
        from jsonschema import Draft202012Validator,FormatChecker
        v=Draft202012Validator(read_json(ROOT/'contracts/delivery-manifest.schema.json'),format_checker=FormatChecker())
        for p in (self.data/'public_s3').rglob('*.manifest.json'):v.validate(read_json(p))

    def test_tmdl_semantic_bindings_match_contract_types_and_dax_references(self):
        import re
        from export_powerbi import export as semantic_export, TYPES
        from odcs import registry_fingerprint
        c=registry();out=self.base/'semantic';stats=semantic_export(c,out)
        self.assertEqual(stats['semantic_tables'],7);self.assertEqual(stats['dax_measures'],16)
        plan=read_json(out/'powerbi/visualization-plan.json')
        self.assertEqual(plan['contract_registry_sha256'],registry_fingerprint(c))
        tables={t['table']:t for t in plan['tables']}
        all_measures={m['name'] for t in tables.values() for m in t['measures']}
        for binding in tables.values():
            layer='visualization' if 'Scorecard' in binding['table'] else 'consumption'
            obj=next(o for o in c[layer]['schema'] if binding['source_object'] in (o['physicalName'],o['physicalName']+'_current'))
            text=(out/'powerbi/PharmaCommercial.SemanticModel/definition/tables'/(binding['table']+'.tmdl')).read_text()
            self.assertIn('annotation ODCSRegistrySHA256 = '+registry_fingerprint(c),text)
            self.assertEqual(binding['columns'],[p['name'] for p in obj['properties']])
            for p in obj['properties']:
                self.assertIn("column '"+p['name']+"'\n\t\tdataType: "+TYPES[p['logicalType']],text)
                self.assertIn('\t\tsourceColumn: '+p['name']+'\n\t\tsummarizeBy: none',text)
            for measure in binding['measures']:
                for table,column in re.findall(r"'([^']+)'\[([^]]+)\]",measure['dax']):
                    self.assertIn(column,tables[table]['columns'])
                for ref in re.findall(r'(?<![\w\'])\[([^]]+)\]',measure['dax']):
                    self.assertIn(ref,all_measures)
        for name in ['Scenario Scorecard','Scenario Scorecard History']:
            rate=next(m['dax'] for m in tables[name]['measures'] if m['name'].startswith('Quality Rate'))
            for dimension in ['snapshot_id','scenario','scope']:self.assertIn('HASONEVALUE(\''+name+'\'['+dimension+'])',rate)
            self.assertIn('{"S01", "S02", "S05"}',rate)
            threshold=next(m['dax'] for m in tables[name]['measures'] if m['name'].startswith('Quality Threshold'))
            self.assertNotIn('100',threshold)  # ODCS thresholds are fractions already.
        self.assertFalse((out/'thoughtspot').exists())

    def test_local_tmdl_sources_match_daily_weekly_and_history_publications(self):
        from export_model import export as snapshot_export,export_history
        from export_powerbi import export as semantic_export
        base=self.base/'semantic-csv';c=registry();semantic_export(c,base)
        for snapshot in ['b012','b014']:snapshot_export(self.db,snapshot,base/snapshot)
        export_history(self.db,base/'history')
        plan=read_json(base/'powerbi/visualization-plan.json')
        with sqlite3.connect(self.db) as con:
            for binding in plan['tables']:
                physical=binding['source_object'];history=physical=='visualization_scenario_scorecard'
                folder=base/'history' if history else base/('b012' if binding['table']=='S5 Campaign' else 'b014')
                csv=folder/(physical.removesuffix('_current')+'.csv');rows=read_csv(csv)
                expected=con.execute('SELECT COUNT(*) FROM "'+physical+'"').fetchone()[0]
                self.assertEqual(len(rows),expected,binding['table'])
                self.assertGreater(expected,0,binding['table'])
                self.assertEqual(list(rows[0]),binding['columns'])
                if binding['table']=='S5 Campaign':self.assertEqual({r['snapshot_id'] for r in rows},{'b012'})
                if history:self.assertEqual(len({r['snapshot_id'] for r in rows}),14)
        self.assertEqual(read_json(base/'history/model-export-manifest.json')['contract_version'],'0.2.1')

if __name__=='__main__':unittest.main()
