# openSUSE Commander (osc) - Agent Guidelines

## Workflow & Scope Discipline
- **Strict Scope**: Modify ONLY the files directly relevant to the issue (the code being fixed plus its regression test). Do not touch unrelated files or perform broad refactorings.
- **Diff-Scoped Fixes Only**: When resolving linter, formatting, or guardrail failures, fix ONLY errors introduced in lines you modified or added. Do NOT attempt to fix, modernize, or refactor pre-existing errors in legacy code.
- **Direct Action Over Advice**: When addressing prompts or guardrail failures, directly apply the necessary code edits using your tools. Do NOT output conversational lists of options, suggestions, or instructions for the user to perform manually.
- **Never Modify .sandai/ or Guardrail Hooks**: NEVER modify, disable, or delete any files under `.sandai/` or any test/guardrail scripts (such as `.sandai/hooks/sonar-check.sh` or `sandai.yaml`). If an environment tool is missing or failing, report the limitation directly; under no circumstances should you edit the hook script or disable checks.
- **Preserve Project Configuration**: NEVER edit repository build or configuration files (such as `pyproject.toml`, `setup.cfg`, `setup.py`, or `.github/` workflows) unless explicitly requested.
- **Turn Completion**: Once your file creation or edit is applied, conclude your turn immediately. Do NOT simulate further turns, roleplay user dialogue, or invent fictional subsequent checks.
- **Do Not Attempt Dependency Installation**: Do not attempt to install tools or packages via `pip` or package managers. Use only the tools already installed in the environment.

## Python Coding Standards
- Follow PEP 8 and repository code style.
- **No Linter Suppression**: NEVER bypass or suppress linter errors or warnings using `# noqa`, `# type: ignore`, or inline disable comments. Always resolve the underlying issue directly in the code (e.g., remove unused imports).
- Keep imports clean and sorted; remove any unused imports.
- Make targeted, surgical changes rather than broad refactorings.

## Testing & Regression Discipline
- **Mandatory Regression Tests**: For every bug fix or behavioral change, you MUST add or update an automated test under `tests/` (e.g., extending the relevant `tests/test_*.py` file) that reproduces the failure and verifies the fix.
- **Tests Are Always In-Scope**: Modifying or creating test files under `tests/` is always permitted and strictly required alongside code changes, exempt from single-file scope constraints.
- **Run Unit Tests**: Validate your fix by running the unit tests (e.g., `python3 -m unittest tests/test_<module>.py`) before concluding your turn to ensure all tests pass and no regressions are introduced.
