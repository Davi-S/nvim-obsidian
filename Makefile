SHELL := /bin/bash

NVIM ?= nvim

.PHONY: fmt lint test test-unit test-integration test-e2e test-red

fmt:
	stylua lua tests plugin

lint:
	stylua --check lua tests plugin
	luacheck lua tests plugin

test: test-unit test-integration test-e2e

test-unit:
	$(NVIM) --headless -u tests/minimal_init.lua -c "PlenaryBustedDirectory tests/unit { minimal_init = 'tests/minimal_init.lua' }" -c qa

test-integration:
	$(NVIM) --headless -u tests/minimal_init.lua -c "PlenaryBustedDirectory tests/integration { minimal_init = 'tests/minimal_init.lua' }" -c qa

test-e2e:
	$(NVIM) --headless -u NONE "+lua dofile('tests/e2e/commands_smoke.lua')" "+qall"

test-red:
	$(NVIM) --headless -u tests/minimal_init.lua -c "PlenaryBustedDirectory tests/unit_red { minimal_init = 'tests/minimal_init.lua' }" -c qa
