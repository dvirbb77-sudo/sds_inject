#!/usr/bin/env bash
#
#
#

set -Eeuo pipefail
IFS=$'\n\t'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source automation/lib/logging.sh
: "${SCRIPT_DIR:-}"

main() {
  local mode="auto"
  local timeout="${TIMEOUT:-300}"
  local kubeconfig="${KUBECONFIG:-/etc/kubernetes/admin.conf}"

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --master)
        mode="master"
        shift
        ;;
      --worker)
        mode="worker"
        shift
        ;;
      --timeout)
        timeout="$2"
        shift 2
        ;;
      --help|-h)
        print_help
        return 0
        ;;
      *)
        log_error "Unknown option: $1"
        print_help
        return 1
        ;;
    esac
  done

  log_info "=========================================="
  log_info "Kubernetes Installation Smoke Test"
  log_info "=========================================="
  log_info "Mode:       $mode"
  log_info "Timeout:    $timeout seconds"
  log_info "Kubeconfig: $kubeconfig"
  log_info ""

  local failed=0

  check_kubernetes_installed || failed=$((failed + 1))
  check_kubelet_status || failed=$((failed + 1))
  check_containerd_status || failed=$((failed + 1))
  check_kubeadm_status || failed=$((failed + 1))

  if [[ "$mode" == "master" || "$mode" == "auto" ]]; then
    check_apiserver_ready "$timeout" "$kubeconfig" || failed=$((failed + 1))
    check_master_ready "$timeout" "$kubeconfig" || failed=$((failed + 1))
    check_cluster_info "$kubeconfig" || failed=$((failed + 1))
  fi

  if [[ "$mode" == "worker" || "$mode" == "auto" ]]; then
    check_node_ready "$timeout" "$kubeconfig" || failed=$((failed + 1))
  fi

  log_info ""
  log_info "=========================================="
  if [[ $failed -eq 0 ]]; then
    log_info "All smoke tests passed"
    log_info "=========================================="
    return 0
  fi

  log_error "$failed test(s) failed"
  log_error "=========================================="
  return 1
}

print_help() {
  cat <<EOF
Usage: $0 [--master|--worker] [--timeout SECONDS]

Run post-installation Kubernetes smoke tests.
EOF
}

check_kubernetes_installed() {
  log_info "Checking Kubernetes binaries..."
  command -v kubectl >/dev/null 2>&1 && command -v kubeadm >/dev/null 2>&1
}

check_kubelet_status() {
  log_info "Checking kubelet service..."
  systemctl is-active kubelet >/dev/null 2>&1
}

check_containerd_status() {
  log_info "Checking containerd service..."
  systemctl is-active containerd >/dev/null 2>&1
}

check_kubeadm_status() {
  log_info "Checking kubeadm..."
  kubeadm version >/dev/null 2>&1
}

check_apiserver_ready() {
  local timeout="$1"
  local kubeconfig="$2"

  log_info "Checking API server readiness..."
  wait_for_command "$timeout" kubectl --kubeconfig "$kubeconfig" get --raw=/readyz
}

check_master_ready() {
  local timeout="$1"
  local kubeconfig="$2"

  log_info "Checking control-plane node readiness..."
  wait_for_command "$timeout" kubectl --kubeconfig "$kubeconfig" get nodes
}

check_cluster_info() {
  local kubeconfig="$1"

  log_info "Checking cluster info..."
  kubectl --kubeconfig "$kubeconfig" cluster-info >/dev/null 2>&1
}

check_node_ready() {
  local timeout="$1"
  local kubeconfig="$2"

  log_info "Checking node readiness..."
  wait_for_command "$timeout" kubectl --kubeconfig "$kubeconfig" wait --for=condition=Ready node --all
}

wait_for_command() {
  local timeout="$1"
  shift
  local deadline=$((SECONDS + timeout))

  until "$@" >/dev/null 2>&1; do
    if [[ $SECONDS -ge $deadline ]]; then
      return 1
    fi
    sleep 5
  done
}

main "$@"
