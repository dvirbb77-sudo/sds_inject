# Project README and Documentation

# Kubernetes Self-Contained Installer

A Kubernetes bootstrap automation framework that produces a **single self-executing installer artifact** capable of deploying complete Kubernetes environments on clean Ubuntu 22.04 systems.

## Overview

The Kubernetes Installer is a comprehensive automation platform designed for:

- Automated master node initialization via kubeadm
- Automated worker node provisioning with cluster join
- Upgrading/reinstalling worker nodes in existing clusters
- Self-contained deployment - no external dependencies required
- Offline installation - all binaries bundled in single artifact
- Enterprise operations - observability, validation, error handling

The final deliverable is a single makeself-packaged .run file that operates completely offline and produces a production-ready Kubernetes cluster.

## Key Features

- Binary Acquisition: Automated download and caching of all required Kubernetes components
- Smoke Testing: Post-installation validation to ensure cluster readiness
- Multi-Node Support: Deploy master and worker nodes with Vagrant or production environment
- Self-Healing: Automatic service recovery and drift detection
- Structured Logging: Comprehensive, timestamped operation logs
- Production Guide: Step-by-step deployment procedures with troubleshooting

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
├── automation/
│   ├── lib/
│   │   ├── logging.sh
│   │   ├── errors.sh
│   │   ├── validation.sh
│   │   └── healing.sh
│   ├── common/
│   │   ├── kernel-modules.sh
│   │   ├── sysctl.sh
│   │   ├── install-containerd.sh
│   │   └── install-kubernetes.sh
│   ├── master/
│   │   └── install-master.sh
│   ├── worker/
│   │   └── install-worker.sh
│   └── runtime/
│       └── detect.sh
│
├── binaries/
│   ├── kubernetes/
│   ├── helm/
│   ├── kustomize/
│   ├── crictl/
│   └── containerd/
│
├── packaging/
│   ├── makeself/
│   └── manifest/
│
├── ci/
│   ├── Jenkinsfile
│   ├── notify.sh
│   ├── notify-slack.sh
│   ├── notify-email.sh
│   ├── test/
│   └── validation/
│
├── cd/
│   ├── deploy.sh
│   ├── reconcile.sh
│   └── fetch-binaries.sh
│
├── configs/
│   ├── kubeadm-master.yaml
│   ├── kubeadm-worker.yaml
│   └── containerd-config.toml
│
├── tests/
│   ├── unit/
│   ├── integration/
│   ├── smoke-test.sh
│   └── vm/
│       └── Vagrantfile
│
├── logs/
├── dist/
├── installer-entrypoint.sh
├── build.sh
├── Makefile
├── README.md
├── PRODUCTION_DEPLOYMENT.md
├── IMPLEMENTATION_GUIDE.md
├── HEALING_FRAMEWORK.md
├── PROJECT_SUMMARY.txt
├── START_HERE.md
└── .gitignore
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
git clone <repository-url>
cd sds_inject_project
```

### 2. Prepare Build Environment

```bash
sudo apt-get update
sudo apt-get install -y bash jq curl wget shellcheck shfmt makeself vagrant virtualbox
```

### 3. Download Kubernetes Binaries

```bash
make fetch-binaries

cd/fetch-binaries.sh [--version VERSION] [--output DIR] [--verify-only]
```

Supported version overrides:

```bash
make fetch-binaries \
  KUBERNETES_VERSION=1.30.0 \
  HELM_VERSION=3.15.0 \
  KUSTOMIZE_VERSION=5.3.0 \
  CONTAINERD_VERSION=1.7.0 \
  CRICTL_VERSION=1.28.0
```

### 4. Build Installer Package

```bash
make validate

make ci-build

make build
```

Output: dist/k8s-installer.run (approximately 1-2GB)

### 5. Smoke Test (Optional)

```bash
bash tests/smoke-test.sh --master

bash tests/smoke-test.sh --worker

bash tests/smoke-test.sh --master --timeout 600
```

### 6. Deploy to System

#### Option A: Local installation (master node)

```bash
scp dist/k8s-installer.run root@target-system:/tmp/

ssh root@target-system
sudo /tmp/k8s-installer.run --master
```

#### Option B: Using deploy script (remote)

```bash
cd/deploy.sh --host 192.168.1.10 --installer dist/k8s-installer.run --mode master

