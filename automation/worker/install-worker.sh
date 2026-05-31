#!/usr/bin/env bash
#
#
#

set -Eeuo pipefail
IFS=$'\n\t'

MASTER_IP="${1:-}"
JOIN_TOKEN="${2:-}"
LOG_FILE="${3:-logs/install.log}"
: "${LOG_FILE:-}"

main() {
  echo "[INFO] Installing Kubernetes worker node..." | tee -a "$LOG_FILE"
  
  if [[ -z "$MASTER_IP"  ]] || [[ -z "$JOIN_TOKEN"  ]]; then
    echo "[ERROR] Usage: install-worker.sh <master_ip> <join_token>" | tee -a "$LOG_FILE"
    return 1
  fi
  
  if ! command -v kubeadm &>/dev/null; then
    echo "[ERROR] kubeadm not found, run install-kubernetes.sh first" | tee -a "$LOG_FILE"
    return 1
  fi
  
  if grep -q "certificate" /etc/kubernetes/kubelet.conf 2>/dev/null; then
    echo "[INFO] Worker node already joined to cluster" | tee -a "$LOG_FILE"
    return 0
  fi
  
  echo "[INFO] Joining cluster at $MASTER_IP..." | tee -a "$LOG_FILE"
  
  echo "[INFO] Discovering cluster CA certificate..." | tee -a "$LOG_FILE"
  local ca_cert_hash
  if ! ca_cert_hash=$(
    kubectl --server="https://$MASTER_IP:6443" \
      --insecure-skip-tls-verify=true \
      -n kube-public \
      get configmap cluster-info \
      -o jsonpath='{.data.kubeconfig}' 2>>"$LOG_FILE" |
      awk '/certificate-authority-data:/ {print $2; exit}' |
      base64 -d |
      openssl x509 -pubkey -noout 2>>"$LOG_FILE" |
      openssl pkey -pubin -outform DER 2>>"$LOG_FILE" |
      openssl dgst -sha256 -hex |
      awk '{print "sha256:" $2}'
  ); then
    echo "[ERROR] Failed to discover cluster CA certificate" | tee -a "$LOG_FILE"
    return 1
  fi

  if [[ ! "$ca_cert_hash" =~ ^sha256:[0-9a-f]{64}$  ]]; then
    echo "[ERROR] Failed to discover a valid cluster CA certificate hash" | tee -a "$LOG_FILE"
    return 1
  fi

  kubeadm join "$MASTER_IP:6443" \
    --token "$JOIN_TOKEN" \
    --discovery-token-ca-cert-hash "$ca_cert_hash" \
    >> "$LOG_FILE" 2>&1 || {
    echo "[ERROR] Failed to join cluster" | tee -a "$LOG_FILE"
    return 1
  }
  
  systemctl start kubelet >> "$LOG_FILE" 2>&1
  
  echo "[INFO] ✓ Worker node joined cluster" | tee -a "$LOG_FILE"
  
  return 0
}

main "$@"

