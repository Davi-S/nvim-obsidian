SHELL := /bin/bash

NVIM ?= nvim

.PHONY: fmt lint test test-unit test-integration test-e2e

fmt:
	stylua lua tests plugin

lint:
	stylua --check lua tests plugin
	luacheck lua tests plugin

test: test-unit test-integration test-e2e

test-unit:
	$(NVIM) --headless -u tests/minimal_init.lua -c "PlenaryBustedDirectory tests/spec { minimal_init = 'tests/minimal_init.lua' }" -c qa

test-integration:
	$(NVIM) --headless -u tests/minimal_init.lua -c "PlenaryBustedDirectory tests/integration { minimal_init = 'tests/minimal_init.lua' }" -c qa

test-e2e:
	$(NVIM) --headless -u NONE "+lua dofile('tests/e2e/core_workflows.lua')" "+qall"
