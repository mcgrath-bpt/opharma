CREATE TABLE IF NOT EXISTS "consumption_s01_engagement" (
  "snapshot_id" TEXT NOT NULL,
  "as_of" TEXT NOT NULL,
  "activity_key" TEXT NOT NULL,
  "customer_key" TEXT NOT NULL,
  "activity_date" TEXT NOT NULL,
  "consent_status" TEXT NOT NULL,
  PRIMARY KEY ("snapshot_id","activity_key")
);

CREATE TABLE IF NOT EXISTS "consumption_s02_product_activity" (
  "snapshot_id" TEXT NOT NULL,
  "as_of" TEXT NOT NULL,
  "customer_key" TEXT NOT NULL,
  "product_code" TEXT NOT NULL,
  "activity_date" TEXT NOT NULL,
  "brand" TEXT NOT NULL,
  "therapy" TEXT NOT NULL,
  "interaction_count" INTEGER NOT NULL,
  PRIMARY KEY ("snapshot_id","customer_key","product_code","activity_date")
);

CREATE TABLE IF NOT EXISTS "consumption_s03_customer_territory" (
  "snapshot_id" TEXT NOT NULL,
  "as_of" TEXT NOT NULL,
  "customer_key" TEXT NOT NULL,
  "territory_code" TEXT,
  "assignment_status" TEXT NOT NULL,
  PRIMARY KEY ("snapshot_id","customer_key")
);

CREATE TABLE IF NOT EXISTS "consumption_s04_interaction" (
  "snapshot_id" TEXT NOT NULL,
  "as_of" TEXT NOT NULL,
  "activity_key" TEXT NOT NULL,
  "customer_key" TEXT NOT NULL,
  "primary_product_code" TEXT NOT NULL,
  "occurred_at" TEXT NOT NULL,
  "channel" TEXT NOT NULL,
  "duration_minutes" INTEGER NOT NULL,
  "source_version" INTEGER NOT NULL,
  PRIMARY KEY ("snapshot_id","activity_key")
);

CREATE TABLE IF NOT EXISTS "consumption_s05_campaign" (
  "snapshot_id" TEXT NOT NULL,
  "as_of" TEXT NOT NULL,
  "campaign_key" TEXT NOT NULL,
  "customer_key" TEXT NOT NULL,
  "product_code" TEXT NOT NULL,
  "contacted" INTEGER NOT NULL,
  "qualifying_interactions" INTEGER NOT NULL,
  PRIMARY KEY ("snapshot_id","campaign_key","customer_key")
);

CREATE TABLE IF NOT EXISTS "consumption_exceptions" (
  "snapshot_id" TEXT NOT NULL,
  "as_of" TEXT NOT NULL,
  "scenario" TEXT NOT NULL,
  "record_key" TEXT NOT NULL,
  "reason" TEXT NOT NULL,
  PRIMARY KEY ("snapshot_id","scenario","record_key","reason")
);

CREATE TABLE IF NOT EXISTS "consumption_dq" (
  "snapshot_id" TEXT NOT NULL,
  "as_of" TEXT NOT NULL,
  "scenario" TEXT NOT NULL,
  "scope" TEXT NOT NULL,
  "numerator" INTEGER NOT NULL,
  "denominator" INTEGER NOT NULL,
  "threshold" REAL NOT NULL,
  "status" TEXT NOT NULL,
  PRIMARY KEY ("snapshot_id","scenario","scope")
);
