# Project README and Documentation

# Kubernetes Self-Contained Installer

A production-grade, enterprise-ready Kubernetes bootstrap automation framework that produces a **single self-executing installer artifact** capable of deploying complete Kubernetes environments on clean Ubuntu 22.04 systems.

## Overview

The Kubernetes Installer is a comprehensive automation platform designed for:

- **Automated master node initialization** via kubeadm
- **Automated worker node provisioning** with cluster join
- **Upgrading/reinstalling worker nodes** in existing clusters
- **Self-contained deployment** - no external dependencies required
- **Offline installation** - all binaries bundled in single artifact
- **Enterprise operations** - observability, validation, error handling

The final deliverable is a single makeself-packaged `.run` file that operates completely offline and produces a production-ready Kubernetes cluster.

## Architecture

```
┌─────────────────────────────────────────────────┐
│   k8s-installer.run (Self-Executing Archive)   │
├─────────────────────────────────────────────────┤
│  • Kubernetes binaries (kubeadm, kubectl, etc) │
│  • Helm, Kustomize, crictl tools               │
│  • Container runtime (containerd)              │
│  • Automation scripts                           │
│  • Configuration templates                      │
└─────────────────────────────────────────────────┘
                      ↓
        ┌─────────────────────────────┐
        │  installer-entrypoint.sh    │
        │  (Bootstrap orchestrator)   │
        └─────────────────────────────┘
                      ↓
        ┌──────────────────────────┐
        │  Pre-installation phase  │
        │  • Validation            │
        │  • OS detection          │
        │  • State detection       │
        └──────────────────────────┘
                      ↓
    ┌─────────────────┴──────────────────┐
    ↓                                    ↓
┌─────────────┐              ┌──────────────────┐
│Master Mode  │              │Worker Mode       │
│             │              │                  │
│• sysctl     │              │• sysctl          │
│• k8s mods   │              │• k8s mods        │
│• containerd │              │• containerd      │
│• kubeadm    │              │• kubeadm         │
│• init       │              │• join            │
└─────────────┘              └──────────────────┘
```

## Repository Structure

```
sds-inject-project/
├── automation/                 # Core installation automation
│   ├── lib/                   # Reusable libraries
│   │   ├── logging.sh         # Structured logging framework
│   │   ├── errors.sh          # Error handling & cleanup
│   │   └── validation.sh      # Pre-flight checks
│   ├── common/                # Shared installation steps
│   │   ├── kernel-modules.sh  # Load kernel modules
│   │   ├── sysctl.sh          # Configure sysctl
│   │   ├── install-containerd.sh  # Container runtime
│   │   └── install-kubernetes.sh  # K8s packages
│   ├── master/                # Master node installation
│   │   └── install-master.sh  # kubeadm init
│   ├── worker/                # Worker node installation
│   │   └── install-worker.sh  # kubeadm join
│   └── runtime/               # Runtime utilities
│       └── detect.sh          # Node state detection
│
├── binaries/                  # (Placeholder) Binary artifacts
│   ├── kubernetes/
│   ├── helm/
│   ├── kustomize/
│   ├── crictl/
│   └── cni/
│
├── packaging/                 # Package manifests
│   ├── makeself/             # makeself templates
│   └── manifest/             # Package metadata
│
├── ci/                        # Continuous Integration
│   ├── Jenkinsfile           # Jenkins pipeline
│   ├── test/                 # CI test scripts
│   └── validation/           # CI validation
│
├── cd/                        # Continuous Deployment
│   ├── deploy.sh             # Remote deployment utility
│   └── reconcile.sh          # State reconciliation
│
├── configs/                   # Configuration templates
│   ├── kubeadm-master.yaml   # Master kubeadm config
│   ├── kubeadm-worker.yaml   # Worker kubeadm config
│   └── containerd-config.toml # containerd runtime config
│
├── tests/                     # Testing infrastructure
│   ├── unit/                 # Unit tests
│   ├── integration/          # Integration tests
│   └── vm/                   # VM test environment
│       └── Vagrantfile       # Vagrant VM definition
│
├── logs/                      # Runtime logs (created during install)
├── dist/                      # Build output (created by build.sh)
├── installer-entrypoint.sh   # Main installer entry point
├── build.sh                  # Build/package script
├── Makefile                  # Build automation
├── README.md                 # This file
└── .gitignore                # Git ignore patterns
```

