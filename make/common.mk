SHELL := /bin/bash
.SHELLFLAGS := -eu -o pipefail -c

ROOT_DIR ?= $(abspath $(dir $(firstword $(MAKEFILE_LIST))))
TF ?= $(shell command -v tofu 2>/dev/null)
TF_DIR ?= $(ROOT_DIR)
TEST_DIRS ?= $(TF_DIR)
TF_ARGS ?=
PREFLIGHT ?= creds-preflight
TF_PRELUDE ?= true
TOFU_VERSION_FILE := $(abspath $(ROOT_DIR)/../.opentofu-version)
PLAN_DIR := $(TF_DIR)/.plans
CHANGE_PLAN := $(PLAN_DIR)/change.tfplan
DESTROY_PLAN := $(PLAN_DIR)/destroy.tfplan
ROOT_NAME := $(notdir $(ROOT_DIR))
PLUGIN_CACHE_DIR := $(abspath $(ROOT_DIR)/../.terraform-plugin-cache)

.DEFAULT_GOAL := help

ifeq ($(strip $(TF)),)
$(error OpenTofu is not installed)
endif

.PHONY: help init plan apply destroy-plan destroy output fmt fmt-check validate test check version-check creds-preflight

help:
	@printf '%s\n' \
	  'Targets:' \
	  '  make init | plan | apply | output' \
	  '  make destroy-plan' \
	  '  make destroy CONFIRM="destroy $(ROOT_NAME)"' \
	  '  make fmt | fmt-check | validate | test | check' \
	  '' \
	  'Overrides: TF=/path/to/tofu TF_ARGS="..."'

version-check:
	@expected="$$(tr -d '[:space:]' < "$(TOFU_VERSION_FILE)")"; \
	actual="$$($(TF) version | awk 'NR == 1 { sub(/^OpenTofu v/, ""); print }')"; \
	[ "$$actual" = "$$expected" ] || { printf 'OpenTofu %s is required; found %s.\n' "$$expected" "$$actual" >&2; exit 1; }

init: version-check
	@$(TF_PRELUDE); "$(TF)" -chdir="$(TF_DIR)" init $(TF_ARGS)

plan: version-check $(PREFLIGHT)
	@mkdir -p "$(PLAN_DIR)"
	@$(TF_PRELUDE); "$(TF)" -chdir="$(TF_DIR)" plan -lock-timeout=5m -out="$(CHANGE_PLAN)" $(TF_ARGS)

apply: version-check
	@test -f "$(CHANGE_PLAN)" || { printf 'No reviewed plan. Run: make plan\n' >&2; exit 1; }
	@$(MAKE) --no-print-directory $(PREFLIGHT)
	@$(TF_PRELUDE); "$(TF)" -chdir="$(TF_DIR)" apply -lock-timeout=5m $(TF_ARGS) "$(CHANGE_PLAN)"

destroy-plan: version-check $(PREFLIGHT)
	@mkdir -p "$(PLAN_DIR)"
	@$(TF_PRELUDE); "$(TF)" -chdir="$(TF_DIR)" plan -destroy -lock-timeout=5m -out="$(DESTROY_PLAN)" $(TF_ARGS)

destroy: version-check
	@test "$(CONFIRM)" = "destroy $(ROOT_NAME)" || { printf 'Refusing destruction. Pass CONFIRM="destroy $(ROOT_NAME)".\n' >&2; exit 1; }
	@test -f "$(DESTROY_PLAN)" || { printf 'No reviewed destroy plan. Run: make destroy-plan\n' >&2; exit 1; }
	@$(MAKE) --no-print-directory $(PREFLIGHT)
	@$(TF_PRELUDE); "$(TF)" -chdir="$(TF_DIR)" apply -lock-timeout=5m $(TF_ARGS) "$(DESTROY_PLAN)"

output: version-check
	@$(TF_PRELUDE); "$(TF)" -chdir="$(TF_DIR)" output $(TF_ARGS)

fmt:
	@"$(TF)" fmt -recursive "$(ROOT_DIR)"

fmt-check:
	@"$(TF)" fmt -check -recursive "$(ROOT_DIR)"

validate: version-check
	@mkdir -p "$(PLUGIN_CACHE_DIR)"
	@get=''; if [ -f "$(TF_DIR)/.terraform-check/modules/modules.json" ]; then get='-get=false'; fi; \
	TF_DATA_DIR="$(TF_DIR)/.terraform-check" TF_PLUGIN_CACHE_DIR="$(PLUGIN_CACHE_DIR)" "$(TF)" -chdir="$(TF_DIR)" init -backend=false -lockfile=readonly $$get >/dev/null
	@TF_DATA_DIR="$(TF_DIR)/.terraform-check" TF_PLUGIN_CACHE_DIR="$(PLUGIN_CACHE_DIR)" "$(TF)" -chdir="$(TF_DIR)" validate

# GNU Make 3.81 ignores .SHELLFLAGS, so this recipe sets the shell flags itself.
test: version-check
	@mkdir -p "$(PLUGIN_CACHE_DIR)"
	@set -eu -o pipefail; for d in $(TEST_DIRS); do \
	  if compgen -G "$$d/*.tftest.hcl" >/dev/null || compgen -G "$$d/tests/*.tftest.hcl" >/dev/null; then \
	    lock=''; if [ -f "$$d/.terraform.lock.hcl" ]; then lock='-lockfile=readonly'; fi; \
	    get=''; if [ -f "$$d/.terraform-check/modules/modules.json" ]; then get='-get=false'; fi; \
	    TF_DATA_DIR="$$d/.terraform-check" TF_PLUGIN_CACHE_DIR="$(PLUGIN_CACHE_DIR)" "$(TF)" -chdir="$$d" init -backend=false $$lock $$get >/dev/null; \
	    TF_DATA_DIR="$$d/.terraform-check" TF_PLUGIN_CACHE_DIR="$(PLUGIN_CACHE_DIR)" "$(TF)" -chdir="$$d" test; \
	  else \
	    printf 'no tests in %s (skipping)\n' "$$d"; \
	  fi; \
	done

check: version-check fmt-check validate test
	@printf 'All static checks passed.\n'

creds-preflight:
	@if [ -r "$${GOOGLE_APPLICATION_CREDENTIALS:-}" ]; then exit 0; fi; \
	if ! command -v gcloud >/dev/null 2>&1; then \
	  printf 'gcloud is required for Application Default Credentials.\n' >&2; exit 1; \
	fi; \
	if ! gcloud auth application-default print-access-token >/dev/null 2>&1; then \
	  printf 'No Application Default Credentials. Run: gcloud auth application-default login\n' >&2; exit 1; \
	fi
