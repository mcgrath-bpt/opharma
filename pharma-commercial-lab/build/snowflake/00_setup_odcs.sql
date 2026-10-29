USE SCHEMA PHARMA_LAB.PHARMA_MODEL;

ALTER SESSION SET TIMEZONE='UTC';

CREATE TABLE IF NOT EXISTS ODCS_MODEL_IDENTITY (release_id VARCHAR, registry_sha256 VARCHAR);

CREATE TABLE IF NOT EXISTS ODCS_SNAPSHOT_AUDIT (snapshot_id VARCHAR, release_id VARCHAR, manifest_sha256 VARCHAR, registry_sha256 VARCHAR, as_of TIMESTAMP_NTZ, published_at TIMESTAMP_LTZ, status VARCHAR);

CREATE TABLE IF NOT EXISTS "canonical_organisation" (
  "snapshot_id" VARCHAR NOT NULL,
  "organisation_key" VARCHAR NOT NULL,
  "organisation_name" VARCHAR NOT NULL,
  "country" VARCHAR NOT NULL,
  PRIMARY KEY ("snapshot_id","organisation_key")
);

CREATE TABLE IF NOT EXISTS "canonical_affiliation" (
  "snapshot_id" VARCHAR NOT NULL,
  "affiliation_key" VARCHAR NOT NULL,
  "customer_key" VARCHAR NOT NULL,
  "organisation_key" VARCHAR NOT NULL,
  "relationship_type" VARCHAR NOT NULL,
  "is_primary" BOOLEAN NOT NULL,
  "effective_from" DATE NOT NULL,
  "effective_to" DATE,
  PRIMARY KEY ("snapshot_id","affiliation_key")
);

CREATE TABLE IF NOT EXISTS "canonical_representative" (
  "snapshot_id" VARCHAR NOT NULL,
  "staff_key" VARCHAR NOT NULL,
  "staff_name" VARCHAR NOT NULL,
  PRIMARY KEY ("snapshot_id","staff_key")
);

CREATE TABLE IF NOT EXISTS "canonical_customer" (
  "snapshot_id" VARCHAR NOT NULL,
  "customer_key" VARCHAR NOT NULL,
  "label" VARCHAR NOT NULL,
  "speciality" VARCHAR NOT NULL,
  "country" VARCHAR NOT NULL,
  "postal_sector" VARCHAR NOT NULL,
  "active" BOOLEAN NOT NULL,
  PRIMARY KEY ("snapshot_id","customer_key")
);

CREATE TABLE IF NOT EXISTS "canonical_product_interval" (
  "snapshot_id" VARCHAR NOT NULL,
  "product_code" VARCHAR NOT NULL,
  "valid_from" DATE NOT NULL,
  "valid_to" DATE,
  "brand" VARCHAR NOT NULL,
  "therapy" VARCHAR NOT NULL,
  "active" BOOLEAN NOT NULL,
  PRIMARY KEY ("snapshot_id","product_code","valid_from")
);

CREATE TABLE IF NOT EXISTS "canonical_territory" (
  "snapshot_id" VARCHAR NOT NULL,
  "territory_code" VARCHAR NOT NULL,
  "territory_name" VARCHAR NOT NULL,
  PRIMARY KEY ("snapshot_id","territory_code")
);

CREATE TABLE IF NOT EXISTS "canonical_interaction_version" (
  "snapshot_id" VARCHAR NOT NULL,
  "activity_key" VARCHAR NOT NULL,
  "source_version" NUMBER(38,0) NOT NULL,
  "crm_customer_key" VARCHAR NOT NULL,
  "customer_key" VARCHAR,
  "staff_key" VARCHAR,
  "primary_product_code" VARCHAR NOT NULL,
  "occurred_at" TIMESTAMP_NTZ NOT NULL,
  "channel" VARCHAR NOT NULL,
  "approval" VARCHAR NOT NULL,
  "duration_minutes" NUMBER(38,0) NOT NULL,
  "modified_at" TIMESTAMP_NTZ NOT NULL,
  "operation" VARCHAR NOT NULL,
  "delivery_batch" VARCHAR NOT NULL,
  PRIMARY KEY ("snapshot_id","activity_key","source_version")
);

