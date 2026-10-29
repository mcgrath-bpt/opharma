-- Execute with a client configured to STOP on the first SQL error.

-- Single loader only. Stage must expose the public_s3 tree at its URL root.

CREATE SCHEMA IF NOT EXISTS PHARMA_LAB.PHARMA_MODEL;

USE SCHEMA PHARMA_LAB.PHARMA_MODEL;

ALTER SESSION SET TIMEZONE = 'UTC';

CREATE FILE FORMAT IF NOT EXISTS LAB_CSV_V1 TYPE=CSV COMPRESSION=NONE FIELD_DELIMITER=',' RECORD_DELIMITER='\n' SKIP_HEADER=1 FIELD_OPTIONALLY_ENCLOSED_BY='"' ESCAPE_UNENCLOSED_FIELD=NONE EMPTY_FIELD_AS_NULL=TRUE NULL_IF=('') ERROR_ON_COLUMN_COUNT_MISMATCH=TRUE ENCODING='UTF8';

CREATE TABLE IF NOT EXISTS LAB_BATCH_AUDIT (batch_id VARCHAR, manifest_sha256 VARCHAR, available_at TIMESTAMP_NTZ, loaded_at TIMESTAMP_LTZ, status VARCHAR);

CREATE TABLE IF NOT EXISTS LAB_FILE_AUDIT (batch_id VARCHAR, file_key VARCHAR, expected_sha256 VARCHAR, expected_rows NUMBER, manifest_sha256 VARCHAR);

EXECUTE IMMEDIATE $$ DECLARE bad_release EXCEPTION (-20001, 'Batch ID already bound to different manifest'); n NUMBER; BEGIN SELECT COUNT(*) INTO :n FROM LAB_BATCH_AUDIT WHERE batch_id='b005' AND manifest_sha256<>'ee8fd8af07bfe583dfb6febcfdc3412b05dfe702e71023b9f1c27d801f844786'; IF (n>0) THEN RAISE bad_release; END IF; END; $$;

CREATE TABLE IF NOT EXISTS RAW_B005_IQVIA_LIKE_PRODUCT (PRODUCT_CODE VARCHAR, BRAND VARCHAR, THERAPY VARCHAR, VALID_FROM VARCHAR, VALID_TO VARCHAR, ACTIVE VARCHAR);

COPY INTO RAW_B005_IQVIA_LIKE_PRODUCT FROM @PHARMA_LAB.INGEST.EXISTING_STAGE FILES=('synthetic/pharma/pharma-lab-0.2.0/sources/iqvia_like/product/batch=b005/part-00001.csv') FILE_FORMAT=(FORMAT_NAME='PHARMA_LAB.PHARMA_MODEL.LAB_CSV_V1') ON_ERROR='ABORT_STATEMENT' FORCE=FALSE;

EXECUTE IMMEDIATE $$ DECLARE bad_count EXCEPTION (-20002, 'Loaded row count differs from manifest: RAW_B005_IQVIA_LIKE_PRODUCT'); n NUMBER; BEGIN SELECT COUNT(*) INTO :n FROM RAW_B005_IQVIA_LIKE_PRODUCT; IF (n<>1) THEN RAISE bad_count; END IF; END; $$;

CREATE TABLE IF NOT EXISTS RAW_B005_IQVIA_LIKE_RX_WEEKLY (OBSERVATION_KEY VARCHAR, PROVIDER_KEY VARCHAR, PRODUCT_CODE VARCHAR, WEEK_ENDING VARCHAR, TRX_COUNT VARCHAR, NRX_COUNT VARCHAR, SALES_UNITS VARCHAR, VERSION_NO VARCHAR);

COPY INTO RAW_B005_IQVIA_LIKE_RX_WEEKLY FROM @PHARMA_LAB.INGEST.EXISTING_STAGE FILES=('synthetic/pharma/pharma-lab-0.2.0/sources/iqvia_like/rx_weekly/batch=b005/part-00001.csv') FILE_FORMAT=(FORMAT_NAME='PHARMA_LAB.PHARMA_MODEL.LAB_CSV_V1') ON_ERROR='ABORT_STATEMENT' FORCE=FALSE;

