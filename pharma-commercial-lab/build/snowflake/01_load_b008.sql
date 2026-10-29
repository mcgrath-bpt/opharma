-- Execute with a client configured to STOP on the first SQL error.

-- Single loader only. Stage must expose the public_s3 tree at its URL root.

CREATE SCHEMA IF NOT EXISTS PHARMA_LAB.PHARMA_MODEL;

USE SCHEMA PHARMA_LAB.PHARMA_MODEL;

ALTER SESSION SET TIMEZONE = 'UTC';

CREATE FILE FORMAT IF NOT EXISTS LAB_CSV_V1 TYPE=CSV COMPRESSION=NONE FIELD_DELIMITER=',' RECORD_DELIMITER='\n' SKIP_HEADER=1 FIELD_OPTIONALLY_ENCLOSED_BY='"' ESCAPE_UNENCLOSED_FIELD=NONE EMPTY_FIELD_AS_NULL=TRUE NULL_IF=('') ERROR_ON_COLUMN_COUNT_MISMATCH=TRUE ENCODING='UTF8';

CREATE TABLE IF NOT EXISTS LAB_BATCH_AUDIT (batch_id VARCHAR, manifest_sha256 VARCHAR, available_at TIMESTAMP_NTZ, loaded_at TIMESTAMP_LTZ, status VARCHAR);

CREATE TABLE IF NOT EXISTS LAB_FILE_AUDIT (batch_id VARCHAR, file_key VARCHAR, expected_sha256 VARCHAR, expected_rows NUMBER, manifest_sha256 VARCHAR);

EXECUTE IMMEDIATE $$ DECLARE bad_release EXCEPTION (-20001, 'Batch ID already bound to different manifest'); n NUMBER; BEGIN SELECT COUNT(*) INTO :n FROM LAB_BATCH_AUDIT WHERE batch_id='b008' AND manifest_sha256<>'b06bad72b0b51a97850f424dd7b76e33e3aa8d460b4d5170e8f34e49e191c40d'; IF (n>0) THEN RAISE bad_release; END IF; END; $$;

CREATE TABLE IF NOT EXISTS RAW_B008_SALESFORCE_LIKE_CONSENT (PREFERENCE_KEY VARCHAR, CONTACT_KEY VARCHAR, CHANNEL VARCHAR, PURPOSE VARCHAR, STATUS VARCHAR, EFFECTIVE_AT VARCHAR, SEQUENCE_NO VARCHAR);

COPY INTO RAW_B008_SALESFORCE_LIKE_CONSENT FROM @PHARMA_LAB.INGEST.EXISTING_STAGE FILES=('synthetic/pharma/pharma-lab-0.2.0/sources/salesforce_like/consent/batch=b008/part-00001.csv') FILE_FORMAT=(FORMAT_NAME='PHARMA_LAB.PHARMA_MODEL.LAB_CSV_V1') ON_ERROR='ABORT_STATEMENT' FORCE=FALSE;

EXECUTE IMMEDIATE $$ DECLARE bad_count EXCEPTION (-20002, 'Loaded row count differs from manifest: RAW_B008_SALESFORCE_LIKE_CONSENT'); n NUMBER; BEGIN SELECT COUNT(*) INTO :n FROM RAW_B008_SALESFORCE_LIKE_CONSENT; IF (n<>1) THEN RAISE bad_count; END IF; END; $$;

CREATE TABLE IF NOT EXISTS RAW_B008_VEEVA_LIKE_ACTIVITY (ACTIVITY_KEY VARCHAR, CUSTOMER_KEY VARCHAR, PRIMARY_PRODUCT_CODE VARCHAR, OCCURRED_AT VARCHAR, CHANNEL VARCHAR, APPROVAL VARCHAR, DURATION_MINUTES VARCHAR, SOURCE_VERSION VARCHAR, MODIFIED_AT VARCHAR, OPERATION VARCHAR, STAFF_KEY VARCHAR);

COPY INTO RAW_B008_VEEVA_LIKE_ACTIVITY FROM @PHARMA_LAB.INGEST.EXISTING_STAGE FILES=('synthetic/pharma/pharma-lab-0.2.0/sources/veeva_like/activity/batch=b008/part-00001.csv') FILE_FORMAT=(FORMAT_NAME='PHARMA_LAB.PHARMA_MODEL.LAB_CSV_V1') ON_ERROR='ABORT_STATEMENT' FORCE=FALSE;

