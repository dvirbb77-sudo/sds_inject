#!/usr/bin/env bash
#
#
#

set -Eeuo pipefail
IFS=$'\n\t'

if [[ -f "automation/lib/logging.sh"  ]]; then
  source automation/lib/logging.sh
fi

declare -ga CLEANUP_FUNCS=()
declare -g ERROR_OCCURRED=0

register_cleanup() {
  local func="$1"
  CLEANUP_FUNCS+=("$func")
  log_debug "Registered cleanup function: $func"
}

_run_cleanup() {
  local exit_code=$?
  
  if [[ $exit_code -ne 0  ]]; then
    ERROR_OCCURRED=1
    log_error "Script exited with code: $exit_code"
  fi
  
  for ((i=${#CLEANUP_FUNCS[@]}-1; i>=0; i--)); do
    local func="${CLEANUP_FUNCS[i]}"
    log_debug "Running cleanup: $func"
    if ! $func 2>&1 | tee -a "$(log_get_file)"; then
      log_warn "Cleanup function $func failed"
    fi
  done
  
  if [[ $ERROR_OCCURRED -eq 1  ]]; then
    exit $exit_code
  fi
}

handle_error() {
  local message="$1"
  local exit_code="${2:-1}"
  
  log_error "$message"
  log_error "Exiting with code: $exit_code"
  
  exit "$exit_code"
}

assert_command() {
  local cmd="$1"
  if ! command -v "$cmd" &>/dev/null; then
    handle_error "Required command not found: $cmd" 1
  fi
}

_setup_traps() {
  trap _run_cleanup EXIT
  trap 'handle_error "Interrupted by signal" 130' INT TERM
}

_setup_traps

