#!/usr/bin/env bash
#
#
#

set -Eeuo pipefail
IFS=$'\n\t'

CONTAINERD_VERSION="${1:-2.0.0}"
LOG_FILE="${2:-logs/install.log}"
: "${LOG_FILE:-}"

source automation/lib/logging.sh
source automation/lib/healing.sh

main() {
  log_info "Installing containerd v${CONTAINERD_VERSION}..."
  

  if command -v containerd &>/dev/null; then
    local current_version
    current_version=$(containerd --version | awk '{print $3}')
    log_info "containerd already installed: v${current_version}"
    
    if ! healing_containerd; then
      log_error "Failed to heal containerd"
      return 1
    fi
    
    return 0
  fi
  
  if ! ensure_package_installed containerd containerd.io; then
    log_error "Failed to install containerd"
    return 1
  fi
  
  if [[ ! -d /etc/containerd  ]]; then
    mkdir -p /etc/containerd
  fi
  
  containerd config default > /etc/containerd/config.toml
  
  sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
  
  systemctl daemon-reload
  
  if ! ensure_service_enabled containerd; then
    log_error "Failed to enable containerd"
    return 1
  fi
  
  if ! ensure_service_running containerd; then
    log_error "Failed to start containerd"
    return 1
  fi
  
  if ! validate_state "containerd" "command -v containerd >/dev/null"; then
    log_error "Failed to verify containerd installation"
    return 1
  fi
  
  log_info "✓ containerd installation complete"
  return 0
}

function healing_containerd() {
  log_info "Attempting to heal containerd..."
  
  if ! ensure_package_installed containerd containerd.io; then
    return 1
  fi
  
  if ! ensure_service_enabled containerd; then
    return 1
  fi
  
  if ! ensure_service_running containerd; then
    return 1
  fi
  
  log_info "containerd healing complete"
  return 0
}

main "$@"
