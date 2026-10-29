"""Generate contract-bound TMDL definitions; no Power BI or Analysis Services calls."""
import json
from common import write_json
from odcs import registry_fingerprint

TYPES = {'string':'string', 'integer':'int64', 'number':'double',
         'boolean':'boolean', 'date':'dateTime', 'timestamp':'dateTime'}
M_TYPES = {'string':'type text', 'integer':'Int64.Type', 'number':'type number',
           'boolean':'type logical', 'date':'type date', 'timestamp':'type datetime'}
SOURCES = [
    'https://learn.microsoft.com/en-us/analysis-services/tmdl/tmdl-overview',
    'https://learn.microsoft.com/en-us/power-bi/developer/projects/projects-dataset',
    'https://learn.microsoft.com/en-us/power-query/connectors/snowflake']

def quote(name):
    return "'" + name.replace("'", "''") + "'"

def measures(name):
    table = quote(name)
    if name == 'S1 Engagement':
        return [('Engagement Activities', f'DISTINCTCOUNT({table}[activity_key])', '#,0')]
    if name == 'S2 Product Activity':
        return [('Product Interactions', f'SUM({table}[interaction_count])', '#,0')]
    if name == 'S3 Customer Territory':
        return [('Territory Customers', f'DISTINCTCOUNT({table}[customer_key])', '#,0')]
    if name == 'S4 Interaction':
        return [('Latest Interactions', f'DISTINCTCOUNT({table}[activity_key])', '#,0')]
    if name == 'S5 Campaign':
        return [('Campaign Member Product Pairs', f'COUNTROWS({table})', '#,0'),
                ('Contacted Campaign Pairs', f'CALCULATE(COUNTROWS({table}), {table}[contacted] = TRUE())', '#,0'),
                ('Campaign Reach', 'DIVIDE([Contacted Campaign Pairs], [Campaign Member Product Pairs])', '0.00%'),
                ('Qualifying Campaign Interactions', f'SUM({table}[qualifying_interactions])', '#,0')]
    # Both current and history require a single logical snapshot/scenario/scope.
    # This also prevents summing repeated snapshots or mixing unrelated denominators.
    guard = f'HASONEVALUE({table}[snapshot_id]) && HASONEVALUE({table}[scenario]) && HASONEVALUE({table}[scope])'
    rate_guard = guard + f' && SELECTEDVALUE({table}[scenario]) IN {{"S01", "S02", "S05"}}'
    suffix = ' History' if name.endswith('History') else ''
    return [(label+suffix, f'IF({guard}, SUM({table}[{column}]))', '#,0')
            for label,column in [('Output Rows','output_rows'), ('Exception Rows','exception_rows')]] + [
        ('Quality Rate'+suffix, f'IF({rate_guard}, DIVIDE(SUM({table}[numerator]), SUM({table}[denominator])))', '0.00%'),
        # Contract thresholds are fractions (0.02 means 2%), as are DAX percentages.
        ('Quality Threshold'+suffix, f'IF({rate_guard}, SELECTEDVALUE({table}[threshold]))', '0.00%')]

def table_text(name, obj, physical, contract, digest, csv_path):
    lines = [f'table {quote(name)}', f'\tannotation ODCSContractId = {contract["id"]}',
             f'\tannotation ODCSContractVersion = {contract["version"]}',
             f'\tannotation ODCSRegistrySHA256 = {digest}',
             f'\tannotation ODCSGrain = {obj["dataGranularityDescription"]}',
             f'\tannotation ODCSSourceObject = {physical}']
    for p in obj['properties']:
        lines += ['', f'\tcolumn {quote(p["name"])}',
                  f'\t\tdataType: {TYPES[p["logicalType"]]}',
                  f'\t\tsourceColumn: {p["name"]}', '\t\tsummarizeBy: none']
        if p['logicalType'] in ('date','timestamp'):
            lines += ['\t\tformatString: ' + ('yyyy-MM-dd' if p['logicalType']=='date' else 'yyyy-MM-dd HH:mm:ss')]
    for label,formula,format_ in measures(name):
        lines += ['', f'\tmeasure {quote(label)} = {formula}', f'\t\tformatString: {format_}', '\t\tdisplayFolder: Scenario Measures']
    names = ', '.join(json.dumps(p['name']) for p in obj['properties'])
    transforms = []
    for p in obj['properties']:
        # CSV nulls are empty text. Dates/timestamps retain UTC wall clock in TOM DateTime.
        kind = p['logicalType']
        conversion = {'string':'Text.From(v)', 'integer':'Int64.From(v)',
                      'number':'Number.From(v, "en-US")',
                      'boolean':'if Value.Is(v, type logical) then v else Logical.FromText(v)',
                      'date':'Date.From(v)',
                      'timestamp':'if Value.Is(v, type text) then DateTimeZone.RemoveZone(DateTimeZone.ToUtc(DateTimeZone.FromText(v))) else DateTime.From(v)'}[kind]
        transforms.append('{'+json.dumps(p['name'])+', each if _ = null or _ = "" then null else let v = _ in '+conversion+', '+M_TYPES[kind]+'}')
    query = [
        'let',
        '    Raw = if DataSourceMode = "CSV" then',
        f'        Table.PromoteHeaders(Csv.Document(File.Contents({csv_path}), [Delimiter=",", Encoding=65001, QuoteStyle=QuoteStyle.Csv]), [PromoteAllScalars=true])',
        '    else if DataSourceMode = "Snowflake" then',
        '        let',
        '            Connection = Snowflake.Databases(SnowflakeServer, SnowflakeWarehouse, [Implementation="2.0"]),',
        '            Database = Connection{[Name=SnowflakeDatabase, Kind="Database"]}[Data],',
        '            Schema = Database{[Name=SnowflakeSchema, Kind="Schema"]}[Data]',
        f'        in Schema{{[Name="{physical}", Kind="View" if Text.EndsWith("{physical}", "_current") else "Table"]}}[Data]',
        '    else error "DataSourceMode must be CSV or Snowflake",',
        f'    Selected = Table.SelectColumns(Raw, {{{names}}}, MissingField.Error),',
        '    Typed = Table.TransformColumns(Selected, {'+', '.join(transforms)+'})',
        'in', '    Typed']
    lines += ['', f'\tpartition {quote(name)} = m', '\t\tmode: import', '\t\tsource =']
    lines += ['\t\t\t'+line for line in query]
    return '\n'.join(lines)+'\n'

