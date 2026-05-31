# Self-Healing Framework Documentation

## Overview

The self-healing framework provides reusable primitives for detecting system state drift and automatically remediating issues in the Kubernetes installer. It integrates seamlessly with existing logging, error handling, and detection libraries.

**Key Benefits:**
- Automatic remediation of failed services
- Idempotent operations (safe to run multiple times)
- Integrated logging of all healing attempts
- Graceful escalation when remediation fails
- Centralized healing logic (no code duplication)

---

## Architecture

```
automation/lib/healing.sh (core primitives)
  ├─ retry()                  - Retry mechanism with exponential backoff
  ├─ ensure_service_running() - Service health checks and restart
  ├─ ensure_service_enabled() - Service enable/disable management
  ├─ ensure_package_installed() - Package installation and verification
  ├─ ensure_module_loaded()   - Kernel module loading
  ├─ ensure_sysctl()          - Sysctl parameter configuration
  ├─ validate_state()         - Generic state validation helper
  └─ perform_healing_phase()  - Coordinated healing for components

Integration points:
  ├─ automation/common/install-containerd.sh
  ├─ automation/common/install-kubernetes.sh
  ├─ automation/common/kernel-modules.sh
  ├─ automation/common/sysctl.sh
  └─ cd/reconcile.sh (healing phase for workers)
```

---

## Core Functions

### 1. retry - Retry command execution

```bash
retry <max_attempts> <delay_seconds> <command> [args...]
```

**Purpose:** Execute a command with automatic retries on failure

**Parameters:**
- `max_attempts`: Number of attempts (1-N)
- `delay_seconds`: Seconds to wait between attempts
- `command`: Command to execute
- `args...`: Arguments to pass to command

**Returns:** 0 if command succeeds within max_attempts, 1 otherwise

**Example:**
```bash
# Retry 3 times with 5-second delays
if retry 3 5 systemctl restart kubelet; then
  log_info "kubelet started successfully"
else
  log_error "kubelet failed after 3 attempts"
fi
```

**Log Output:**
```
[DEBUG] Attempt 1/3: systemctl restart kubelet
[DEBUG] Command failed, waiting 5s before retry...
[DEBUG] Attempt 2/3: systemctl restart kubelet
[INFO] Command succeeded on attempt 2
```

---

### 2. ensure_service_running - Ensure systemd service is active

```bash
ensure_service_running <service_name>
```

**Purpose:** Check if service is running, restart if not

**Parameters:**
- `service_name`: Name of systemd service (e.g., "kubelet", "containerd")

**Returns:** 0 if service is running, 1 if failed to start

**Behavior:**
1. Check if service is already active (exit 0 if yes)
2. If not active, attempt `systemctl restart`
3. Wait 1 second and re-validate
4. Return 0 if active, 1 if still inactive

**Example:**
```bash
if ensure_service_running kubelet; then
  log_info "kubelet is running"
else
  log_error "Failed to start kubelet - check logs with: journalctl -u kubelet"
fi
```

**Log Output:**
```
[WARN] kubelet is not running, attempting restart...
[INFO] Restarted kubelet
[INFO] kubelet is now active
```

---

### 3. ensure_service_enabled - Ensure service is enabled at boot

```bash
ensure_service_enabled <service_name>
```

**Purpose:** Enable systemd service for persistent startup

**Parameters:**
- `service_name`: Name of systemd service

**Returns:** 0 if enabled, 1 if failed

**Example:**
```bash
ensure_service_enabled containerd
ensure_service_enabled kubelet
```

---

### 4. ensure_package_installed - Install package if missing

```bash
ensure_package_installed <binary_name> [package_name]
```

**Purpose:** Check if binary exists, install via apt-get if missing

**Parameters:**
- `binary_name`: Binary to check (e.g., "containerd")
- `package_name`: Package name if different from binary (optional, defaults to binary_name)

**Returns:** 0 if installed/available, 1 if failed

**Behavior:**
1. Check if binary already exists (exit 0 if yes)
2. If missing, run `apt-get update`
3. Run `apt-get install -y <package_name>`
4. Verify binary is available after install
5. Return 0 if successful, 1 if still missing

**Example:**
```bash
# Binary and package have same name
ensure_package_installed curl

# Binary and package have different names
ensure_package_installed containerd containerd.io
```

**Log Output:**
```
[WARN] containerd not found, installing containerd.io...
[INFO] Installed containerd.io
[INFO] containerd is now available
```

---

### 5. ensure_module_loaded - Load kernel module

```bash
ensure_module_loaded <module_name>
```

