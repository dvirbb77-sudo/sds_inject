#!/usr/bin/env bash
#
#
#

set -Eeuo pipefail
IFS=$'\n\t'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PARENT_DIR="$(dirname "$SCRIPT_DIR")"

source "$PARENT_DIR/automation/lib/logging.sh"
source "$PARENT_DIR/automation/lib/errors.sh"
source "$PARENT_DIR/automation/lib/healing.sh"
source "$PARENT_DIR/automation/runtime/detect.sh"

readonly TARGET_VERSION="${TARGET_VERSION:-1.31.1}"

function main()
{
    local node_type
    local current_version
    local version_status

    node_type=$(get_node_type)

    log_info "Current node type: $node_type"
    log_info "Current version: $(get_kubernetes_version)"
    log_info "Target version : $TARGET_VERSION"

    case "$node_type" in

        uninitialized)

            log_info "No cluster detected"
            exec bash "$PARENT_DIR/installer-entrypoint.sh" --master
            ;;

        master)

            current_version=$(get_kubernetes_version)

            log_warn "Control-plane detected"
            log_warn "Automatic control-plane upgrades are disabled"

            log_warn "Run manually:"
            log_warn "kubeadm upgrade plan"
            log_warn "kubeadm upgrade apply v${TARGET_VERSION}"

            exit 0
            ;;

        worker)

            if ! perform_healing "$node_type"; then
              log_warn "Healing phase had issues, continuing with reconciliation..."
            fi

            current_version="$(normalize_version "$(get_kubernetes_version)")"

            version_status=$(compare_versions \
                "$current_version" \
                "$TARGET_VERSION")

            case "$version_status" in

                equal)
                    log_info "Worker already at target version"
                    ;;

                older)
                    reconcile_worker "$current_version"
                    ;;

                newer)
                    log_warn "Worker newer than target"
                    ;;

                *)
                    handle_error "Unknown version state" 1
                    ;;
            esac

            ;;

        *)

            handle_error \
                "Unable to determine node state" \
                1
            ;;
    esac
}

function healing_phase_containerd() {
  log_info "Healing containerd..."
  
  if ! ensure_service_enabled containerd; then
    log_warn "Could not enable containerd"
  fi
  
  if ! ensure_service_running containerd; then
    log_error "containerd failed to heal"
    return 1
  fi
  
  return 0
}

function healing_phase_kubelet() {
  log_info "Healing kubelet..."
  
  if ! ensure_service_enabled kubelet; then
    log_warn "Could not enable kubelet"
  fi
  
  sleep 2
  
  if ! ensure_service_running kubelet; then
    log_error "kubelet failed to heal"
    return 1
  fi
  
  return 0
}

function healing_phase_sysctl() {
  log_info "Healing sysctl parameters..."
  
  local -a params=(
    "net.ipv4.ip_forward:1"
    "net.bridge.bridge-nf-call-iptables:1"
    "net.bridge.bridge-nf-call-ip6tables:1"
    "vm.overcommit_memory:1"
  )
  
  local failed=0
  for param_spec in "${params[@]}"; do
    local param="${param_spec%:*}"
    local expected="${param_spec#*:}"
    
    if ! ensure_sysctl "$param" "$expected"; then
      log_warn "Failed to verify/correct sysctl $param"
      failed=$((failed + 1))
    fi
  done
  
  if [[ $failed -gt 0  ]]; then
    return 1
  fi
  
  return 0
}

function perform_healing() {
  local node_type="$1"
  
  log_info "=== Beginning healing phase ==="
  
  if [[ "$node_type" != "worker"  ]]; then
    log_info "Skipping healing (not a worker node)"
    return 0
  fi
  
  local healing_failed=0
  
  if ! healing_phase_containerd; then
    log_warn "containerd healing failed, continuing..."
    healing_failed=$((healing_failed + 1))
  fi
  
  if ! healing_phase_sysctl; then
    log_warn "sysctl healing failed, continuing..."
    healing_failed=$((healing_failed + 1))
  fi
  
  if ! healing_phase_kubelet; then
    log_warn "kubelet healing failed, continuing with reconciliation..."
    healing_failed=$((healing_failed + 1))
  fi
  
  log_info "=== Healing phase complete (failures: $healing_failed) ==="
  
  return 0
}

function normalize_version()
{
    local version="$1"

    version="${version#v}"

    echo "$version"
}

function validate_version()
{
    local version="$1"

    [[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$  ]]
}

function compare_versions()
{
    local current
    local target

    current="$(normalize_version "$1")"
    target="$(normalize_version "$2")"

    validate_version "$current" || return 1
    validate_version "$target" || return 1

    local curr_major curr_minor
    local target_major target_minor

    curr_major=$(echo "$current" | cut -d. -f1)
    curr_minor=$(echo "$current" | cut -d. -f2)

    target_major=$(echo "$target" | cut -d. -f1)
    target_minor=$(echo "$target" | cut -d. -f2)

    if [[ $target_major -gt $curr_major  ]]; then
        echo older
    elif [[ $target_major -lt $curr_major  ]]; then
        echo newer
    elif [[ $target_minor -gt $curr_minor  ]]; then
        echo older
    elif [[ $target_minor -lt $curr_minor  ]]; then
        echo newer
    else
        echo equal
    fi
}

function reconcile_worker()
{
    local current_version="$1"

    log_warn "Worker node requires reconciliation"
    log_info "Current version: $current_version"
    log_info "Target version : $TARGET_VERSION"

    [[ -n "${MASTER_IP:-}"  ]] ||
        handle_error "MASTER_IP environment variable is required" 1

    [[ -n "${JOIN_TOKEN:-}"  ]] ||
        handle_error "JOIN_TOKEN environment variable is required" 1

    log_warn "Resetting worker node"

    kubeadm reset -f

    bash "$PARENT_DIR/installer-entrypoint.sh" \
        --worker \
        --master-ip "$MASTER_IP" \
        --join-token "$JOIN_TOKEN"
}

function cleanup_reconcile()
{
    log_debug "Reconciliation cleanup complete"
}

register_cleanup cleanup_reconcile

main "$@"
