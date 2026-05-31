#!/usr/bin/env bash
#
#
#

set -Eeuo pipefail
IFS=$'\n\t'

KUBEADM_CONFIG="${1:-configs/kubeadm-master.yaml}"
LOG_FILE="${2:-logs/install.log}"
: "${LOG_FILE:-}"

main() {
  echo "[INFO] Installing Kubernetes master node..." | tee -a "$LOG_FILE"
  
  if ! command -v kubeadm &>/dev/null; then
    echo "[ERROR] kubeadm not found, run install-kubernetes.sh first" | tee -a "$LOG_FILE"
    return 1
  fi
  
  if [[ -f /etc/kubernetes/admin.conf  ]]; then
    echo "[INFO] Kubernetes master already initialized" | tee -a "$LOG_FILE"
    return 0
  fi
  
  echo "[INFO] Running kubeadm init..." | tee -a "$LOG_FILE"
  
  if [[ -f "$KUBEADM_CONFIG"  ]]; then
    kubeadm init --config="$KUBEADM_CONFIG" >> "$LOG_FILE" 2>&1
  else
    echo "[WARN] kubeadm config not found at $KUBEADM_CONFIG, using defaults" | tee -a "$LOG_FILE"
    kubeadm init >> "$LOG_FILE" 2>&1
  fi
  
  export KUBECONFIG=/etc/kubernetes/admin.conf
  
  echo "[INFO] Waiting for API server..." | tee -a "$LOG_FILE"
  local max_attempts=30
  local attempt=0
  
  while [[ $attempt -lt $max_attempts  ]]; do
    if kubectl get nodes >> "$LOG_FILE" 2>&1; then
      break
    fi
    attempt=$((attempt + 1))
    sleep 2
  done
  
  echo "[INFO] CNI installation not implemented yet" | tee -a "$LOG_FILE"
  echo "[TODO] Install selected CNI plugin (Calico, Flannel, etc.)" | tee -a "$LOG_FILE"

  echo "[INFO] Master node installation complete" | tee -a "$LOG_FILE"
  echo "[TODO] Configure CNI plugin for pod networking" | tee -a "$LOG_FILE"
  
  return 0
}

main "$@"

