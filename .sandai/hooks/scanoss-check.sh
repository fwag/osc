#!/usr/bin/env bash
# SCANOSS code snippet reproduction and license compliance guardrail.
#
# Analyzes files changed or added since SANDAI_BASE_COMMIT against the SCANOSS
# Knowledge Base to ensure the agent did not regurgitate external open source
# snippets or introduce license compliance violations.
set -eo pipefail

BASE_COMMIT="${SANDAI_BASE_COMMIT:-master}"

# Verify scanoss-py is installed
if ! command -v scanoss-py >/dev/null 2>&1; then
  echo ""
  echo "=== SCANOSS ERROR ==="
  echo "The 'scanoss-py' executable was not found in the container environment."
  echo "Please ensure the sandbox container image was built with python3-scanoss installed."
  exit 1
fi

FILE_LIST=$(mktemp)
SCAN_OUTPUT=$(mktemp)
trap 'rm -f "$FILE_LIST" "$SCAN_OUTPUT"' EXIT

# Detect changed or untracked files scoped to this PR / run, ignoring internal sandbox config
{ git diff --name-only "$BASE_COMMIT" 2>/dev/null || true; git ls-files --others --exclude-standard 2>/dev/null || true; } \
  | { grep -v -E '^(\.sandai|\.git)/' || true; } \
  | sort -u > "$FILE_LIST"

if [ ! -s "$FILE_LIST" ]; then
  echo "[SCANOSS] No modified files detected since $BASE_COMMIT. Skipping scan."
  exit 0
fi

COUNT=$(wc -l < "$FILE_LIST" | tr -d '[:space:]')
echo "[SCANOSS] Scanning $COUNT modified file(s) for third-party snippets and license matches..."

# Check for custom settings/whitelist file (.sandai/scanoss.json takes precedence over scanoss.json)
SETTINGS_ARGS=()
if [ -f ".sandai/scanoss.json" ]; then
  SETTINGS_ARGS+=(--settings ".sandai/scanoss.json")
elif [ -f "scanoss.json" ]; then
  SETTINGS_ARGS+=(--settings "scanoss.json")
fi

# Run scanoss on changed files list
scanoss-py scan "${SETTINGS_ARGS[@]}" --files-from "$FILE_LIST" -o "$SCAN_OUTPUT"

# Parse scan results and report any snippet matches or copyleft issues
python3 - "$SCAN_OUTPUT" <<'PY'
import json, sys

try:
    with open(sys.argv[1]) as f:
        results = json.load(f)
except Exception as e:
    print(f"[SCANOSS] Failed to parse scan output: {e}")
    sys.exit(0)

violations = []
for file_path, matches in results.items():
    if not matches:
        continue
    for m in matches:
        match_id = m.get("id")
        if not match_id or match_id == "none":
            continue
        purls = m.get("purl", [])
        purl_str = ", ".join(purls) if isinstance(purls, list) else str(purls)
        lines = m.get("lines", "")
        licenses = [l.get("name") for l in m.get("licenses", []) if l.get("name")]
        lic_str = f" [{', '.join(licenses)}]" if licenses else ""
        component = m.get("component", "")
        details = f"{purl_str}" if purl_str else component
        violations.append(f"{file_path} (lines {lines}): matched {details}{lic_str}")

if violations:
    print("")
    print("=== SCANOSS DETECTED EXTERNAL CODE SNIPPETS ===")
    print("The code generated in this iteration matches external open source repositories:")
    for v in violations:
        print(f"  - {v}")
    print("")
    print("Please rewrite the flagged sections from scratch without copying external code snippets.")
    sys.exit(1)

print("[SCANOSS] Quality Gate passed: no external code snippet matches detected.")
sys.exit(0)
PY