EXECUTE IMMEDIATE $$ DECLARE bad_count EXCEPTION (-20002, 'Loaded row count differs from manifest: RAW_B008_VEEVA_LIKE_ACTIVITY'); n NUMBER; BEGIN SELECT COUNT(*) INTO :n FROM RAW_B008_VEEVA_LIKE_ACTIVITY; IF (n<>25) THEN RAISE bad_count; END IF; END; $$;

CREATE TABLE IF NOT EXISTS RAW_B008_VEEVA_LIKE_ACTIVITY_PRODUCT (ACTIVITY_KEY VARCHAR, SOURCE_VERSION VARCHAR, PRODUCT_CODE VARCHAR, DETAIL_RANK VARCHAR);

COPY INTO RAW_B008_VEEVA_LIKE_ACTIVITY_PRODUCT FROM @PHARMA_LAB.INGEST.EXISTING_STAGE FILES=('synthetic/pharma/pharma-lab-0.2.0/sources/veeva_like/activity_product/batch=b008/part-00001.csv') FILE_FORMAT=(FORMAT_NAME='PHARMA_LAB.PHARMA_MODEL.LAB_CSV_V1') ON_ERROR='ABORT_STATEMENT' FORCE=FALSE;

EXECUTE IMMEDIATE $$ DECLARE bad_count EXCEPTION (-20002, 'Loaded row count differs from manifest: RAW_B008_VEEVA_LIKE_ACTIVITY_PRODUCT'); n NUMBER; BEGIN SELECT COUNT(*) INTO :n FROM RAW_B008_VEEVA_LIKE_ACTIVITY_PRODUCT; IF (n<>25) THEN RAISE bad_count; END IF; END; $$;

BEGIN TRANSACTION;

INSERT INTO LAB_FILE_AUDIT SELECT 'b008','synthetic/pharma/pharma-lab-0.2.0/sources/salesforce_like/consent/batch=b008/part-00001.csv','3b17ca12a322a6c68f0a7103cee49882842a72993c9682a5b290f39369a47638',1,'b06bad72b0b51a97850f424dd7b76e33e3aa8d460b4d5170e8f34e49e191c40d' WHERE NOT EXISTS (SELECT 1 FROM LAB_FILE_AUDIT WHERE batch_id='b008' AND file_key='synthetic/pharma/pharma-lab-0.2.0/sources/salesforce_like/consent/batch=b008/part-00001.csv');

INSERT INTO LAB_FILE_AUDIT SELECT 'b008','synthetic/pharma/pharma-lab-0.2.0/sources/veeva_like/activity/batch=b008/part-00001.csv','2a6cd86245c8779dc419389a058d429b0b9b8f2d3b451825cc0bed32455a2a21',25,'b06bad72b0b51a97850f424dd7b76e33e3aa8d460b4d5170e8f34e49e191c40d' WHERE NOT EXISTS (SELECT 1 FROM LAB_FILE_AUDIT WHERE batch_id='b008' AND file_key='synthetic/pharma/pharma-lab-0.2.0/sources/veeva_like/activity/batch=b008/part-00001.csv');

INSERT INTO LAB_FILE_AUDIT SELECT 'b008','synthetic/pharma/pharma-lab-0.2.0/sources/veeva_like/activity_product/batch=b008/part-00001.csv','cf316edd7433917616988dd45c21816d9abcc6bc89879f9dc0feb4ca65986a88',25,'b06bad72b0b51a97850f424dd7b76e33e3aa8d460b4d5170e8f34e49e191c40d' WHERE NOT EXISTS (SELECT 1 FROM LAB_FILE_AUDIT WHERE batch_id='b008' AND file_key='synthetic/pharma/pharma-lab-0.2.0/sources/veeva_like/activity_product/batch=b008/part-00001.csv');

INSERT INTO LAB_BATCH_AUDIT SELECT 'b008','b06bad72b0b51a97850f424dd7b76e33e3aa8d460b4d5170e8f34e49e191c40d',TO_TIMESTAMP_NTZ('2026-10-08T05:00:00Z'),CURRENT_TIMESTAMP(),'LOADED' WHERE NOT EXISTS (SELECT 1 FROM LAB_BATCH_AUDIT WHERE batch_id='b008');

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
SELECT r.*, 'b001' AS _batch_id, TO_TIMESTAMP_NTZ('2026-10-01T05:00:00Z') AS _available_at, 'bootstrap' AS _mode, 'synthetic/pharma/pharma-lab-0.2.0/sources/manual/territory_mapping/batch=b001/part-00001.csv' AS _file_key FROM RAW_B001_MANUAL_TERRITORY_MAPPING r WHERE EXISTS (SELECT 1 FROM LAB_BATCH_AUDIT a WHERE a.batch_id='b001' AND a.status='LOADED')
UNION ALL
SELECT r.*, 'b007' AS _batch_id, TO_TIMESTAMP_NTZ('2026-10-07T05:00:00Z') AS _available_at, 'incremental' AS _mode, 'synthetic/pharma/pharma-lab-0.2.0/sources/manual/territory_mapping/batch=b007/part-00001.csv' AS _file_key FROM RAW_B007_MANUAL_TERRITORY_MAPPING r WHERE EXISTS (SELECT 1 FROM LAB_BATCH_AUDIT a WHERE a.batch_id='b007' AND a.status='LOADED');

