#!/usr/bin/env bash
set -eo pipefail

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

echo "[SonarQube] Starting analysis for project '$PROJECT_KEY' against $SONAR_URL..."

# Verify sonar-scanner is available
if ! command -v sonar-scanner >/dev/null 2>&1; then
  echo ""
  echo "=== SONARQUBE ERROR ==="
  echo "The 'sonar-scanner' executable was not found in the container environment."
  echo "Please ensure the sandbox container image was built with sonar-scanner-cli installed."
  echo "Under no circumstances should you attempt to disable or modify this guardrail script."
  exit 1
fi

BASE_COMMIT="${SANDAI_BASE_COMMIT:-master}"
# Issues created by this analysis carry the scanner-side analysis date, so a local timestamp is consistent
SCAN_START=$(date -u +%Y-%m-%dT%H:%M:%S+0000)
SCAN_LOG=$(mktemp)
trap 'rm -f "$SCAN_LOG"' EXIT

# 1. Run scanner and wait for server-side processing. SCM exclusions stay enabled so that
#    gitignored/untracked files (no blame data) are not indexed and misreported as new code.
SCAN_RC=0
sonar-scanner \
  -Dsonar.host.url="$SONAR_URL" \
  -Dsonar.projectKey="$PROJECT_KEY" \
  -Dsonar.qualitygate.wait=true \
  -Dsonar.exclusions="$EXCLUSIONS" \
  ${SONAR_TOKEN:+-Dsonar.token="$SONAR_TOKEN"} 2>&1 | tee "$SCAN_LOG" || SCAN_RC=$?

# A failing server Quality Gate is expected on legacy code; anything else is a real scanner error
if [ "$SCAN_RC" -ne 0 ] && ! grep -q "QUALITY GATE STATUS: FAILED" "$SCAN_LOG"; then
  echo ""
  echo "=== SONARQUBE SCANNER ERROR ==="
  echo "sonar-scanner exited with code $SCAN_RC before a Quality Gate verdict was produced. See output above."
  exit 1
fi

# 2. Gate locally on issues attributable to this change: issues created by this analysis,
#    or issues located on lines added/modified since $BASE_COMMIT. Pre-existing issues are ignored.
set +e
python3 - "$SONAR_URL" "$PROJECT_KEY" "$BASE_COMMIT" "$SCAN_START" <<'PY'
import json, os, re, ssl, subprocess, sys, urllib.parse, urllib.request
from datetime import datetime

sonar_url, project_key, base_commit, scan_start = sys.argv[1:5]
token = os.environ.get("SONAR_TOKEN", "")
ctx = ssl._create_unverified_context()

def git(*args):
    return subprocess.run(["git", *args], capture_output=True, text=True).stdout

def search(**params):
    issues, page = [], 1
    while True:
        query = urllib.parse.urlencode({"componentKeys": project_key, "resolved": "false", "ps": 500, "p": page, **params})
        req = urllib.request.Request(f"{sonar_url}/api/issues/search?{query}")
        if token:
            req.add_header("Authorization", f"Bearer {token}")
        data = json.load(urllib.request.urlopen(req, context=ctx, timeout=60))
        issues += data.get("issues", [])
        if page * 500 >= min(data.get("paging", {}).get("total", 0), 10000):
            return issues
        page += 1

# Map each changed file to the set of changed line numbers (None = whole file is new)
changed = {f: None for f in git("ls-files", "--others", "--exclude-standard").split()}
current = None
for line in git("diff", "-U0", "--no-color", "--no-renames", base_commit).splitlines():
    if line.startswith("+++ "):
        current = line[6:] if line.startswith("+++ b/") else None
        if current:
            changed.setdefault(current, set())
    elif line.startswith("@@") and current and changed[current] is not None:
        m = re.match(r"@@ -\S+ \+(\d+)(?:,(\d+))? @@", line)
        start, count = int(m.group(1)), int(m.group(2) or 1)
        changed[current].update(range(start, start + count))

try:
    found = {i["key"]: i for i in search(createdAfter=scan_start)}
    for path in changed:
        for i in search(componentKeys=f"{project_key}:{path}"):
            lines = changed[path]
            if lines is None or i.get("line") in lines:
                found[i["key"]] = i
except Exception as e:
    print(f"Failed to query SonarQube issues API: {e}")
    if not token:
        print(f"Note: SONAR_TOKEN is not set in the environment. Please export SONAR_TOKEN to authenticate against {sonar_url}.")
    sys.exit(1)

if not found:
    print("[SonarQube] No new issues on code changed since base commit "
          f"{base_commit[:12]} (pre-existing issues in unchanged code are ignored).")
    sys.exit(0)

print("")
print("=== SONARQUBE QUALITY GATE FAILED ===")
print(f"Found {len(found)} issue(s) introduced by your changes:")
for n, i in enumerate(sorted(found.values(), key=lambda i: (i.get("component", ""), i.get("line", 0))), 1):
    comp = i.get("component", "").split(":", 1)[-1]
    print(f"{n}. [{i.get('severity', 'INFO')}] {comp}:{i.get('line', 1)} - {i.get('message', 'No description')} (Rule: {i.get('rule', '')})")
sys.exit(2)
PY
GATE_RC=$?
set -eo pipefail

if [ "$GATE_RC" -eq 2 ]; then
  echo ""
  echo "Please apply the necessary code changes to fix the issues listed above."
  exit 1
elif [ "$GATE_RC" -ne 0 ]; then
  exit 1
fi

echo "[SonarQube] Quality Gate passed successfully."
exit 0
