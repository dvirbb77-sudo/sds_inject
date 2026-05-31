#!/usr/bin/env bash
#
#
#

set -Eeuo pipefail
IFS=$'\n\t'

source automation/lib/logging.sh

test_count=0
pass_count=0
fail_count=0

function assert_true() {
  local test_name="$1"
  local command="$2"
  
  test_count=$((test_count + 1))
  
  if eval "$command" &>/dev/null; then
    echo " PASS: $test_name"
    pass_count=$((pass_count + 1))
  else
    echo " FAIL: $test_name"
    fail_count=$((fail_count + 1))
  fi
}

echo "Running logging library tests..."
echo ""

assert_true "log_info is callable" "[[ -n \"\$(type log_info 2>/dev/null)\" ]]"
assert_true "log_error is callable" "[[ -n \"\$(type log_error 2>/dev/null)\" ]]"
assert_true "log_warn is callable" "[[ -n \"\$(type log_warn 2>/dev/null)\" ]]"
assert_true "log_debug is callable" "[[ -n \"\$(type log_debug 2>/dev/null)\" ]]"
assert_true "log_get_file is callable" "[[ -n \"\$(type log_get_file 2>/dev/null)\" ]]"

log_info "Test logging message"
assert_true "log file is created" "[[ -f \"\$(log_get_file)\" ]]"

assert_true "log file contains log_info message" "grep -q 'Test logging message' \"\$(log_get_file)\""

log_warn "Warning test message"
assert_true "log file contains warning" "grep -q 'Warning test message' \"\$(log_get_file)\""

log_error "Error test message"
assert_true "log file contains error" "grep -q 'Error test message' \"\$(log_get_file)\""

log_file=$(log_get_file)
assert_true "log file path is absolute" "[[ \"$log_file\" == /* ]]"
assert_true "log file directory exists" "[[ -d \"\$(dirname \"$log_file\")\" ]]"

assert_true "log entries have timestamps" "grep -q '\[202[0-9]-.*\]' \"\$(log_get_file)\""

if [[ $test_count -eq 0 ]]; then
  echo " FAIL: No tests were executed"
  exit 1
fi

echo ""
echo "=================="
echo "Tests: $pass_count/$test_count passed"

if [[ $fail_count -gt 0 ]]; then
  echo "Failures: $fail_count"
fi

if [[ $pass_count -eq $test_count ]]; then
  echo "All tests passed!"
  exit 0
else
  exit 1
fi
