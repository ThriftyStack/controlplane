# Authentik identity root — shared OpenTofu targets (see ../make/common.mk).
# Auth: ADC -> Secret Manager -> Vault -> Authentik API token.
# The direct API path needs LAN, WARP, or NetBird reachability.
ROOT_DIR := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
TEST_DIRS := $(ROOT_DIR) $(ROOT_DIR)/modules/groups $(ROOT_DIR)/modules/oauth2_apps
include $(ROOT_DIR)/../make/common.mk