CREATE OR REPLACE VIEW SRC_SALESFORCE_LIKE_CAMPAIGN AS
SELECT r.*, 'b001' AS _batch_id, TO_TIMESTAMP_NTZ('2026-10-01T05:00:00Z') AS _available_at, 'bootstrap' AS _mode, 'synthetic/pharma/pharma-lab-0.2.0/sources/salesforce_like/campaign/batch=b001/part-00001.csv' AS _file_key FROM RAW_B001_SALESFORCE_LIKE_CAMPAIGN r WHERE EXISTS (SELECT 1 FROM LAB_BATCH_AUDIT a WHERE a.batch_id='b001' AND a.status='LOADED');

CREATE OR REPLACE VIEW SRC_SALESFORCE_LIKE_CAMPAIGN_MEMBER AS
SELECT r.*, 'b001' AS _batch_id, TO_TIMESTAMP_NTZ('2026-10-01T05:00:00Z') AS _available_at, 'bootstrap' AS _mode, 'synthetic/pharma/pharma-lab-0.2.0/sources/salesforce_like/campaign_member/batch=b001/part-00001.csv' AS _file_key FROM RAW_B001_SALESFORCE_LIKE_CAMPAIGN_MEMBER r WHERE EXISTS (SELECT 1 FROM LAB_BATCH_AUDIT a WHERE a.batch_id='b001' AND a.status='LOADED');

CREATE OR REPLACE VIEW SRC_SALESFORCE_LIKE_CONSENT AS
SELECT r.*, 'b001' AS _batch_id, TO_TIMESTAMP_NTZ('2026-10-01T05:00:00Z') AS _available_at, 'bootstrap' AS _mode, 'synthetic/pharma/pharma-lab-0.2.0/sources/salesforce_like/consent/batch=b001/part-00001.csv' AS _file_key FROM RAW_B001_SALESFORCE_LIKE_CONSENT r WHERE EXISTS (SELECT 1 FROM LAB_BATCH_AUDIT a WHERE a.batch_id='b001' AND a.status='LOADED')
UNION ALL
SELECT r.*, 'b002' AS _batch_id, TO_TIMESTAMP_NTZ('2026-10-02T05:00:00Z') AS _available_at, 'incremental' AS _mode, 'synthetic/pharma/pharma-lab-0.2.0/sources/salesforce_like/consent/batch=b002/part-00001.csv' AS _file_key FROM RAW_B002_SALESFORCE_LIKE_CONSENT r WHERE EXISTS (SELECT 1 FROM LAB_BATCH_AUDIT a WHERE a.batch_id='b002' AND a.status='LOADED')
UNION ALL
SELECT r.*, 'b004' AS _batch_id, TO_TIMESTAMP_NTZ('2026-10-04T05:00:00Z') AS _available_at, 'incremental' AS _mode, 'synthetic/pharma/pharma-lab-0.2.0/sources/salesforce_like/consent/batch=b004/part-00001.csv' AS _file_key FROM RAW_B004_SALESFORCE_LIKE_CONSENT r WHERE EXISTS (SELECT 1 FROM LAB_BATCH_AUDIT a WHERE a.batch_id='b004' AND a.status='LOADED')
UNION ALL
SELECT r.*, 'b008' AS _batch_id, TO_TIMESTAMP_NTZ('2026-10-08T05:00:00Z') AS _available_at, 'incremental' AS _mode, 'synthetic/pharma/pharma-lab-0.2.0/sources/salesforce_like/consent/batch=b008/part-00001.csv' AS _file_key FROM RAW_B008_SALESFORCE_LIKE_CONSENT r WHERE EXISTS (SELECT 1 FROM LAB_BATCH_AUDIT a WHERE a.batch_id='b008' AND a.status='LOADED');

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
SELECT r.*, 'b005' AS _batch_id, TO_TIMESTAMP_NTZ('2026-10-05T05:00:00Z') AS _available_at, 'incremental' AS _mode, 'synthetic/pharma/pharma-lab-0.2.0/sources/veeva_like/activity/batch=b005/part-00001.csv' AS _file_key FROM RAW_B005_VEEVA_LIKE_ACTIVITY r WHERE EXISTS (SELECT 1 FROM LAB_BATCH_AUDIT a WHERE a.batch_id='b005' AND a.status='LOADED')
UNION ALL
SELECT r.*, 'b006' AS _batch_id, TO_TIMESTAMP_NTZ('2026-10-06T05:00:00Z') AS _available_at, 'incremental' AS _mode, 'synthetic/pharma/pharma-lab-0.2.0/sources/veeva_like/activity/batch=b006/part-00001.csv' AS _file_key FROM RAW_B006_VEEVA_LIKE_ACTIVITY r WHERE EXISTS (SELECT 1 FROM LAB_BATCH_AUDIT a WHERE a.batch_id='b006' AND a.status='LOADED')
UNION ALL
SELECT r.*, 'b007' AS _batch_id, TO_TIMESTAMP_NTZ('2026-10-07T05:00:00Z') AS _available_at, 'incremental' AS _mode, 'synthetic/pharma/pharma-lab-0.2.0/sources/veeva_like/activity/batch=b007/part-00001.csv' AS _file_key FROM RAW_B007_VEEVA_LIKE_ACTIVITY r WHERE EXISTS (SELECT 1 FROM LAB_BATCH_AUDIT a WHERE a.batch_id='b007' AND a.status='LOADED')
UNION ALL
SELECT r.*, 'b008' AS _batch_id, TO_TIMESTAMP_NTZ('2026-10-08T05:00:00Z') AS _available_at, 'incremental' AS _mode, 'synthetic/pharma/pharma-lab-0.2.0/sources/veeva_like/activity/batch=b008/part-00001.csv' AS _file_key FROM RAW_B008_VEEVA_LIKE_ACTIVITY r WHERE EXISTS (SELECT 1 FROM LAB_BATCH_AUDIT a WHERE a.batch_id='b008' AND a.status='LOADED');

