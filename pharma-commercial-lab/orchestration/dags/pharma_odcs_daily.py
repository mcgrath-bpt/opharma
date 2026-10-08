"""Airflow 2.10+ DAG: source-only daily operations, serialized catchup and retries.

Deploy the project and requirements-dev.txt on each worker. Fixture generation
is a separate producer operation. PHARMA_PROJECT_ROOT selects that deployment.
"""
import os
import subprocess
from datetime import datetime,timedelta,timezone
from pathlib import Path
from airflow import DAG
from airflow.operators.python import PythonOperator

PROJECT=Path(os.environ.get('PHARMA_PROJECT_ROOT',Path(__file__).resolve().parents[2]))

def validate_contracts():
    import sys
    subprocess.run([sys.executable,str(PROJECT/'src/odcs.py')],cwd=PROJECT,check=True)

def operate(data_interval_end, **context):
    import sys
    command=[sys.executable,str(PROJECT/'src/operate_date.py'),'--date',data_interval_end.date().isoformat(),'--public-root',os.environ.get('PHARMA_PUBLIC_ROOT',str(PROJECT/'data/operations-release/public_s3')),'--db',os.environ.get('PHARMA_LOCAL_DB',str(PROJECT/'data/operations/model-v02.sqlite'))]
    engine=os.environ.get('PHARMA_ENGINE','local')
    if engine not in ('local','snowflake'):raise ValueError('PHARMA_ENGINE must be local or snowflake')
    if engine=='snowflake':
        command+=['--engine','snowflake','--connection',os.environ['PHARMA_SNOWFLAKE_CONNECTION'],'--stage',os.environ['PHARMA_STAGE'],'--schema',os.environ['PHARMA_SCHEMA'],'--out',os.environ['PHARMA_CLOUD_EVIDENCE']]
    subprocess.run(command,cwd=PROJECT,check=True)

# Cron data_interval_end is the publication date. Start one day before b001 so
# the first scheduled interval ends on 1 October, rather than skipping b001.
with DAG('pharma_odcs_daily',start_date=datetime(2026,9,30,tzinfo=timezone.utc),schedule='0 6 * * *',catchup=True,max_active_runs=1,default_args={'retries':2,'retry_delay':timedelta(minutes=5)},tags=['pharma','odcs','S1-S5']) as dag:
    contracts=PythonOperator(task_id='validate_odcs_contracts',python_callable=validate_contracts)
    hydrate=PythonOperator(task_id='hydrate_quality_and_publish',python_callable=operate)
    contracts >> hydrate
