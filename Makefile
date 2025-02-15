# ====================================================================================
# Crossplane Configuration Package Makefile
# ====================================================================================

# USAGE DOCUMENTATION
# ====================================================================================
#
# This is a generic Makefile to be used across repositories building Crossplane
# configuration packages. It provides a comprehensive set of targets for development,
# testing, and deployment.
#
# PROJECT CONFIGURATION
# -------------------
# Create a project.mk file in your repository to configure project-specific settings.
# Required variables:
# - PROJECT_NAME: Name of your Crossplane configuration package
#
# Example project.mk:
#   PROJECT_NAME = custom-config
#   UPTEST_DEFAULT_TIMEOUT = 3600s
#   UPTEST_SKIP_IMPORT = true
#
# PRIMARY TARGETS
# --------------
#
# Development Tools:
# -----------------
# - `yamllint`
#   Runs yamllint recursively on all files in the `api` folder to ensure YAML
#   quality and consistency
#
# - `check-examples`
#   Validates consistency between example configurations and dependencies:
#   - Compares Function package versions in examples/ against crossplane.yaml
#   - Ensures all Function versions in examples match dependency declarations
#   - Helps prevent version mismatches that could cause deployment issues
#   Example errors:
#     - Example using function-foo:v1.2.0 while crossplane.yaml specifies v1.1.0
#     - Missing Function dependencies in crossplane.yaml that are used in examples
#   Usage: Run before committing changes to ensure example validity
#
# Rendering and Validation:
# -----------------
# - `render`
#   Renders the composition output for rapid feedback during template development.
#   Requirements:
#   - Claims must have these annotations:
#       render.crossplane.io/composition-path: apis/pat/composition.yaml
#       render.crossplane.io/function-path: examples/functions.yaml
#   Note: This only populates the cache. Use `render.show` to view output.
#
# - `render.show`
#   Displays the rendered YAML output. Useful for:
#   - Manual validation
#   - Piping to validation tools, e.g.:
#     make render.show | crossplane beta validate crossplane.yaml -
#
# Testing:
# -----------------
# - `render.test`
#   Executes kcl-unit tests on rendered manifests. Tests should be:
#   - Located in the `test` folder
#   - Written as standard kcl-tests
#   This ensures the rendered output meets expected specifications.
#
# - `e2e`
#   Comprehensive end-to-end testing, including:
#   - Cluster creation
#   - Configuration setup
#   - Testing create, import, and delete operations
#
#   Cloud Provider Requirements:
#   For configurations creating cloud provider resources, set:
#   UPTEST_CLOUD_CREDENTIALS - Provider-specific credentials:
#   - AWS:   export UPTEST_CLOUD_CREDENTIALS=$(cat ~/.aws/credentials)
#   - GCP:   export UPTEST_CLOUD_CREDENTIALS=$(cat gcp-sa.json)
#   - Azure: export UPTEST_CLOUD_CREDENTIALS=$(cat azure.json)
#
#   Configuration Options:
#   - UPTEST_SKIP_DELETE (default: false)
#     Skip deletion testing of created resources
#   - UPTEST_SKIP_UPDATE (default: false)
#     Skip testing of claim updates
#   - UPTEST_SKIP_IMPORT (default: false)
#     Skip testing of resource imports
#
#   Example Usage:
#     make e2e UPTEST_SKIP_DELETE=true
#
# LANGUAGE-SPECIFIC OPTIONS
# ------------------------
#
# KCL Support:
# - KCL_COMPOSITION_PATH
#   Path to the KCL file generating composition.yaml
#   Default: apis/kcl/generate.k
#
# NOTE: The platform setting is constrained to linux_amd64 as Configuration package
# images are not architecture-specific. This avoids unnecessary multi-arch image
# generation.

# ====================================================================================
# Project Configuration
# ====================================================================================

# Include project.mk for project specific settings
include project.mk

ifndef PROJECT_NAME
  $(error PROJECT_NAME is not set. Please create `project.mk` and set it there.)
endif

# Project Configuration
# ------------------
PROJECT_REPO := github.com/upbound/$(PROJECT_NAME)
PLATFORMS ?= linux_amd64

# Tool Versions
# ------------------
UP_VERSION = v0.37.1
UP_CHANNEL = stable
CROSSPLANE_CLI_VERSION = v1.18.0
CROSSPLANE_VERSION = v1.18.0-up.1
UPTEST_VERSION = v1.2.0

# Crossplane Configuration
# ------------------
CROSSPLANE_CHART_REPO = https://charts.upbound.io/stable
CROSSPLANE_CHART_NAME = universal-crossplane
CROSSPLANE_NAMESPACE = upbound-system
CROSSPLANE_ARGS = "--enable-usages"
KIND_CLUSTER_NAME ?= uptest-$(PROJECT_NAME)

