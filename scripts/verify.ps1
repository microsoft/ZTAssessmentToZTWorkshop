#!/usr/bin/env pwsh
# verify.ps1 - Readiness verify loop for ZTAssessmentToZTWorkshop.
# Confirms the converter script parses and test-mapping.json is valid JSON.
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
Push-Location $root
$failures = 0

Write-Host "== Parse check: Convert-ZTAssessmentToZTWorkshop.ps1 =="
$script = Join-Path $root 'Convert-ZTAssessmentToZTWorkshop.ps1'
if (-not (Test-Path $script)) { Write-Host "  MISSING: converter script"; $failures++ }
else {
    $tokens = $null; $errors = $null
    [System.Management.Automation.Language.Parser]::ParseFile($script, [ref]$tokens, [ref]$errors) | Out-Null
    if ($errors -and $errors.Count -gt 0) {
        Write-Host "  SYNTAX ERRORS:"; $errors | ForEach-Object { Write-Host "    $($_.Message)" }; $failures++
    } else { Write-Host "  OK: parses cleanly." }
}

Write-Host "== JSON check: test-mapping.json =="
$map = Join-Path $root 'test-mapping.json'
if (-not (Test-Path $map)) { Write-Host "  MISSING: test-mapping.json"; $failures++ }
else {
    try { Get-Content $map -Raw | ConvertFrom-Json -ErrorAction Stop | Out-Null; Write-Host "  OK: valid JSON." }
    catch { Write-Host "  INVALID JSON: $($_.Exception.Message)"; $failures++ }
}

Pop-Location
if ($failures -gt 0) { Write-Host "verify.ps1 FAILED with $failures error(s)." -ForegroundColor Red; exit 1 }
Write-Host "verify.ps1 PASSED." -ForegroundColor Green
exit 0
