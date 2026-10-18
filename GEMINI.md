# openSUSE Commander (osc) - Agent Guidelines

## Workflow & Scope Discipline
- **Strict Scope**: Modify ONLY the files directly relevant to the issue (the code being fixed plus its regression test). Do not touch unrelated files or perform broad refactorings.
- **Fix Root Causes, Not Crash Sites**:
  - Do NOT patch low-level generic utilities (such as URL builders, string formatters, or generic parsers) to swallow or filter unexpected `None` or invalid values when caller logic passed bad state.
  - Trace the call stack back to the caller (e.g. commandline handlers or business logic) and fix *why* invalid arguments or `None` values were generated or passed in the first place.
- **Preserve API & Protocol Semantics**:
  - Ensure fixes do not corrupt REST API endpoints or command semantics (e.g. silently dropping `None` from a URL path array alters the endpoint from a specific resource to a parent collection).
- **Diff-Scoped Fixes Only**: When resolving linter, formatting, or guardrail failures, fix ONLY errors introduced in lines you modified or added. Do NOT attempt to fix, modernize, or refactor pre-existing errors in legacy code.
- **Direct Action Over Advice**: When addressing prompts or guardrail failures, directly apply the necessary code edits using your tools. Do NOT output conversational lists of options, suggestions, or instructions for the user to perform manually.
- **Never Modify .sandai/ or Guardrail Hooks**: NEVER modify, disable, or delete any files under `.sandai/` or any test/guardrail scripts (such as `.sandai/hooks/sonar-check.sh` or `sandai.yaml`). If an environment tool is missing or failing, report the limitation directly; under no circumstances should you edit the hook script or disable checks.
- **Preserve Project Configuration**: NEVER edit repository build or configuration files (such as `pyproject.toml`, `setup.cfg`, `setup.py`, or `.github/` workflows) unless explicitly requested.
- **Task Completion & Termination**: When the task is complete and verified, publish your final summary and terminate. Do not repeatedly call update_topic or perform repetitive conversational cycles once work is verified.
- **Turn Completion**: Once your file creation, edit, and test verification are complete, conclude your turn immediately with a concise summary. Do NOT simulate further turns, roleplay user dialogue, invent fictional subsequent checks, or repeat status messages.
- **Do Not Attempt Dependency Installation**: Do not attempt to install tools or packages via `pip` or package managers. Use only the tools already installed in the environment.

## Python Coding Standards
- Follow PEP 8 and repository code style.
- **No Linter Suppression**: NEVER bypass or suppress linter errors or warnings using `# noqa`, `# type: ignore`, or inline disable comments. Always resolve the underlying issue directly in the code (e.g., remove unused imports).
- Keep imports clean and sorted; remove any unused imports.
- Make targeted, surgical changes rather than broad refactorings.

## Testing & Regression Discipline
- **Mandatory In-Tree Regression Tests**: Every bug fix or behavioral change MUST include an automated regression test committed to git. A PR without a test change under `tests/` is incomplete.
- **Test the Actual Bug Scenario, Not Just Helper Functions**:
  - Regression tests must exercise the real issue reported in the prompt (e.g. testing the command handler, argument resolution, or link expansion with mocks), not merely asserting that a low-level helper accepts bad inputs.
- **Always Extend Existing Test Files (No Scratch Files)**:
  - Do NOT create standalone or temporary test files (e.g., NEVER create files like `tests/test_makeurl.py`, `tests/test_temp.py`, or scratch scripts).
  - Always locate the existing test file under `tests/` (e.g., `tests/test_core.py`, `tests/test_commandline.py`) and append a new `def test_*` method directly into the existing test class.
  - Modifying files under `tests/` is always permitted and strictly required alongside code changes.
- **Self-Contained Offline Tests Only**:
  - While `api.opensuse.org` is reachable for inspection and verifying API payloads, **ALL automated tests committed to the repository MUST be strictly offline**.
  - NEVER make live network requests inside automated tests. Tests must remain fast, deterministic, and hermetic.
  - Follow the repository mocking pattern (as in `tests/test_commandline.py`): use `with unittest.mock.patch('osc.core.http_GET', ...)` or inherit from `OscTestCase` in `tests/common.py` to provide mock responses without network calls.
- **NEVER Delete or Revert Tests**:
  - NEVER delete, remove, revert, or clean up test methods or files after running them.
  - All test methods written must remain permanently in the repository and be part of the final commit.
  - If a test file fails due to an uninstalled optional module or environment issue, do NOT revert or delete your test. Instead, mock the missing component with `unittest.mock` or place the test method into a test module that runs cleanly (such as `tests/test_core.py`), ensuring your regression test is always committed.
- **Run Unit Tests**: Validate your fix by running the unit tests (e.g., `python3 -m unittest tests/test_<module>.py`) before concluding your turn to verify that both your new test and existing tests pass.
