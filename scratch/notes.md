
duckdb pharma crm template

Building a Pharmaceutical Customer Relationship Management (CRM) analytical model on top of DuckDB requires handling two main sets of data: HCPs (Healthcare Professionals/Doctors) and HCOs (Healthcare Organisations/Hospitals/Clinics), alongside compliance tracking, sample drops, and medical sales representative (Rep) activity.
DuckDB is ideal for this because pharmaceutical data involves heavily messy, disparate data sources (like regional doctor registries, conference lead exports, and sales logs) that need to be aggregated and cleaned locally.
Below is an optimized, local-first DuckDB Pharma CRM analytical schema template written in standard DuckDB SQL. It establishes core tables, tracking mechanisms (for compliance-heavy features like sample drops and medical inquiries), and an analytical view for territory performance.

🏢 1. Database Schema Template
-- ============================================================================
-- PHARMA CRM DATA ARCHITECTURE (DuckDB Template)
-- ============================================================================

-- 1. Healthcare Organisations (HCOs / Accounts)
CREATE TABLE IF NOT EXISTS hcos (
    hco_id VARCHAR PRIMARY KEY,
    name VARCHAR NOT NULL,
    type VARCHAR,                -- 'Hospital', 'Clinic', 'Pharmacy Network'
    specialty_focus VARCHAR,     -- 'Oncology', 'Cardiology', etc.
    address VARCHAR,
    city VARCHAR,
    territory_code VARCHAR NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 2. Healthcare Professionals (HCPs / Contacts)
CREATE TABLE IF NOT EXISTS hcps (
    hcp_id VARCHAR PRIMARY KEY,
    first_name VARCHAR,
    last_name VARCHAR NOT NULL,
    license_number VARCHAR UNIQUE, -- National registry ID (e.g., NPI in US)
    specialty VARCHAR NOT NULL,   -- 'Oncology', 'GP', 'Pediatrics'
    tier VARCHAR DEFAULT 'C',     -- 'A' (High prescriber), 'B', 'C'
    primary_hco_id VARCHAR REFERENCES hcos(hco_id),
    email VARCHAR,
    marketing_consent BOOLEAN DEFAULT FALSE,
    last_interaction_date DATE
);

-- 3. Products / Drug Portfolio
CREATE TABLE IF NOT EXISTS products (
    product_id VARCHAR PRIMARY KEY,
    brand_name VARCHAR NOT NULL,
    therapeutic_area VARCHAR,     -- 'Cardiovascular', 'Immunology'
    dosage_form VARCHAR,          -- 'Tablet', 'Injectable'
    launch_date DATE
);

-- 4. Medical Sales Representatives
CREATE TABLE IF NOT EXISTS reps (
    rep_id VARCHAR PRIMARY KEY,
    full_name VARCHAR NOT NULL,
    territory_code VARCHAR NOT NULL,
    role VARCHAR DEFAULT 'Medical Representative' -- 'MSL', 'Key Account Mgr'
);

-- 5. Call Logs & Interactions (The core CRM activity stream)
CREATE TABLE IF NOT EXISTS interactions (
    interaction_id VARCHAR PRIMARY KEY,
    rep_id VARCHAR REFERENCES reps(rep_id),
    hcp_id VARCHAR REFERENCES hcps(hcp_id),
    hco_id VARCHAR REFERENCES hcos(hco_id),
    interaction_date DATE NOT NULL,
    channel VARCHAR,              -- 'In-Person', 'Virtual Call', 'Email', 'Dinner Meeting'
    discussion_topic VARCHAR,     -- 'Product Launch', 'Clinical Trial Data'
    next_steps VARCHAR
);

-- 6. Sample Drops & Promotional Material Distribution (Strictly Monitored for Compliance)
CREATE TABLE IF NOT EXISTS sample_distributions (
    distribution_id VARCHAR PRIMARY KEY,
    interaction_id VARCHAR REFERENCES interactions(interaction_id),
    product_id VARCHAR REFERENCES products(product_id),
    quantity_dropped INTEGER NOT NULL,
    lot_number VARCHAR            -- Required for traceability and compliance
);


📊 2. Analytical Intelligence Layer

Pharma commercial excellence teams evaluate performance through Call Frequency (how often a Tier A doctor is visited) and Reach (percentage of targeted doctors visited).
Run this query to build a performance dashboard directly in DuckDB:

CREATE OR REPLACE VIEW v_rep_territory_performance AS
SELECT 
    r.full_name AS rep_name,
    r.territory_code,
    COUNT(DISTINCT i.interaction_id) AS total_visits,
    COUNT(DISTINCT i.hcp_id) AS distinct_hcps_reached,
    
    -- Track alignment with high-priority targets
    COUNT(DISTINCT CASE WHEN h.tier = 'A' THEN i.hcp_id END) AS tier_a_hcps_reached,
    
    -- Track sample allocation patterns
    COALESCE(SUM(sd.quantity_dropped), 0) AS total_samples_distributed
FROM reps r
LEFT JOIN interactions i ON r.rep_id = i.rep_id
LEFT JOIN hcps h ON i.hcp_id = h.hcp_id
LEFT JOIN sample_distributions sd ON i.interaction_id = sd.interaction_id
GROUP BY ALL;



📥 3. Quick Data Ingestion & Export

DuckDB excels at manipulating data pipelines without a heavy ETL server footprint. If your field reps log their notes in disparate spreadsheets or external cloud dumps, you can pipeline everything smoothly:
sql
-- Seed the database directly from your conference lead CSVs or external Parquet files
INSERT INTO hcps 
SELECT * FROM read_csv_auto('path/to/raw_crm_leads_export.csv');

-- Analyze target distribution on the fly
SELECT specialty, tier, COUNT(*) 
FROM hcps 
GROUP BY ALL 
ORDER BY COUNT(*) DESC;

-- Export clean lists directly into analytical tools (like PowerBI or Tableau)
COPY (SELECT * FROM v_rep_territory_performance) 
TO 'territory_report.parquet' (FORMAT PARQUET);
Use code with caution.

💡 Implementation Tips for Pharma CRMs

1. Compliance Tracking: To adapt this for local regulatory requirements (such as Sunshine Act or EFPIA reporting), link sample_distributions data alongside monetary expenditures (e.g., promotional meals) directly into the interactions table.
2. AI-Ready Analytics: If you link DuckDB to Python (via tools like Streamlit, Marimo, or scikit-learn), this relational structure maps cleanly into graph analytics for tracking doctor referral paths or prescription intent modeling.
Would you like help adapting this template to a specific stack—such as a Python Streamlit dashboard, a dbt-core layer, or implementing a master patient-blinded registry layer? Let me know what your end-user architecture looks like!
