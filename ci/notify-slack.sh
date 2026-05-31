#!/usr/bin/env bash
#
#
#

set -Eeuo pipefail
IFS=$'\n\t'

function _notify_slack_impl() {
  local status="$1"
  local message="$2"
  
  [[ -z "$SLACK_WEBHOOK_URL" ]] && {
    echo "[ERROR] SLACK_WEBHOOK_URL not set" >&2
    return 1
  }
  
  local color="good"
  case "$status" in
    success)
      color="good"
      ;;
    failure | failed)
      color="danger"
      ;;
    unstable | warning)
      color="warning"
      ;;
    *)
      color="#439FE0"
      ;;
  esac
  
  local title="${JOB_NAME} #${BUILD_NUMBER}"
  [[ "$status" == "success" ]] && title=" $title PASSED"
  [[ "$status" == "failure" ]] || [[ "$status" == "failed" ]] && title=" $title FAILED"
  [[ "$status" == "unstable" ]] || [[ "$status" == "warning" ]] && title=" $title UNSTABLE"
  
  local payload
  payload=$(cat <<EOF
{
  "attachments": [
    {
      "color": "$color",
      "title": "$title",
      "text": "$message",
      "fields": [
        {
          "title": "Status",
          "value": "$status",
          "short": true
        },
        {
          "title": "Build #",
          "value": "$BUILD_NUMBER",
          "short": true
        }
        $(if [[ -n "$BUILD_URL" ]]; then echo ",{\"title\": \"URL\",\"value\": \"$BUILD_URL\",\"short\": false}"; fi)
      ],
      "footer": "Kubernetes Installer CI",
      "ts": $(date +%s)
    }
  ]
}
EOF
  )
  
  if curl -X POST \
    -H 'Content-type: application/json' \
    --data "$payload" \
    "$SLACK_WEBHOOK_URL" 2>/dev/null; then
    echo "[NOTIFY] Slack notification sent successfully"
    return 0
  else
    echo "[ERROR] Failed to send Slack notification" >&2
    return 1
  fi
}

export -f _notify_slack_impl
