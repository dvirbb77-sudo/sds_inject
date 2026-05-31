#!/usr/bin/env bash
#
# detect.sh - Detect cluster configuration and node type
# Determines if node is master/worker and current installation state
#

set -Eeuo pipefail
IFS=$'\n\t'

KUBERNETES_DIR="${KUBERNETES_DIR:-/etc/kubernetes}"
SYSTEMCTL_SKIP="${SYSTEMCTL_SKIP:-0}"

function is_kubernetes_installed() {
  [[ -f "$KUBERNETES_DIR/admin.conf"  ]] || [[ -f "$KUBERNETES_DIR/kubelet.conf"  ]]
}

function is_master_node() {
  [[ -f "$KUBERNETES_DIR/manifests/kube-apiserver.yaml"  ]] && \
  [[ -f "$KUBERNETES_DIR/manifests/kube-controller-manager.yaml"  ]]
}

function is_worker_node() {
  [[ -f "$KUBERNETES_DIR/kubelet.conf"  ]] && ! is_master_node
}

function get_node_type() {
  if ! is_kubernetes_installed; then
    echo "uninitialized"
  elif is_master_node; then
    echo "master"
  elif is_worker_node; then
    echo "worker"
  else
    echo "unknown"
  fi
}

function get_kubelet_status() {
  if [[ "$SYSTEMCTL_SKIP" -eq 1  ]]; then
    [[ -f "$KUBERNETES_DIR/kubelet.conf"  ]] && echo "configured" || echo "not-configured"
    return 0
  fi

  if systemctl is-active --quiet kubelet 2>/dev/null; then
    echo "running"
  elif systemctl is-enabled --quiet kubelet 2>/dev/null; then
    echo "enabled"
  else
    echo "stopped"
  fi
}

function get_kubernetes_version() {
  if command -v kubeadm &>/dev/null; then
    kubeadm version -o short 2>/dev/null || echo "unknown"
  elif command -v kubectl &>/dev/null; then
    kubectl version --short 2>/dev/null | grep "Server" || echo "unknown"
  else
    echo "not-installed"
  fi
}