EXECUTE IMMEDIATE $$ DECLARE bad_count EXCEPTION (-20002, 'Loaded row count differs from manifest: RAW_B005_IQVIA_LIKE_RX_WEEKLY'); n NUMBER; BEGIN SELECT COUNT(*) INTO :n FROM RAW_B005_IQVIA_LIKE_RX_WEEKLY; IF (n<>1) THEN RAISE bad_count; END IF; END; $$;

CREATE TABLE IF NOT EXISTS RAW_B005_VEEVA_LIKE_ACTIVITY (ACTIVITY_KEY VARCHAR, CUSTOMER_KEY VARCHAR, PRIMARY_PRODUCT_CODE VARCHAR, OCCURRED_AT VARCHAR, CHANNEL VARCHAR, APPROVAL VARCHAR, DURATION_MINUTES VARCHAR, SOURCE_VERSION VARCHAR, MODIFIED_AT VARCHAR, OPERATION VARCHAR, STAFF_KEY VARCHAR);

COPY INTO RAW_B005_VEEVA_LIKE_ACTIVITY FROM @PHARMA_LAB.INGEST.EXISTING_STAGE FILES=('synthetic/pharma/pharma-lab-0.2.0/sources/veeva_like/activity/batch=b005/part-00001.csv') FILE_FORMAT=(FORMAT_NAME='PHARMA_LAB.PHARMA_MODEL.LAB_CSV_V1') ON_ERROR='ABORT_STATEMENT' FORCE=FALSE;

EXECUTE IMMEDIATE $$ DECLARE bad_count EXCEPTION (-20002, 'Loaded row count differs from manifest: RAW_B005_VEEVA_LIKE_ACTIVITY'); n NUMBER; BEGIN SELECT COUNT(*) INTO :n FROM RAW_B005_VEEVA_LIKE_ACTIVITY; IF (n<>25) THEN RAISE bad_count; END IF; END; $$;

CREATE TABLE IF NOT EXISTS RAW_B005_VEEVA_LIKE_ACTIVITY_PRODUCT (ACTIVITY_KEY VARCHAR, SOURCE_VERSION VARCHAR, PRODUCT_CODE VARCHAR, DETAIL_RANK VARCHAR);

COPY INTO RAW_B005_VEEVA_LIKE_ACTIVITY_PRODUCT FROM @PHARMA_LAB.INGEST.EXISTING_STAGE FILES=('synthetic/pharma/pharma-lab-0.2.0/sources/veeva_like/activity_product/batch=b005/part-00001.csv') FILE_FORMAT=(FORMAT_NAME='PHARMA_LAB.PHARMA_MODEL.LAB_CSV_V1') ON_ERROR='ABORT_STATEMENT' FORCE=FALSE;

EXECUTE IMMEDIATE $$ DECLARE bad_count EXCEPTION (-20002, 'Loaded row count differs from manifest: RAW_B005_VEEVA_LIKE_ACTIVITY_PRODUCT'); n NUMBER; BEGIN SELECT COUNT(*) INTO :n FROM RAW_B005_VEEVA_LIKE_ACTIVITY_PRODUCT; IF (n<>25) THEN RAISE bad_count; END IF; END; $$;

BEGIN TRANSACTION;

INSERT INTO LAB_FILE_AUDIT SELECT 'b005','synthetic/pharma/pharma-lab-0.2.0/sources/iqvia_like/product/batch=b005/part-00001.csv','c624b48fcb2173d052aea4370de2c7feaac22a9789a58c4f22ef25f104883c8f',1,'ee8fd8af07bfe583dfb6febcfdc3412b05dfe702e71023b9f1c27d801f844786' WHERE NOT EXISTS (SELECT 1 FROM LAB_FILE_AUDIT WHERE batch_id='b005' AND file_key='synthetic/pharma/pharma-lab-0.2.0/sources/iqvia_like/product/batch=b005/part-00001.csv');

