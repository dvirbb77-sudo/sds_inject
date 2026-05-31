#!/usr/bin/env bash
#
#
#

set -Eeuo pipefail
IFS=$'\n\t'

source automation/lib/logging.sh
source automation/lib/healing.sh

main() {
  : "${1:-logs/install.log}"
  
  log_info "Loading kernel modules..."
  
  local modules=(
    "overlay"
    "br_netfilter"
    "vhost_net"
    "vhost_vsock"
  )
  
  local failed=0
  
  for module in "${modules[@]}"; do
    if ! ensure_module_loaded "$module"; then
      log_warn "Failed to load module: $module"
      failed=$((failed + 1))
    else
      log_info "Loaded kernel module: $module"
    fi
  done
  
  cat > /etc/modules-load.d/kubernetes.conf <<EOF
overlay
br_netfilter
EOF
  
  log_info "✓ Kernel module configuration complete"
  
  if [[ $failed -gt 0  ]]; then
    log_warn "Failed to load $failed modules"
    return 1
  fi
  
  return 0
}

main "$@"