cd/deploy.sh \
  --host 192.168.1.11 \
  --installer dist/k8s-installer.run \
  --mode worker \
  --master-ip 192.168.1.10 \
  --join-token $(kubeadm token create)
```

#### Option C: Reconciliation mode

```bash
./cd/reconcile.sh
```

### 7. Production Deployment

For detailed production deployment procedures, refer to PRODUCTION_DEPLOYMENT.md:

```bash
cat PRODUCTION_DEPLOYMENT.md
```

This guide includes:
- Phase-by-phase deployment steps
- Time estimates and success criteria
- Troubleshooting procedures
- Rollback procedures
- Post-installation verification
- Monitoring and maintenance

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
apt-get install -y groovy

groovy -e 'new GroovyShell().evaluate(new File("ci/Jenkinsfile").text)'

make ci-build
```

## Testing

### Unit Tests

```bash
make test

bash tests/unit/validation-tests.sh
bash tests/unit/logging-tests.sh
bash tests/unit/detect-tests.sh
bash tests/unit/installer-tests.sh
```

### Smoke Testing

After installation, verify the Kubernetes cluster:

```bash
bash tests/smoke-test.sh --master

bash tests/smoke-test.sh --worker

bash tests/smoke-test.sh --master --timeout 600
```

Smoke test checks:
- Kubernetes installation verification
- kubelet service status
- containerd service status
- kubeadm functionality
- API server readiness (master)
- Master node readiness (master)
- Cluster information (master)
- Node readiness (worker)

### VM Integration Tests

Single-node testing:

```bash
make test-vm

cd tests/vm
vagrant up k8s-master
vagrant ssh k8s-master
vagrant provision k8s-master
vagrant destroy k8s-master
```

Multi-node testing:

```bash
make test-vm-workers

cd tests/vm
vagrant up
vagrant ssh k8s-master
vagrant ssh k8s-worker-1
vagrant ssh k8s-worker-2
vagrant destroy -f
```

### Validation During Install

Pre-installation validation:

```bash
/tmp/k8s-installer.run --validate-only

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
k8s-installer.run

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
export KUBERNETES_VERSION=1.31.1
export HELM_VERSION=3.16.1
export KUSTOMIZE_VERSION=5.4.2
export CONTAINERD_VERSION=2.0.0

make build

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
free -h

k8s-installer.run --validate-only

source automation/lib/validation.sh
validate_memory 1024
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
source automation/runtime/detect.sh
get_node_type

kubeadm reset -f
```

### Debug Installation

```bash
DEBUG=1 k8s-installer.run --master

set -x
k8s-installer.run --master

source automation/lib/logging.sh
source automation/lib/validation.sh
validate_all

systemctl status kubelet
systemctl status containerd
kubectl get nodes
```

## Monitoring & Observability

### Post-Installation Verification

```bash
sudo systemctl status kubelet

kubeadm version

kubectl get nodes
kubectl describe node $(hostname)

kubectl cluster-info
kubectl get cs

kubectl get daemonset -A
```

### Troubleshooting Commands

```bash
journalctl -u kubelet -f

journalctl -u containerd -f

tail -f /var/log/pods/kube-system_kube-apiserver-*/kube-apiserver/0.log

systemctl --failed
```

## Deployment Examples

### Single-Node Development Cluster

```bash
scp dist/k8s-installer.run root@devbox:/tmp/
ssh root@devbox
/tmp/k8s-installer.run --master
kubectl get nodes
```

### Three-Node Cluster

```bash
k8s-installer.run --master

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
aws ec2 run-instances --image-id ami-0c55b159cbfafe1f0 --instance-type t3.medium
cd/deploy.sh --host <ec2-ip> --mode master

az vm create --image UbuntuLTS
cd/deploy.sh --host <azure-ip> --mode master

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
kubectl apply -f configs/network-policy.yaml
kubectl apply -f configs/rbac-baseline.yaml
kubectl apply -f configs/pod-security.yaml
```

## Support & Issues

- Report issues: GitHub Issues
- Documentation: This README
- Logs: Check `logs/install-*.log` for detailed diagnostics
- Debug: Use `DEBUG=1` environment variable


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
**Contact**: dvirbb77@gmail.com
