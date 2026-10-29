# opharma — ODCS pharma commercial development baseline

This README records the repository review, implementation, dataset updates, verification and deliverables completed today. It also explains how to use the resulting project.

The result is a locally validated development and acceptance baseline for the five initial pharma investigations, S1–S5. It has **five ODCS contracts**, a **14-delivery synthetic dataset**, a **persistent Python/SQLite model**, generated **Snowflake SQL/Python deployment assets**, and a **Power BI / Analysis Services TMDL semantic model**. Airflow, Jenkins, Collibra, Ataccama and Immuta have explicit integration assets and remaining acceptance steps.

**Current package: v0.2.1.** The source dataset retains release identity `pharma-lab-0.2.0`. Four contracts remain at version `0.2.0`; the visualization contract is `0.2.1` following the correction from the initial ThoughtSpot assumption to **TMDL — Tabular Model Definition Language**. Use v0.2.1 for further work; the earlier v0.2.0 ZIP has the superseded visualization handoff.

This change brings the implementation and work record into `opharma` under `pharma-commercial-lab/`, preserving the original exploratory notes in `scratch/`. The standalone `mcgrath-bpt/pharma-commercial-lab` repository is unchanged by this PR. No external data platform has been deployed or configured through this work.

**For a Git checkout:** all source fixtures, modeled CSV exports, contracts and acceptance evidence are committed. The generated SQLite database is omitted from Git; run the local workflow below to build it. Root `make` and `Jenkinsfile` entry points run the implementation in its subdirectory.

## Contents

