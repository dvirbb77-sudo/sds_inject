#!/usr/bin/env bash
#
#
#

set -Eeuo pipefail
IFS=$'\n\t'

KUBERNETES_VERSION="1.31.1"
HELM_VERSION="3.16.1"
KUSTOMIZE_VERSION="5.4.2"
CONTAINERD_VERSION="2.0.0"
CRICTL_VERSION="1.29.0"
OUTPUT_DIR="binaries"
ARCH="amd64"
OS="linux"

main() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --version|--kubernetes-version)
        KUBERNETES_VERSION="$2"
        shift 2
        ;;
      --helm-version)
        HELM_VERSION="$2"
        shift 2
        ;;
      --kustomize-version)
        KUSTOMIZE_VERSION="$2"
        shift 2
        ;;
      --containerd-version)
        CONTAINERD_VERSION="$2"
        shift 2
        ;;
      --crictl-version)
        CRICTL_VERSION="$2"
        shift 2
        ;;
      --output)
        OUTPUT_DIR="$2"
        shift 2
        ;;
      --arch)
        ARCH="$2"
        shift 2
        ;;
      --help|-h)
        print_help
        return 0
        ;;
      *)
        echo "Unknown option: $1" >&2
        print_help >&2
        return 1
        ;;
    esac
  done

  mkdir -p \
    "$OUTPUT_DIR/kubernetes" \
    "$OUTPUT_DIR/helm" \
    "$OUTPUT_DIR/kustomize" \
    "$OUTPUT_DIR/containerd" \
    "$OUTPUT_DIR/crictl" \
    "$OUTPUT_DIR/cni"

  fetch_kubernetes
  fetch_helm
  fetch_kustomize
  fetch_containerd
  fetch_crictl
}

print_help() {
  cat <<EOF
Usage: $0 [OPTIONS]

Download binary artifacts into the installer binaries directory.

OPTIONS:
  --version VERSION              Kubernetes version
  --helm-version VERSION         Helm version
  --kustomize-version VERSION    Kustomize version
  --containerd-version VERSION   containerd version
  --crictl-version VERSION       crictl version
  --output DIR                   Output directory
  --arch ARCH                    Target architecture
EOF
}

fetch_kubernetes() {
  local base_url="https://dl.k8s.io/release/v${KUBERNETES_VERSION}/bin/${OS}/${ARCH}"
  local binary

  for binary in kubeadm kubelet kubectl; do
    download_file "$base_url/$binary" "$OUTPUT_DIR/kubernetes/$binary"
    chmod +x "$OUTPUT_DIR/kubernetes/$binary"
  done
}

fetch_helm() {
  local archive="helm-v${HELM_VERSION}-${OS}-${ARCH}.tar.gz"
  local url="https://get.helm.sh/$archive"
  local tmp_dir

  tmp_dir=$(mktemp -d)
  trap 'rm -rf "$tmp_dir"' RETURN
  download_file "$url" "$tmp_dir/$archive"
  tar -xzf "$tmp_dir/$archive" -C "$tmp_dir"
  install -m 0755 "$tmp_dir/${OS}-${ARCH}/helm" "$OUTPUT_DIR/helm/helm"
}

fetch_kustomize() {
  local archive="kustomize_v${KUSTOMIZE_VERSION}_${OS}_${ARCH}.tar.gz"
  local url="https://github.com/kubernetes-sigs/kustomize/releases/download/kustomize/v${KUSTOMIZE_VERSION}/$archive"
  local tmp_dir

  tmp_dir=$(mktemp -d)
  trap 'rm -rf "$tmp_dir"' RETURN
  download_file "$url" "$tmp_dir/$archive"
  tar -xzf "$tmp_dir/$archive" -C "$tmp_dir"
  install -m 0755 "$tmp_dir/kustomize" "$OUTPUT_DIR/kustomize/kustomize"
}

fetch_containerd() {
  local archive="containerd-${CONTAINERD_VERSION}-${OS}-${ARCH}.tar.gz"
  local url="https://github.com/containerd/containerd/releases/download/v${CONTAINERD_VERSION}/$archive"

  download_file "$url" "$OUTPUT_DIR/containerd/$archive"
}

fetch_crictl() {
  local archive="crictl-v${CRICTL_VERSION}-${OS}-${ARCH}.tar.gz"
  local url="https://github.com/kubernetes-sigs/cri-tools/releases/download/v${CRICTL_VERSION}/$archive"
  local tmp_dir

  tmp_dir=$(mktemp -d)
  trap 'rm -rf "$tmp_dir"' RETURN
  download_file "$url" "$tmp_dir/$archive"
  tar -xzf "$tmp_dir/$archive" -C "$tmp_dir"
  install -m 0755 "$tmp_dir/crictl" "$OUTPUT_DIR/crictl/crictl"
}

download_file() {
  local url="$1"
  local output="$2"

  echo "[INFO] Downloading $url"
  curl -fL --retry 3 --retry-delay 2 -o "$output" "$url"
}

main "$@"