CREATE TABLE IF NOT EXISTS "canonical_interaction_product" (
  "snapshot_id" VARCHAR NOT NULL,
  "activity_key" VARCHAR NOT NULL,
  "source_version" NUMBER(38,0) NOT NULL,
  "product_code" VARCHAR NOT NULL,
  PRIMARY KEY ("snapshot_id","activity_key","source_version","product_code")
);

CREATE TABLE IF NOT EXISTS "canonical_consent_event" (
  "snapshot_id" VARCHAR NOT NULL,
  "preference_key" VARCHAR NOT NULL,
  "customer_key" VARCHAR,
  "contact_key" VARCHAR NOT NULL,
  "channel" VARCHAR NOT NULL,
  "purpose" VARCHAR NOT NULL,
  "status" VARCHAR NOT NULL,
  "effective_at" TIMESTAMP_NTZ NOT NULL,
  "sequence_no" NUMBER(38,0) NOT NULL,
  "delivery_batch" VARCHAR NOT NULL,
  PRIMARY KEY ("snapshot_id","preference_key")
);

CREATE TABLE IF NOT EXISTS "canonical_customer_territory" (
  "snapshot_id" VARCHAR NOT NULL,
  "assignment_key" VARCHAR NOT NULL,
  "customer_key" VARCHAR NOT NULL,
  "territory_code" VARCHAR NOT NULL,
  "effective_from" DATE NOT NULL,
  "effective_to" DATE,
  PRIMARY KEY ("snapshot_id","assignment_key")
);

CREATE TABLE IF NOT EXISTS "canonical_campaign" (
  "snapshot_id" VARCHAR NOT NULL,
  "campaign_key" VARCHAR NOT NULL,
  "product_code" VARCHAR NOT NULL,
  "start_date" DATE NOT NULL,
  "end_date_exclusive" DATE NOT NULL,
  "status" VARCHAR NOT NULL,
  PRIMARY KEY ("snapshot_id","campaign_key")
);

CREATE TABLE IF NOT EXISTS "canonical_campaign_member" (
  "snapshot_id" VARCHAR NOT NULL,
  "membership_key" VARCHAR NOT NULL,
  "campaign_key" VARCHAR NOT NULL,
  "customer_key" VARCHAR,
  "contact_key" VARCHAR NOT NULL,
  "member_status" VARCHAR NOT NULL,
  PRIMARY KEY ("snapshot_id","membership_key")
);

CREATE TABLE IF NOT EXISTS "canonical_rx_version" (
  "snapshot_id" VARCHAR NOT NULL,
  "observation_key" VARCHAR NOT NULL,
  "version_no" NUMBER(38,0) NOT NULL,
  "customer_key" VARCHAR NOT NULL,
  "product_code" VARCHAR NOT NULL,
  "week_ending" DATE NOT NULL,
  "trx_count" NUMBER(38,0) NOT NULL,
  "nrx_count" NUMBER(38,0) NOT NULL,
  "sales_units" NUMBER(38,0) NOT NULL,
  PRIMARY KEY ("snapshot_id","observation_key","version_no")
);


CREATE TABLE IF NOT EXISTS "pipeline_s01_engagement" (
  "snapshot_id" VARCHAR NOT NULL,
  "as_of" TIMESTAMP_NTZ NOT NULL,
  "activity_key" VARCHAR NOT NULL,
  "customer_key" VARCHAR NOT NULL,
  "activity_date" DATE NOT NULL,
  "consent_status" VARCHAR NOT NULL,
  PRIMARY KEY ("snapshot_id","activity_key")
);

CREATE TABLE IF NOT EXISTS "pipeline_s02_product_activity" (
  "snapshot_id" VARCHAR NOT NULL,
  "as_of" TIMESTAMP_NTZ NOT NULL,
  "customer_key" VARCHAR NOT NULL,
  "product_code" VARCHAR NOT NULL,
  "activity_date" DATE NOT NULL,
  "brand" VARCHAR NOT NULL,
  "therapy" VARCHAR NOT NULL,
  "interaction_count" NUMBER(38,0) NOT NULL,
  PRIMARY KEY ("snapshot_id","customer_key","product_code","activity_date")
);