**Purpose:** Load kernel module if not already loaded

**Parameters:**
- `module_name`: Kernel module name (e.g., "overlay", "br_netfilter")

**Returns:** 0 if loaded, 1 if failed

**Behavior:**
1. Check if module is already loaded via `lsmod`
2. If not loaded, run `modprobe <module_name>`
3. Re-verify module is loaded
4. Return 0 if loaded, 1 if not loaded after modprobe

**Example:**
```bash
ensure_module_loaded overlay
ensure_module_loaded br_netfilter
```

**Log Output:**
```
[WARN] overlay is not loaded, loading...
[INFO] Loaded kernel module overlay
[INFO] overlay is now loaded
```

---

### 6. ensure_sysctl - Configure kernel parameter

```bash
ensure_sysctl <param_name> <expected_value>
```

**Purpose:** Check kernel parameter value, correct if drift detected

**Parameters:**
- `param_name`: Sysctl parameter name (e.g., "net.ipv4.ip_forward")
- `expected_value`: Expected value (e.g., "1")

**Returns:** 0 if param is correct, 1 if failed to correct

**Behavior:**
1. Read current value via `sysctl -n <param>`
2. If matches expected, exit 0
3. If mismatch, apply `sysctl -w param=value`
4. Re-read to verify change applied
5. Return 0 if correct, 1 if still wrong

**Example:**
```bash
ensure_sysctl "net.ipv4.ip_forward" "1"
ensure_sysctl "vm.overcommit_memory" "1"
ensure_sysctl "fs.file-max" "2097152"
```

**Log Output:**
```
[WARN] net.ipv4.ip_forward is 0, expected 1 - applying correction...
[INFO] Set net.ipv4.ip_forward to 1
[INFO] net.ipv4.ip_forward is now correctly set to 1
```

---

### 7. validate_state - Generic state validation

```bash
validate_state <state_name> <validation_command>
```

**Purpose:** Execute validation command and log result

**Parameters:**
- `state_name`: Human-readable name of state being validated
- `validation_command`: Shell command that returns 0/1

**Returns:** 0 if validation passes, 1 if fails

**Example:**
```bash
# Validate containerd is installed
validate_state "containerd" "command -v containerd >/dev/null"

# Validate kubelet is running
validate_state "kubelet running" "systemctl is-active kubelet"

# Validate custom condition
validate_state "port 6443 listening" "netstat -tuln | grep -q :6443"
```

**Log Output:**
```
[DEBUG] Validating state: containerd
[INFO] containerd validation passed

[DEBUG] Validating state: kubelet running
[WARN] kubelet running validation failed
```

---

### 8. perform_healing_phase - Coordinated healing

```bash
perform_healing_phase <component_name> <healing_function>
```

**Purpose:** Execute healing function with logging and error handling

**Parameters:**
- `component_name`: Name of component being healed
- `healing_function`: Function name to call (must be defined)

**Returns:** 0 if healing completed, 1 if function not found

**Example:**
```bash
function healing_containerd() {
  ensure_package_installed containerd containerd.io
  ensure_service_enabled containerd
  ensure_service_running containerd
}

perform_healing_phase "containerd" healing_containerd
```

---

## Integration Patterns

### Pattern 1: Installation Script with Healing

```bash
#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'

source automation/lib/logging.sh
source automation/lib/healing.sh

main() {
  log_info "Installing containerd..."
  
  # Check if already installed
  if command -v containerd &>/dev/null; then
    log_info "containerd already installed"
  else
    # Install via healing framework
    if ! ensure_package_installed containerd containerd.io; then
      return 1
    fi
  fi
  
  # Enable and start service
  ensure_service_enabled containerd
  ensure_service_running containerd
  
  log_info " containerd installation complete"
}

main "$@"
```

### Pattern 2: Reconciliation with Healing Phase

```bash
function perform_healing() {
  local node_type="$1"
  
  log_info "=== Beginning healing phase ==="
  
  # Only heal workers
  if [[ "$node_type" != "worker" ]]; then
    return 0
  fi
  
  # Attempt healing
  ensure_service_enabled containerd
  ensure_service_running containerd
  
  ensure_service_enabled kubelet
  ensure_service_running kubelet
  
  ensure_sysctl "net.ipv4.ip_forward" "1"
  
  log_info "=== Healing phase complete ==="
}

# In main reconciliation logic
perform_healing "$node_type"

# Then proceed with version checks and upgrades
```

### Pattern 3: Component-Specific Healing Functions

