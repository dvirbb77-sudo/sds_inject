#!/bin/bash
#
# test-installer.sh - Integration tests for installer
# Validates core installation automation logic without full K8s deployment
#
# Tests cover:
#  1. Installer help functionality
#  2. Argument validation
#  3. Validate-only mode
#  4. Detection workflow
#

set -Eeuo pipefail
IFS=$'\n\t'

test_count=0
pass_count=0
fail_count=0

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

function assert_exit_code() {
  local test_name="$1"
  local expected_code="$2"
  shift 2
  local command="$*"
  
  test_count=$((test_count + 1))
  
  local actual_code=0
  eval "$command" &>/dev/null || actual_code=$?
  
  if [[ "$expected_code" -eq "$actual_code" ]]; then
    echo "✓ PASS: $test_name (exit code $actual_code)"
    pass_count=$((pass_count + 1))
  else
    echo "✗ FAIL: $test_name"
    echo "  Expected: $expected_code, Got: $actual_code"
    fail_count=$((fail_count + 1))
  fi
}

function assert_output_contains() {
  local test_name="$1"
  local expected_string="$2"
  shift 2
  local command="$*"
  
  test_count=$((test_count + 1))
  
  local output
  output=$(eval "$command" 2>&1) || true
  
  if echo "$output" | grep -q "$expected_string"; then
    echo "✓ PASS: $test_name"
    pass_count=$((pass_count + 1))
  else
    echo "✗ FAIL: $test_name (expected string not found: $expected_string)"
    fail_count=$((fail_count + 1))
  fi
}

echo "Running integration tests..."
echo "Script dir: $SCRIPT_DIR"
echo ""

cd "$SCRIPT_DIR"
assert_exit_code "installer help returns 0" 0 "./installer-entrypoint.sh --help"

assert_output_contains "help contains usage info" "Usage:" "./installer-entrypoint.sh --help"

assert_exit_code "invalid argument returns 1" 1 "./installer-entrypoint.sh --invalid-arg"

assert_exit_code "worker without params returns 1" 1 "./installer-entrypoint.sh --worker"

assert_exit_code "detection functions callable" 0 "bash -c 'source automation/runtime/detect.sh && type get_node_type && type is_master_node && type is_worker_node'"

assert_exit_code "logging functions callable" 0 "bash -c 'source automation/lib/logging.sh && type log_info && type log_error && type log_get_file'"

assert_exit_code "validation functions callable" 0 "bash -c 'source automation/lib/validation.sh && type validate_all'"

assert_exit_code "error handling framework callable" 0 "bash -c 'source automation/lib/errors.sh && type handle_error && type register_cleanup'"

assert_exit_code "installer syntax valid" 0 "bash -n ./installer-entrypoint.sh"

assert_exit_code "automation scripts syntax valid" 0 "bash -n automation/common/sysctl.sh && bash -n automation/common/kernel-modules.sh"

if [[ $test_count -eq 0 ]]; then
  echo "✗ FAIL: No tests were executed"
  exit 1
fi

echo ""
echo "=================="
echo "Integration Tests: $pass_count/$test_count passed"

if [[ $fail_count -gt 0 ]]; then
  echo "Failures: $fail_count"
  exit 1
else
  echo "All integration tests passed!"
  exit 0
fi