CREATE TABLE IF NOT EXISTS "pipeline_s03_customer_territory" (
  "snapshot_id" VARCHAR NOT NULL,
  "as_of" TIMESTAMP_NTZ NOT NULL,
  "customer_key" VARCHAR NOT NULL,
  "territory_code" VARCHAR,
  "assignment_status" VARCHAR NOT NULL,
  PRIMARY KEY ("snapshot_id","customer_key")
);

CREATE TABLE IF NOT EXISTS "pipeline_s04_interaction" (
  "snapshot_id" VARCHAR NOT NULL,
  "as_of" TIMESTAMP_NTZ NOT NULL,
  "activity_key" VARCHAR NOT NULL,
  "customer_key" VARCHAR NOT NULL,
  "primary_product_code" VARCHAR NOT NULL,
  "occurred_at" TIMESTAMP_NTZ NOT NULL,
  "channel" VARCHAR NOT NULL,
  "duration_minutes" NUMBER(38,0) NOT NULL,
  "source_version" NUMBER(38,0) NOT NULL,
  PRIMARY KEY ("snapshot_id","activity_key")
);

CREATE TABLE IF NOT EXISTS "pipeline_s05_campaign" (
  "snapshot_id" VARCHAR NOT NULL,
  "as_of" TIMESTAMP_NTZ NOT NULL,
  "campaign_key" VARCHAR NOT NULL,
  "customer_key" VARCHAR NOT NULL,
  "product_code" VARCHAR NOT NULL,
  "contacted" BOOLEAN NOT NULL,
  "qualifying_interactions" NUMBER(38,0) NOT NULL,
  PRIMARY KEY ("snapshot_id","campaign_key","customer_key")
);

CREATE TABLE IF NOT EXISTS "pipeline_exceptions" (
  "snapshot_id" VARCHAR NOT NULL,
  "as_of" TIMESTAMP_NTZ NOT NULL,
  "scenario" VARCHAR NOT NULL,
  "record_key" VARCHAR NOT NULL,
  "reason" VARCHAR NOT NULL,
  PRIMARY KEY ("snapshot_id","scenario","record_key","reason")
);

CREATE TABLE IF NOT EXISTS "pipeline_dq" (
  "snapshot_id" VARCHAR NOT NULL,
  "as_of" TIMESTAMP_NTZ NOT NULL,
  "scenario" VARCHAR NOT NULL,
  "scope" VARCHAR NOT NULL,
  "numerator" NUMBER(38,0) NOT NULL,
  "denominator" NUMBER(38,0) NOT NULL,
  "threshold" NUMBER(18,6) NOT NULL,
  "status" VARCHAR NOT NULL,
  PRIMARY KEY ("snapshot_id","scenario","scope")
);


CREATE TABLE IF NOT EXISTS "consumption_s01_engagement" (
  "snapshot_id" VARCHAR NOT NULL,
  "as_of" TIMESTAMP_NTZ NOT NULL,
  "activity_key" VARCHAR NOT NULL,
  "customer_key" VARCHAR NOT NULL,
  "activity_date" DATE NOT NULL,
  "consent_status" VARCHAR NOT NULL,
  PRIMARY KEY ("snapshot_id","activity_key")
);

CREATE TABLE IF NOT EXISTS "consumption_s02_product_activity" (
  "snapshot_id" VARCHAR NOT NULL,
  "as_of" TIMESTAMP_NTZ NOT NULL,
  "customer_key" VARCHAR NOT NULL,
  "product_code" VARCHAR NOT NULL,
  "activity_date" DATE NOT NULL,
  "brand" VARCHAR NOT NULL,
  "therapy" VARCHAR NOT NULL,
  "interaction_count" NUMBER(38,0) NOT NULL,
  PRIMARY KEY ("snapshot_id","customer_key","product_code","activity_date")
);

CREATE TABLE IF NOT EXISTS "consumption_s03_customer_territory" (
  "snapshot_id" VARCHAR NOT NULL,
  "as_of" TIMESTAMP_NTZ NOT NULL,
  "customer_key" VARCHAR NOT NULL,
  "territory_code" VARCHAR,
  "assignment_status" VARCHAR NOT NULL,
  PRIMARY KEY ("snapshot_id","customer_key")
);

