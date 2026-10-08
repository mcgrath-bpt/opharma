PYTHON ?= python3
DATA ?= data/operations-release
DB ?= data/operations/model-v02.sqlite

.PHONY: contracts fixture operate test integration-export snowflake-render
contracts:
	$(PYTHON) src/odcs.py
fixture:
	$(PYTHON) src/generate_operations.py --out $(DATA)
operate:
	$(PYTHON) src/run_operations.py --data $(DATA) --db $(DB)
test:
	$(PYTHON) -m unittest discover -s tests -v
integration-export:
	$(PYTHON) src/export_integrations.py
snowflake-render:
	$(PYTHON) src/render_operations_sql.py --public-root $(DATA)/public_s3 --stage $(STAGE) --schema $(SCHEMA) --out build/snowflake