INSERT INTO LAB_FILE_AUDIT SELECT 'b005','synthetic/pharma/pharma-lab-0.2.0/sources/iqvia_like/rx_weekly/batch=b005/part-00001.csv','54489d20fe21ee211cb7f26a0e0d3905cba217773d192de7e292aed5a5e89dbd',1,'ee8fd8af07bfe583dfb6febcfdc3412b05dfe702e71023b9f1c27d801f844786' WHERE NOT EXISTS (SELECT 1 FROM LAB_FILE_AUDIT WHERE batch_id='b005' AND file_key='synthetic/pharma/pharma-lab-0.2.0/sources/iqvia_like/rx_weekly/batch=b005/part-00001.csv');

INSERT INTO LAB_FILE_AUDIT SELECT 'b005','synthetic/pharma/pharma-lab-0.2.0/sources/veeva_like/activity/batch=b005/part-00001.csv','095d83a40b369f422d886f7c3f14612973f94eb67cb7e264e9df1bb3a8b49c2b',25,'ee8fd8af07bfe583dfb6febcfdc3412b05dfe702e71023b9f1c27d801f844786' WHERE NOT EXISTS (SELECT 1 FROM LAB_FILE_AUDIT WHERE batch_id='b005' AND file_key='synthetic/pharma/pharma-lab-0.2.0/sources/veeva_like/activity/batch=b005/part-00001.csv');

INSERT INTO LAB_FILE_AUDIT SELECT 'b005','synthetic/pharma/pharma-lab-0.2.0/sources/veeva_like/activity_product/batch=b005/part-00001.csv','8ffc445233d1af19ee7706ea2fefa5c5a941eed5d6e29f4662522d16e337ddd2',25,'ee8fd8af07bfe583dfb6febcfdc3412b05dfe702e71023b9f1c27d801f844786' WHERE NOT EXISTS (SELECT 1 FROM LAB_FILE_AUDIT WHERE batch_id='b005' AND file_key='synthetic/pharma/pharma-lab-0.2.0/sources/veeva_like/activity_product/batch=b005/part-00001.csv');

INSERT INTO LAB_BATCH_AUDIT SELECT 'b005','ee8fd8af07bfe583dfb6febcfdc3412b05dfe702e71023b9f1c27d801f844786',TO_TIMESTAMP_NTZ('2026-10-05T05:00:00Z'),CURRENT_TIMESTAMP(),'LOADED' WHERE NOT EXISTS (SELECT 1 FROM LAB_BATCH_AUDIT WHERE batch_id='b005');

COMMIT;

CREATE OR REPLACE VIEW SRC_IQVIA_LIKE_AFFILIATION AS
SELECT r.*, 'b001' AS _batch_id, TO_TIMESTAMP_NTZ('2026-10-01T05:00:00Z') AS _available_at, 'bootstrap' AS _mode, 'synthetic/pharma/pharma-lab-0.2.0/sources/iqvia_like/affiliation/batch=b001/part-00001.csv' AS _file_key FROM RAW_B001_IQVIA_LIKE_AFFILIATION r WHERE EXISTS (SELECT 1 FROM LAB_BATCH_AUDIT a WHERE a.batch_id='b001' AND a.status='LOADED');

CREATE OR REPLACE VIEW SRC_IQVIA_LIKE_ORGANISATION AS
SELECT r.*, 'b001' AS _batch_id, TO_TIMESTAMP_NTZ('2026-10-01T05:00:00Z') AS _available_at, 'bootstrap' AS _mode, 'synthetic/pharma/pharma-lab-0.2.0/sources/iqvia_like/organisation/batch=b001/part-00001.csv' AS _file_key FROM RAW_B001_IQVIA_LIKE_ORGANISATION r WHERE EXISTS (SELECT 1 FROM LAB_BATCH_AUDIT a WHERE a.batch_id='b001' AND a.status='LOADED');