CREATE TABLE IF NOT EXISTS "consumption_s04_interaction" (
  "snapshot_id" VARCHAR NOT NULL,
  "as_of" TIMESTAMP_NTZ NOT NULL,
  "activity_key" VARCHAR NOT NULL,
  "customer_key" VARCHAR NOT NULL,
  "primary_product_code" VARCHAR NOT NULL,
  "occurred_at" TIMESTAMP_NTZ NOT NULL,
  "channel" VARCHAR NOT NULL,
  "duration_minutes" NUMBER(38,0) NOT NULL,
  "source_version" NUMBER(38,0) NOT NULL,
  PRIMARY KEY ("snapshot_id","activity_key")
);

CREATE TABLE IF NOT EXISTS "consumption_s05_campaign" (
  "snapshot_id" VARCHAR NOT NULL,
  "as_of" TIMESTAMP_NTZ NOT NULL,
  "campaign_key" VARCHAR NOT NULL,
  "customer_key" VARCHAR NOT NULL,
  "product_code" VARCHAR NOT NULL,
  "contacted" BOOLEAN NOT NULL,
  "qualifying_interactions" NUMBER(38,0) NOT NULL,
  PRIMARY KEY ("snapshot_id","campaign_key","customer_key")
);

CREATE TABLE IF NOT EXISTS "consumption_exceptions" (
  "snapshot_id" VARCHAR NOT NULL,
  "as_of" TIMESTAMP_NTZ NOT NULL,
  "scenario" VARCHAR NOT NULL,
  "record_key" VARCHAR NOT NULL,
  "reason" VARCHAR NOT NULL,
  PRIMARY KEY ("snapshot_id","scenario","record_key","reason")
);

CREATE TABLE IF NOT EXISTS "consumption_dq" (
  "snapshot_id" VARCHAR NOT NULL,
  "as_of" TIMESTAMP_NTZ NOT NULL,
  "scenario" VARCHAR NOT NULL,
  "scope" VARCHAR NOT NULL,
  "numerator" NUMBER(38,0) NOT NULL,
  "denominator" NUMBER(38,0) NOT NULL,
  "threshold" NUMBER(18,6) NOT NULL,
  "status" VARCHAR NOT NULL,
  PRIMARY KEY ("snapshot_id","scenario","scope")
);


CREATE TABLE IF NOT EXISTS "visualization_scenario_scorecard" (
  "snapshot_id" VARCHAR NOT NULL,
  "as_of" TIMESTAMP_NTZ NOT NULL,
  "scenario" VARCHAR NOT NULL,
  "scope" VARCHAR NOT NULL,
  "output_rows" NUMBER(38,0) NOT NULL,
  "exception_rows" NUMBER(38,0) NOT NULL,
  "numerator" NUMBER(38,0) NOT NULL,
  "denominator" NUMBER(38,0) NOT NULL,
  "threshold" NUMBER(18,6) NOT NULL,
  "status" VARCHAR NOT NULL,
  "scheduled" BOOLEAN NOT NULL,
  PRIMARY KEY ("snapshot_id","scenario","scope")
);


CREATE OR REPLACE VIEW "pipeline_s01_engagement_current" AS SELECT * FROM "pipeline_s01_engagement" WHERE "snapshot_id"=(SELECT snapshot_id FROM ODCS_SNAPSHOT_AUDIT WHERE status='PUBLISHED' ORDER BY as_of DESC LIMIT 1);

CREATE OR REPLACE VIEW "pipeline_s02_product_activity_current" AS SELECT * FROM "pipeline_s02_product_activity" WHERE "snapshot_id"=(SELECT snapshot_id FROM ODCS_SNAPSHOT_AUDIT WHERE status='PUBLISHED' ORDER BY as_of DESC LIMIT 1);

CREATE OR REPLACE VIEW "pipeline_s03_customer_territory_current" AS SELECT * FROM "pipeline_s03_customer_territory" WHERE "snapshot_id"=(SELECT snapshot_id FROM ODCS_SNAPSHOT_AUDIT WHERE status='PUBLISHED' ORDER BY as_of DESC LIMIT 1);

