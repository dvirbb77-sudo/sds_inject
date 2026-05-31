#!/usr/bin/env bash
#
#
#

set -Eeuo pipefail
IFS=$'\n\t'

if [[ -f "automation/lib/logging.sh"  ]]; then
  source automation/lib/logging.sh
fi

function retry() {
  local max_attempts="$1"
  local delay="$2"
  shift 2
  local command=("$@")
  
  local attempt=1
  
  while [[ $attempt -le $max_attempts  ]]; do
    log_debug "Attempt $attempt/$max_attempts: ${command[*]}"
    
    if "${command[@]}"; then
      log_debug "Command succeeded on attempt $attempt"
      return 0
    fi
    
    if [[ $attempt -lt $max_attempts  ]]; then
      log_debug "Command failed, waiting ${delay}s before retry..."
      sleep "$delay"
    fi
    
    attempt=$((attempt + 1))
  done
  
  log_error "Command failed after $max_attempts attempts: ${command[*]}"
  return 1
}

function ensure_service_running() {
  local service="$1"
  
  if [[ -z "$service"  ]]; then
    log_error "ensure_service_running: service name required"
    return 1
  fi
  
  if systemctl is-active "$service" >/dev/null 2>&1; then
    log_debug "$service is already running"
    return 0
  fi
  
  log_warn "$service is not running, attempting restart..."
  
  if systemctl restart "$service" >/dev/null 2>&1; then
    log_info "Restarted $service"
    
    sleep 1
    if systemctl is-active "$service" >/dev/null 2>&1; then
      log_info "$service is now active"
      return 0
    else
      log_error "$service is still inactive after restart"
      return 1
    fi
  else
    log_error "Failed to restart $service"
    return 1
  fi
}

function ensure_service_enabled() {
  local service="$1"
  
  if [[ -z "$service"  ]]; then
    log_error "ensure_service_enabled: service name required"
    return 1
  fi
  
  if systemctl is-enabled "$service" >/dev/null 2>&1; then
    log_debug "$service is already enabled"
    return 0
  fi
  
  log_warn "$service is not enabled, enabling..."
  
  if systemctl enable "$service" >/dev/null 2>&1; then
    log_info "Enabled $service"
    
    if systemctl is-enabled "$service" >/dev/null 2>&1; then
      log_info "$service is now enabled"
      return 0
    else
      log_error "$service is still disabled after enable"
      return 1
    fi
  else
    log_error "Failed to enable $service"
    return 1
  fi
}

function ensure_package_installed() {
  local binary="$1"
  local package="${2:-$1}"
  
  if [[ -z "$binary"  ]]; then
    log_error "ensure_package_installed: binary name required"
    return 1
  fi
  
  if command -v "$binary" >/dev/null 2>&1; then
    log_debug "$binary is already installed"
    return 0
  fi
  
  log_warn "$binary not found, installing $package..."
  
  if ! apt-get update >/dev/null 2>&1; then
    log_warn "apt-get update failed, continuing..."
  fi
  
  if apt-get install -y "$package" >/dev/null 2>&1; then
    log_info "Installed $package"
    
    if command -v "$binary" >/dev/null 2>&1; then
      log_info "$binary is now available"
      return 0
    else
      log_error "$binary still not found after install"
      return 1
    fi
  else
    log_error "Failed to install $package"
    return 1
  fi
}

function ensure_module_loaded() {
  local module="$1"
  
  if [[ -z "$module"  ]]; then
    log_error "ensure_module_loaded: module name required"
    return 1
  fi
  
  if lsmod 2>/dev/null | grep -q "^${module}"; then
    log_debug "$module is already loaded"
    return 0
  fi
  
  log_warn "$module is not loaded, loading..."
  
  if modprobe "$module" >/dev/null 2>&1; then
    log_info "Loaded kernel module $module"
    
    if lsmod 2>/dev/null | grep -q "^${module}"; then
      log_info "$module is now loaded"
      return 0
    else
      log_error "$module did not persist after modprobe"
      return 1
    fi
  else
    log_warn "Failed to load kernel module $module (may not be available)"
    return 1
  fi
}

function ensure_sysctl() {
  local param="$1"
  local expected="$2"
  
  if [[ -z "$param" || -z "$expected"  ]]; then
    log_error "ensure_sysctl: param name and value required"
    return 1
  fi
  
  local current
  current=$(sysctl -n "$param" 2>/dev/null || echo "")
  
  if [[ "$current" == "$expected"  ]]; then
    log_debug "$param is already set to $expected"
    return 0
  fi
  
  log_warn "$param is $current, expected $expected - applying correction..."
  
  if sysctl -w "$param=$expected" >/dev/null 2>&1; then
    log_info "Set $param to $expected"
    
    current=$(sysctl -n "$param" 2>/dev/null || echo "")
    if [[ "$current" == "$expected"  ]]; then
      log_info "$param is now correctly set to $expected"
      return 0
    else
      log_error "$param is still $current after sysctl -w"
      return 1
    fi
  else
    log_error "Failed to set $param to $expected"
    return 1
  fi
}

function validate_state() {
  local state_name="$1"
  local validation_cmd="$2"
  
  if [[ -z "$state_name" || -z "$validation_cmd"  ]]; then
    log_error "validate_state: state_name and validation_command required"
    return 1
  fi
  
  log_debug "Validating state: $state_name"
  
  if eval "$validation_cmd" >/dev/null 2>&1; then
    log_info " $state_name validation passed"
    return 0
  else
    log_warn " $state_name validation failed"
    return 1
  fi
}

function healing_summary() {
  local service="$1"
  local status="${2:-unknown}"
  local message="${3:-}"
  
  case "$status" in
    success)
      log_info "Healing summary: $service healed successfully $message"
      ;;
    failure)
      log_error "Healing summary: $service healing failed $message"
      log_error "[ACTION] Check service status: systemctl status $service"
      log_error "[ACTION] Check logs: journalctl -u $service -n 20"
      ;;
    *)
      log_warn "Healing summary: $service healing status unknown"
      ;;
  esac
}

function perform_healing_phase() {
  local component="$1"
  local healing_func="$2"
  
  if [[ -z "$component" || -z "$healing_func"  ]]; then
    log_error "perform_healing_phase: component name and healing function required"
    return 1
  fi
  
  log_info "=== Healing phase: $component ==="
  
  if declare -f "$healing_func" >/dev/null 2>&1; then
    if "$healing_func"; then
      log_info "Healing phase for $component completed successfully"
      return 0
    else
      log_error "Healing phase for $component failed"
      return 1
    fi
  else
    log_error "Healing function $healing_func not found"
    return 1
  fi
}

declare -g HEALING_LOADED=1
: "${HEALING_LOADED:-}"

