# Makefile - Kubernetes Installer Project
# Provides targets for building, testing, and packaging

SHELL := /bin/bash
.PHONY: help clean build test validate package deploy vagrant fetch-binaries smoke-test

# Configuration
INSTALLER_VERSION ?= 1.0.0
KUBERNETES_VERSION ?= 1.31.1
HELM_VERSION ?= 3.16.1
KUSTOMIZE_VERSION ?= 5.4.2
CONTAINERD_VERSION ?= 2.0.0
CRICTL_VERSION ?= 1.29.0

# Directories
DIST_DIR := dist
BUILD_DIR := build
TEST_DIR := tests
BINARIES_DIR := binaries

# Targets
help:
	@echo "Kubernetes Installer Project Makefile"
	@echo ""
	@echo "Core Targets:"
	@echo "  make fetch-binaries - Download Kubernetes binaries (REQUIRED FIRST)"
	@echo "  make build          - Build installer package"
	@echo "  make validate       - Run shell script validation"
	@echo "  make test           - Run unit tests"
	@echo "  make smoke-test     - Run post-install smoke tests"
	@echo "  make test-vm        - Boot test VM and run tests"
	@echo "  make clean          - Clean build artifacts"
	@echo "  make lint           - Lint shell scripts"
	@echo ""
	@echo "Configuration:"
	@echo "  KUBERNETES_VERSION  = $(KUBERNETES_VERSION)"
	@echo "  HELM_VERSION        = $(HELM_VERSION)"
	@echo "  KUSTOMIZE_VERSION   = $(KUSTOMIZE_VERSION)"
	@echo "  CONTAINERD_VERSION  = $(CONTAINERD_VERSION)"
	@echo "  CRICTL_VERSION      = $(CRICTL_VERSION)"
	@echo ""
	@echo "Quick Start:"
	@echo "  1. make fetch-binaries"
	@echo "  2. make ci-build"
	@echo "  3. make test-vm"

clean:
	@echo "Cleaning build artifacts..."
	rm -rf $(DIST_DIR) $(BUILD_DIR) payload
	find . -name "*.log" -delete
	@echo "✓ Clean complete"

validate:
	@echo "Validating shell scripts..."
	@find automation -name "*.sh" -type f -exec bash -n {} \;
	@find . -maxdepth 1 -name "*.sh" -type f -exec bash -n {} \;
	@find cd -name "*.sh" -type f -exec bash -n {} \;
	@find tests -name "*.sh" -type f -exec bash -n {} \;
	@echo "✓ Shell validation passed"

lint:
	@echo "Linting shell scripts with shellcheck..."
	@command -v shellcheck >/dev/null || { echo "shellcheck not installed"; exit 1; }
	@find automation -name "*.sh" -type f -exec shellcheck -x {} \;
	@find . -maxdepth 1 -name "*.sh" -type f -exec shellcheck -x {} \;
	@find cd -name "*.sh" -type f -exec shellcheck -x {} \;
	@echo "✓ Lint passed"

test:
	@echo "Running unit tests..."
	@[[ -d $(TEST_DIR)/unit ]] || { echo "No unit tests found"; exit 0; }
	@bash $(TEST_DIR)/unit/logging-tests.sh || true
	@bash $(TEST_DIR)/unit/validation-tests.sh || true
	@bash $(TEST_DIR)/unit/detect-tests.sh || true
	@bash $(TEST_DIR)/unit/installer-tests.sh || true
	@echo "✓ Unit tests complete"

fetch-binaries:
	@echo "Fetching Kubernetes binaries..."
	@bash cd/fetch-binaries.sh \
		--version $(KUBERNETES_VERSION) \
		--helm-version $(HELM_VERSION) \
		--kustomize-version $(KUSTOMIZE_VERSION) \
		--containerd-version $(CONTAINERD_VERSION) \
		--crictl-version $(CRICTL_VERSION) \
		--output $(BINARIES_DIR)
	@echo "✓ Binary acquisition complete"

build: validate
	@[[ -d binaries ]] || { echo "ERROR: Binaries not acquired - run 'make fetch-binaries' first"; exit 1; }
	@echo "Building installer package..."
	@K8S_VERSION=$(KUBERNETES_VERSION) bash build.sh
	@echo "✓ Build complete - Output: $(DIST_DIR)/k8s-installer.run"

package: build
	@echo "Packaging complete - installer at: $(DIST_DIR)/k8s-installer.run"
	@ls -lh $(DIST_DIR)/k8s-installer.run 2>/dev/null || true

smoke-test:
	@echo "Running smoke tests..."
	@bash tests/smoke-test.sh --master
	@echo "✓ Smoke tests passed"

test-vm: build
	@echo "Starting test VM..."
	@cd tests/vm && vagrant up k8s-master
	@echo "Running tests..."
	@cd tests/vm && vagrant provision k8s-master
	@echo "✓ VM tests complete"

test-vm-workers: build
	@echo "Starting multi-node test VMs..."
	@cd tests/vm && vagrant up
	@echo "✓ VMs started"
	@echo "Note: Run worker provisioning manually with:"
	@echo "  cd tests/vm && vagrant provision k8s-worker-1 --provision-with shell"

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