CREATE OR REPLACE VIEW SRC_VEEVA_LIKE_ACTIVITY_PRODUCT AS
SELECT r.*, 'b001' AS _batch_id, TO_TIMESTAMP_NTZ('2026-10-01T05:00:00Z') AS _available_at, 'bootstrap' AS _mode, 'synthetic/pharma/pharma-lab-0.2.0/sources/veeva_like/activity_product/batch=b001/part-00001.csv' AS _file_key FROM RAW_B001_VEEVA_LIKE_ACTIVITY_PRODUCT r WHERE EXISTS (SELECT 1 FROM LAB_BATCH_AUDIT a WHERE a.batch_id='b001' AND a.status='LOADED')
UNION ALL
SELECT r.*, 'b002' AS _batch_id, TO_TIMESTAMP_NTZ('2026-10-02T05:00:00Z') AS _available_at, 'incremental' AS _mode, 'synthetic/pharma/pharma-lab-0.2.0/sources/veeva_like/activity_product/batch=b002/part-00001.csv' AS _file_key FROM RAW_B002_VEEVA_LIKE_ACTIVITY_PRODUCT r WHERE EXISTS (SELECT 1 FROM LAB_BATCH_AUDIT a WHERE a.batch_id='b002' AND a.status='LOADED')
UNION ALL
SELECT r.*, 'b003' AS _batch_id, TO_TIMESTAMP_NTZ('2026-10-03T05:00:00Z') AS _available_at, 'incremental' AS _mode, 'synthetic/pharma/pharma-lab-0.2.0/sources/veeva_like/activity_product/batch=b003/part-00001.csv' AS _file_key FROM RAW_B003_VEEVA_LIKE_ACTIVITY_PRODUCT r WHERE EXISTS (SELECT 1 FROM LAB_BATCH_AUDIT a WHERE a.batch_id='b003' AND a.status='LOADED')
UNION ALL
SELECT r.*, 'b004' AS _batch_id, TO_TIMESTAMP_NTZ('2026-10-04T05:00:00Z') AS _available_at, 'incremental' AS _mode, 'synthetic/pharma/pharma-lab-0.2.0/sources/veeva_like/activity_product/batch=b004/part-00001.csv' AS _file_key FROM RAW_B004_VEEVA_LIKE_ACTIVITY_PRODUCT r WHERE EXISTS (SELECT 1 FROM LAB_BATCH_AUDIT a WHERE a.batch_id='b004' AND a.status='LOADED')
UNION ALL
SELECT r.*, 'b005' AS _batch_id, TO_TIMESTAMP_NTZ('2026-10-05T05:00:00Z') AS _available_at, 'incremental' AS _mode, 'synthetic/pharma/pharma-lab-0.2.0/sources/veeva_like/activity_product/batch=b005/part-00001.csv' AS _file_key FROM RAW_B005_VEEVA_LIKE_ACTIVITY_PRODUCT r WHERE EXISTS (SELECT 1 FROM LAB_BATCH_AUDIT a WHERE a.batch_id='b005' AND a.status='LOADED')
UNION ALL
SELECT r.*, 'b006' AS _batch_id, TO_TIMESTAMP_NTZ('2026-10-06T05:00:00Z') AS _available_at, 'incremental' AS _mode, 'synthetic/pharma/pharma-lab-0.2.0/sources/veeva_like/activity_product/batch=b006/part-00001.csv' AS _file_key FROM RAW_B006_VEEVA_LIKE_ACTIVITY_PRODUCT r WHERE EXISTS (SELECT 1 FROM LAB_BATCH_AUDIT a WHERE a.batch_id='b006' AND a.status='LOADED')
UNION ALL
SELECT r.*, 'b007' AS _batch_id, TO_TIMESTAMP_NTZ('2026-10-07T05:00:00Z') AS _available_at, 'incremental' AS _mode, 'synthetic/pharma/pharma-lab-0.2.0/sources/veeva_like/activity_product/batch=b007/part-00001.csv' AS _file_key FROM RAW_B007_VEEVA_LIKE_ACTIVITY_PRODUCT r WHERE EXISTS (SELECT 1 FROM LAB_BATCH_AUDIT a WHERE a.batch_id='b007' AND a.status='LOADED')
UNION ALL
SELECT r.*, 'b008' AS _batch_id, TO_TIMESTAMP_NTZ('2026-10-08T05:00:00Z') AS _available_at, 'incremental' AS _mode, 'synthetic/pharma/pharma-lab-0.2.0/sources/veeva_like/activity_product/batch=b008/part-00001.csv' AS _file_key FROM RAW_B008_VEEVA_LIKE_ACTIVITY_PRODUCT r WHERE EXISTS (SELECT 1 FROM LAB_BATCH_AUDIT a WHERE a.batch_id='b008' AND a.status='LOADED');