def export(contracts, root):
    digest = registry_fingerprint(contracts)
    folder = root/'powerbi/PharmaCommercial.SemanticModel'
    definition = folder/'definition'
    (definition/'tables').mkdir(parents=True, exist_ok=True)
    write_json(folder/'definition.pbism', {'version':'4.0', 'settings':{'qnaEnabled':False}})
    (definition/'database.tmdl').write_text('database PharmaCommercial\n\tcompatibilityLevel: 1600\n')
    model = ['model Model', '\tculture: en-US', '\tdefaultPowerBIDataSourceVersion: powerBI_V3',
             '\tdiscourageImplicitMeasures', f'\tannotation ODCSRegistrySHA256 = {digest}']
    parameters = {
        'DataSourceMode':'CSV', 'DailyCsvFolder':'CONFIGURE_ABSOLUTE_PATH/model_export/b014',
        'WeeklyCsvFolder':'CONFIGURE_ABSOLUTE_PATH/model_export/b012',
        'HistoryCsvFile':'CONFIGURE_ABSOLUTE_PATH/model_export/history/visualization_scenario_scorecard.csv',
        'SnowflakeServer':'CONFIGURE_ACCOUNT.snowflakecomputing.com',
        'SnowflakeWarehouse':'CONFIGURE_WAREHOUSE', 'SnowflakeDatabase':'PHARMA_LAB',
        'SnowflakeSchema':'PHARMA_MODEL'}
    (definition/'expressions.tmdl').write_text('\n\n'.join(
        f'expression {k} = {json.dumps(v)} meta [IsParameterQuery=true, Type="Text", IsParameterQueryRequired=true]'
        for k,v in parameters.items())+'\n')
    labels = ['S1 Engagement','S2 Product Activity','S3 Customer Territory','S4 Interaction','S5 Campaign']
    datasets = [(label,obj,obj['physicalName']+'_current',contracts['consumption'],
                 ('WeeklyCsvFolder' if label.startswith('S5') else 'DailyCsvFolder')+' & "/'+obj['physicalName']+'.csv"')
                for label,obj in zip(labels,[o for o in contracts['consumption']['schema'] if o['name'].startswith('s0')])]
    obj = contracts['visualization']['schema'][0]
    datasets += [('Scenario Scorecard',obj,obj['physicalName']+'_current',contracts['visualization'],
                  'DailyCsvFolder & "/'+obj['physicalName']+'.csv"'),
                 ('Scenario Scorecard History',obj,obj['physicalName'],contracts['visualization'],'HistoryCsvFile')]
    bindings = []
    for name,obj,physical,contract,csv_path in datasets:
        model += [f'\tref table {quote(name)}']
        (definition/'tables'/(name+'.tmdl')).write_text(table_text(name,obj,physical,contract,digest,csv_path))
        bindings.append(dict(table=name,source_object=physical,contract_id=contract['id'],
                             contract_version=contract['version'],columns=[p['name'] for p in obj['properties']],
                             grain=obj['dataGranularityDescription'],measures=[dict(name=n,dax=d,format=f) for n,d,f in measures(name)]))
    (definition/'model.tmdl').write_text('\n'.join(model)+'\n')
    write_json(root/'powerbi/visualization-plan.json', dict(
        language='Tabular Model Definition Language (TMDL)', contract_id=contracts['visualization']['id'],
        contract_registry_sha256=digest, model_path='PharmaCommercial.SemanticModel/definition',
        import_status='NOT_IMPORTED', local_validation='STATIC_CONTRACT_BINDINGS_ONLY',
        sources=SOURCES, parameters=parameters, tables=bindings,
        relationships='Independent scenario fact tables; no cross-fact joins or automatic relationship detection.',
        refresh='Import mode: refresh after a complete daily publication; S5 reads latest Monday publication.',
        acceptance=['DeserializeDatabaseFromFolder with Microsoft TOM; compile DAX and refresh in Power BI Desktop or Analysis Services.',
                    'Compare imported row counts and measures against the snapshot exports; validate blank diagnostic rates and threshold units.',
                    'Bind Snowflake credentials outside source control; accept workspace access and Power BI RLS for imported data.',
                    'Published reports and service refresh schedules are separate deployment assets.']))
    return {'tmdl_files':len(list(definition.rglob('*.tmdl'))), 'semantic_tables':len(datasets),
            'dax_measures':sum(len(measures(name)) for name,*_ in datasets)}