CREATE OR REPLACE VIEW SRC_IQVIA_LIKE_PRODUCT AS
SELECT r.*, 'b001' AS _batch_id, TO_TIMESTAMP_NTZ('2026-10-01T05:00:00Z') AS _available_at, 'bootstrap' AS _mode, 'synthetic/pharma/pharma-lab-0.2.0/sources/iqvia_like/product/batch=b001/part-00001.csv' AS _file_key FROM RAW_B001_IQVIA_LIKE_PRODUCT r WHERE EXISTS (SELECT 1 FROM LAB_BATCH_AUDIT a WHERE a.batch_id='b001' AND a.status='LOADED')
UNION ALL
SELECT r.*, 'b005' AS _batch_id, TO_TIMESTAMP_NTZ('2026-10-05T05:00:00Z') AS _available_at, 'incremental' AS _mode, 'synthetic/pharma/pharma-lab-0.2.0/sources/iqvia_like/product/batch=b005/part-00001.csv' AS _file_key FROM RAW_B005_IQVIA_LIKE_PRODUCT r WHERE EXISTS (SELECT 1 FROM LAB_BATCH_AUDIT a WHERE a.batch_id='b005' AND a.status='LOADED');

CREATE OR REPLACE VIEW SRC_IQVIA_LIKE_PROVIDER AS
SELECT r.*, 'b001' AS _batch_id, TO_TIMESTAMP_NTZ('2026-10-01T05:00:00Z') AS _available_at, 'bootstrap' AS _mode, 'synthetic/pharma/pharma-lab-0.2.0/sources/iqvia_like/provider/batch=b001/part-00001.csv' AS _file_key FROM RAW_B001_IQVIA_LIKE_PROVIDER r WHERE EXISTS (SELECT 1 FROM LAB_BATCH_AUDIT a WHERE a.batch_id='b001' AND a.status='LOADED');

CREATE OR REPLACE VIEW SRC_IQVIA_LIKE_RX_WEEKLY AS
SELECT r.*, 'b001' AS _batch_id, TO_TIMESTAMP_NTZ('2026-10-01T05:00:00Z') AS _available_at, 'bootstrap' AS _mode, 'synthetic/pharma/pharma-lab-0.2.0/sources/iqvia_like/rx_weekly/batch=b001/part-00001.csv' AS _file_key FROM RAW_B001_IQVIA_LIKE_RX_WEEKLY r WHERE EXISTS (SELECT 1 FROM LAB_BATCH_AUDIT a WHERE a.batch_id='b001' AND a.status='LOADED')
UNION ALL
SELECT r.*, 'b002' AS _batch_id, TO_TIMESTAMP_NTZ('2026-10-02T05:00:00Z') AS _available_at, 'incremental' AS _mode, 'synthetic/pharma/pharma-lab-0.2.0/sources/iqvia_like/rx_weekly/batch=b002/part-00001.csv' AS _file_key FROM RAW_B002_IQVIA_LIKE_RX_WEEKLY r WHERE EXISTS (SELECT 1 FROM LAB_BATCH_AUDIT a WHERE a.batch_id='b002' AND a.status='LOADED')
UNION ALL
SELECT r.*, 'b005' AS _batch_id, TO_TIMESTAMP_NTZ('2026-10-05T05:00:00Z') AS _available_at, 'incremental' AS _mode, 'synthetic/pharma/pharma-lab-0.2.0/sources/iqvia_like/rx_weekly/batch=b005/part-00001.csv' AS _file_key FROM RAW_B005_IQVIA_LIKE_RX_WEEKLY r WHERE EXISTS (SELECT 1 FROM LAB_BATCH_AUDIT a WHERE a.batch_id='b005' AND a.status='LOADED');

CREATE OR REPLACE VIEW SRC_MANUAL_TERRITORY_MAPPING AS
SELECT r.*, 'b001' AS _batch_id, TO_TIMESTAMP_NTZ('2026-10-01T05:00:00Z') AS _available_at, 'bootstrap' AS _mode, 'synthetic/pharma/pharma-lab-0.2.0/sources/manual/territory_mapping/batch=b001/part-00001.csv' AS _file_key FROM RAW_B001_MANUAL_TERRITORY_MAPPING r WHERE EXISTS (SELECT 1 FROM LAB_BATCH_AUDIT a WHERE a.batch_id='b001' AND a.status='LOADED');

