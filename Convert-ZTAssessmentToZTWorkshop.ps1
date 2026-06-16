<#
.SYNOPSIS
    Converts a Zero Trust Assessment HTML report into a JSON file importable by the Zero Trust Workshop.

.DESCRIPTION
    Reads a Zero Trust Assessment HTML report, extracts each assessment test, maps it to the
    corresponding Zero Trust Workshop task using test-mapping.json, and produces a Workshop-ready
    JSON file where each task's notes field is pre-populated with the assessment's findings.

    Tests with TestStatus of 'Skipped' are excluded, and tests without a mapping entry are silently
    dropped from the output. When -Pillar is supplied, only that pillar is processed.

.PARAMETER HtmlFilePath
    Path to the Zero Trust Assessment HTML report. Required.

.PARAMETER MappingFilePath
    Path to the TestId-to-TaskOverride mapping file. Defaults to test-mapping.json next to the
    script. Relative paths are resolved against the script's directory. The script exits with an
    error if the file is missing or unparseable.

.PARAMETER OutputFilePath
    Path for the generated JSON file. Defaults to
    ./ZTA-to-Workshop-{Pillar-or-all}-{yyyy-MM-dd_HHmmss}.json in the current directory.

.PARAMETER Pillar
    Restrict processing to a single pillar. Valid values: Identity, Devices, Data, Network. Omit
    to process all four pillars. The selected pillar's name is included in the default output
    filename.

.EXAMPLE
    .\Convert-ZTAssessmentToZTWorkshop.ps1 -HtmlFilePath .\ZeroTrustAssessmentReport.html

    Converts the full assessment report and writes ZTA-to-Workshop-all-<timestamp>.json in the
    current directory.

.EXAMPLE
    .\Convert-ZTAssessmentToZTWorkshop.ps1 -HtmlFilePath .\ZeroTrustAssessmentReport.html -Pillar Identity

    Exports only Identity tests to ZTA-to-Workshop-Identity-<timestamp>.json.

.EXAMPLE
    .\Convert-ZTAssessmentToZTWorkshop.ps1 -HtmlFilePath .\ZeroTrustAssessmentReport.html -OutputFilePath .\my-workshop-import.json

    Converts the assessment and writes to the specified output path.

.LINK
    https://github.com/microsoft/zerotrustassessment

.LINK
    https://zerotrust.microsoft.com/
#>
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
    [string]$Pillar
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Pillars to pre-initialize in the output. Includes pillars that don't yet have
# any test mappings - they appear in the output as empty placeholders so the
# Workshop importer always sees the same shape regardless of mapping coverage.
$script:KnownPillars = @('identity', 'devices', 'data', 'network', 'infrastructure', 'security-ops', 'ai')

# The Workshop importer rejects any task whose notes field exceeds this many
# characters (spaces included). The combined notes for each task - including the
# "ZT Assessment result:" wrapper - are hard-capped to this length so the export
# always imports successfully regardless of how many tests map to one task.
$script:MaxNotesLength = 1000

# Matches a markdown inline link [text](url) and captures the display text.
# The url alternation tolerates one level of nested parentheses (common in
# Azure portal/Wikipedia-style URLs) so the link is fully consumed.
$script:MarkdownLinkRegex = [regex]'\[([^\]]+)\]\((?:[^()]|\([^()]*\))*\)'

function Remove-MarkdownFormatting {
    # Normalises a note line for the Workshop importer:
    #   * [text](url) -> text         (unwrap inline links, drop the URL)
    #   * leading #, ##, ### ...      (drop markdown heading markers)
    #   * **bold** -> bold            (remove bold emphasis markers)
    #   * `n / \n literals            (drop stray newline escapes from source)
    # Backtick code spans are intentionally preserved.
    param([string]$Text)
    if ([string]::IsNullOrEmpty($Text)) { return $Text }
    $Text = $script:MarkdownLinkRegex.Replace($Text, '$1')  # [text](url) -> text
    $Text = [regex]::Replace($Text, '^\s*#{1,6}\s*', '')    # leading heading hashes
    $Text = $Text -replace '\*\*', ''                         # **bold** -> bold
    # Some source TestResult values contain literal newline escape sequences
    # (PowerShell-style `n or C-style \n) that leaked in as visible text rather
    # than real line breaks. Strip them so they don't show up in the notes.
    $Text = $Text -replace '`n', ' ' -replace '\\n', ' '
    $Text = [regex]::Replace($Text, '\s{2,}', ' ')           # collapse doubled spaces
    return $Text.Trim()
}

# Any single extracted note line longer than this is compacted to a concise
# "<icon> <TestTitle>" summary so verbose result text doesn't dominate the
# notes (and to leave room for more findings under the overall hard cap).
$script:MaxNotesLineLength = 200

