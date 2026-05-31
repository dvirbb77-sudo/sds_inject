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
  
  log_info "Configuring sysctl parameters..."
  
  local -A sysctls=(
    ["net.ipv4.ip_forward"]="1"
    ["net.bridge.bridge-nf-call-iptables"]="1"
    ["net.bridge.bridge-nf-call-ip6tables"]="1"
    ["net.ipv4.ip_unprivileged_port_start"]="0"
    ["vm.overcommit_memory"]="1"
    ["kernel.panic"]="10"
    ["kernel.panic_on_oops"]="1"
    ["fs.file-max"]="2097152"
    ["fs.inotify.max_user_watches"]="524288"
  )
  
  local failed=0
  for param in "${!sysctls[@]}"; do
    if ! ensure_sysctl "$param" "${sysctls[$param]}"; then
      log_warn "Failed to set $param to ${sysctls[$param]}"
      failed=$((failed + 1))
    fi
  done
  
  cat > /etc/sysctl.d/99-kubernetes.conf <<EOF
net.ipv4.ip_forward=1
net.bridge.bridge-nf-call-iptables=1
net.bridge.bridge-nf-call-ip6tables=1
net.ipv4.ip_unprivileged_port_start=0
vm.overcommit_memory=1
kernel.panic=10
kernel.panic_on_oops=1
fs.file-max=2097152
fs.inotify.max_user_watches=524288
EOF
  
  if sysctl -p /etc/sysctl.d/99-kubernetes.conf >/dev/null 2>&1; then
    log_info "Applied persistent sysctl configuration"
  else
    log_warn "Failed to apply persistent sysctl configuration"
    failed=$((failed + 1))
  fi
  
  log_info "Disabling swap..."
  swapoff -a >/dev/null 2>&1 || log_warn "Failed to disable swap (may not be present)"
  sed -i '/ swap / s/^/#/' /etc/fstab >/dev/null 2>&1 || log_warn "Failed to comment swap in fstab"
  
  log_info "✓ sysctl configuration complete"
  
  if [[ $failed -gt 0  ]]; then
    log_warn "Failed to apply $failed sysctl parameters"
    return 1
  fi
  
  return 0
}

main "$@"
