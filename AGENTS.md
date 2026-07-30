# AGENTS.md — ZTAssessmentToZTWorkshop

Converts **Zero Trust Assessment** output into a **Zero Trust Workshop** format via a single
PowerShell script (`Convert-ZTAssessmentToZTWorkshop.ps1`) driven by a JSON mapping
(`test-mapping.json`). This file is the entry point for humans and coding agents.

## Repository map
| Path | What lives here |
| --- | --- |
| `Convert-ZTAssessmentToZTWorkshop.ps1` | The converter (all logic). |
| `test-mapping.json` | Mapping table the converter consumes; must be valid JSON. |
| `readme.md` | Usage and run instructions. |
| `SECURITY.md`, `LICENSE.txt` | Governance files. |

## Conventions
See [`docs/conventions.md`](docs/conventions.md).

## Verification / Definition of Done
```powershell
pwsh scripts/verify.ps1
```
`verify.ps1` confirms the converter script parses cleanly and `test-mapping.json` is valid
JSON. A change is done when `verify.ps1` passes and a sample conversion still succeeds per
`readme.md`.

## PR & work-item telemetry — required
Every PR must follow [`.github/instructions/telemetry.instructions.md`](.github/instructions/telemetry.instructions.md).

## Copilot
See [`.github/copilot-instructions.md`](.github/copilot-instructions.md).
