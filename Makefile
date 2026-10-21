ROOT ?= authentik
ROOT_DIR := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))/$(ROOT)

.PHONY: check plan apply destroy-plan destroy fmt fmt-check validate test

check plan apply destroy-plan destroy fmt fmt-check validate test:
	@$(MAKE) -C "$(ROOT_DIR)" $@
