#!/usr/bin/env bash
#
#
#

set -Eeuo pipefail
IFS=$'\n\t'

test_count=0
pass_count=0
fail_count=0

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

MOCK_DIR=$(mktemp -d)
trap 'rm -rf "$MOCK_DIR"' EXIT

function assert_success() {
  local test_name="$1"
  shift
  
  test_count=$((test_count + 1))
  
  if "$@" >/dev/null 2>&1; then
    echo " PASS: $test_name"
    pass_count=$((pass_count + 1))
  else
    echo " FAIL: $test_name (command failed)"
    fail_count=$((fail_count + 1))
  fi
}

function assert_failure() {
  local test_name="$1"
  shift
  
  test_count=$((test_count + 1))
  
  if ! "$@" >/dev/null 2>&1; then
    echo " PASS: $test_name"
    pass_count=$((pass_count + 1))
  else
    echo " FAIL: $test_name (command succeeded when it should have failed)"
    fail_count=$((fail_count + 1))
  fi
}

function test_retry_stops_on_success() {
  local attempt_file="$MOCK_DIR/retry-stops-attempts"
  local attempt
  printf '0\n' > "$attempt_file"
  
  if retry 3 1 bash -c "attempt=\$(cat \"\$1\"); attempt=\$((attempt + 1)); printf \"%s\\n\" \"\$attempt\" > \"\$1\"; [[ \$attempt -ge 2 ]]" _ "$attempt_file"; then
    attempt=$(cat "$attempt_file")
    if [[ $attempt -eq 2  ]]; then
      return 0
    fi
  fi
  return 1
}

function test_command_success() {
  local counter_file="$MOCK_DIR/eventually-succeeds-attempts"
  printf '0\n' > "$counter_file"
  
  if retry 3 1 bash -c "counter=\$(cat \"\$1\"); counter=\$((counter + 1)); printf \"%s\\n\" \"\$counter\" > \"\$1\"; [[ \$counter -ge 2 ]]" _ "$counter_file"; then
    return 0
  fi
  return 1
}

function test_exports() {
  source "$SCRIPT_DIR/automation/lib/healing.sh" 2>/dev/null || true
  
  declare -f retry >/dev/null 2>&1 || return 1
  declare -f ensure_service_running >/dev/null 2>&1 || return 1
  declare -f ensure_service_enabled >/dev/null 2>&1 || return 1
  declare -f ensure_package_installed >/dev/null 2>&1 || return 1
  declare -f ensure_module_loaded >/dev/null 2>&1 || return 1
  declare -f ensure_sysctl >/dev/null 2>&1 || return 1
  declare -f validate_state >/dev/null 2>&1 || return 1
  declare -f healing_summary >/dev/null 2>&1 || return 1
  declare -f perform_healing_phase >/dev/null 2>&1 || return 1
  
  return 0
}

echo "=== Healing Framework Tests ==="
echo ""

source "$SCRIPT_DIR/automation/lib/logging.sh" 2>/dev/null || true
source "$SCRIPT_DIR/automation/lib/healing.sh" 2>/dev/null || true

assert_success "retry succeeds on first attempt" \
  retry 3 1 true

assert_failure "retry fails after max attempts exhausted" \
  retry 2 1 false

test_count=$((test_count + 1))
if test_retry_stops_on_success >/dev/null 2>&1; then
  echo " PASS: retry stops after first success (doesn't retry unnecessarily)"
  pass_count=$((pass_count + 1))
else
  echo " FAIL: retry stops after first success (doesn't retry unnecessarily)"
  fail_count=$((fail_count + 1))
fi

assert_failure "ensure_service_running fails for non-existent service" \
  ensure_service_running "nonexistent-test-service-12345"

assert_failure "ensure_service_enabled fails for non-existent service" \
  ensure_service_enabled "nonexistent-test-service-12345"

assert_failure "ensure_package_installed fails for invalid package" \
  ensure_package_installed "nonexistent-binary-package-xyz" "nonexistent-package-xyz"

assert_failure "ensure_module_loaded fails without module name" \
  bash -c "source $SCRIPT_DIR/automation/lib/healing.sh 2>/dev/null && ensure_module_loaded ''"

assert_failure "ensure_sysctl fails without parameters" \
  bash -c "source $SCRIPT_DIR/automation/lib/healing.sh 2>/dev/null && ensure_sysctl '' ''"

assert_success "validate_state function is callable" \
  bash -c "source $SCRIPT_DIR/automation/lib/healing.sh 2>/dev/null && type validate_state"

assert_success "healing_summary function is callable" \
  bash -c "source $SCRIPT_DIR/automation/lib/healing.sh 2>/dev/null && type healing_summary"

assert_failure "perform_healing_phase fails for non-existent healing function" \
  bash -c "source $SCRIPT_DIR/automation/lib/healing.sh 2>/dev/null && perform_healing_phase 'test' 'nonexistent_function'"

assert_success "healing library loads independently" \
  bash -c "source $SCRIPT_DIR/automation/lib/healing.sh 2>/dev/null && [[ \$HEALING_LOADED -eq 1  ]]"

test_count=$((test_count + 1))
if test_command_success >/dev/null 2>&1; then
  echo " PASS: retry eventually succeeds after failures"
  pass_count=$((pass_count + 1))
else
  echo " FAIL: retry eventually succeeds after failures"
  fail_count=$((fail_count + 1))
fi

assert_failure "ensure_sysctl requires both param and value" \
  bash -c "source $SCRIPT_DIR/automation/lib/healing.sh 2>/dev/null && ensure_sysctl 'net.ipv4.ip_forward'"

test_count=$((test_count + 1))
if test_exports >/dev/null 2>&1; then
  echo " PASS: healing library exports all required functions"
  pass_count=$((pass_count + 1))
else
  echo " FAIL: healing library exports all required functions"
  fail_count=$((fail_count + 1))
fi

echo ""
echo "=================="
echo "Healing Tests: $pass_count/$test_count passed"

if [[ $fail_count -gt 0  ]]; then
  echo "Failures: $fail_count"
  exit 1
else
  echo "All healing tests passed!"
  exit 0
fi
