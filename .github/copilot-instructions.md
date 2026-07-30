# Copilot instructions — ZTAssessmentToZTWorkshop

Start with [`AGENTS.md`](../AGENTS.md) for the repository map, conventions, and verification
steps. This file adds Copilot-specific guardrails.

## What this repo is
A single PowerShell converter (`Convert-ZTAssessmentToZTWorkshop.ps1`) plus a JSON mapping
(`test-mapping.json`). No build system — the script runs directly.

## Working here
- Keep converter logic in `Convert-ZTAssessmentToZTWorkshop.ps1`.
- When changing behavior, update `test-mapping.json` and keep it **valid JSON**
  (`scripts/verify.ps1` parses it).
- Preserve compatibility with Windows PowerShell 5.1 and PowerShell 7+ where practical.
- Never commit real assessment output containing customer/tenant data.

## PR guardrails
- Keep PRs small and single-purpose.
- Do not commit secrets or customer data.
- Apply the PR labels and description footer required by
  [`.github/instructions/telemetry.instructions.md`](instructions/telemetry.instructions.md).
