# Conventions — ZTAssessmentToZTWorkshop

Observed conventions for this repo. Derived from the current structure; update as it evolves.

## Layout
- **`Convert-ZTAssessmentToZTWorkshop.ps1`** — the converter.
- **`test-mapping.json`** — mapping data consumed by the converter (valid JSON).
- **Governance** — `readme.md`, `SECURITY.md`, `LICENSE.txt`.

## Coding conventions
- PowerShell, approved verbs, `[CmdletBinding()]` with validated parameters.
- Treat `test-mapping.json` as data: keep it valid JSON and schema-consistent.
- No secrets, tokens, or customer/tenant data in code, mappings, or samples.

## Validation
Run `pwsh scripts/verify.ps1` — confirms the converter parses and `test-mapping.json` is
valid JSON.
