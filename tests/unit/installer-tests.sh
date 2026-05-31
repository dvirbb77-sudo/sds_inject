#!/usr/bin/env bash
#
#
#

set -Eeuo pipefail
IFS=$'\n\t'

test_count=0
pass_count=0
fail_count=0

function assert_exit_code() {
  local test_name="$1"
  local expected_code="$2"
  shift 2
  local command="$*"
  
  test_count=$((test_count + 1))
  
  local actual_code=0
  eval "$command" || actual_code=$?
  
  if [[ "$expected_code" -eq "$actual_code" ]]; then
    echo "✓ PASS: $test_name (exit code $actual_code)"
    pass_count=$((pass_count + 1))
  else
    echo "✗ FAIL: $test_name"
    echo "  Expected exit code: $expected_code"
    echo "  Got exit code:      $actual_code"
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
    echo "✗ FAIL: $test_name"
    echo "  Expected to find: $expected_string"
    echo "  Output: $output"
    fail_count=$((fail_count + 1))
  fi
}

echo "Running installer-entrypoint.sh tests..."
echo ""

assert_exit_code "help returns exit code 0" 0 "./installer-entrypoint.sh --help"

assert_output_contains "help output contains Usage" "Usage:" "./installer-entrypoint.sh --help"

assert_exit_code "invalid argument returns exit code 1" 1 "./installer-entrypoint.sh --invalid-arg"

assert_exit_code "worker without master-ip fails" 1 "./installer-entrypoint.sh --worker"

if [[ $EUID -eq 0 ]]; then
  assert_exit_code "validate-only succeeds" 0 "./installer-entrypoint.sh --validate-only"
else
  echo "⊘ SKIP: validate-only test (requires root)"
fi

assert_output_contains "help mentions master mode" "--master" "./installer-entrypoint.sh --help"
assert_output_contains "help mentions worker mode" "--worker" "./installer-entrypoint.sh --help"
assert_output_contains "help mentions validate-only" "--validate-only" "./installer-entrypoint.sh --help"

assert_exit_code "installer functions are callable" 0 "bash -c 'source automation/lib/logging.sh && source automation/runtime/detect.sh && type log_info && type get_node_type'"

if [[ $test_count -eq 0 ]]; then
  echo "✗ FAIL: No tests were executed"
  exit 1
fi

echo ""
echo "=================="
echo "Tests: $pass_count/$test_count passed"

if [[ $fail_count -gt 0 ]]; then
  echo "Failures: $fail_count"
  exit 1
else
  echo "All tests passed!"
  exit 0
fi