CREATE OR REPLACE VIEW SRC_SALESFORCE_LIKE_CAMPAIGN AS
SELECT r.*, 'b001' AS _batch_id, TO_TIMESTAMP_NTZ('2026-10-01T05:00:00Z') AS _available_at, 'bootstrap' AS _mode, 'synthetic/pharma/pharma-lab-0.2.0/sources/salesforce_like/campaign/batch=b001/part-00001.csv' AS _file_key FROM RAW_B001_SALESFORCE_LIKE_CAMPAIGN r WHERE EXISTS (SELECT 1 FROM LAB_BATCH_AUDIT a WHERE a.batch_id='b001' AND a.status='LOADED');

CREATE OR REPLACE VIEW SRC_SALESFORCE_LIKE_CAMPAIGN_MEMBER AS
SELECT r.*, 'b001' AS _batch_id, TO_TIMESTAMP_NTZ('2026-10-01T05:00:00Z') AS _available_at, 'bootstrap' AS _mode, 'synthetic/pharma/pharma-lab-0.2.0/sources/salesforce_like/campaign_member/batch=b001/part-00001.csv' AS _file_key FROM RAW_B001_SALESFORCE_LIKE_CAMPAIGN_MEMBER r WHERE EXISTS (SELECT 1 FROM LAB_BATCH_AUDIT a WHERE a.batch_id='b001' AND a.status='LOADED');

CREATE OR REPLACE VIEW SRC_SALESFORCE_LIKE_CONSENT AS
SELECT r.*, 'b001' AS _batch_id, TO_TIMESTAMP_NTZ('2026-10-01T05:00:00Z') AS _available_at, 'bootstrap' AS _mode, 'synthetic/pharma/pharma-lab-0.2.0/sources/salesforce_like/consent/batch=b001/part-00001.csv' AS _file_key FROM RAW_B001_SALESFORCE_LIKE_CONSENT r WHERE EXISTS (SELECT 1 FROM LAB_BATCH_AUDIT a WHERE a.batch_id='b001' AND a.status='LOADED')
UNION ALL
SELECT r.*, 'b002' AS _batch_id, TO_TIMESTAMP_NTZ('2026-10-02T05:00:00Z') AS _available_at, 'incremental' AS _mode, 'synthetic/pharma/pharma-lab-0.2.0/sources/salesforce_like/consent/batch=b002/part-00001.csv' AS _file_key FROM RAW_B002_SALESFORCE_LIKE_CONSENT r WHERE EXISTS (SELECT 1 FROM LAB_BATCH_AUDIT a WHERE a.batch_id='b002' AND a.status='LOADED')
UNION ALL
SELECT r.*, 'b004' AS _batch_id, TO_TIMESTAMP_NTZ('2026-10-04T05:00:00Z') AS _available_at, 'incremental' AS _mode, 'synthetic/pharma/pharma-lab-0.2.0/sources/salesforce_like/consent/batch=b004/part-00001.csv' AS _file_key FROM RAW_B004_SALESFORCE_LIKE_CONSENT r WHERE EXISTS (SELECT 1 FROM LAB_BATCH_AUDIT a WHERE a.batch_id='b004' AND a.status='LOADED');

CREATE OR REPLACE VIEW SRC_SALESFORCE_LIKE_CONTACT AS
SELECT r.*, 'b001' AS _batch_id, TO_TIMESTAMP_NTZ('2026-10-01T05:00:00Z') AS _available_at, 'bootstrap' AS _mode, 'synthetic/pharma/pharma-lab-0.2.0/sources/salesforce_like/contact/batch=b001/part-00001.csv' AS _file_key FROM RAW_B001_SALESFORCE_LIKE_CONTACT r WHERE EXISTS (SELECT 1 FROM LAB_BATCH_AUDIT a WHERE a.batch_id='b001' AND a.status='LOADED');