# Status icons are built from Unicode code points rather than embedded as literal
# emoji in the source. Windows PowerShell 5.1 decodes .ps1 files using the system
# ANSI code page unless the file carries a UTF-8 BOM; literal emoji then turn into
# mojibake (a multi-character sequence) on that host. Building them from code
# points makes the output correct regardless of how the script file is decoded.
$script:IconPassed  = [char]::ConvertFromUtf32(0x2705)                 # check mark
$script:IconFailed  = [char]::ConvertFromUtf32(0x274C)                 # cross mark
$script:IconWarning = [char]::ConvertFromUtf32(0x26A0) + [char]0xFE0F  # warning sign + variation selector
# Horizontal ellipsis for the "more findings" marker, also built from a code
# point so the marker text written to the notes is never affected by how the
# script file itself is decoded.
$script:Ellipsis = [char]::ConvertFromUtf32(0x2026)                   # ...

function Get-StatusIcon {
    # Maps a TestStatus to a status icon used when compacting long note lines.
    #   Passed -> check, Failed -> cross, anything else -> warning.
    param([string]$Status)
    switch -Regex ($Status) {
        '^Passed$' { return $script:IconPassed }
        '^Failed$' { return $script:IconFailed }
        default    { return $script:IconWarning }
    }
}

# --- 0. Resolve pillar filter and build default output filename ---
# When -Pillar is supplied, restrict processing to that pillar and tag the
# output filename with its name. Otherwise tag the filename with "all".
$pillarFilterKey = $null
$pillarSegment   = 'all'
if ($PSBoundParameters.ContainsKey('Pillar')) {
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
    exit 1
}

$htmlContent = Get-Content -LiteralPath $HtmlFilePath -Raw -Encoding UTF8

# --- 2. Extract the Tests JSON array ---
# Use bracket-balancing to find the full array, skipping characters inside JSON strings
$testsMatch = [regex]::Match($htmlContent, '"Tests"\s*:\s*\[')
if (-not $testsMatch.Success) {
    Write-Error "Failed to extract 'Tests' array from the HTML file. No matching JSON block found."
    exit 1
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
    exit 1
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
    exit 1
}

