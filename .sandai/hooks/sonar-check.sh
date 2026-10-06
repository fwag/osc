#!/usr/bin/env bash
# SonarQube guardrail scoped to the changes of the current sandai run.
#
# Usage:
#   sonar-check.sh baseline   Analyze the unmodified fork point (run once per run, before the agent commits)
#   sonar-check.sh            Analyze the agent's changes and enforce the server Quality Gate on them
#
# The project's new code definition must be "Previous version". The baseline analysis is tagged with
# one version and every check with another, so the gate's new code period always starts at the
# baseline: only lines committed after it (the agent's commits) count as new code.
set -eo pipefail

MODE="${1:-check}"

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

# Sandbox artifacts are never analyzed; project-defined exclusions are preserved
EXCLUSIONS=".sandai/**,.scannerwork/**"
if [ -f "sonar-project.properties" ]; then
  PROJECT_EXCLUSIONS=$(grep "^sonar.exclusions=" sonar-project.properties | cut -d'=' -f2- | tr -d '[:space:]')
  EXCLUSIONS="${EXCLUSIONS}${PROJECT_EXCLUSIONS:+,$PROJECT_EXCLUSIONS}"
fi

# Fallback defaults
SONAR_URL="${SONAR_URL:-https://cq.opensuse.org}"
SONAR_URL="${SONAR_URL%/}"
if [ -z "$PROJECT_KEY" ]; then
  PROJECT_KEY=$(basename "$PWD")
fi

BASE_COMMIT="${SANDAI_BASE_COMMIT:-$(git rev-parse HEAD)}"
BASE_SHORT="${BASE_COMMIT:0:12}"
if [ "$MODE" = "baseline" ]; then
  VERSION="base-$BASE_SHORT"
else
  VERSION="change-$BASE_SHORT"
fi

echo "[SonarQube] Running $MODE analysis for project '$PROJECT_KEY' (version $VERSION) against $SONAR_URL..."

# Verify sonar-scanner is available
if ! command -v sonar-scanner >/dev/null 2>&1; then
  echo ""
  echo "=== SONARQUBE ERROR ==="
  echo "The 'sonar-scanner' executable was not found in the container environment."
  echo "Please ensure the sandbox container image was built with sonar-scanner-cli installed."
  echo "Under no circumstances should you attempt to disable or modify this guardrail script."
  exit 1
fi

SCAN_LOG=$(mktemp)
trap 'rm -f "$SCAN_LOG"' EXIT

# SCM exclusions stay enabled so gitignored/untracked files (no blame data) are not indexed.
# Scanner output is only shown when the scan itself fails.
SCAN_RC=0
sonar-scanner \
  -Dsonar.host.url="$SONAR_URL" \
  -Dsonar.projectKey="$PROJECT_KEY" \
  -Dsonar.projectVersion="$VERSION" \
  -Dsonar.qualitygate.wait="$([ "$MODE" = "baseline" ] && echo false || echo true)" \
  -Dsonar.exclusions="$EXCLUSIONS" \
  ${SONAR_TOKEN:+-Dsonar.token="$SONAR_TOKEN"} >"$SCAN_LOG" 2>&1 || SCAN_RC=$?

if [ "$MODE" = "baseline" ]; then
  if [ "$SCAN_RC" -ne 0 ]; then
    cat "$SCAN_LOG"
    echo "=== SONARQUBE BASELINE ERROR === sonar-scanner exited with code $SCAN_RC."
    exit 1
  fi
  echo "[SonarQube] Baseline analysis of $BASE_SHORT uploaded."
  exit 0
fi

if [ "$SCAN_RC" -eq 0 ]; then
  echo "[SonarQube] Quality Gate passed on the code changed since $BASE_SHORT."
  exit 0
fi

if ! grep -q "QUALITY GATE STATUS: FAILED" "$SCAN_LOG"; then
  cat "$SCAN_LOG"
  echo ""
  echo "=== SONARQUBE SCANNER ERROR ==="
  echo "sonar-scanner exited with code $SCAN_RC before a Quality Gate verdict was produced. See output above."
  exit 1
fi

# Quality Gate failed: report the failed conditions and the new-code issues
python3 - "$SONAR_URL" "$PROJECT_KEY" "$BASE_SHORT" <<'PY'
import json, os, ssl, sys, urllib.parse, urllib.request

sonar_url, project_key, base_short = sys.argv[1:4]
token = os.environ.get("SONAR_TOKEN", "")
ctx = ssl._create_unverified_context()

def get_json(path, **params):
    req = urllib.request.Request(f"{sonar_url}{path}?{urllib.parse.urlencode(params)}")
    if token:
        req.add_header("Authorization", f"Bearer {token}")
    return json.load(urllib.request.urlopen(req, context=ctx, timeout=60))

print("")
print("=== SONARQUBE QUALITY GATE FAILED ===")
print(f"The Quality Gate is evaluated only on code changed since base commit {base_short}.")
try:
    status = get_json("/api/qualitygates/project_status", projectKey=project_key)["projectStatus"]
    print("Failed conditions:")
    for c in status.get("conditions", []):
        if c.get("status") == "ERROR":
            op = "<" if c.get("comparator") == "LT" else ">"
            print(f"  - {c['metricKey']} = {c.get('actualValue')} (required: not {op} {c.get('errorThreshold')})")

    issues = []
    page = 1
    while True:
        data = get_json("/api/issues/search", componentKeys=project_key, inNewCodePeriod="true",
                        resolved="false", ps=500, p=page)
        issues += data.get("issues", [])
        if page * 500 >= min(data.get("paging", {}).get("total", 0), 10000):
            break
        page += 1
except Exception as e:
    print(f"Failed to query SonarQube API: {e}")
    sys.exit(0)

if issues:
    print(f"New issues ({len(issues)}):")
    for n, i in enumerate(sorted(issues, key=lambda i: (i.get("component", ""), i.get("line", 0))), 1):
        comp = i.get("component", "").split(":", 1)[-1]
        print(f"{n}. [{i.get('severity', 'INFO')}] {comp}:{i.get('line', 1)} - {i.get('message', 'No description')} (Rule: {i.get('rule', '')})")
PY

echo ""
echo "Please apply the necessary code changes to fix the problems listed above."
exit 1
