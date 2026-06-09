[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$HtmlFilePath,

    [Parameter(Mandatory = $false)]
    [string]$MappingFilePath = './test-mapping.json',

    [Parameter(Mandatory = $false)]
    [string]$OutputFilePath,

    [Parameter(Mandatory = $false)]
    [ValidateSet('Identity', 'Devices', 'Data', 'Network')]
    [string]$Pillar,

    [Parameter(Mandatory = $false)]
    [string[]]$KnownPillars = @('identity', 'devices', 'data', 'network', 'infrastructure', 'security-ops', 'ai')
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# --- 0. Resolve pillar filter and build default output filename ---
# When -Pillar is supplied, restrict processing to that pillar and tag the
# output filename with its name. Otherwise tag the filename with "all".
$pillarFilterKey = $null
$pillarSegment   = 'all'
if ($PSBoundParameters.ContainsKey('Pillar') -and -not [string]::IsNullOrWhiteSpace($Pillar)) {
    # ValidateSet matches case-insensitively but preserves the user's casing,
    # so normalise to the canonical title-case form for the filename and logs.
    $canonicalPillar = @{
        identity = 'Identity'
        devices  = 'Devices'
        data     = 'Data'
        network  = 'Network'
    }
    $pillarFilterKey = $Pillar.ToLower()
    $pillarSegment   = $canonicalPillar[$pillarFilterKey]
    Write-Host "Pillar filter active: only '$pillarSegment' tests will be exported."
}

if ([string]::IsNullOrWhiteSpace($OutputFilePath)) {
    $OutputFilePath = "./ZTA-to-Workshop-{0}-{1}.json" -f $pillarSegment, (Get-Date -Format 'yyyy-MM-dd_HHmmss')
}

# --- 1. Validate and read the HTML file ---
if (-not (Test-Path -LiteralPath $HtmlFilePath)) {
    Write-Error "HTML file not found: $HtmlFilePath"
    return
}

$htmlContent = Get-Content -LiteralPath $HtmlFilePath -Raw -Encoding UTF8

# --- 2. Extract the Tests JSON array ---
# Use bracket-balancing to find the full array, skipping characters inside JSON strings
$testsMatch = [regex]::Match($htmlContent, '"Tests"\s*:\s*\[')
if (-not $testsMatch.Success) {
    Write-Error "Failed to extract 'Tests' array from the HTML file. No matching JSON block found."
    return
}

$arrayStart = $testsMatch.Index + $testsMatch.Length - 1  # index of the opening [
$depth = 0
$arrayEnd = -1
$inString = $false
for ($i = $arrayStart; $i -lt $htmlContent.Length; $i++) {
    $ch = $htmlContent[$i]
    if ($inString) {
        if ($ch -eq '\' ) {
            $i++  # skip escaped character
        }
        elseif ($ch -eq '"') {
            $inString = $false
        }
    }
    else {
        if ($ch -eq '"') { $inString = $true }
        elseif ($ch -eq '[') { $depth++ }
        elseif ($ch -eq ']') {
            $depth--
            if ($depth -eq 0) {
                $arrayEnd = $i
                break
            }
        }
    }
}

if ($arrayEnd -lt 0) {
    Write-Error "Failed to extract 'Tests' array from the HTML file. Unterminated array."
    return
}

$arrayJson = $htmlContent.Substring($arrayStart, $arrayEnd - $arrayStart + 1)
$jsonString = '{{"Tests": {0}}}' -f $arrayJson

try {
    $parsed = $jsonString | ConvertFrom-Json
    $tests = @($parsed.Tests)
    Write-Host "Extracted $($tests.Count) tests from the HTML file."
}
catch {
    Write-Error "Failed to parse extracted JSON: $_"
    return
}

# --- 3. Load the mapping file ---
# Resolve relative MappingFilePath against the script's directory
if (-not [System.IO.Path]::IsPathRooted($MappingFilePath)) {
    $scriptDir = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }
    $MappingFilePath = Join-Path $scriptDir $MappingFilePath
}
Write-Host "Looking for mapping file at: $MappingFilePath"
$pillarMappings = @{}  # pillar -> hashtable of TestId -> list of OverrideIds
$hasMappingFile = $false
if (Test-Path -LiteralPath $MappingFilePath) {
    try {
        # Parse manually with regex to support duplicate keys (ConvertFrom-Json drops duplicates)
        $rawMapping = Get-Content -LiteralPath $MappingFilePath -Raw -Encoding UTF8
        $totalEntries = 0
        $pillarRegex = [regex]'"([^"]+)"\s*:\s*\{([^}]*)\}'
        $entryRegex  = [regex]'"([^"]+)"\s*:\s*"([^"]+)"'
        foreach ($pillarMatch in $pillarRegex.Matches($rawMapping)) {
            $pillarKey = $pillarMatch.Groups[1].Value.ToLower()
            $pillarMappings[$pillarKey] = @{}
            foreach ($entryMatch in $entryRegex.Matches($pillarMatch.Groups[2].Value)) {
                $tid = $entryMatch.Groups[1].Value
                $oid = $entryMatch.Groups[2].Value
                if (-not $pillarMappings[$pillarKey].ContainsKey($tid)) {
                    $pillarMappings[$pillarKey][$tid] = [System.Collections.Generic.List[string]]::new()
                }
                $pillarMappings[$pillarKey][$tid].Add($oid)
                $totalEntries++
            }
        }
        $hasMappingFile = $true
        Write-Host "Loaded mapping file with $totalEntries entries across $($pillarMappings.Count) pillars."
    }
    catch {
        Write-Warning "Failed to parse mapping file '$MappingFilePath'. Falling back to using TestId directly. Error: $_"
    }
}
else {
    Write-Warning "Mapping file not found: $MappingFilePath. Falling back to using TestId directly as the override key."
}

