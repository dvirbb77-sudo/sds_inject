#!/usr/bin/env bash
#
#
#

set -Eeuo pipefail
IFS=$'\n\t'


SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "$SCRIPT_DIR/automation/lib/logging.sh"
source "$SCRIPT_DIR/automation/lib/errors.sh"
source "$SCRIPT_DIR/automation/lib/validation.sh"
source "$SCRIPT_DIR/automation/runtime/detect.sh"

readonly INSTALLER_VERSION="1.0.0"
readonly KUBERNETES_VERSION="${KUBERNETES_VERSION:-1.31.1}"
readonly HELM_VERSION="${HELM_VERSION:-3.16.1}"
readonly KUSTOMIZE_VERSION="${KUSTOMIZE_VERSION:-5.4.2}"
readonly CONTAINERD_VERSION="${CONTAINERD_VERSION:-2.0.0}"

main() {
  local mode="auto"
  local master_ip=""
  local join_token=""
  local validate_only=0
  
  while [[ $# -gt 0  ]]; do
    case "$1" in
      --master)
        mode="master"
        shift
        ;;
      --worker)
        mode="worker"
        shift
        ;;
      --master-ip)
        master_ip="$2"
        shift 2
        ;;
      --join-token)
        join_token="$2"
        shift 2
        ;;
      --validate-only)
        validate_only=1
        shift
        ;;
      --debug)
        DEBUG=1
: "${DEBUG:-}"
        shift
        ;;
      --help|-h)
        show_usage
        exit 0
        ;;
      *)
        log_error "Unknown option: $1"
        show_usage
        exit 1
        ;;
    esac
  done
  
  register_cleanup cleanup_installer
  
  log_info "=========================================="
  log_info "Kubernetes Installer v${INSTALLER_VERSION}"
  log_info "=========================================="
  log_info "System: $(uname -s) $(uname -r)"
  log_info "Log file: $(log_get_file)"
  
  if ! validate_all; then
    handle_error "Pre-installation validations failed" 1
  fi
  
  if [[ $validate_only -eq 1  ]]; then
    log_info "Validation only mode - exiting"
    exit 0
  fi
  
  local node_type
  node_type=$(get_node_type)
  log_info "Detected node type: $node_type"
  log_info "Kubelet status: $(get_kubelet_status)"
  
  if [[ "$mode" == "auto"  ]]; then
    if [[ "$node_type" == "uninitialized"  ]]; then
      mode="master"
      log_info "Auto-detected mode: installing as master"
    else
      log_warn "Node already initialized (type: $node_type)"
      log_warn "Use --master or --worker to override"
      return 0
    fi
  fi
  
  case "$mode" in
    master)
      log_info "Installing Kubernetes master node..."
      install_master
      ;;
    worker)
      if [[ -z "$master_ip"  ]] || [[ -z "$join_token"  ]]; then
        handle_error "Worker mode requires --master-ip and --join-token" 1
      fi
      log_info "Installing Kubernetes worker node..."
      install_worker "$master_ip" "$join_token"
      ;;
    *)
      handle_error "Unknown installation mode: $mode" 1
      ;;
  esac
  
  log_info "=========================================="
  log_info "✓ Installation complete"
  log_info "=========================================="
}

show_usage() {
  cat <<EOF
Usage: $0 [OPTIONS]

Kubernetes self-contained installer v${INSTALLER_VERSION}

OPTIONS:
  --master              Install as control-plane (master) node
  --worker              Install as worker node
  --master-ip IP        Master IP for worker join (worker mode)
  --join-token TOKEN    Join token for worker (worker mode)
  --validate-only       Run validations without installation
  --debug               Enable debug logging
  --help                Show this help message

EXAMPLES:
  $0 --master
  
  $0 --worker --master-ip 192.168.1.100 --join-token <token>
  
  $0 --validate-only

EOF
}

install_master() {

  bash "$SCRIPT_DIR/automation/common/kernel-modules.sh" "$(log_get_file)"
  bash "$SCRIPT_DIR/automation/common/sysctl.sh" "$(log_get_file)"  
  bash "$SCRIPT_DIR/automation/common/install-containerd.sh" "$CONTAINERD_VERSION" "$(log_get_file)"
  bash "$SCRIPT_DIR/automation/common/install-kubernetes.sh" "$KUBERNETES_VERSION" "$(log_get_file)"
  bash "$SCRIPT_DIR/automation/master/install-master.sh" "$(log_get_file)"  
  log_info "Master installation complete"
}

install_worker() {
  local master_ip="$1"
  local join_token="$2"

  bash "$SCRIPT_DIR/automation/common/kernel-modules.sh" "$(log_get_file)"
  bash "$SCRIPT_DIR/automation/common/sysctl.sh" "$(log_get_file)"
  
  bash "$SCRIPT_DIR/automation/common/install-containerd.sh" "$CONTAINERD_VERSION" "$(log_get_file)"
  
  bash "$SCRIPT_DIR/automation/common/install-kubernetes.sh" "$KUBERNETES_VERSION" "$(log_get_file)"
  
  bash "$SCRIPT_DIR/automation/worker/install-worker.sh" "$master_ip" "$join_token" "$(log_get_file)"
  
  log_info "Worker installation complete"
}

cleanup_installer() {
  log_debug "Running installer cleanup"
  
  if [[ $ERROR_OCCURRED -eq 1  ]]; then
    log_error "Installation failed - logs available at $(log_get_file)"
  fi
}

main "$@"
