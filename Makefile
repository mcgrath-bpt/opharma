PYTHON ?= python3

.PHONY: contracts fixture operate test integration-export snowflake-render
contracts fixture operate test integration-export snowflake-render:
	$(MAKE) -C pharma-commercial-lab $@ PYTHON=$(PYTHON)