# --- 4. Initialize pillars ---
# When a pillar filter is active, only that pillar is initialized so the
# output JSON contains a single pillar section.
$pillars = [ordered]@{}
if ($pillarFilterKey) {
    $pillars[$pillarFilterKey] = [ordered]@{ taskOverrides = [ordered]@{} }
}
else {
    foreach ($p in $KnownPillars) {
        $pillars[$p] = [ordered]@{ taskOverrides = [ordered]@{} }
    }
}

# --- 5. Process each test ---
$modifiedCount = 0
$collectedNotes = @{}

$skippedNoPillar = 0
$skippedStatus = 0
$skippedPillarFilter = 0
foreach ($test in $tests) {
    $testId = [string]$test.TestId

    # Skip tests whose status is "Skipped" — they don't represent an
    # assessed result and only add noise to the override notes.
    $testStatus = if ($test.PSObject.Properties['TestStatus']) { [string]$test.TestStatus } else { '' }
    if ($testStatus -ieq 'Skipped') {
        $skippedStatus++
        continue
    }

    $pillarRaw = if ($test.PSObject.Properties['TestPillar']) { $test.TestPillar } else { $null }
    if ([string]::IsNullOrWhiteSpace($pillarRaw)) {
        Write-Warning "Test $testId has no TestPillar; skipping."
        $skippedNoPillar++
        continue
    }
    $pillarKey = $pillarRaw.ToLower()

    # Honour the -Pillar filter when one is supplied.
    if ($pillarFilterKey -and $pillarKey -ne $pillarFilterKey) {
        $skippedPillarFilter++
        continue
    }

    # Resolve override keys — look up in the pillar-specific mapping
    if ($hasMappingFile) {
        $pillarMap = if ($pillarMappings.ContainsKey($pillarKey)) { $pillarMappings[$pillarKey] } else { @{} }
        if ($pillarMap.ContainsKey($testId)) {
            $overrideIds = $pillarMap[$testId]
        }
        else {
            # TestId has no mapping in this pillar — skip it
            continue
        }
    }
    else {
        # No mapping file loaded — use TestId directly
        $overrideIds = @($testId)
    }

    # Extract notes: text between first \n and second \n
    # ConvertFrom-Json converts JSON \n escapes to actual newlines,
    # but handle both real newlines and literal \n just in case
    $testResult = $test.TestResult
    $notesText = ''
    if ($null -ne $testResult -and $testResult.Length -gt 0) {
        # Determine the newline delimiter present in the string
        if ($testResult.Contains("`n")) {
            $nl = "`n"
        }
        elseif ($testResult.Contains('\n')) {
            $nl = '\n'
        }
        else {
            $nl = $null
        }

        if ($null -ne $nl) {
            # Split on the delimiter and find the first non-empty line after the leading delimiter
            $parts = $testResult.Split($nl)
            foreach ($part in $parts) {
                $trimmed = $part.Trim()
                if ($trimmed.Length -gt 0) {
                    $notesText = $trimmed
                    break
                }
            }
        }
        else {
            # No newline at all — use entire trimmed TestResult
            $notesText = $testResult.Trim()
        }
    }

    # Ensure pillar exists
    if (-not $pillars.Contains($pillarKey)) {
        $pillars[$pillarKey] = [ordered]@{ taskOverrides = [ordered]@{} }
    }

    foreach ($overrideId in $overrideIds) {
        # Collect notes per overrideId — combine all mapped TestResults (skip empty)
        if ($notesText.Length -gt 0) {
            $noteKey = "$pillarKey|$overrideId"
            if (-not $collectedNotes.ContainsKey($noteKey)) {
                $collectedNotes[$noteKey] = [System.Collections.Generic.List[string]]::new()
            }
            $collectedNotes[$noteKey].Add($notesText)
        }

        # Track which pillar/overrideId combos exist
        if (-not $pillars[$pillarKey].taskOverrides.Contains($overrideId)) {
            $pillars[$pillarKey].taskOverrides[$overrideId] = [ordered]@{
                status = 'not-reviewed'
                notes  = ''
            }
            $modifiedCount++
        }
    }
}

