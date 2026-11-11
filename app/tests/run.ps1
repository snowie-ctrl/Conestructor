# Copied from Gluttony app/tests/run.ps1; CONESTRUCTOR_ names, the bundled Ubuntu Mono for offscreen runs,
# and -NoCpp / -Qml to run one stage or one QML file.
# Runs the C++ tests (ctest) and then the QML logic tests (qmltestrunner), then prints one summary line per
# stage. Exits 0 only when both stages pass.
#   run.ps1                    everything
#   run.ps1 -R tst_settings    only C++ tests whose name matches
#   run.ps1 -NoCpp -Qml tst_units.qml   one QML test file
param([string]$R = '', [switch]$NoCpp, [switch]$NoQml, [string]$Qml = '')
# Not 'Stop': ctest and qmltestrunner write to stderr, and when the caller redirects it (2>&1) PowerShell would
# turn the first such line into an error that ends the script before the QML stage runs.
$ErrorActionPreference = 'Continue'
$qt    = if ($env:CONESTRUCTOR_QT)       { $env:CONESTRUCTOR_QT }       else { 'D:\allNewQT6\6.11.1\msvc2022_64' }
$tools = if ($env:CONESTRUCTOR_QT_TOOLS) { $env:CONESTRUCTOR_QT_TOOLS } else { 'D:\allNewQT6\Tools' }
$src   = Split-Path $PSScriptRoot -Parent
$build = Join-Path $src 'build\tests'

$env:PATH = "$tools\CMake_64\bin;$qt\bin;$env:PATH"
# No window is needed to check logic; offscreen keeps runs quiet and works headless.
$env:QT_QPA_PLATFORM = 'offscreen'
# The offscreen platform looks for fonts in the Qt install, which ships none, and warns in every GUI test.
$env:QT_QPA_FONTDIR = Join-Path $src 'assets\fonts\Ubuntu_Mono'
# tst_conefile reads docs/cone-format.schema.json with XMLHttpRequest, which QML allows for local files only when asked.
$env:QML_XHR_ALLOW_FILE_READ = '1'

# ---- C++ tests ----
$ctestPassed = $true
if ($NoCpp) {
    $ctestSummary = 'ctest: skipped (-NoCpp)'
} else {
    $ctestArgs = @('--test-dir', $build, '--output-on-failure')
    if ($R) { $ctestArgs += @('-R', $R) }
    & ctest @ctestArgs 2>&1 | ForEach-Object { "$_" } | Tee-Object -Variable ctestLines
    $ctestExit = $LASTEXITCODE
    $failedTests = @($ctestLines | ForEach-Object { if ($_ -match '^\s*\d+\s+-\s+(\S+)\s+\(') { $Matches[1] } })
    if ($ctestExit -eq 0) {
        $ctestSummary = 'ctest: passed'
    } else {
        $ctestPassed = $false
        $names = if ($failedTests.Count -gt 0) { $failedTests -join ', ' } else { "exit code $ctestExit" }
        $ctestSummary = "ctest: FAILED ($names)"
    }
    Write-Output $ctestSummary
}

# ---- QML tests ----
$qmlPassed = $true
$qmlDir = Join-Path $PSScriptRoot 'qml'
$qmlInput = if ($Qml) { Join-Path $qmlDir $Qml } else { $qmlDir }
if ($NoQml) {
    $qmlSummary = 'qml: skipped (-NoQml)'
} elseif (-not $Qml -and -not (Get-ChildItem $qmlDir -Filter 'tst_*.qml' -ErrorAction SilentlyContinue)) {
    $qmlSummary = 'qml: no tests'
} else {
    New-Item -ItemType Directory -Force $build | Out-Null
    $results = Join-Path $build 'qml-results.txt'
    Remove-Item -LiteralPath $results -Force -ErrorAction SilentlyContinue
    & qmltestrunner -input $qmlInput -o "$results,txt" 2>&1 | ForEach-Object { "$_" }
    $qmlExit = $LASTEXITCODE
    if (Test-Path -LiteralPath $results) {
        $qmlLines = Get-Content -LiteralPath $results
        $qmlLines
        $passedCount = 0
        $failedCount = 0
        foreach ($line in $qmlLines) {
            if ($line -match '^Totals:\s+(\d+) passed,\s+(\d+) failed') {
                $passedCount += [int]$Matches[1]
                $failedCount += [int]$Matches[2]
            }
        }
        $qmlPassed = $qmlExit -eq 0 -and $failedCount -eq 0
        $qmlSummary = "qml: $passedCount passed, $failedCount failed"
        if ($qmlExit -ne 0 -and $failedCount -eq 0) { $qmlSummary += " (qmltestrunner exit code $qmlExit)" }
    } else {
        $qmlPassed = $false
        $qmlSummary = "qml: FAILED (no results file; qmltestrunner exit code $qmlExit)"
    }
    Write-Output $qmlSummary
}

Write-Output ''
Write-Output $ctestSummary
Write-Output $qmlSummary
if ($ctestPassed -and $qmlPassed) { exit 0 } else { exit 1 }
