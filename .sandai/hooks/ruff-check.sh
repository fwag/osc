#!/usr/bin/env bash
# Diff-scoped Ruff linter guardrail.
#
# Analyzes only the Python files and lines modified or created since SANDAI_BASE_COMMIT,
# ensuring the agent's changes adhere to code style without penalizing or requiring
# rewrites of pre-existing legacy code.
set -eo pipefail

BASE_COMMIT="${SANDAI_BASE_COMMIT:-master}"

# Verify ruff is installed
if ! command -v ruff >/dev/null 2>&1; then
  echo ""
  echo "=== RUFF ERROR ==="
  echo "The 'ruff' executable was not found in the container environment."
  exit 1
fi

python3 - "$BASE_COMMIT" <<'PY'
import json, os, re, subprocess, sys

base_commit = sys.argv[1]

# 1. Collect modified and untracked python files
try:
    tracked = subprocess.check_output(
        ["git", "diff", "--name-only", base_commit], text=True
    ).splitlines()
except Exception:
    tracked = []

try:
    untracked = subprocess.check_output(
        ["git", "ls-files", "--others", "--exclude-standard"], text=True
    ).splitlines()
except Exception:
    untracked = []

files_to_check = set()
untracked_py = set()
for f in tracked:
    f = f.strip()
    if f.endswith(".py") and os.path.isfile(f) and not f.startswith(".sandai/"):
        files_to_check.add(f)

for f in untracked:
    f = f.strip()
    if f.endswith(".py") and os.path.isfile(f) and not f.startswith(".sandai/"):
        files_to_check.add(f)
        untracked_py.add(f)

if not files_to_check:
    print(f"[Ruff] No modified Python files detected since {base_commit}. Skipping.")
    sys.exit(0)

# 2. Map modified line numbers for tracked files
hunk_re = re.compile(r"^@@ -\d+(?:,\d+)? \+(\d+)(?:,(\d+))? @@")
changed_lines = {}
for f in files_to_check:
    if f in untracked_py:
        continue
    try:
        diff_out = subprocess.check_output(
            ["git", "diff", "-U0", base_commit, "--", f], text=True
        )
        lines = set()
        for line in diff_out.splitlines():
            m = hunk_re.match(line)
            if m:
                start = int(m.group(1))
                count = int(m.group(2)) if m.group(2) is not None else 1
                for l in range(start, start + count):
                    lines.add(l)
        changed_lines[f] = lines
    except Exception:
        changed_lines[f] = set()

# 3. Run ruff check with JSON output
cmd = ["ruff", "check", "--no-cache", "--output-format", "json"] + sorted(files_to_check)
proc = subprocess.run(cmd, capture_output=True, text=True)

try:
    diagnostics = json.loads(proc.stdout)
except Exception:
    # If JSON parsing failed, print raw output and exit with ruff's code
    if proc.stdout or proc.stderr:
        print((proc.stdout + "\n" + proc.stderr).strip())
    sys.exit(proc.returncode)

# 4. Filter violations to changed lines only (or syntax errors anywhere in modified files)
relevant = []
for diag in diagnostics:
    raw_fname = diag.get("filename", "")
    fname = os.path.relpath(raw_fname) if os.path.isabs(raw_fname) else raw_fname
    row = diag.get("location", {}).get("row", 0)
    code = diag.get("code", "")

    # Always flag syntax errors in touched files
    if code == "invalid-syntax" or diag.get("name") == "invalid-syntax":
        relevant.append(diag)
        continue

    if fname in untracked_py:
        relevant.append(diag)
    elif fname in changed_lines and row in changed_lines[fname]:
        relevant.append(diag)

if not relevant:
    print(f"[Ruff] Quality Gate passed: all modified lines adhere to style standards.")
    sys.exit(0)

print("")
print(f"=== RUFF LINTER FAILED ({len(relevant)} issue(s) in modified lines) ===")
for i, diag in enumerate(relevant, 1):
    raw_fname = diag.get("filename", "")
    fname = os.path.relpath(raw_fname) if os.path.isabs(raw_fname) else raw_fname
    loc = diag.get("location", {})
    row = loc.get("row", 0)
    col = loc.get("column", 0)
    code = diag.get("code", "")
    msg = diag.get("message", "")
    print(f"{i}. {fname}:{row}:{col}: [{code}] {msg}")

print("")
print("Please fix the linter issues in the modified lines listed above.")
sys.exit(1)
PY
