#!/usr/bin/env bash
#
# detect.sh - Detect cluster configuration and node type
#

set -Eeuo pipefail
IFS=$'\n\t'

readonly KUBERNETES_DIR="${KUBERNETES_DIR:-/etc/kubernetes}"

function _systemctl()
{
    if [[ "${SYSTEMCTL_SKIP:-0}" == "1" ]]; then
        return 0
    fi

    systemctl "$@"
}

function is_kubernetes_installed()
{
    [[ -f "${KUBERNETES_DIR}/admin.conf" ]] ||
    [[ -f "${KUBERNETES_DIR}/kubelet.conf" ]]
}

function is_master_node()
{
    [[ -f "${KUBERNETES_DIR}/manifests/kube-apiserver.yaml" ]] &&
    [[ -f "${KUBERNETES_DIR}/manifests/kube-controller-manager.yaml" ]]
}

function is_worker_node()
{
    [[ -f "${KUBERNETES_DIR}/kubelet.conf" ]] || return 1

    is_master_node && return 1

    return 0
}

function get_node_type()
{
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

function get_kubelet_status()
{
    if [[ "${SYSTEMCTL_SKIP:-0}" == "1" ]]; then
        echo "configured"
        return 0
    fi

    if _systemctl is-active --quiet kubelet; then
        echo "running"
    elif _systemctl is-enabled --quiet kubelet; then
        echo "enabled"
    else
        echo "stopped"
    fi
}

function get_kubernetes_version()
{
    if command -v kubeadm >/dev/null 2>&1; then
        kubeadm version -o short 2>/dev/null || echo "unknown"
        return
    fi

    if command -v kubelet >/dev/null 2>&1; then
        kubelet --version 2>/dev/null | awk '{print $2}'
        return
    fi

    echo "not-installed"
}
