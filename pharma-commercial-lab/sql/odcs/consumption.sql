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