CREATE OR REPLACE VIEW "pipeline_s04_interaction_current" AS SELECT * FROM "pipeline_s04_interaction" WHERE "snapshot_id"=(SELECT snapshot_id FROM ODCS_SNAPSHOT_AUDIT WHERE status='PUBLISHED' ORDER BY as_of DESC LIMIT 1);

CREATE OR REPLACE VIEW "pipeline_s05_campaign_current" AS SELECT * FROM "pipeline_s05_campaign" WHERE "snapshot_id"=(SELECT snapshot_id FROM ODCS_SNAPSHOT_AUDIT WHERE status='PUBLISHED' ORDER BY as_of DESC LIMIT 1);

CREATE OR REPLACE VIEW "pipeline_exceptions_current" AS SELECT * FROM "pipeline_exceptions" WHERE "snapshot_id"=(SELECT snapshot_id FROM ODCS_SNAPSHOT_AUDIT WHERE status='PUBLISHED' ORDER BY as_of DESC LIMIT 1);

CREATE OR REPLACE VIEW "pipeline_dq_current" AS SELECT * FROM "pipeline_dq" WHERE "snapshot_id"=(SELECT snapshot_id FROM ODCS_SNAPSHOT_AUDIT WHERE status='PUBLISHED' ORDER BY as_of DESC LIMIT 1);

CREATE OR REPLACE VIEW "consumption_s01_engagement_current" AS SELECT * FROM "consumption_s01_engagement" WHERE "snapshot_id"=(SELECT snapshot_id FROM ODCS_SNAPSHOT_AUDIT WHERE status='PUBLISHED' ORDER BY as_of DESC LIMIT 1);

CREATE OR REPLACE VIEW "consumption_s02_product_activity_current" AS SELECT * FROM "consumption_s02_product_activity" WHERE "snapshot_id"=(SELECT snapshot_id FROM ODCS_SNAPSHOT_AUDIT WHERE status='PUBLISHED' ORDER BY as_of DESC LIMIT 1);

CREATE OR REPLACE VIEW "consumption_s03_customer_territory_current" AS SELECT * FROM "consumption_s03_customer_territory" WHERE "snapshot_id"=(SELECT snapshot_id FROM ODCS_SNAPSHOT_AUDIT WHERE status='PUBLISHED' ORDER BY as_of DESC LIMIT 1);

CREATE OR REPLACE VIEW "consumption_s04_interaction_current" AS SELECT * FROM "consumption_s04_interaction" WHERE "snapshot_id"=(SELECT snapshot_id FROM ODCS_SNAPSHOT_AUDIT WHERE status='PUBLISHED' ORDER BY as_of DESC LIMIT 1);

CREATE OR REPLACE VIEW "consumption_s05_campaign_current" AS SELECT * FROM "consumption_s05_campaign" WHERE "snapshot_id"=(SELECT snapshot_id FROM ODCS_SNAPSHOT_AUDIT WHERE status='PUBLISHED' AND DAYOFWEEKISO(as_of)=1 ORDER BY as_of DESC LIMIT 1);

CREATE OR REPLACE VIEW "consumption_exceptions_current" AS SELECT * FROM "consumption_exceptions" WHERE "snapshot_id"=(SELECT snapshot_id FROM ODCS_SNAPSHOT_AUDIT WHERE status='PUBLISHED' ORDER BY as_of DESC LIMIT 1);

CREATE OR REPLACE VIEW "consumption_dq_current" AS SELECT * FROM "consumption_dq" WHERE "snapshot_id"=(SELECT snapshot_id FROM ODCS_SNAPSHOT_AUDIT WHERE status='PUBLISHED' ORDER BY as_of DESC LIMIT 1);

CREATE OR REPLACE VIEW "visualization_scenario_scorecard_current" AS SELECT * FROM "visualization_scenario_scorecard" WHERE "snapshot_id"=(SELECT snapshot_id FROM ODCS_SNAPSHOT_AUDIT WHERE status='PUBLISHED' ORDER BY as_of DESC LIMIT 1);
