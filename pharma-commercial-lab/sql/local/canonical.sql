CREATE TABLE IF NOT EXISTS "canonical_organisation" (
  "snapshot_id" TEXT NOT NULL,
  "organisation_key" TEXT NOT NULL,
  "organisation_name" TEXT NOT NULL,
  "country" TEXT NOT NULL,
  PRIMARY KEY ("snapshot_id","organisation_key")
);

CREATE TABLE IF NOT EXISTS "canonical_affiliation" (
  "snapshot_id" TEXT NOT NULL,
  "affiliation_key" TEXT NOT NULL,
  "customer_key" TEXT NOT NULL,
  "organisation_key" TEXT NOT NULL,
  "relationship_type" TEXT NOT NULL,
  "is_primary" INTEGER NOT NULL,
  "effective_from" TEXT NOT NULL,
  "effective_to" TEXT,
  PRIMARY KEY ("snapshot_id","affiliation_key")
);

CREATE TABLE IF NOT EXISTS "canonical_representative" (
  "snapshot_id" TEXT NOT NULL,
  "staff_key" TEXT NOT NULL,
  "staff_name" TEXT NOT NULL,
  PRIMARY KEY ("snapshot_id","staff_key")
);

CREATE TABLE IF NOT EXISTS "canonical_customer" (
  "snapshot_id" TEXT NOT NULL,
  "customer_key" TEXT NOT NULL,
  "label" TEXT NOT NULL,
  "speciality" TEXT NOT NULL,
  "country" TEXT NOT NULL,
  "postal_sector" TEXT NOT NULL,
  "active" INTEGER NOT NULL,
  PRIMARY KEY ("snapshot_id","customer_key")
);

CREATE TABLE IF NOT EXISTS "canonical_product_interval" (
  "snapshot_id" TEXT NOT NULL,
  "product_code" TEXT NOT NULL,
  "valid_from" TEXT NOT NULL,
  "valid_to" TEXT,
  "brand" TEXT NOT NULL,
  "therapy" TEXT NOT NULL,
  "active" INTEGER NOT NULL,
  PRIMARY KEY ("snapshot_id","product_code","valid_from")
);

CREATE TABLE IF NOT EXISTS "canonical_territory" (
  "snapshot_id" TEXT NOT NULL,
  "territory_code" TEXT NOT NULL,
  "territory_name" TEXT NOT NULL,
  PRIMARY KEY ("snapshot_id","territory_code")
);

CREATE TABLE IF NOT EXISTS "canonical_interaction_version" (
  "snapshot_id" TEXT NOT NULL,
  "activity_key" TEXT NOT NULL,
  "source_version" INTEGER NOT NULL,
  "crm_customer_key" TEXT NOT NULL,
  "customer_key" TEXT,
  "staff_key" TEXT,
  "primary_product_code" TEXT NOT NULL,
  "occurred_at" TEXT NOT NULL,
  "channel" TEXT NOT NULL,
  "approval" TEXT NOT NULL,
  "duration_minutes" INTEGER NOT NULL,
  "modified_at" TEXT NOT NULL,
  "operation" TEXT NOT NULL,
  "delivery_batch" TEXT NOT NULL,
  PRIMARY KEY ("snapshot_id","activity_key","source_version")
);

CREATE TABLE IF NOT EXISTS "canonical_interaction_product" (
  "snapshot_id" TEXT NOT NULL,
  "activity_key" TEXT NOT NULL,
  "source_version" INTEGER NOT NULL,
  "product_code" TEXT NOT NULL,
  PRIMARY KEY ("snapshot_id","activity_key","source_version","product_code")
);

CREATE TABLE IF NOT EXISTS "canonical_consent_event" (
  "snapshot_id" TEXT NOT NULL,
  "preference_key" TEXT NOT NULL,
  "customer_key" TEXT,
  "contact_key" TEXT NOT NULL,
  "channel" TEXT NOT NULL,
  "purpose" TEXT NOT NULL,
  "status" TEXT NOT NULL,
  "effective_at" TEXT NOT NULL,
  "sequence_no" INTEGER NOT NULL,
  "delivery_batch" TEXT NOT NULL,
  PRIMARY KEY ("snapshot_id","preference_key")
);

CREATE TABLE IF NOT EXISTS "canonical_customer_territory" (
  "snapshot_id" TEXT NOT NULL,
  "assignment_key" TEXT NOT NULL,
  "customer_key" TEXT NOT NULL,
  "territory_code" TEXT NOT NULL,
  "effective_from" TEXT NOT NULL,
  "effective_to" TEXT,
  PRIMARY KEY ("snapshot_id","assignment_key")
);

CREATE TABLE IF NOT EXISTS "canonical_campaign" (
  "snapshot_id" TEXT NOT NULL,
  "campaign_key" TEXT NOT NULL,
  "product_code" TEXT NOT NULL,
  "start_date" TEXT NOT NULL,
  "end_date_exclusive" TEXT NOT NULL,
  "status" TEXT NOT NULL,
  PRIMARY KEY ("snapshot_id","campaign_key")
);

CREATE TABLE IF NOT EXISTS "canonical_campaign_member" (
  "snapshot_id" TEXT NOT NULL,
  "membership_key" TEXT NOT NULL,
  "campaign_key" TEXT NOT NULL,
  "customer_key" TEXT,
  "contact_key" TEXT NOT NULL,
  "member_status" TEXT NOT NULL,
  PRIMARY KEY ("snapshot_id","membership_key")
);

CREATE TABLE IF NOT EXISTS "canonical_rx_version" (
  "snapshot_id" TEXT NOT NULL,
  "observation_key" TEXT NOT NULL,
  "version_no" INTEGER NOT NULL,
  "customer_key" TEXT NOT NULL,
  "product_code" TEXT NOT NULL,
  "week_ending" TEXT NOT NULL,
  "trx_count" INTEGER NOT NULL,
  "nrx_count" INTEGER NOT NULL,
  "sales_units" INTEGER NOT NULL,
  PRIMARY KEY ("snapshot_id","observation_key","version_no")
);