- [Repositories and deliverables](#repositories-and-deliverables)
- [Review findings and fixes](#review-findings-and-fixes)
- [ODCS adoption](#odcs-adoption)
- [Updated sources and modeled schema](#updated-sources-and-modeled-schema)
- [The five investigations](#the-five-investigations)
- [Recurring dataset and hydration](#recurring-dataset-and-hydration)
- [Measured results](#measured-results)
- [TMDL semantic model](#tmdl-semantic-model)
- [Run locally](#run-locally)
- [Target platform assets](#target-platform-assets)
- [Verification and remaining work](#verification-and-remaining-work)

## Repositories and deliverables

The two repositories reviewed were:

| Repository | Reviewed base commit | Role in the updated project |
|---|---|---|
| [mcgrath-bpt/pharma-commercial-lab](https://github.com/mcgrath-bpt/pharma-commercial-lab) | `912713205f7d738dff330db5d00c04121b099af1` | Main executable implementation, contracts, source fixtures, model, tests and target assets |
| [mcgrath-bpt/opharma](https://github.com/mcgrath-bpt/opharma) | `26b04c45f8ca8d5a61758beb6991872a572ed75d` | Exploratory schema/SQL notes; README now points to the shared implementation and contracts |

`opharma` was an exploratory repository, rather than a second runnable application. Its representative view was corrected to retain `rep_id` when grouping representatives who can share a name.

The source files were obtained through the GitHub connector because direct cloning was unavailable in this environment. Those snapshots are the provenance of this import; the new feature branch is based on the current `opharma` main branch.

### Where to find the work

Paths below are relative to this README and remain usable when the two project directories are kept together.

| Deliverable | Location |
|---|---|
| Initial code review | [code-review.md](code-review.md) |
| Main project README | [pharma-commercial-lab/README.md](pharma-commercial-lab/README.md) |
| Detailed operating guide | [docs/ODCS_OPERATIONS.md](pharma-commercial-lab/docs/ODCS_OPERATIONS.md) |
| Five active ODCS contracts | [contracts/odcs/](pharma-commercial-lab/contracts/odcs/) |
| Recurring fixture configuration | [config/operations.json](pharma-commercial-lab/config/operations.json) |
| Public source deliveries | [data/operations-release/public_s3/](pharma-commercial-lab/data/operations-release/public_s3/) |
| Persistent local database | Generated at `pharma-commercial-lab/data/operations/model-v02.sqlite` by the local runner |
| Daily modeled CSV exports | [model_export/b014/](pharma-commercial-lab/data/operations-release/model_export/b014/) |
| Latest Monday modeled CSV exports | [model_export/b012/](pharma-commercial-lab/data/operations-release/model_export/b012/) |
| Historical scorecard CSV and manifest | [model_export/history/](pharma-commercial-lab/data/operations-release/model_export/history/) |
| TMDL semantic model | [PharmaCommercial.SemanticModel/definition/](pharma-commercial-lab/integrations/powerbi/PharmaCommercial.SemanticModel/definition/) |
| Semantic model binding and acceptance plan | [powerbi/visualization-plan.json](pharma-commercial-lab/integrations/powerbi/visualization-plan.json) |
| Generated Snowflake scripts | [build/snowflake/](pharma-commercial-lab/build/snowflake/) |
| Machine-readable verification record | [evidence/odcs-operations-verification.json](pharma-commercial-lab/evidence/odcs-operations-verification.json) |
| Test execution log | [evidence/operations-tests.txt](pharma-commercial-lab/evidence/operations-tests.txt) |
| File inventory and hashes | [release-manifest.json](pharma-commercial-lab/release-manifest.json) |

The original crawl implementation and documentation remain available. Some original scenario documents quote the two-checkpoint crawl fixture's counts and open-work status. For today's recurring implementation, use this README, the ODCS operating guide and the v0.2.1 verification record.

## Review findings and fixes

The initial review identified six issues. The [review report](code-review.md) records the original locations, reasoning and validation limits. Statements there about code not yet being patched refer to the review stage; the subsequent implementation includes the fixes described here.

| Finding | Resulting change | Verification or limit |
|---|---|---|
| One CRM/customer or Salesforce/contact key could resolve to different approved providers depending on input order | Resolve only an unambiguous source-key-to-provider mapping; ambiguous identities remain unmatched | Python regression covers both record orders; SQL mapping also checks source-key uniqueness |
| Malformed versions or timezone-free timestamps could abort the whole calculation | Validate fields during record classification and quarantine invalid records without replacing trusted state | Tests cover blank, nonnumeric and invalid integer versions, missing/invalid timestamps and malformed durations |
| Reconciliation ignored extra output cells | Reject malformed row widths before exact result comparison | A surplus-cell regression proves reconciliation now fails |
| Historical consent conflict detection depended on row order | Check every consent rank for conflicting statuses separately from choosing the latest effective consent | Regression covers historical-first and latest-first orderings |
| Identical product redelivery could be mistaken for conflicting hierarchy | Compare business payload independently of transport metadata | The recurring fixture includes unchanged product redelivery and reconciles successfully |
| The exploratory representative view could merge different reps sharing a name | Include `rep_id` in the projection/grouping | Draft SQL was updated; the original issue was reproduced locally with equivalent SQLite grouping, not executed in DuckDB/Snowflake |

Additional operational regressions cover late identical activity redelivery, strict integer parsing, threshold boundaries, rollback and repaired retry, and preservation of previously accepted state when a later record is invalid.

## ODCS adoption

The implementation uses the **Open Data Contract Standard, version 3.1.0**. The official JSON schema, license and provenance are vendored under [contracts/vendor/](pharma-commercial-lab/contracts/vendor/), allowing offline validation once the Python dependency is installed.

The five contracts are ownership and authoring bundles. They collectively describe **43 schema objects**; they do not restrict the project to five physical tables.

| Contract ID | Version | Objects | Responsibilities |
|---|---|---:|---|
| `pharma.commercial.source` | `0.2.0` | 15 | Source columns, business keys, semantic types, schema editions, delivery modes, manifest bindings and freshness |
| `pharma.commercial.canonical` | `0.2.0` | 13 | Typed source-derived entities, version/history rules, snapshot grains, relationships and nullable unresolved identity |
| `pharma.commercial.pipeline` | `0.2.0` | 7 | S1–S5 transformations, exceptions, DQ evidence and scenario semantics |
| `pharma.commercial.consumption` | `0.2.0` | 7 | Stable analyst outputs and daily/Monday publication behavior |
| `pharma.commercial.visualization` | `0.2.1` | 1 | Scorecard grain/types and links to TMDL definitions, scoped measures and source bindings |

All contracts have **proposed** status and proposed ownership. Production stewardship and approval still need real owners.

### How contracts affect operation

- Source files are bound to a contract ID, version and SHA-256, with a separate source schema edition per entity.
- Validation checks exact headers, counts, file bytes/hashes and ready-marker bindings.
- Canonical foreign relationships include the reporting snapshot in their keys.
- Modeled data passes required-field, type, uniqueness, relationship, interval and measure checks before publication.
- The compatibility checker rejects specified breaking changes unless the contract has an appropriate major-version change.
- Each local database is bound to one source release and one complete contract-registry fingerprint.
- Governance handoffs and TMDL annotations retain contract IDs, versions and registry bindings.

The current registry fingerprint is:

```text
27073c77045040ad84e10495e2a2a19995bfd7b94d1c9fdb0ca8b05ca8bf2cbe
```

The TMDL correction changed that fingerprint. The delivered database was therefore rebuilt and all 14 checkpoints reconciled again, rather than silently rebinding old published snapshots.

Airflow DAGs and TMDL files are separate artifacts referenced through ODCS custom properties. They are not treated as native ODCS workflow or semantic-model syntax.

## Updated sources and modeled schema

### Public source entities

The fixture provides imperfect synthetic projections in the following source dialects:

| Source family | Entities |
|---|---|
| IQVIA-like | `provider`, `organisation`, `affiliation`, `product`, `rx_weekly` |
| Veeva-like | `customer`, `staff`, `territory`, `activity`, `activity_product` |
| Salesforce-like | `contact`, `consent`, `campaign`, `campaign_member` |
| Manual business file | `territory_mapping` |

Source CSV values retain a text representation at the ingestion boundary. Semantic types and modeled types are separately declared and enforced.

The updated activity feed adds **`staff_key`**, enabling representative attribution at interaction/version grain. That entity has source schema edition **2.0**; other source entities retain edition **1.0**. Source schema editions are distinct from ODCS contract versions.

A deterministic territory XLSX workbook, CSV adapter and provenance receipt support the monthly business-file route. The workbook conversion was tested for byte-identical CSV output. The CSV loader consumes the converted file.

### Canonical model

The public-source canonical model contains the following 13 entities. Every primary grain also includes `snapshot_id`.

| Entity | Grain or temporal behavior |
|---|---|
| `organisation` | Approved source organisation |
| `affiliation` | Customer–organisation effective relationship |
| `representative` | Public staff identifier |
| `customer` | Approved provider inventory, retaining inactive providers |
| `product_interval` | Product and effective-from interval; half-open end |
| `territory` | Territory reference identifier |
| `interaction_version` | Structurally accepted activity/version, including tombstones and staff attribution |
| `interaction_product` | Accepted activity/version/product details; complete detail replacement |
| `consent_event` | Delivered preference events; future-effective events retained but excluded from current selection |
| `customer_territory` | Delivered effective assignment; latest current effective-from wins |
| `campaign` | Campaign/product and inclusive-start, exclusive-end window |
| `campaign_member` | Membership with nullable unresolved customer identity |
| `rx_version` | Versioned weekly commercial observations; replacements are nonadditive |

Keys are public source keys. The ingestion and transformation code does not read the evaluator's hidden identity crosswalk.

The independent private evaluator retains its 16-entity truth model. It supplies acceptance expectations, not operational inputs. Rep–territory history and other unavailable public feeds were not invented simply to fill the public model.

## The five investigations

| Use case | Published output and grain | Main rules |
|---|---|---|
| S1: engagement and consent | `s01_engagement`: one approved interaction per snapshot | Unique active approved customer match; current granted commercial consent at reporting cutoff; exclude withdrawn/missing consent; identity alert above 2%; target deadline 07:00 UTC |
| S2: activity and product | `s02_product_activity`: customer/product/activity date | Distinct interaction count; current approved product hierarchy; retain valid product details and flag unknown references; unknown-product alert above 1%; target deadline 06:30 UTC |
| S3: customer and territory | `s03_customer_territory`: active approved customer | Half-open effective intervals; most recently effective current assignment; retain missing-territory rows with an exception; conflicting tied assignments fail |
| S4: late arrivals and corrections | `s04_interaction`: latest accepted nondeleted activity | Seven-calendar-day lateness rules; accepted corrections replace prior state; tombstones suppress downstream records; malformed or late records do not overwrite trusted state |
| S5: campaign effectiveness | `s05_campaign`: campaign/customer, with associated product | Enrolled approved members; zero-contact rows retained; approved interactions within the campaign window; cancelled campaigns excluded; unmatched-member alert above 5% per campaign; Monday publication |

S1 uses consent at the reporting cutoff, so a withdrawal can remove historical engagement from the current view. S2 uses hierarchy current at cutoff, so a product hierarchy update can restate prior activity dates. Consent is not added as an extra filter to S2 or S5.

S5 contact counts are campaign-to-date through the cutoff. An interaction can qualify for overlapping campaigns; these counts are descriptive, not causal attribution.

Pipeline and consumption each also contain `exceptions` and `dq`. S3/S4 diagnostics must be inspected through exceptions; the absence of a percentage-rate alert does not imply that every record is clean.

## Recurring dataset and hydration

### Fixture configuration

| Setting | Delivered value |
|---|---|
| Dataset release | `pharma-lab-0.2.0` |
| Seed | `20261008` |
| Delivery calendar | 1–14 October 2026 |
| Deliveries | 14 ordered checkpoints, `b001`–`b014` |
| Declared source availability | 05:00 UTC |
| Logical reporting cutoff | 06:00 UTC |
| Initial historical interactions | 300 |
| New interactions | 24 per daily delivery after the first two checkpoints |
| Population | 100 invented HCPs, 12 HCOs, 4 products, 4 territories, 8 representatives and 5 campaigns |
| Active approved HCPs in business outputs | 99 |
| Public delivery inventory | 50 manifest-listed files containing 5,979 rows |

The calendar is a synthetic logical-time simulation. Checkpoints after today's date are fixture data, not evidence that those source deliveries happened in the real world.

### Deliberate investigation events

| Checkpoint | Event |
|---|---|
| `b001` | Historical bootstrap, unresolved identity, unknown products, duplicates, missing territory/consent and campaign boundary cases |
| `b002` | Seven/eight-day late boundaries, correction, tombstone, missing interaction date, consent withdrawal and hierarchy changes |
| `b004` | Further consent withdrawal delivered after its effective time |
| `b005` | Identical product redelivery; first Monday S5 publication; commercial restatement |
| `b007` | Territory realignment delivered after its 6 October effective date; invisible at `b006` |
| `b008` | Consent restoration |
| `b009` | Revised product hierarchy and an eight-day-late event |
| `b010` | Malformed interaction version and missing date |
| `b012` | Second Monday S5 publication and commercial restatement |

Corrections and tombstones recur across the calendar. [scenario-events.json](pharma-commercial-lab/data/operations-release/scenario-events.json) records the added fixture events.

### Operational behavior

A batch is visible only after its exact files and manifest pass validation. Raw ingestion, canonical snapshots, scenario outputs, quality evidence, consumption and the publication ledger commit atomically in SQLite.

Identical replay adds no rows. A changed manifest cannot reuse the same published identity. Missing predecessors are rejected. A failed batch rolls back its data changes while retaining failure information in `run_log`; a repaired batch can then be retried.

S1–S4 current consumption views select the latest completed daily checkpoint. S5 current consumption selects the latest completed Monday checkpoint. Daily S5 calculations remain available for diagnostics between weekly publications.

A business `ALERT` can accompany correct publication. Structural/type/key/relationship errors block publication; expected data-quality exceptions and correctly calculated percentage alerts are part of the investigation outputs.

The generator creates a finite simulation, configurable for 10–90 deliveries. It is not a continuously running upstream producer. Semi-regular operation uses new ordered, immutable source batches with the same manifest and contract rules. Reference effectiveness and delivery visibility remain separate.

## Measured results

The validated local database has **14 published checkpoints**, with every checkpoint reconciled against independently generated expected outputs. SQLite integrity returned `ok`.

### Current analyst datasets

The counts below were read from the delivered database on 8 October 2026.

| Current view | Snapshot | Rows | Additional result |
|---|---|---:|---|
| `consumption_s01_engagement_current` | `b014` | 549 | Approved, currently consented engagement |
| `consumption_s02_product_activity_current` | `b014` | 576 | Sum of interaction counts: 578; customer/product/day grain |
| `consumption_s03_customer_territory_current` | `b014` | 99 | All active approved customers retained |
| `consumption_s04_interaction_current` | `b014` | 586 | Latest accepted nondeleted activity |
| `consumption_s05_campaign_current` | `b012` | 79 | 21 contacted rows and 33 qualifying campaign interactions |

S2's aggregate count can exceed a distinct activity population because one interaction can discuss multiple products. S5's measures can count an interaction in more than one campaign by design.

The `b014` snapshot-specific S5 consumption CSV is empty because 14 October is a Wednesday. That is expected. The live weekly view and TMDL weekly CSV binding retain Monday `b012`.

### Data-quality evidence

At `b014`, the S1 unmatched-identity count is **18 / 579**, above its 2% budget, and its status is `ALERT`. S2 unknown-product evidence is **2 / 579**, within the 1% budget, and its status is `PASS`.

These are deliberately imperfect synthetic source results. Passing acceptance means the model calculates and classifies them correctly, not that the fixture has no defects.

### Acceptance totals

| Check | Result |
|---|---|
| Official ODCS validation | All five contracts validated |
| Independent checkpoint reconciliation | 14 / 14 passed |
| Quality evaluations | 756 / 756 passed: 54 per checkpoint |
| Test suite | 35 tests: 34 passed, 1 skipped |
| Daily modeled export | `b014`: 28 CSV objects, 9,602 rows across layers |
| Monday modeled export | `b012`: 28 CSV objects, 9,299 rows across layers |
| Scorecard history export | 112 rows across 14 snapshots |
| Typed export manifests | Registry fingerprints and file hashes verified |
| S3 upload | Local validation/dry run only |

Cross-layer export totals count rows in canonical, pipeline, consumption and visualization objects. They are not unique-person or unique-interaction totals.

The skipped test concerns the original remote v0.1 workbook, which was not retrieved. The newly generated v0.2 deterministic workbook has its own passing conversion/reproducibility tests.

## TMDL semantic model

The visualization requirement was clarified to mean **Tabular Model Definition Language**, used by Power BI and Analysis Services. The earlier ThoughtSpot assets were removed from the current package, the visualization contract was patched, and affected exports/target bindings were regenerated.

The delivered semantic model contains **10 TMDL files, seven tables and 16 explicit DAX measures**, plus `definition.pbism` and a binding/acceptance plan.

| Semantic table | Purpose |
|---|---|
| `S1 Engagement` | Distinct engagement activities |
| `S2 Product Activity` | Product interaction counts by customer/product/day |
| `S3 Customer Territory` | Customer counts by territory and assignment status |
| `S4 Interaction` | Latest interaction counts and feed attributes |
| `S5 Campaign` | Membership counts, contacted rows, campaign reach and qualifying interactions |
| `Scenario Scorecard` | Latest daily scoped quality and output measures |
| `Scenario Scorecard History` | Snapshot-by-snapshot quality/output comparisons |

### Semantic rules

- Identifier and threshold columns use `summarizeBy: none`; measures are explicit DAX.
- Quality rates use a ratio of summed numerators and denominators within a single snapshot/scenario/scope.
- Rates return blank for zero denominators and S3/S4 diagnostic scenarios.
- History measures guard against totals spanning multiple snapshots.
- Thresholds are fractions: `0.02` displays as `2%` without dividing by 100 again.
- Campaign reach is a contacted-row ratio at the contracted campaign/customer grain, with one associated product per campaign. It is not a distinct-customer reach metric across campaigns.
- The scenario facts are independent. No fact-to-fact joins or shared-customer relationship assumptions have been introduced.
- Each table retains ODCS contract, version, grain and registry annotations.

### Local CSV mode

The default `DataSourceMode` is `CSV`. In [expressions.tmdl](pharma-commercial-lab/integrations/powerbi/PharmaCommercial.SemanticModel/definition/expressions.tmdl), replace placeholder paths with absolute paths on the machine running the semantic engine:

| Parameter | Value to configure |
|---|---|
| `DailyCsvFolder` | Absolute path to `data/operations-release/model_export/b014` |
| `WeeklyCsvFolder` | Absolute path to `data/operations-release/model_export/b012` |
| `HistoryCsvFile` | Absolute path to `data/operations-release/model_export/history/visualization_scenario_scorecard.csv` |

For a new delivery, export the new daily snapshot and point the daily folder to it. Advance the weekly folder only when a new Monday snapshot is published. Regenerate history as needed.

### Snowflake mode

Set `DataSourceMode` to `Snowflake`, then configure `SnowflakeServer`, `SnowflakeWarehouse`, `SnowflakeDatabase` and `SnowflakeSchema`. The generated import partitions use published current views and the scorecard history table. Configure authentication in the client/service connection rather than in source files.

The definitions follow the [Microsoft TMDL documentation](https://learn.microsoft.com/en-us/analysis-services/tmdl/tmdl-overview), [Power BI semantic model folder format](https://learn.microsoft.com/en-us/power-bi/developer/projects/projects-dataset) and [Snowflake connector documentation](https://learn.microsoft.com/en-us/power-query/connectors/snowflake).

### Microsoft-engine acceptance still required

Local checks validate contract/type/column bindings, DAX field references, scoped-rate guards and CSV row-count parity. **Microsoft TOM parsing, DAX compilation and Power Query refresh have not been executed.**

In a TOM-enabled environment, parse the definition folder using `TmdlSerializer.DeserializeDatabaseFromFolder(path)`, then compile and process it on the chosen engine. For Power BI Desktop, place the definitions into an existing TMDL-enabled PBIP semantic model while preserving the report binding/platform metadata. Compare imported counts and measures against the exported evidence.

This is a semantic-model deliverable, not a finished report or complete PBIP report project. Workspace access/RLS and service refresh also need acceptance. Import mode caches data, so Snowflake/Immuta source policy enforcement alone does not establish per-viewer permissions on that cache.

## Run locally

The core development route uses Python, SQLite and the open-source `jsonschema` validator. TMDL generation uses the Python standard library. Power BI/Analysis Services remains the target semantic engine.

The examples use a POSIX shell. Start in the repository root and enter `pharma-commercial-lab` as shown below. Python 3.10 or newer is a practical baseline for the project source; the delivered requirements pin `jsonschema==4.26.0`. Installing dependencies requires normal package access or an existing local installation.

### 1. Validate and replay the delivered model

```sh
cd pharma-commercial-lab
python3 -m venv .venv
.venv/bin/python -m pip install -r requirements-dev.txt
.venv/bin/python src/odcs.py
.venv/bin/python src/run_operations.py
.venv/bin/python -m unittest discover -s tests -v
```

On the first run from this Git checkout, the runner hydrates a new database from the committed fixture. Subsequent runs verify identical replay. The original ZIP distribution also includes the validated database. If the default fixture is absent, the runner generates it from configuration. It also performs evaluator reconciliation; it is the local acceptance runner.

Expected baseline: five valid contracts, 14 reconciled checkpoints, 34 passed tests and one legacy workbook skip.

### 2. Build a separate database from the same source release

Use a new destination for an independent rebuild:

```sh
.venv/bin/python src/run_operations.py \
  --data data/operations-release \
  --db data/operations/model-rebuild.sqlite
```

This leaves the delivered database intact. A database bound to an earlier registry cannot be reused after contract changes without a rebuild or reviewed migration.

### 3. Run the public-source-only operational path

For a fresh source-only database, hydrate predecessors in order:

```sh
.venv/bin/python src/hydrate_operations.py \
  --public-root data/operations-release/public_s3 \
  --db data/operations/model-source-only.sqlite \
  --batch b001 --exports /tmp/pharma-source-b001

.venv/bin/python src/operate_date.py \
  --public-root data/operations-release/public_s3 \
  --db data/operations/model-source-only.sqlite \
  --date 2026-10-02
```

These entry points consume public deliveries; they do not read evaluator truth. `operate_date.py` selects the due manifest from its logical date.

### 4. Regenerate CSV and integration assets

```sh
.venv/bin/python src/export_model.py \
  --db data/operations/model-v02.sqlite --snapshot b014 \
  --out data/operations-release/model_export/b014

.venv/bin/python src/export_model.py \
  --db data/operations/model-v02.sqlite --snapshot b012 \
  --out data/operations-release/model_export/b012

.venv/bin/python src/export_model.py \
  --db data/operations/model-v02.sqlite --history \
  --out data/operations-release/model_export/history

.venv/bin/python src/export_integrations.py
```

Exports include manifest hashes and registry bindings. Integration generation writes governance handoffs and TMDL source definitions; it does not contact vendors. It regenerates TMDL parameter placeholders, so apply environment-specific bindings after generation or automate them in deployment configuration.

### 5. Inspect publication and quality evidence

This read-only example needs no SQLite command-line installation:

```sh
.venv/bin/python - <<'PY'
import sqlite3
from pathlib import Path
path = Path('data/operations/model-v02.sqlite').resolve()
with sqlite3.connect(path.as_uri() + '?mode=ro', uri=True) as db:
    print('Published snapshots:', db.execute(
        'SELECT snapshot_id, as_of FROM batch_audit ORDER BY snapshot_id'
    ).fetchall())
    print('Quality checks, passed:', db.execute(
        'SELECT COUNT(*), SUM(passed) FROM quality_evidence'
    ).fetchone())
    print('Weekly current:', db.execute(
        'SELECT DISTINCT snapshot_id FROM consumption_s05_campaign_current'
    ).fetchall())
PY
```

### 6. Extend the fixture calendar

Edit a copy of `config/operations.json`, use a distinct `release_id`, and generate into an empty directory. `delivery_count` supports 10–90 checkpoints; seed, volume and timing are configurable. The generator refuses to overwrite a nonempty destination. See its CLI help before running:

```sh
.venv/bin/python src/generate_operations.py --help
```

Use a separate database for the new release. Do not mutate previously published source batches to simulate updates; publish new corrections, tombstones, intervals/events or replacement versions instead.

Normal operations validate existing contracts. `src/build_contracts.py` is the authoring generator and should be run intentionally when changing contract definitions, not as a silent hydration step.

## Target platform assets

| Platform | Delivered work | Current execution status |
|---|---|---|
| Snowflake SQL/Python | Typed DDL, exact-file loading, source-derived canonical/Gold calculations, checked publication, replay harness and query-ID evidence support | 14 checkpoints rendered; not executed against Snowflake |
| Airflow | Daily 06:00 UTC DAG, logical-date selection, serial catchup, retries, contract validation and local/Snowflake adapter selection | DAG compiled; not deployed |
| Jenkins | Dependency setup, ODCS validation/evolution gate, regression/recovery tests, isolated recurring acceptance and artifact archiving | Pipeline supplied; not executed in Jenkins |
| Collibra | 43 contract-bound assets with fields/ownership/classification and 78 dataset lineage edges | Vendor-neutral handoff generated; not imported |
| Ataccama | 54 quality rule definitions and connection/parameter requirements | Vendor-neutral handoff generated; not imported/executed in ONE |
| Immuta | Object-level role/purpose/classification intent and public/evaluator boundary | Policy intent generated; tenant policies not enforced |
| Power BI / Analysis Services | Seven-table TMDL model, 16 DAX measures, CSV/Snowflake partitions and ODCS annotations | Static/data checks passed; Microsoft engine not executed |
| S3 | Conditional public-tree uploader and integrity checks | Dry run validated; no upload performed |

### Render Snowflake assets

From the main project directory:

```sh
.venv/bin/python src/render_operations_sql.py \
  --public-root data/operations-release/public_s3 \
  --stage PHARMA_LAB.INGEST.EXISTING_STAGE \
  --schema PHARMA_LAB.PHARMA_MODEL \
  --out build/snowflake
```

The stage/schema names are example bindings, not provisioned infrastructure. The existing stage must expose the public source tree at its URL root. Only the public tree is an upload input.

The script order is setup once, then loading, Gold calculation and checked publication for each ordered batch. Explicit uniqueness checks are required because standard Snowflake table primary keys do not enforce uniqueness.

After providing a real named Snowflake connection, warehouse, stage and permissions, install `requirements-snowflake.txt` and use `src/run_operations_snowflake.py`. Capture query IDs and reconcile each exported checkpoint before claiming cloud parity. The operating guide contains the full target command.

### Configure orchestration and governance

Deploy [the Airflow DAG](pharma-commercial-lab/orchestration/dags/pharma_odcs_daily.py) with worker project paths/dependencies and the selected engine connection. Maintain a single writer and validate failed-delivery repair/catchup behavior.

Configure [the Jenkinsfile](pharma-commercial-lab/Jenkinsfile) against the actual SCM and build agents. Its PR evolution check needs the target branch fetched; local source snapshots have no Git history to supply that comparison automatically.

The Collibra, Ataccama and Immuta files are **vendor-neutral handoff records**, not tested native import payloads for a particular tenant/version. Bind actual asset/relation types, stewards, rule APIs, groups and attributes; then validate import/execution and access outcomes. These adapters need real target acceptance.

## Verification and remaining work

The durable record is [evidence/odcs-operations-verification.json](pharma-commercial-lab/evidence/odcs-operations-verification.json), supported by the test log, checkpoint reconciliation report, modeled export manifests and release inventory.

Tests cover the original crawl behavior and the new recurring model: all daily checkpoints, source/registry bindings, nonadditive replay, ordering, rollback/repaired retry, identity ambiguity, malformed inputs, consent conflicts, hierarchy changes, late reference visibility, representative attribution, weekly consumption, workbook conversion and generated SQL/TMDL bindings.

The delivered baseline supports local investigation and semi-regular hydration. Before treating it as an operational target deployment, complete the following work:

1. **Approve ownership and contracts.** Assign real producer/consumer owners and agree contract evolution, delivery and alert responsibilities.
2. **Execute a Snowflake pilot.** Bind the existing stage and schema; prove source-only S2/S4 first, then territory/XLSX S3, and reconcile every checkpoint. Accept S1/S5 after identity, consent, hierarchy and weekly behavior are established.
3. **Validate the semantic engine.** Parse TMDL with Microsoft TOM, compile DAX, refresh CSV/Snowflake partitions, compare measures, and create the actual Power BI reports.
4. **Deploy orchestration and CI.** Execute Airflow/Jenkins jobs, test catchup and repair, and prove real freshness and deadline behavior. Logical fixture times do not establish S2's 06:30 or S1's 07:00 completion.
5. **Implement notification delivery.** Route percentage alerts and S3/S4 exceptions to agreed recipients; no notifier has been deployed.
6. **Accept catalog, quality and policy integrations.** Import/match handoffs to actual Collibra/Ataccama/Immuta APIs and prove allowed/denied access, including Power BI cached-data access.
7. **Connect ongoing producers.** Supply new immutable ordered batches under the agreed contract/cadence; the fixture generator remains a development simulator.

No live S3, Snowflake, Microsoft semantic-engine, Jenkins or governance-tenant result is implied by the passing local acceptance evidence.
