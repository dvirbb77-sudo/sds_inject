#!/usr/bin/env bash
#
#
#

set -Eeuo pipefail
IFS=$'\n\t'

main() {
  local host=""
  local installer="dist/k8s-installer.run"
  local mode="auto"
  local master_ip=""
  local join_token=""
  local ssh_user="root"
  local ssh_key=""
  local timeout=3600
  local dry_run=0
  
  while [[ $# -gt 0  ]]; do
    case "$1" in
      --host)
        host="$2"
        shift 2
        ;;
      --installer)
        installer="$2"
        shift 2
        ;;
      --mode)
        mode="$2"
        shift 2
        ;;
      --master-ip)
        master_ip="$2"
        shift 2
        ;;
      --join-token)
        join_token="$2"
        shift 2
        ;;
      --user)
        ssh_user="$2"
        shift 2
        ;;
      --key)
        ssh_key="$2"
        shift 2
        ;;
      --timeout)
        timeout="$2"
        shift 2
        ;;
      --dry-run)
        dry_run=1
        shift
        ;;
      --help|-h)
        show_usage
        exit 0
        ;;
      *)
        echo "Unknown option: $1"
        show_usage
        exit 1
        ;;
    esac
  done
  
  if [[ -z "$host"  ]]; then
    echo "Error: --host is required"
    show_usage
    exit 1
  fi
  
  if [[ ! -f "$installer"  ]]; then
    echo "Error: Installer not found: $installer"
    exit 1
  fi
  
  echo "[INFO] Deploying to: $host"
  echo "[INFO] Installer: $installer"
  echo "[INFO] Mode: $mode"
  

  local ssh_cmd="ssh"
  if [[ -n "$ssh_key"  ]]; then
    ssh_cmd="$ssh_cmd -i $ssh_key"
  fi
  ssh_cmd="$ssh_cmd -o ConnectTimeout=10"
  
  local remote_cmd="/tmp/k8s-installer.run"
  remote_cmd="$remote_cmd --mode $mode"
  
  if [[ "$mode" == "worker"  ]]; then
    if [[ -z "$master_ip"  ]]; then
      echo "Error: --master-ip required for worker mode"
      exit 1
    fi
    remote_cmd="$remote_cmd --master-ip $master_ip"
    
    if [[ -z "$join_token"  ]]; then
      echo "Error: --join-token required for worker mode"
      exit 1
    fi
    remote_cmd="$remote_cmd --join-token $join_token"
  fi
  
  if [[ $dry_run -eq 1  ]]; then
    echo "[DRY-RUN] Would execute:"
    echo "  1. Copy $installer to $ssh_user@$host:/tmp/"
    echo "  2. Execute: $remote_cmd"
    return 0
  fi
  
  echo "[INFO] Copying installer to $host..."
  if ! scp "$installer" "$ssh_user@$host:/tmp/k8s-installer.run"; then
    echo "[ERROR] Failed to copy installer"
    exit 1
  fi
  
  echo "[INFO] Executing installer on $host..."
  if ! $ssh_cmd "$ssh_user@$host" timeout "$timeout" "bash $remote_cmd"; then
    echo "[ERROR] Installation failed"
    exit 1
  fi
  
  echo "[INFO] ✓ Deployment complete"
}

show_usage() {
  cat <<EOF
Usage: $0 [OPTIONS]

Deploy Kubernetes installer to remote system

OPTIONS:
  --host HOST           Target hostname or IP (required)
  --installer PATH      Path to k8s-installer.run (default: dist/k8s-installer.run)
  --mode MODE           Installation mode: master, worker (default: auto-detect)
  --master-ip IP        Master IP for worker mode
  --join-token TOKEN    Join token for worker mode
  --user USER           SSH user (default: root)
  --key PATH            SSH private key path
  --timeout SECONDS     Command timeout (default: 3600)
  --dry-run             Show what would be executed
  --help                Show this help

EXAMPLES:
  $0 --host node1 --installer dist/k8s-installer.run --mode master
  
  $0 --host node2 --installer dist/k8s-installer.run \\
     --mode worker --master-ip 192.168.1.100 --join-token abc123

EOF
}

main "$@"
