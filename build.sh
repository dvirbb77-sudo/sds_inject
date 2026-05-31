#!/usr/bin/env bash
#
#
#

set -Eeuo pipefail
IFS=$'\n\t'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DIST_DIR="${SCRIPT_DIR}/dist"
PAYLOAD_DIR="${SCRIPT_DIR}/payload"
MANIFEST_FILE="${SCRIPT_DIR}/packaging/manifest/manifest.json"

KUBERNETES_VERSION="${KUBERNETES_VERSION:-1.31.1}"
HELM_VERSION="${HELM_VERSION:-3.16.1}"
KUSTOMIZE_VERSION="${KUSTOMIZE_VERSION:-5.4.2}"
CONTAINERD_VERSION="${CONTAINERD_VERSION:-2.0.0}"
CRICTL_VERSION="${CRICTL_VERSION:-1.29.0}"

main() {
  log_info "Building Kubernetes installer package..."
  log_info "Kubernetes: $KUBERNETES_VERSION"
  log_info "Helm: $HELM_VERSION"
  log_info "Kustomize: $KUSTOMIZE_VERSION"
  log_info "Containerd: $CONTAINERD_VERSION"
  
  if [[ -d "$PAYLOAD_DIR"  ]]; then
    log_info "Cleaning previous payload..."
    rm -rf "$PAYLOAD_DIR"
  fi
  
  log_info "Creating payload structure..."
  mkdir -p "$PAYLOAD_DIR"
  

  cp -r "$SCRIPT_DIR/automation" "$PAYLOAD_DIR/"
  cp -r "$SCRIPT_DIR/configs" "$PAYLOAD_DIR/"
  cp "$SCRIPT_DIR/installer-entrypoint.sh" "$PAYLOAD_DIR/"
  mkdir -p "$PAYLOAD_DIR/logs"
  
  log_info "Copying binaries..."
  mkdir -p "$PAYLOAD_DIR/binaries"
  cp -a "$SCRIPT_DIR/binaries/." "$PAYLOAD_DIR/binaries/"
  

  log_info "Creating manifest..."
  mkdir -p "$(dirname "$MANIFEST_FILE")"
  cat > "$MANIFEST_FILE" <<EOF
{
  "kubernetes": "$KUBERNETES_VERSION",
  "helm": "$HELM_VERSION",
  "kustomize": "$KUSTOMIZE_VERSION",
  "containerd": "$CONTAINERD_VERSION",
  "crictl": "$CRICTL_VERSION",
  "build_date": "$(date -Iseconds)",
  "build_host": "$(hostname)",
  "build_user": "$USER"
}
EOF
  
  cp "$MANIFEST_FILE" "$PAYLOAD_DIR/"
  

  mkdir -p "$DIST_DIR"

  if ! command -v makeself.sh &>/dev/null; then
    log_error "makeself not found - install with: apt-get install makeself"
    return 1
  fi
  
  log_info "Creating makeself archive..."
  local installer="${DIST_DIR}/k8s-installer.run"
  
  makeself.sh \
    --sha256 \
    --nomd5 \
    "$PAYLOAD_DIR" \
    "$installer" \
    "Kubernetes Self-Contained Installer" \
    "./installer-entrypoint.sh"
  
  if [[ ! -f "$installer"  ]]; then
    log_error "Failed to create installer package"
    return 1
  fi
  
  chmod +x "$installer"
  
  local size
  size=$(du -h "$installer" | cut -f1)
  local sha256
  sha256=$(sha256sum "$installer" | awk '{print $1}')
  
  log_info "=========================================="
  log_info " Build complete!"
  log_info "=========================================="
  log_info "Installer: $installer"
  log_info "Size: $size"
  log_info "SHA256: $sha256"
  log_info "=========================================="
  
  return 0
}

log_info() {
  echo "[INFO] $*"
}

log_error() {
  echo "[ERROR] $*" >&2
}

main "$@"