# --- 3. Load the mapping file ---
# Resolve relative MappingFilePath against the script's directory
if (-not [System.IO.Path]::IsPathRooted($MappingFilePath)) {
    $scriptDir = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }
    $MappingFilePath = Join-Path $scriptDir $MappingFilePath
}
Write-Host "Looking for mapping file at: $MappingFilePath"
$pillarMappings = @{}  # pillar -> hashtable of TestId -> list of OverrideIds (from JSON arrays)
if (-not (Test-Path -LiteralPath $MappingFilePath)) {
    Write-Error "Mapping file not found: $MappingFilePath. This file is required and should ship alongside the script."
    exit 1
}
try {
    # The mapping file is standard JSON: pillar -> { TestId -> [ TaskOverrideId, ... ] }.
    # A test may map to multiple tasks, expressed as a JSON array. A bare string is
    # also accepted for backward compatibility and treated as a single-element array.
    $mappingObject = Get-Content -LiteralPath $MappingFilePath -Raw -Encoding UTF8 | ConvertFrom-Json
    $totalEntries = 0
    foreach ($pillarProp in $mappingObject.PSObject.Properties) {
        $pillarKey = $pillarProp.Name.ToLower()
        $pillarMappings[$pillarKey] = @{}
        if ($null -eq $pillarProp.Value) { continue }
        foreach ($entryProp in $pillarProp.Value.PSObject.Properties) {
            $tid = $entryProp.Name
            $list = [System.Collections.Generic.List[string]]::new()
            foreach ($oid in @($entryProp.Value)) {
                $oidStr = [string]$oid
                if (-not [string]::IsNullOrWhiteSpace($oidStr) -and -not $list.Contains($oidStr)) {
                    $list.Add($oidStr)
                    $totalEntries++
                }
            }
            $pillarMappings[$pillarKey][$tid] = $list
        }
    }
    Write-Host "Loaded mapping file with $totalEntries entries across $($pillarMappings.Count) pillars."
}
catch {
    Write-Error "Failed to parse mapping file '$MappingFilePath'. Fix the JSON and rerun. Error: $_"
    exit 1
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

    # Skip tests whose status is "Skipped" - they don't represent an
    # assessed result and only add noise to the override notes.
    $testStatus = if ($test.PSObject.Properties['TestStatus']) { [string]$test.TestStatus } else { '' }
    if ($testStatus -ieq 'Skipped') {
        $skippedStatus++
        continue
    }

    # TestTitle is used to compact overly long note lines into a concise summary.
    $testTitle = if ($test.PSObject.Properties['TestTitle']) { [string]$test.TestTitle } else { '' }

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

    # Resolve override keys - look up in the pillar-specific mapping
    $pillarMap = if ($pillarMappings.ContainsKey($pillarKey)) { $pillarMappings[$pillarKey] } else { @{} }
    if ($pillarMap.ContainsKey($testId)) {
        $overrideIds = $pillarMap[$testId]
    }
    else {
        # TestId has no mapping in this pillar - skip it
        continue
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
            # No newline at all - use entire trimmed TestResult
            $notesText = $testResult.Trim()
        }
    }

    # Unwrap markdown links, strip heading hashes, and remove bold markers in
    # the extracted note (backtick code spans are left intact).
    $notesText = Remove-MarkdownFormatting $notesText

    # Normalise every note to a consistent "<icon> <Status>: <text>" shape:
    #   * Strip any leading status emoji the assessment already added so the
    #     icon isn't duplicated.
    #   * For verbose notes (over the per-line limit) use the concise TestTitle
    #     instead of the full result text, leaving more room for other findings
    #     under the overall hard cap.
    #   * Prepend our own status icon and word (omitted when TestStatus is
    #     unknown). Notes with no TestTitle still get the prefix on their text.
    if (-not [string]::IsNullOrWhiteSpace($notesText)) {
        $notesText = [regex]::Replace($notesText, '^[\p{So}\uFE0F\s]+', '')
        $body = if ($notesText.Length -gt $script:MaxNotesLineLength -and -not [string]::IsNullOrWhiteSpace($testTitle)) {
            $testTitle.Trim()
        }
        else {
            $notesText
        }
        $icon = Get-StatusIcon $testStatus
        $notesText = if ([string]::IsNullOrWhiteSpace($testStatus)) {
            "$icon $body"
        }
        else {
            "$icon $($testStatus.Trim()): $body"
        }
    }

    # Ensure pillar exists
    if (-not $pillars.Contains($pillarKey)) {
        $pillars[$pillarKey] = [ordered]@{ taskOverrides = [ordered]@{} }
    }

    foreach ($overrideId in $overrideIds) {
        # Collect notes per overrideId - combine all mapped TestResults (skip empty)
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
    # Deduplicate identical lines - the Workshop importer rejects entries
    # whose notes contain repeated lines.
    $uniqueLines = [System.Collections.Generic.List[string]]::new()
    $seen = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
    foreach ($line in $collectedNotes[$noteKey]) {
        if ($seen.Add($line)) { $uniqueLines.Add($line) }
    }

    # Hard-cap the final notes to $script:MaxNotesLength characters (wrapper
    # included). Keep whole lines and, when truncation is needed, append a
    # marker noting how many findings were dropped so nothing looks silently
    # lost. Truncating on line boundaries keeps each retained finding readable.
    $prefix     = "ZT Assessment result:`n"
    $suffix     = "`n"
    $bodyBudget = $script:MaxNotesLength - $prefix.Length - $suffix.Length

    $combined = $uniqueLines -join "`n"
    if ($combined.Length -le $bodyBudget) {
        $finalBody = $combined
    }
    else {
        $total      = $uniqueLines.Count
        $kept       = [System.Collections.Generic.List[string]]::new()
        $runningLen = 0
        for ($idx = 0; $idx -lt $total; $idx++) {
            $line = $uniqueLines[$idx]
            $sep  = if ($kept.Count -gt 0) { 1 } else { 0 }
            $prospective = $runningLen + $sep + $line.Length
            # Reserve room for the drop marker if any lines would remain after this one.
            $dropAfter = $total - ($kept.Count + 1)
            $markerLen = if ($dropAfter -gt 0) { 1 + "$($script:Ellipsis)(+$dropAfter more findings)".Length } else { 0 }
            if (($prospective + $markerLen) -le $bodyBudget) {
                $kept.Add($line)
                $runningLen = $prospective
            }
            else {
                break
            }
        }
        $dropped   = $total - $kept.Count
        $finalBody = $kept -join "`n"
        if ($dropped -gt 0) {
            $marker = "$($script:Ellipsis)(+$dropped more findings)"
            $finalBody = if ($finalBody.Length -gt 0) { "$finalBody`n$marker" } else { $marker }
        }
        Write-Warning "Notes for $pKey/$oKey exceeded $script:MaxNotesLength chars; kept $($kept.Count) of $total finding(s)."
    }

    $pillars[$pKey].taskOverrides[$oKey].notes = "$prefix$finalBody$suffix"
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

# --- 8. Build the full output structure ---
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
        totalTasks         = $tests.Count
        modifiedTasks      = $modifiedCount
        completedTasks     = 0
        inProgressTasks    = 0
        plannedTasks       = 0
        pillarsWithChanges = $pillarsWithChanges
    }
}

# --- 9. Write output ---
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
# Write as UTF-8 without a BOM, consistently across PowerShell editions. Out-File
# -Encoding UTF8 emits a BOM on Windows PowerShell 5.1 but not on PowerShell 7;
# writing via .NET keeps the bytes identical everywhere and avoids a stray BOM in
# the JSON. Resolve relative paths against the current location so .NET and
# PowerShell agree on the destination.
$resolvedOutputPath = if ([System.IO.Path]::IsPathRooted($OutputFilePath)) {
    $OutputFilePath
}
else {
    Join-Path (Get-Location).Path $OutputFilePath
}
# End the file with a single trailing newline (matches prior Out-File output).
if (-not $jsonOutput.EndsWith("`n")) { $jsonOutput += [Environment]::NewLine }
[System.IO.File]::WriteAllText($resolvedOutputPath, $jsonOutput, (New-Object System.Text.UTF8Encoding($false)))

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
