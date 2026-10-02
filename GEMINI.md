# openSUSE Commander (osc) - Agent Guidelines

## Workflow & Scope Discipline
- **Strict Scope**: Modify ONLY the specific files requested by the prompt, issue, or guardrail check.
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
