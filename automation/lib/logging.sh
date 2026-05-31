#!/usr/bin/env bash
#
#
#

set -Eeuo pipefail
IFS=$'\n\t'

declare -g LOG_DIR="${LOG_DIR:=logs}"
declare -g LOG_FILE="${LOG_FILE:=${LOG_DIR}/install-$(date +%Y%m%d-%H%M%S).log}"
: "${LOG_FILE:-}"
declare -g LOG_LEVEL="${LOG_LEVEL:=INFO}"
declare -g DEBUG="${DEBUG:=0}"
: "${DEBUG:-}"

_log_init() {
  if [[ ! -d "$LOG_DIR"  ]]; then
    mkdir -p "$LOG_DIR"
  fi
}

_log_timestamp() {
  date '+%Y-%m-%d %H:%M:%S'
}

_log() {
  local level="$1"
  shift
  local message="$*"
  local timestamp
  timestamp=$(_log_timestamp)
  
  local formatted="[${timestamp}] [${level}] ${message}"
  
  echo "$formatted"
  
  echo "$formatted" >> "$LOG_FILE"
}

log_info() {
  _log "INFO" "$@"
}

log_warn() {
  _log "WARN" "$@" >&2
}

log_error() {
  _log "ERROR" "$@" >&2
}

log_debug() {
  if [[ "$DEBUG" -eq 1  ]]; then
    _log "DEBUG" "$@"
  fi
}

log_get_file() {
  echo "$LOG_FILE"
}

_log_init

