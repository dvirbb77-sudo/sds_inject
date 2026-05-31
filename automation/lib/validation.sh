#!/usr/bin/env bash
#
#
#

set -Eeuo pipefail
IFS=$'\n\t'

if [[ -f "automation/lib/logging.sh"  ]]; then
  source automation/lib/logging.sh
fi

validate_root() {
  if [[ $EUID -ne 0  ]]; then
    log_error "This script must be run as root"
    return 1
  fi
  log_info " Running as root"
  return 0
}

validate_os() {
  if ! [[ -f /etc/os-release  ]]; then
    log_error "Cannot determine OS"
    return 1
  fi
  
  local version_id
  version_id=$(awk -F= '$1 == "VERSION_ID" { gsub(/"/, "", $2); print $2 }' /etc/os-release)
  
  if [[ "$version_id" != "22.04"  ]]; then
    log_error "This script requires Ubuntu 22.04, found: $version_id"
    return 1
  fi
  
  log_info " Ubuntu 22.04 verified"
  return 0
}

validate_cpu() {
  local min_cpu="${1:-2}"
  local cpu_count
  cpu_count=$(nproc)
  
  if [[ $cpu_count -lt $min_cpu  ]]; then
    log_error "Insufficient CPU cores: $cpu_count (minimum: $min_cpu)"
    return 1
  fi
  
  log_info " CPU validation passed: $cpu_count cores"
  return 0
}

validate_memory() {
  local min_memory_mb="${1:-2048}"
  local available_kb
  available_kb=$(grep MemAvailable /proc/meminfo | awk '{print $2}')
  local available_mb=$((available_kb / 1024))
  
  if [[ $available_mb -lt $min_memory_mb  ]]; then
    log_error "Insufficient memory: ${available_mb}MB (minimum: ${min_memory_mb}MB)"
    return 1
  fi
  
  log_info " Memory validation passed: ${available_mb}MB"
  return 0
}

validate_disk() {
  local min_disk_gb="${1:-10}"
  local available_kb
  available_kb=$(df / | tail -1 | awk '{print $4}')
  local available_gb=$((available_kb / 1024 / 1024))
  
  if [[ $available_gb -lt $min_disk_gb  ]]; then
    log_error "Insufficient disk space: ${available_gb}GB (minimum: ${min_disk_gb}GB)"
    return 1
  fi
  
  log_info " Disk validation passed: ${available_gb}GB"
  return 0
}

validate_network() {
  local timeout=5
  
  if ! timeout "$timeout" curl -sf https://www.google.com &>/dev/null; then
    log_warn "No internet connectivity detected (installer may have offline mode)"
    return 0
  fi
  
  log_info " Network connectivity verified"
  return 0
}

validate_required_commands() {
  local required_cmds=("curl" "grep" "sed" "awk" "jq")
  local missing=()
  
  for cmd in "${required_cmds[@]}"; do
    if ! command -v "$cmd" &>/dev/null; then
      missing+=("$cmd")
    fi
  done
  
  if [[ ${#missing[@]} -gt 0  ]]; then
    log_error "Missing required commands: ${missing[*]}"
    return 1
  fi
  
  log_info " All required commands available"
  return 0
}

validate_all() {
  local failed=0
  
  log_info "Running pre-installation validations..."
  
  validate_root || failed=$((failed + 1))
  validate_os || failed=$((failed + 1))
  validate_cpu 2 || failed=$((failed + 1))
  validate_memory 2048 || failed=$((failed + 1))
  validate_disk 10 || failed=$((failed + 1))
  validate_network || failed=$((failed + 1))
  validate_required_commands || failed=$((failed + 1))
  
  if [[ $failed -gt 0  ]]; then
    log_error "Validations failed: $failed"
    return 1
  fi
  
  log_info " All validations passed"
  return 0
}