# XPKG Configuration
# ------------------
XPKG_DIR = $(shell pwd)
XPKG_IGNORE ?= .github/workflows/*.yaml,.github/workflows/*.yml,examples/*.yaml,.work/uptest-datasource.yaml,.cache/render/*
XPKG_REG_ORGS ?= xpkg.upbound.io/upbound
# NOTE: Skip promoting on xpkg.upbound.io as channel tags are inferred
XPKG_REG_ORGS_NO_PROMOTE ?= xpkg.upbound.io/upbound
XPKGS = $(PROJECT_NAME)

# Testing Configuration
# ------------------
UPTEST_LOCAL_DEPLOY_TARGET = local.xpkg.deploy.configuration.$(PROJECT_NAME)
UPTEST_DEFAULT_TIMEOUT ?= 2400s

# KCL Configuration
# ------------------
KCL_COMPOSITION_PATH ?= apis/kcl/generate.k
LANG_KCL := $(shell find ./apis -type f -name '*.k')

# Include makelib files
# ------------------
-include build/makelib/common.mk
-include build/makelib/k8s_tools.mk
-include build/makelib/xpkg.mk
-include build/makelib/local.xpkg.mk
-include build/makelib/controlplane.mk
-include build/makelib/uptest.mk

# ====================================================================================
# Targets
# ====================================================================================

# Initial Setup
# ------------------
# We want submodules to be set up the first time `make` is run.
# We manage the build/ folder and its Makefiles as a submodule.
# The first time `make` is run, the includes of build/*.mk files will
# all fail, and this target will be run. The next time, the default as defined
# by the includes will be run instead.
fallthrough: submodules  ## Initial setup and submodule initialization
	@echo Initial setup complete. Running make again . . .
	@make

submodules:  ## Update the submodules, including common build scripts
	@git submodule sync
	@git submodule update --init --recursive

# Build Targets
# ------------------
# We must ensure up is installed in tool cache prior to build as including the k8s_tools
# machinery prior to the xpkg machinery sets UP to point to tool cache.
build.init: $(UP)  ## Initialize build requirements

# KCL Targets
# ------------------
ifdef LANG_KCL
kcl: $(KCL)  ## Generate KCL-based Composition
	@$(INFO) Generating kcl composition
	@$(KCL) $(KCL_COMPOSITION_PATH) 1>/dev/null
	@$(OK) Generated kcl composition

render: kcl  ## Render the composition output
build.init: kcl
.PHONY: kcl
endif

# Testing Targets
# ------------------
render.test: $(CROSSPLANE_CLI) $(KCL) render  ## Test rendered compositions
	@for RENDERED_COMPOSITION in $$(find .cache/render -maxdepth 1 -type f -name '*.yaml'); do \
		$(INFO) "Testing $${RENDERED_COMPOSITION}"; \
		export RENDERED_COMPOSITION; \
		$(KCL) test test/ && \
		$(OK) "Success testing \"$${RENDERED_COMPOSITION}\"!" || \
		($(ERR) "Failure testing \"$${RENDERED_COMPOSITION}\"!" && exit 1); \
	done

check-examples:  ## Validate package versions in examples match dependencies
	@$(INFO) Checking if package versions in dependencies match examples
	@FN_EXAMPLES=$$( \
		find examples -type f -name "*.yaml" | \
		xargs $(YQ) -r -o=json 'select(.kind == "Function" and (.apiVersion | test("^pkg.crossplane.io/"))) | .spec.package' | \
		sort -u); \
	FN_DEPS=$$( \
		$(YQ) '.spec.dependsOn[] | select(.function != null) | (.function + ":" + .version)' crossplane.yaml | \
		sort -u \
	); \
	if [ "$$FN_EXAMPLES" != "$$FN_DEPS" ]; then \
		echo "Function package versions in examples and in crossplane.yaml don't match!"; \
		echo "" ; \
		echo "Versions in dependencies:"; \
		echo "---" ; \
		echo "$$FN_DEPS"; \
		echo "" ; \
		echo "Versions in examples:"; \
		echo "---" ; \
		echo "$$FN_EXAMPLES"; \
		exit 1; \
	fi;
	@$(OK) Package versions are sane

# Help Targets
# ------------------
help: help.local  ## Display this help message

help.local:
	@echo "Available targets:"
	@echo
	@grep -E '^[a-zA-Z_-]+.*:.*?## .*$$' Makefile | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'

.PHONY: uptest e2e render yamllint help help.local check-examples render.test