## Requirements

### Host System (Build)
- Ubuntu 22.04 or later (for consistency)
- bash 5.0+
- git
- make
- curl
- jq
- shellcheck (for linting)
- shfmt (for formatting)
- makeself (for packaging)
- vagrant (optional, for VM testing)

### Target System (Installation)
- Ubuntu 22.04 LTS (exact version required)
- Minimum 2 CPU cores
- Minimum 2GB RAM
- Minimum 10GB disk space
- Network connectivity during installation
- Root access required

## Getting Started

### 1. Clone Repository

```bash
git clone https://github.com/yourorgan/sds-inject-project.git
cd sds-inject-project
```

### 2. Build Installer Package

```bash
# Validate scripts
make validate

# Run all checks (lint, test, build)
make ci-build

# Build installer artifact
make build

# Output: dist/k8s-installer.run
```

### 3. Deploy to System

#### Option A: Local installation (master node)

```bash
# Copy installer to target system
scp dist/k8s-installer.run root@target-system:/tmp/

# SSH to target and execute
ssh root@target-system
sudo /tmp/k8s-installer.run --master
```

#### Option B: Using deploy script (remote)

```bash
# Deploy master
cd/deploy.sh --host 192.168.1.10 --installer dist/k8s-installer.run --mode master

# Deploy worker
cd/deploy.sh \
  --host 192.168.1.11 \
  --installer dist/k8s-installer.run \
  --mode worker \
  --master-ip 192.168.1.10 \
  --join-token $(kubeadm token create)
```

#### Option C: Reconciliation mode

```bash
# Automatic detection and remediation
./cd/reconcile.sh
```

## Build & Package Flow

### 1. Source Assembly
```
automation/ + configs/ + binaries/ 
    ↓
Create payload directory structure
    ↓
Verify checksums
    ↓
Generate manifest.json
```

### 2. Manifest Generation
```json
{
  "kubernetes": "1.31.1",
  "helm": "3.16.1",
  "kustomize": "5.4.2",
  "containerd": "2.0.0",
  "crictl": "1.29.0",
  "build_date": "2026-05-26T12:00:00+00:00",
  "build_host": "ci-builder-01",
  "build_user": "jenkins"
}
```

### 3. Makeself Packaging
```bash
makeself.sh \
  --sha256 \
  --nomd5 \
  payload/ \
  dist/k8s-installer.run \
  "Kubernetes Self-Contained Installer" \
  "./installer-entrypoint.sh"
```

### 4. Output Artifact
```
dist/k8s-installer.run
├── Permissions: executable (755)
├── Metadata: SHA256 hash
└── Size: ~1-2GB (depends on binary versions)
```

## CI/CD Pipeline (Jenkins)

### Pipeline Stages

1. **Checkout** - Clone repository and verify source
2. **Shellcheck** - Static analysis of shell scripts
3. **Shfmt** - Shell script formatting validation
4. **Unit Tests** - Run basic unit tests
5. **Build Package** - Create installer artifact
6. **Verify Artifact** - Checksum and size validation
7. **Integration Tests** - Boot VM and test installation
8. **Archive Artifacts** - Save build outputs
9. **Notify** - Slack/email notifications

### Pipeline Features

- **Declarative syntax** for maintainability
- **Timeout protection** (2 hours max)
- **Artifact archival** for traceability
- **Build history** (keeps last 10 builds)
- **Failure notifications** with logs
- **Post-build cleanup** and resource release

### Running Locally

```bash
# Install Jenkins-related tools
apt-get install -y groovy

# Validate Jenkinsfile syntax
groovy -e 'new GroovyShell().evaluate(new File("ci/Jenkinsfile").text)'

# Run equivalent of pipeline
make ci-build
```

## Testing

### Unit Tests

```bash
# Run all unit tests
make test

# Run specific test
bash tests/unit/validation-tests.sh
```

### VM Integration Tests

```bash
# Boot test VM and run installer
make test-vm

# Manual VM control
cd tests/vm
vagrant up              # Create and provision VMs
vagrant ssh k8s-master  # SSH into master
vagrant provision       # Re-run provisioning
vagrant destroy         # Cleanup VMs
```

