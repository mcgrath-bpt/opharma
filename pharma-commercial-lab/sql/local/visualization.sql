CREATE TABLE IF NOT EXISTS "visualization_scenario_scorecard" (
  "snapshot_id" TEXT NOT NULL,
  "as_of" TEXT NOT NULL,
  "scenario" TEXT NOT NULL,
  "scope" TEXT NOT NULL,
  "output_rows" INTEGER NOT NULL,
  "exception_rows" INTEGER NOT NULL,
  "numerator" INTEGER NOT NULL,
  "denominator" INTEGER NOT NULL,
  "threshold" REAL NOT NULL,
  "status" TEXT NOT NULL,
  "scheduled" INTEGER NOT NULL,
  PRIMARY KEY ("snapshot_id","scenario","scope")
);