CREATE OR REPLACE VIEW SRC_VEEVA_LIKE_ACTIVITY AS
SELECT r.*, 'b001' AS _batch_id, TO_TIMESTAMP_NTZ('2026-10-01T05:00:00Z') AS _available_at, 'bootstrap' AS _mode, 'synthetic/pharma/pharma-lab-0.2.0/sources/veeva_like/activity/batch=b001/part-00001.csv' AS _file_key FROM RAW_B001_VEEVA_LIKE_ACTIVITY r WHERE EXISTS (SELECT 1 FROM LAB_BATCH_AUDIT a WHERE a.batch_id='b001' AND a.status='LOADED')
UNION ALL
SELECT r.*, 'b002' AS _batch_id, TO_TIMESTAMP_NTZ('2026-10-02T05:00:00Z') AS _available_at, 'incremental' AS _mode, 'synthetic/pharma/pharma-lab-0.2.0/sources/veeva_like/activity/batch=b002/part-00001.csv' AS _file_key FROM RAW_B002_VEEVA_LIKE_ACTIVITY r WHERE EXISTS (SELECT 1 FROM LAB_BATCH_AUDIT a WHERE a.batch_id='b002' AND a.status='LOADED')
UNION ALL
SELECT r.*, 'b003' AS _batch_id, TO_TIMESTAMP_NTZ('2026-10-03T05:00:00Z') AS _available_at, 'incremental' AS _mode, 'synthetic/pharma/pharma-lab-0.2.0/sources/veeva_like/activity/batch=b003/part-00001.csv' AS _file_key FROM RAW_B003_VEEVA_LIKE_ACTIVITY r WHERE EXISTS (SELECT 1 FROM LAB_BATCH_AUDIT a WHERE a.batch_id='b003' AND a.status='LOADED')
UNION ALL
SELECT r.*, 'b004' AS _batch_id, TO_TIMESTAMP_NTZ('2026-10-04T05:00:00Z') AS _available_at, 'incremental' AS _mode, 'synthetic/pharma/pharma-lab-0.2.0/sources/veeva_like/activity/batch=b004/part-00001.csv' AS _file_key FROM RAW_B004_VEEVA_LIKE_ACTIVITY r WHERE EXISTS (SELECT 1 FROM LAB_BATCH_AUDIT a WHERE a.batch_id='b004' AND a.status='LOADED')
UNION ALL
SELECT r.*, 'b005' AS _batch_id, TO_TIMESTAMP_NTZ('2026-10-05T05:00:00Z') AS _available_at, 'incremental' AS _mode, 'synthetic/pharma/pharma-lab-0.2.0/sources/veeva_like/activity/batch=b005/part-00001.csv' AS _file_key FROM RAW_B005_VEEVA_LIKE_ACTIVITY r WHERE EXISTS (SELECT 1 FROM LAB_BATCH_AUDIT a WHERE a.batch_id='b005' AND a.status='LOADED');