```bash
function healing_containerd() {
  log_info "Healing containerd..."
  ensure_package_installed containerd containerd.io || return 1
  ensure_service_enabled containerd || return 1
  ensure_service_running containerd || return 1
  log_info "containerd healed successfully"
}

function healing_kubelet() {
  log_info "Healing kubelet..."
  ensure_service_enabled kubelet || return 1
  sleep 2  # Wait for dependencies
  ensure_service_running kubelet || return 1
  log_info "kubelet healed successfully"
}

# Use in reconciliation
perform_healing_phase "containerd" healing_containerd
perform_healing_phase "kubelet" healing_kubelet
```

---

## Logging and Observability

Every healing action logs its status for audit trails:

### Success Logs
```
[INFO] containerd is already running
[WARN] containerd is not running, attempting restart...
[INFO] Restarted containerd
[INFO] containerd is now active
```

### Failure Logs
```
[ERROR] containerd failed to start after restart
[ERROR] containerd failed to heal
[ACTION] check journalctl -u containerd
```

### Summary Logs
```
[INFO] Healing summary: containerd healed successfully
[ERROR] Healing summary: kubelet healing failed - check service logs
```

---

## Safety Guarantees

1. **Idempotent**: Safe to run multiple times
   - Already enabled services aren't re-enabled
   - Already loaded modules aren't re-loaded
   - Already correct sysctl params aren't re-applied

2. **Non-Destructive**:
   - Never removes user data
   - Never reformats disks
   - Never destroys Kubernetes state

3. **Master Node Safe**:
   - Healing only applies to worker nodes
   - Master nodes are never automatically modified
   - Manual intervention required for master changes

4. **Graceful Degradation**:
   - Healing failures don't crash scripts
   - Reconciliation continues even if healing fails
   - Clear error messages guide operators

---

## Testing

Unit tests for healing framework:

```bash
bash tests/unit/healing-tests.sh
```

**Tested Functionality:**
- retry mechanism (success, failure, early exit)
- ensure_* functions (validation, error handling)
- validate_state helper
- Function exports and signatures
- Library load independence

---

## Troubleshooting

### Service won't start
Check systemd journal:
```bash
journalctl -u kubelet -n 50 --no-pager
journalctl -u containerd -n 50 --no-pager
```

### Sysctl parameter not persisting
Check configuration file:
```bash
cat /etc/sysctl.d/99-kubernetes.conf
sysctl net.ipv4.ip_forward
```

### Kernel module not loading
Check if module is available:
```bash
modprobe -n overlay  # Dry run
lsmod | grep overlay  # Check if loaded
```

### Package install fails
Check APT status:
```bash
apt-get update
apt-cache search containerd
apt-get install -y containerd.io
```

---

## Files Modified

1. **New File**: `automation/lib/healing.sh` (400+ lines)
   - Core healing primitives
   - Logging integration
   - Comprehensive error handling

2. **Modified**: `automation/common/install-containerd.sh`
   - Uses `ensure_package_installed()`
   - Uses `ensure_service_enabled()`
   - Uses `ensure_service_running()`

3. **Modified**: `automation/common/install-kubernetes.sh`
   - Uses healing framework for kubelet
   - Graceful error handling for installation failures

4. **Modified**: `automation/common/kernel-modules.sh`
   - Uses `ensure_module_loaded()` instead of raw modprobe

5. **Modified**: `automation/common/sysctl.sh`
   - Uses `ensure_sysctl()` for parameter management
   - Idempotent parameter application

6. **Modified**: `cd/reconcile.sh`
   - Added `perform_healing()` function
   - Healing phase for worker nodes before reconciliation
   - Master nodes remain unchanged (safe mode)

7. **New File**: `tests/unit/healing-tests.sh`
   - 15+ unit tests
   - Tests all core functions
   - Mocked systemd/lsmod/sysctl

---

## Next Steps

### Immediate Usage
1. Run reconciliation with healing:
   ```bash
   bash cd/reconcile.sh
   ```

2. Check logs for healing actions:
   ```bash
   tail -f logs/kubernetes-installer-*.log
   ```

3. Verify services after healing:
   ```bash
   systemctl status containerd kubelet
   ```

### Future Enhancements
- Automatic metric collection during healing
- Healing metrics dashboard
- Healing failure notifications (Slack/email)
- Rollback capability if healing breaks things
- Healing policy configuration (aggressive vs. conservative)

---

## Conclusion

The self-healing framework provides production-grade automatic remediation while maintaining safety and observability. All healing actions are logged, failures are escalated with actionable error messages, and master nodes are protected from automatic modifications.

The framework integrates seamlessly with existing logging and error handling, ensuring consistent behavior across all installer scripts.
