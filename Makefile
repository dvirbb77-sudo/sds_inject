# Makefile - Kubernetes Installer Project
# Provides targets for building, testing, and packaging

SHELL := /bin/bash
.PHONY: help clean build test validate package deploy vagrant

# Configuration
INSTALLER_VERSION ?= 1.0.0
KUBERNETES_VERSION ?= 1.31.1
HELM_VERSION ?= 3.16.1
KUSTOMIZE_VERSION ?= 5.4.2
CONTAINERD_VERSION ?= 2.0.0

# Directories
DIST_DIR := dist
BUILD_DIR := build
TEST_DIR := tests

# Targets
help:
	@echo "Kubernetes Installer Project Makefile"
	@echo ""
	@echo "Targets:"
	@echo "  make build          - Build installer package"
	@echo "  make validate       - Run shell script validation"
	@echo "  make test           - Run unit tests"
	@echo "  make test-vm        - Boot test VM and run tests"
	@echo "  make package        - Package installer artifact"
	@echo "  make clean          - Clean build artifacts"
	@echo "  make lint           - Lint shell scripts"
	@echo ""
	@echo "Configuration:"
	@echo "  KUBERNETES_VERSION = $(KUBERNETES_VERSION)"
	@echo "  HELM_VERSION = $(HELM_VERSION)"
	@echo "  KUSTOMIZE_VERSION = $(KUSTOMIZE_VERSION)"
	@echo "  CONTAINERD_VERSION = $(CONTAINERD_VERSION)"

clean:
	@echo "Cleaning build artifacts..."
	rm -rf $(DIST_DIR) $(BUILD_DIR) payload
	find . -name "*.log" -delete
	@echo "✓ Clean complete"

validate:
	@echo "Validating shell scripts..."
	@find automation -name "*.sh" -type f -exec bash -n {} \;
	@find . -maxdepth 1 -name "*.sh" -type f -exec bash -n {} \;
	@echo "✓ Shell validation passed"

lint:
	@echo "Linting shell scripts with shellcheck..."
	@command -v shellcheck >/dev/null || { echo "shellcheck not installed"; exit 1; }
	@find automation -name "*.sh" -type f -exec shellcheck -x {} \;
	@find . -maxdepth 1 -name "*.sh" -type f -exec shellcheck -x {} \;
	@echo "✓ Lint passed"

test:
	@echo "Running unit tests..."
	@[[ -d $(TEST_DIR)/unit ]] || { echo "No unit tests found"; exit 0; }
	@bash -x $(TEST_DIR)/unit/*.sh || { echo "✗ Unit tests failed"; exit 1; }
	@echo "✓ Unit tests passed"

build: validate
	@echo "Building installer package..."
	@bash build.sh
	@echo "✓ Build complete"

package: build
	@echo "Packaging complete - installer at: $(DIST_DIR)/k8s-installer.run"

test-vm:
	@echo "Starting test VM..."
	@cd tests/vm && vagrant up
	@echo "Running tests..."
	@cd tests/vm && vagrant provision
	@echo "✓ VM tests complete"

vagrant-destroy:
	@echo "Destroying test VMs..."
	@cd tests/vm && vagrant destroy -f
	@echo "✓ VMs destroyed"

# CI/CD targets
ci-check: validate lint test
	@echo "✓ CI checks passed"

ci-build: ci-check package
	@echo "✓ CI build complete"

.DEFAULT_GOAL := help
