#!/usr/bin/env bash
#
#
#

set -Eeuo pipefail
IFS=$'\n\t'

KUBERNETES_VERSION="${1:-1.31.1}"
LOG_FILE="${2:-logs/install.log}"
: "${LOG_FILE:-}"

source automation/lib/logging.sh
source automation/lib/healing.sh

main() {
  log_info "Installing Kubernetes v${KUBERNETES_VERSION}..."
  
  if command -v kubeadm &>/dev/null; then
    local current_version
    current_version=$(kubeadm version -o short 2>/dev/null || echo "unknown")
    log_info "kubeadm already installed: ${current_version}"
    
    if ! healing_kubelet; then
      log_warn "Failed to heal kubelet, but kubeadm is present"
    fi
    
    return 0
  fi
  
  if ! ensure_package_installed curl; then
    log_warn "curl installation failed, attempting to continue..."
  fi
  
  log_info "Adding Kubernetes GPG key..."
  if ! curl -fsSL "https://pkgs.k8s.io/core:/stable:/v${KUBERNETES_VERSION%.*}/deb/Release.key" | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg 2>/dev/null; then
    log_warn "Failed to add Kubernetes GPG key (may impact package verification)"
  fi
  
  echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v${KUBERNETES_VERSION%.*}/deb/ /" > /etc/apt/sources.list.d/kubernetes.list
  
  apt-get update >/dev/null 2>&1 || log_warn "apt-get update had issues"
  
  if ! apt-get install -y "kubelet" kubeadm kubectl >/dev/null 2>&1; then
    log_error "Failed to install Kubernetes packages"
    return 1
  fi
  
  log_info "Installed Kubernetes packages"
  
  apt-mark hold kubelet kubeadm kubectl >/dev/null 2>&1 || log_warn "Failed to hold Kubernetes packages"
  
  systemctl daemon-reload >/dev/null 2>&1
  
  if ! healing_kubelet; then
    log_warn "kubelet not fully operational (may start after containerd is ready)"
  fi
  
  if ! validate_state "Kubernetes" "command -v kubeadm >/dev/null"; then
    log_error "Failed to verify Kubernetes installation"
    return 1
  fi
  
  log_info "✓ Kubernetes installation complete"
  return 0
}

function healing_kubelet() {
  log_info "Attempting to heal kubelet..."
  
  if ! ensure_service_enabled kubelet; then
    return 1
  fi
  
  if ! ensure_service_running kubelet; then
    log_warn "Kubelet failed to start, checking containerd..."
    if systemctl is-active containerd >/dev/null 2>&1; then
      log_warn "containerd is running, kubelet may need more time to initialize"
    else
      log_warn "containerd is not running, kubelet cannot start"
    fi
    return 1
  fi
  
  log_info "kubelet healing complete"
  return 0
}

main "$@"