# --- 6. Combine collected notes into final notes values ---
foreach ($noteKey in $collectedNotes.Keys) {
    $parts = $noteKey -split '\|', 2
    $pKey = $parts[0]
    $oKey = $parts[1]
    # Deduplicate identical lines — the Workshop importer rejects entries
    # whose notes contain repeated lines.
    $uniqueLines = [System.Collections.Generic.List[string]]::new()
    $seen = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
    foreach ($line in $collectedNotes[$noteKey]) {
        if ($seen.Add($line)) { $uniqueLines.Add($line) }
    }
    $combined = ($uniqueLines) -join "`n"
    $pillars[$pKey].taskOverrides[$oKey].notes = "ZT Assessment result:`n$combined`n"
}

# --- 7. Compute statistics ---
$pillarsWithChanges = @()
foreach ($pKey in $pillars.Keys) {
    if ($pillars[$pKey].taskOverrides.Count -gt 0) {
        $pillarsWithChanges += $pKey
    }
}

$timestamp = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss.fffZ')

# When -Pillar is used, scope and currentPillar reflect the selection so the
# Workshop importer opens the correct pillar by default.
$exportScope         = if ($pillarFilterKey) { $pillarFilterKey } else { 'all' }
$currentPillarOutput = if ($pillarFilterKey) { $pillarFilterKey } else { 'identity' }

# --- 7. Build the full output structure ---
$output = [ordered]@{
    metadata      = [ordered]@{
        version            = '1.0.0'
        formatVersion      = '1.0'
        exportedAt         = $timestamp
        applicationVersion = '1.0.0'
        exportType         = 'full-configuration'
        scope              = $exportScope
        description        = 'Zero Trust Assessment Result Export'
    }
    configuration = [ordered]@{
        applicationState = [ordered]@{
            currentPillar = $currentPillarOutput
            lastModified  = $timestamp
        }
        pillars          = $pillars
        globalSettings   = [ordered]@{
            preferences = [ordered]@{
                autoSave            = $true
                confirmationDialogs = $true
            }
        }
    }
    statistics    = [ordered]@{
        totalTasks         = @($tests).Count
        modifiedTasks      = $modifiedCount
        completedTasks     = 0
        inProgressTasks    = 0
        plannedTasks       = 0
        pillarsWithChanges = $pillarsWithChanges
    }
}

# --- 8. Write output ---
$jsonOutput = $output | ConvertTo-Json -Depth 10
# Convert 4-space indentation to 2-space indentation
$jsonOutput = ($jsonOutput -split "`n" | ForEach-Object {
    if ($_ -match '^( +)') {
        $spaces = $Matches[1]
        $newIndent = ' ' * [math]::Floor($spaces.Length / 2)
        $newIndent + $_.TrimStart()
    } else {
        $_
    }
}) -join "`n"
$jsonOutput | Out-File -LiteralPath $OutputFilePath -Encoding UTF8 -Force

if ($skippedNoPillar -gt 0) {
    Write-Host "Skipped $skippedNoPillar test(s) with missing/empty TestPillar."
}
if ($skippedStatus -gt 0) {
    Write-Host "Skipped $skippedStatus test(s) with TestStatus = 'Skipped'."
}
if ($skippedPillarFilter -gt 0) {
    Write-Host "Skipped $skippedPillarFilter test(s) outside the selected pillar ('$pillarSegment')."
}
Write-Host "Output written to: $OutputFilePath"
