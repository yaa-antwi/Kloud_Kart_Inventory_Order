Set-Location $PSScriptRoot

$logDir = Join-Path $PSScriptRoot 'logs'
$buildOutputDir = Join-Path $PSScriptRoot 'sql\build_outputs'
New-Item -ItemType Directory -Force $logDir, $buildOutputDir | Out-Null

$started = Get-Date
$reportPath = Join-Path $logDir ("test_run_{0}.md" -f $started.ToString('yyyyMMdd_HHmmss_fff'))
$checksPath = Join-Path $PSScriptRoot 'sql\build_outputs\02_checks.md'
$env:DATABASE_URL = 'postgresql://postgres:kloudkart@localhost:5432/postgres'
$env:PYTHONIOENCODING = 'utf-8'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$script:failures = 0

Set-Content -Encoding utf8 -Path $reportPath -Value @(
    '# Test run',
    '',
    "Started: $($started.ToString('yyyy-MM-dd HH:mm:ss'))",
    '',
    'This report records the SQL checks and three verbose race-test runs.',
    ''
)

function Add-ReportSection($title, $command, $exitCode, $lines) {
    $result = if ($exitCode -eq 0) { 'Command exited successfully' } else { "Command exited with code $exitCode" }
    Add-Content -Encoding utf8 -Path $reportPath -Value (
        @(
            "## $title",
            '',
            'Command:',
            '```powershell',
            $command,
            '```',
            '',
            $result,
            '',
            '```text'
        ) + @($lines) + @('```', '')
    )
}

function Add-ChecksArtifact($lines) {
    Add-Content -Encoding utf8 -Path $reportPath -Value (
        @(
            '### SQL check results (13 checks)',
            '',
            'Source: `sql/build_outputs/02_checks.md`',
            '',
            '```text'
        ) + @($lines) + @('```', '')
    )
}

$startOutput = @(docker start kloudkart 2>&1 | ForEach-Object { "$_" })
$startCode = $LASTEXITCODE
Add-ReportSection 'Start database' 'docker start kloudkart' $startCode $startOutput
if ($startCode -ne 0) {
    $script:failures++
    Add-Content -Encoding utf8 -Path $reportPath -Value @('## Overall result', '', 'FAILED: could not start the database.')
    Write-Host "Test report saved to: $reportPath"
    exit 1
}

Start-Sleep -Seconds 5

$checksCommand = 'docker exec -w /lab -i kloudkart psql -U postgres -v ON_ERROR_STOP=1 -f sql/build/99_checks.sql'
$checksOutput = @(docker exec -w /lab -i kloudkart psql -U postgres -v ON_ERROR_STOP=1 -f sql/build/99_checks.sql 2>&1 | ForEach-Object { "$_" })
$checksCode = $LASTEXITCODE
Add-ReportSection 'SQL checks' $checksCommand $checksCode $checksOutput

if (Test-Path $checksPath) {
    $checkLines = @(Get-Content $checksPath)
    Add-ChecksArtifact $checkLines
    $failedChecks = @($checkLines | Where-Object { $_ -match '^\s*\d+\s*\|.*\|\s*f\s*$' })
    if ($checksCode -ne 0 -or $failedChecks.Count -gt 0) {
        $script:failures++
        Add-Content -Encoding utf8 -Path $reportPath -Value "SQL checks failed: command exit code $checksCode; failed check rows $($failedChecks.Count)."
    }
    else {
        Add-Content -Encoding utf8 -Path $reportPath -Value 'SQL checks passed.'
    }
}
else {
    $script:failures++
    Add-Content -Encoding utf8 -Path $reportPath -Value "SQL check report was not created: $checksPath"
}

for ($run = 1; $run -le 3; $run++) {
    $raceCommand = 'python M03_Resources\race_test.py --verbose'
    $raceOutput = @(python M03_Resources\race_test.py --verbose 2>&1 | ForEach-Object { "$_" })
    $raceCode = $LASTEXITCODE
    Add-ReportSection "Race test run $run" $raceCommand $raceCode $raceOutput

    $passed = @($raceOutput | Where-Object { $_ -cmatch '^PASSED' }).Count -gt 0
    if ($raceCode -ne 0 -or -not $passed) {
        $script:failures++
        Add-Content -Encoding utf8 -Path $reportPath -Value "Race test run $run failed."
    }
    else {
        Add-Content -Encoding utf8 -Path $reportPath -Value "Race test run $run passed."
    }

    $legacyReport = Join-Path $PSScriptRoot "sql\build_outputs\03_race_test_run$run.md"
    Set-Content -Encoding utf8 -Path $legacyReport -Value (
        @("# Race test, run $run", '', "Written: $(Get-Date -Format 'yyyy-MM-dd HH:mm')", '', '```text') +
        $raceOutput +
        @('```')
    )
}

if ($script:failures -eq 0) {
    Add-Content -Encoding utf8 -Path $reportPath -Value @('', '## Overall result', '', 'PASSED: all SQL checks and all three race-test runs passed.')
    Write-Host 'PASSED: all SQL checks and all three race-test runs passed.'
}
else {
    Add-Content -Encoding utf8 -Path $reportPath -Value @('', '## Overall result', '', "FAILED: $($script:failures) test group(s) failed.")
    Write-Host "FAILED: $($script:failures) test group(s) failed."
}

Write-Host "Test report saved to: $reportPath"

if ($script:failures -gt 0) {
    exit 1
}
