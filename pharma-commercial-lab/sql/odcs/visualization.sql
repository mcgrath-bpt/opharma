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
