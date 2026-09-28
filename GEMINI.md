# openSUSE Commander (osc) - Agent Guidelines

## Workflow & Scope Discipline
- **Strict Scope**: Modify ONLY the specific files requested by the prompt, issue, or guardrail check.
- **Preserve Project Configuration**: NEVER edit repository build or configuration files (such as `pyproject.toml`, `setup.cfg`, `setup.py`, or `.github/` workflows) unless explicitly requested.
- **Turn Completion**: Once your file creation or edit is applied, conclude your turn immediately. Do NOT simulate further turns, roleplay user dialogue, or invent fictional subsequent checks.
- **Do Not Attempt Dependency Installation**: Do not attempt to install tools or packages via `pip` or package managers. Use only the tools already installed in the environment.

## Python Coding Standards
- Follow PEP 8 and repository code style.
- Keep imports clean and sorted; remove any unused imports.
- Make targeted, surgical changes rather than broad refactorings.