CREATE OR REPLACE VIEW SRC_VEEVA_LIKE_CUSTOMER AS
SELECT r.*, 'b001' AS _batch_id, TO_TIMESTAMP_NTZ('2026-10-01T05:00:00Z') AS _available_at, 'bootstrap' AS _mode, 'synthetic/pharma/pharma-lab-0.2.0/sources/veeva_like/customer/batch=b001/part-00001.csv' AS _file_key FROM RAW_B001_VEEVA_LIKE_CUSTOMER r WHERE EXISTS (SELECT 1 FROM LAB_BATCH_AUDIT a WHERE a.batch_id='b001' AND a.status='LOADED');

CREATE OR REPLACE VIEW SRC_VEEVA_LIKE_STAFF AS
SELECT r.*, 'b001' AS _batch_id, TO_TIMESTAMP_NTZ('2026-10-01T05:00:00Z') AS _available_at, 'bootstrap' AS _mode, 'synthetic/pharma/pharma-lab-0.2.0/sources/veeva_like/staff/batch=b001/part-00001.csv' AS _file_key FROM RAW_B001_VEEVA_LIKE_STAFF r WHERE EXISTS (SELECT 1 FROM LAB_BATCH_AUDIT a WHERE a.batch_id='b001' AND a.status='LOADED');

CREATE OR REPLACE VIEW SRC_VEEVA_LIKE_TERRITORY AS
SELECT r.*, 'b001' AS _batch_id, TO_TIMESTAMP_NTZ('2026-10-01T05:00:00Z') AS _available_at, 'bootstrap' AS _mode, 'synthetic/pharma/pharma-lab-0.2.0/sources/veeva_like/territory/batch=b001/part-00001.csv' AS _file_key FROM RAW_B001_VEEVA_LIKE_TERRITORY r WHERE EXISTS (SELECT 1 FROM LAB_BATCH_AUDIT a WHERE a.batch_id='b001' AND a.status='LOADED');
