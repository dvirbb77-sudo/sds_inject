#!/usr/bin/env bash
#
#
#

set -Eeuo pipefail
IFS=$'\n\t'

SLACK_WEBHOOK_URL="${SLACK_WEBHOOK_URL:-}"
SLACK_ENABLED="${SLACK_ENABLED:-0}"
EMAIL_ENABLED="${EMAIL_ENABLED:-0}"
EMAIL_RECIPIENTS="${EMAIL_RECIPIENTS:-}"

BUILD_URL="${BUILD_URL:-}"
JOB_NAME="${JOB_NAME:-KubernetesInstaller}"
BUILD_NUMBER="${BUILD_NUMBER:-0}"
BUILD_RESULT="${BUILD_RESULT:-UNKNOWN}"

function log_notify() {
  echo "[NOTIFY] $*"
}

function notify() {
  local status="$1"
  local message="$2"
  
  [[ -z "$status" ]] && {
    echo "Usage: notify <status> <message>" >&2
    return 1
  }
  
  log_notify "Sending notification: status=$status"
  
  if [[ "$SLACK_ENABLED" -eq 1 ]] && [[ -n "$SLACK_WEBHOOK_URL" ]]; then
    notify_slack "$status" "$message"
  fi
  
  if [[ "$EMAIL_ENABLED" -eq 1 ]] && [[ -n "$EMAIL_RECIPIENTS" ]]; then
    notify_email "$status" "$message"
  fi
  
  if [[ "$SLACK_ENABLED" -eq 0 ]] && [[ "$EMAIL_ENABLED" -eq 0 ]]; then
    log_notify "No backends enabled - log only"
    log_notify "Status: $status"
    log_notify "Message: $message"
  fi
}

function notify_slack() {
  local status="$1"
  local message="$2"
  
  if [[ -f "ci/notify-slack.sh" ]]; then
    source ci/notify-slack.sh
    _notify_slack_impl "$status" "$message"
  else
    log_notify "Slack backend not found - skipping"
  fi
}

function notify_email() {
  local status="$1"
  local message="$2"
  
  if [[ -f "ci/notify-email.sh" ]]; then
    source ci/notify-email.sh
    _notify_email_impl "$status" "$message"
  else
    log_notify "Email backend not found - skipping"
  fi
}

export -f notify
export -f notify_slack
export -f notify_email