### Validation During Install

```bash
# Validate without installing
/tmp/k8s-installer.run --validate-only

# Install with debug logging
DEBUG=1 /tmp/k8s-installer.run --master
```

## Installation Modes

### Master Node (Control-Plane)

Installs a single control-plane node suitable for:
- Development/testing environments
- Single-node clusters
- Initial cluster bootstrap

```bash
k8s-installer.run --master
```

**What's installed:**
- containerd (container runtime)
- kubelet, kubeadm, kubectl
- etcd (embedded)
- kube-apiserver, kube-controller-manager, kube-scheduler
- System configurations (sysctl, kernel modules)

### Worker Node

Joins an existing Kubernetes cluster:
- Requires master endpoint and join token
- Suitable for scaling clusters horizontally
- Idempotent (can rejoin cluster)

```bash
k8s-installer.run \
  --worker \
  --master-ip 192.168.1.10 \
  --join-token 123abc.xyz789
```

**What's installed:**
- containerd (container runtime)
- kubelet, kubectl
- System configurations
- Automatic node registration

### Auto-Detect (Reconciliation)

Determines current state and applies appropriate installation:

```bash
# Automatic mode - detects and acts accordingly
k8s-installer.run

# Explicitly detect state
./cd/reconcile.sh
```

**Behavior:**
- If no Kubernetes: Install as master
- If Kubernetes + worker: Ready for upgrade
- If Kubernetes + master: Warn about dangers

## Configuration

### kubeadm Configuration

Master node (`configs/kubeadm-master.yaml`):
- Kubernetes version
- Pod subnet (for CNI)
- Service subnet
- API server endpoints

Worker node (`configs/kubeadm-worker.yaml`):
- Master endpoint
- Bootstrap token
- Node name

### containerd Configuration

Runtime settings (`configs/containerd-config.toml`):
- CGroup driver (systemd)
- Sandbox image
- Runtime runtimes

### Environment Variables

```bash
# Override versions during build
export KUBERNETES_VERSION=1.31.1
export HELM_VERSION=3.16.1
export KUSTOMIZE_VERSION=5.4.2
export CONTAINERD_VERSION=2.0.0

make build

# Override at install time
export LOG_DIR=/var/log/k8s-install
export DEBUG=1
/tmp/k8s-installer.run --master
```

## Logging

All installation operations produce structured, timestamped logs:

```
[2026-05-26 12:34:56] [INFO] Starting install
[2026-05-26 12:34:57] [INFO] Running pre-installation validations...
[2026-05-26 12:34:58] [INFO] Ubuntu 22.04 verified
[2026-05-26 12:35:01] [INFO] All validations passed
```

### Log Locations

- **Runtime logs**: `logs/install-YYYYMMDD-HHMMSS.log`
- **Default location**: `./logs/`
- **Custom location**: `export LOG_DIR=/var/log/k8s && export LOG_FILE=/var/log/k8s/install.log`

### Log Levels

- **INFO** - General informational messages
- **WARN** - Non-critical warnings
- **ERROR** - Errors requiring attention
- **DEBUG** - Detailed debugging (only if DEBUG=1)

## Troubleshooting

### Installation Fails with "Insufficient Memory"

**Issue**: Installer exits because system has < 2GB RAM

**Solution**:
```bash
# Check current memory
free -h

# Either allocate more resources or skip validation
k8s-installer.run --validate-only  # Dry run

# Custom validation
source automation/lib/validation.sh
validate_memory 1024  # Check for 1GB instead of 2GB
```

### Network Issues

**Issue**: Package download fails during installation

**Solution**:
1. Verify internet connectivity: `ping 8.8.8.8`
2. Check DNS: `nslookup kubernetes.io`
3. Use offline mode if binaries already present

### kubeadm Join Fails

**Issue**: Worker cannot join master

**Solution**:
1. Verify token hasn't expired: `kubeadm token list`
2. Generate new token: `kubeadm token create`
3. Check master is reachable: `ping <master-ip>`
4. Check firewall (port 6443): `nc -zv <master-ip> 6443`

### Conflicting Installations

**Issue**: Kubernetes already installed but in different state

**Solution**:
```bash
# Detect current state
source automation/runtime/detect.sh
get_node_type

# If safe to reset
kubeadm reset -f  # WARNING: Destructive!
# Then re-run installer
```

