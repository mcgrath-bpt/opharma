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
