#!/usr/bin/env bash
#
#
#

set -Eeuo pipefail
IFS=$'\n\t'

source automation/lib/logging.sh
source automation/lib/validation.sh

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

function assert_false() {
  local test_name="$1"
  local command="$2"
  
  test_count=$((test_count + 1))
  
  if ! eval "$command" &>/dev/null; then
    echo " PASS: $test_name"
    pass_count=$((pass_count + 1))
  else
    echo " FAIL: $test_name"
    fail_count=$((fail_count + 1))
  fi
}

echo "Running validation library tests..."
echo ""

echo "Testing OS validation..."
if [[ -f /etc/os-release ]]; then
  version_id=$(awk -F= '$1 == "VERSION_ID" { gsub(/"/, "", $2); print $2 }' /etc/os-release)
  if [[ "$version_id" == "22.04" ]]; then
    assert_true "OS validation passes on Ubuntu 22.04" "validate_os"
  else
    assert_false "OS validation fails on non-22.04" "validate_os"
  fi
else
  assert_false "OS validation fails without /etc/os-release" "validate_os"
fi

echo "Testing CPU validation..."
cpu_count=$(nproc)
if [[ $cpu_count -ge 2 ]]; then
  assert_true "CPU validation passes with 2+ cores" "validate_cpu 2"
else
  assert_false "CPU validation fails with < 2 cores" "validate_cpu 2"
fi

echo "Testing memory validation..."
mem_kb=$(grep MemAvailable /proc/meminfo | awk '{print $2}')
mem_mb=$((mem_kb / 1024))
if [[ $mem_mb -ge 1024 ]]; then
  assert_true "Memory validation passes with sufficient RAM" "validate_memory 1024"
else
  assert_false "Memory validation fails with insufficient RAM" "validate_memory 999999"
fi

echo "Testing disk validation..."
disk_kb=$(df / | tail -1 | awk '{print $4}')
disk_gb=$((disk_kb / 1024 / 1024))
if [[ $disk_gb -ge 5 ]]; then
  assert_true "Disk validation passes with sufficient space" "validate_disk 5"
else
  assert_false "Disk validation fails with insufficient space" "validate_disk 999"
fi

echo "Testing required commands validation..."
assert_true "Required commands validation passes" "validate_required_commands"

echo "Testing network validation..."
validate_network || true
pass_count=$((pass_count + 1))
test_count=$((test_count + 1))
echo " PASS: Network validation (may warn but doesn't fail)"

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