### Debug Installation

```bash
# Enable debug logging
DEBUG=1 k8s-installer.run --master

# Show all installation steps
set -x  # Before running installer
k8s-installer.run --master

# Validate intermediate steps
source automation/lib/logging.sh
source automation/lib/validation.sh
validate_all

# Check individual services
systemctl status kubelet
systemctl status containerd
kubectl get nodes
```

## Monitoring & Observability

### Post-Installation Verification

```bash
# Check kubelet status
sudo systemctl status kubelet

# Verify kubeadm installed correctly
kubeadm version

# Check node readiness
kubectl get nodes
kubectl describe node $(hostname)

# Verify cluster state
kubectl cluster-info
kubectl get cs

# Check CNI status
kubectl get daemonset -A
```

### Troubleshooting Commands

```bash
# Kubelet logs
journalctl -u kubelet -f

# containerd logs
journalctl -u containerd -f

# API server logs
tail -f /var/log/pods/kube-system_kube-apiserver-*/kube-apiserver/0.log

# All system services
systemctl --failed
```

## Deployment Examples

### Single-Node Development Cluster

```bash
# On clean Ubuntu 22.04 VM:
scp dist/k8s-installer.run root@devbox:/tmp/
ssh root@devbox
/tmp/k8s-installer.run --master
kubectl get nodes
```

### Three-Node Cluster

```bash
# Master
k8s-installer.run --master

# Workers (after master is ready)
TOKEN=$(kubeadm token create)
MASTER_IP=$(kubectl get node -o wide | grep master | awk '{print $6}')

for worker in 192.168.1.11 192.168.1.12; do
  cd/deploy.sh \
    --host $worker \
    --installer dist/k8s-installer.run \
    --mode worker \
    --master-ip $MASTER_IP \
    --join-token $TOKEN
done
```

### Multi-Cloud Deployment

```bash
# AWS EC2
aws ec2 run-instances --image-id ami-0c55b159cbfafe1f0 --instance-type t3.medium
cd/deploy.sh --host <ec2-ip> --mode master

# Azure VM
az vm create --image UbuntuLTS
cd/deploy.sh --host <azure-ip> --mode master

# GCP Compute
gcloud compute instances create k8s-node --image-family=ubuntu-2204-lts
cd/deploy.sh --host <gcp-ip> --mode master
```

## Future Improvements

- [ ] Multi-master HA configuration
- [ ] Custom CNI plugin selection (Calico, Flannel, Weave)
- [ ] In-cluster component upgrades
- [ ] Automated backup/restore procedures
- [ ] Node autoscaling integration
- [ ] Prometheus/Grafana observability stack
- [ ] Sealed Secrets integration
- [ ] Network policy templates
- [ ] Image registry cache/mirror
- [ ] Documentation in multiple languages

## Contributing

Guidelines for contributions:

1. **Shell scripts** - Must pass shellcheck and shfmt
2. **New features** - Add tests and documentation
3. **Bug fixes** - Include regression tests
4. **Documentation** - Keep README updated
5. **Commit messages** - Use conventional commits

## Security Considerations

**WARNING**: This installer is designed for controlled environments. Security considerations:

- Requires root access (dangerous!)
- Uses `kubeadm init` which has security implications
- Default certificates have limited validity
- Network policy not configured
- RBAC requires manual setup
- Consider security hardening before production use

### Security Hardening

For production deployments:

```bash
# After installation, apply security hardening
kubectl apply -f configs/network-policy.yaml  # (Create this)
kubectl apply -f configs/rbac-baseline.yaml   # (Create this)
kubectl apply -f configs/pod-security.yaml    # (Create this)
```

## Support & Issues

- Report issues: GitHub Issues
- Documentation: This README
- Logs: Check `logs/install-*.log` for detailed diagnostics
- Debug: Use `DEBUG=1` environment variable

## License

[Specify your license - MIT, Apache 2.0, etc.]

## Changelog

### v1.0.0 (2026-05-26)
- Initial release
- Master node installation
- Worker node provisioning
- Jenkins CI/CD pipeline
- Vagrant-based testing
- Comprehensive logging

---

**Last Updated**: 2026-05-26
**Maintainer**: DevOps Team
**Contact**: devops@example.com
