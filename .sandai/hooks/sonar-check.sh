#!/usr/bin/env bash
set -e

# Configuration
SONAR_URL="${SONAR_HOST_URL:-}"
PROJECT_KEY="${SONAR_PROJECT_KEY:-}"

# Auto-detect configuration from sonar-project.properties if present
if [ -f "sonar-project.properties" ]; then
  if [ -z "$SONAR_URL" ]; then
    SONAR_URL=$(grep "^sonar.host.url=" sonar-project.properties | cut -d'=' -f2 | tr -d '[:space:]')
  fi
  if [ -z "$PROJECT_KEY" ]; then
    PROJECT_KEY=$(grep "^sonar.projectKey=" sonar-project.properties | cut -d'=' -f2 | tr -d '[:space:]')
  fi
fi

# Fallback defaults
SONAR_URL="${SONAR_URL:-https://cq.opensuse.org}"
if [ -z "$PROJECT_KEY" ]; then
  PROJECT_KEY=$(basename "$PWD")
fi

echo "[SonarQube] Starting analysis for project '$PROJECT_KEY' against $SONAR_URL..."

SCAN_FAILED=0
# 1. Run scanner and wait for Quality Gate evaluation on the server
sonar-scanner \
  -Dsonar.host.url="$SONAR_URL" \
  -Dsonar.projectKey="$PROJECT_KEY" \
  -Dsonar.qualitygate.wait=true \
  ${SONAR_TOKEN:+-Dsonar.token="$SONAR_TOKEN"} || SCAN_FAILED=1

# 2. If the scan failed (Quality Gate FAILED), query SonarQube REST API for actionable issues
if [ "$SCAN_FAILED" -ne 0 ]; then
  echo ""
  echo "=== SONARQUBE QUALITY GATE FAILED ==="
  echo "Fetching unresolved issues from $SONAR_URL/api/issues/search..."
  echo ""

  # Query SonarQube REST API for open issues and format nicely with python3
  AUTH_HEADER=""
  if [ -n "$SONAR_TOKEN" ]; then
    AUTH_HEADER="-u ${SONAR_TOKEN}:"
  fi

  curl -s -k $AUTH_HEADER "${SONAR_URL}/api/issues/search?componentKeys=${PROJECT_KEY}&resolved=false&ps=30" | \
    python3 -c '
import sys, json

try:
    data = json.load(sys.stdin)
    issues = data.get("issues", [])
    if not issues:
        print("Quality Gate failed, but no specific code issues were returned via API.")
        print("Check server analysis status on SonarQube dashboard.")
    else:
        print(f"Found {len(issues)} open issue(s):")
        for i, issue in enumerate(issues, 1):
            comp = issue.get("component", "").split(":")[-1]
            line = issue.get("line", 1)
            sev = issue.get("severity", "INFO")
            msg = issue.get("message", "No description")
            rule = issue.get("rule", "")
            print(f"{i}. [{sev}] {comp}:{line} - {msg} (Rule: {rule})")
except Exception as e:
    print(f"Failed to parse SonarQube API response: {e}")
'

  echo ""
  echo "Please apply the necessary code changes to fix the issues listed above."
  exit 1
fi

echo "[SonarQube] Quality Gate passed successfully."
exit 0