CREATE OR REPLACE VIEW SRC_VEEVA_LIKE_ACTIVITY_PRODUCT AS
SELECT r.*, 'b001' AS _batch_id, TO_TIMESTAMP_NTZ('2026-10-01T05:00:00Z') AS _available_at, 'bootstrap' AS _mode, 'synthetic/pharma/pharma-lab-0.2.0/sources/veeva_like/activity_product/batch=b001/part-00001.csv' AS _file_key FROM RAW_B001_VEEVA_LIKE_ACTIVITY_PRODUCT r WHERE EXISTS (SELECT 1 FROM LAB_BATCH_AUDIT a WHERE a.batch_id='b001' AND a.status='LOADED')
UNION ALL
SELECT r.*, 'b002' AS _batch_id, TO_TIMESTAMP_NTZ('2026-10-02T05:00:00Z') AS _available_at, 'incremental' AS _mode, 'synthetic/pharma/pharma-lab-0.2.0/sources/veeva_like/activity_product/batch=b002/part-00001.csv' AS _file_key FROM RAW_B002_VEEVA_LIKE_ACTIVITY_PRODUCT r WHERE EXISTS (SELECT 1 FROM LAB_BATCH_AUDIT a WHERE a.batch_id='b002' AND a.status='LOADED')
UNION ALL
SELECT r.*, 'b003' AS _batch_id, TO_TIMESTAMP_NTZ('2026-10-03T05:00:00Z') AS _available_at, 'incremental' AS _mode, 'synthetic/pharma/pharma-lab-0.2.0/sources/veeva_like/activity_product/batch=b003/part-00001.csv' AS _file_key FROM RAW_B003_VEEVA_LIKE_ACTIVITY_PRODUCT r WHERE EXISTS (SELECT 1 FROM LAB_BATCH_AUDIT a WHERE a.batch_id='b003' AND a.status='LOADED')
UNION ALL
SELECT r.*, 'b004' AS _batch_id, TO_TIMESTAMP_NTZ('2026-10-04T05:00:00Z') AS _available_at, 'incremental' AS _mode, 'synthetic/pharma/pharma-lab-0.2.0/sources/veeva_like/activity_product/batch=b004/part-00001.csv' AS _file_key FROM RAW_B004_VEEVA_LIKE_ACTIVITY_PRODUCT r WHERE EXISTS (SELECT 1 FROM LAB_BATCH_AUDIT a WHERE a.batch_id='b004' AND a.status='LOADED')
UNION ALL
SELECT r.*, 'b005' AS _batch_id, TO_TIMESTAMP_NTZ('2026-10-05T05:00:00Z') AS _available_at, 'incremental' AS _mode, 'synthetic/pharma/pharma-lab-0.2.0/sources/veeva_like/activity_product/batch=b005/part-00001.csv' AS _file_key FROM RAW_B005_VEEVA_LIKE_ACTIVITY_PRODUCT r WHERE EXISTS (SELECT 1 FROM LAB_BATCH_AUDIT a WHERE a.batch_id='b005' AND a.status='LOADED');

CREATE OR REPLACE VIEW SRC_VEEVA_LIKE_CUSTOMER AS
SELECT r.*, 'b001' AS _batch_id, TO_TIMESTAMP_NTZ('2026-10-01T05:00:00Z') AS _available_at, 'bootstrap' AS _mode, 'synthetic/pharma/pharma-lab-0.2.0/sources/veeva_like/customer/batch=b001/part-00001.csv' AS _file_key FROM RAW_B001_VEEVA_LIKE_CUSTOMER r WHERE EXISTS (SELECT 1 FROM LAB_BATCH_AUDIT a WHERE a.batch_id='b001' AND a.status='LOADED');

CREATE OR REPLACE VIEW SRC_VEEVA_LIKE_STAFF AS
SELECT r.*, 'b001' AS _batch_id, TO_TIMESTAMP_NTZ('2026-10-01T05:00:00Z') AS _available_at, 'bootstrap' AS _mode, 'synthetic/pharma/pharma-lab-0.2.0/sources/veeva_like/staff/batch=b001/part-00001.csv' AS _file_key FROM RAW_B001_VEEVA_LIKE_STAFF r WHERE EXISTS (SELECT 1 FROM LAB_BATCH_AUDIT a WHERE a.batch_id='b001' AND a.status='LOADED');

CREATE OR REPLACE VIEW SRC_VEEVA_LIKE_TERRITORY AS
SELECT r.*, 'b001' AS _batch_id, TO_TIMESTAMP_NTZ('2026-10-01T05:00:00Z') AS _available_at, 'bootstrap' AS _mode, 'synthetic/pharma/pharma-lab-0.2.0/sources/veeva_like/territory/batch=b001/part-00001.csv' AS _file_key FROM RAW_B001_VEEVA_LIKE_TERRITORY r WHERE EXISTS (SELECT 1 FROM LAB_BATCH_AUDIT a WHERE a.batch_id='b001' AND a.status='LOADED');
