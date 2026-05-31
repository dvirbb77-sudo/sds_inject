#!/usr/bin/env bash
#
#
#

set -Eeuo pipefail
IFS=$'\n\t'

function _notify_email_impl() {
  local status="$1"
  local message="$2"
  
  [[ -z "$EMAIL_RECIPIENTS" ]] && {
    echo "[ERROR] EMAIL_RECIPIENTS not set" >&2
    return 1
  }
  
  if ! command -v mail &>/dev/null && ! command -v sendmail &>/dev/null; then
    echo "[WARN] mail/sendmail not available - email notification skipped" >&2
    return 0
  fi
  
  local subject; subject="[Kubernetes Installer] ${JOB_NAME} #${BUILD_NUMBER} - $(echo "$status" | tr '[:lower:]' '[:upper:]')"
  
  local body
  body=$(cat <<EOF
Build Status Report
===================

Job Name:       $JOB_NAME
Build Number:   $BUILD_NUMBER
Status:         $status
Build URL:      ${BUILD_URL:-N/A}

Message:
--------
$message

Timestamp: $(date)

---
Kubernetes Installer CI System
EOF
  )
  
  if command -v mail &>/dev/null; then
    if echo "$body" | mail -s "$subject" "$EMAIL_RECIPIENTS" 2>/dev/null; then
      echo "[NOTIFY] Email notification sent successfully"
      return 0
    else
      echo "[WARN] Failed to send email via mail command" >&2
      return 1
    fi
  else
    echo "[WARN] mail command not available - email notification skipped" >&2
    return 0
  fi
}

export -f _notify_email_impl
