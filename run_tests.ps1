
Set-Location $PSScriptRoot


# Folders and report


$logDir = Join-Path $PSScriptRoot 'logs'
$buildOutputDir = Join-Path $PSScriptRoot 'sql\build_outputs'

New-Item -ItemType Directory -Force $logDir, $buildOutputDir | Out-Null

$started = Get-Date
$reportPath = Join-Path $logDir ("test_run_{0}.md" -f $started.ToString('yyyyMMdd_HHmmss_fff'))
$checksPath = Join-Path $buildOutputDir '02_checks.md'


# Load local environment settings


$envFile = Join-Path $PSScriptRoot '.env'

if (-not (Test-Path $envFile)) {
    throw "Missing .env file. Create it in the project root using the README instructions."
}

Get-Content $envFile | ForEach-Object {
    if ($_ -match '^\s*([^#][^=]*)=(.*)$') {
        $name = $matches[1].Trim()
        $value = $matches[2].Trim()

        [Environment]::SetEnvironmentVariable($name, $value, 'Process')
    }
}

if ([string]::IsNullOrWhiteSpace($env:DATABASE_URL)) {
    throw "DATABASE_URL is missing from .env."
}

if ([string]::IsNullOrWhiteSpace($env:POSTGRES_PASSWORD)) {
    throw "POSTGRES_PASSWORD is missing from .env."
}

$env:PYTHONIOENCODING = 'utf-8'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$script:failures = 0

# --------------------------------------------------
# Report functions
# --------------------------------------------------

Set-Content -Encoding utf8 -Path $reportPath -Value @(
    '# Test run',
    '',
    "Started: $($started.ToString('yyyy-MM-dd HH:mm:ss'))",
    '',
    'This report records the SQL checks and three verbose race-test runs.',
    ''
)

function Add-ReportSection($title, $command, $exitCode, $lines) {
    $result = if ($exitCode -eq 0) {
        'Command exited successfully'
    }
    else {
        "Command exited with code $exitCode"
    }

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

# --------------------------------------------------
# Start database
# --------------------------------------------------

$startOutput = @(docker start kloudkart 2>&1 | ForEach-Object { "$_" })
$startCode = $LASTEXITCODE

Add-ReportSection 'Start database' 'docker start kloudkart' $startCode $startOutput

if ($startCode -ne 0) {
    $script:failures++

    Add-Content -Encoding utf8 -Path $reportPath -Value @(
        '## Overall result',
        '',
        'FAILED: could not start the database.'
    )

    Write-Host "Test report saved to: $reportPath"
    exit 1
}

# --------------------------------------------------
# Wait for PostgreSQL to become ready
# --------------------------------------------------

$maxAttempts = 30
$ready = $false

for ($attempt = 1; $attempt -le $maxAttempts; $attempt++) {
    docker exec kloudkart pg_isready -U postgres -d postgres *> $null

    if ($LASTEXITCODE -eq 0) {
        $ready = $true
        break
    }

    Start-Sleep -Seconds 1
}

if (-not $ready) {
    $script:failures++

    Add-Content -Encoding utf8 -Path $reportPath -Value @(
        '## Database readiness',
        '',
        "FAILED: PostgreSQL was not ready after $maxAttempts seconds."
    )

    Write-Host "Test report saved to: $reportPath"
    exit 1
}

Add-Content -Encoding utf8 -Path $reportPath -Value @(
    '## Database readiness',
    '',
    'PostgreSQL is ready.'
)

# --------------------------------------------------
# Run SQL checks
# --------------------------------------------------

$checksCommand = 'docker exec -w /lab -i kloudkart psql -U postgres -v ON_ERROR_STOP=1 -f tests/99_checks.sql'

$checksOutput = @(
    docker exec -w /lab -i kloudkart psql -U postgres -v ON_ERROR_STOP=1 -f tests/99_checks.sql 2>&1 |
    ForEach-Object { "$_" }
)

$checksCode = $LASTEXITCODE

Add-ReportSection 'SQL checks' $checksCommand $checksCode $checksOutput

if (Test-Path $checksPath) {
    $checkLines = @(Get-Content $checksPath)
    Add-ChecksArtifact $checkLines

    $failedChecks = @(
        $checkLines |
        Where-Object { $_ -match '^\s*\d+\s*\|.*\|\s*f\s*$' }
    )

    if ($checksCode -ne 0 -or $failedChecks.Count -gt 0) {
        $script:failures++

        Add-Content -Encoding utf8 -Path $reportPath -Value (
            "SQL checks failed: command exit code $checksCode; failed check rows $($failedChecks.Count)."
        )
    }
    else {
        Add-Content -Encoding utf8 -Path $reportPath -Value 'SQL checks passed.'
    }
}
else {
    $script:failures++

    Add-Content -Encoding utf8 -Path $reportPath -Value (
        "SQL check report was not created: $checksPath"
    )
}

# --------------------------------------------------
# Run concurrency test three times
# --------------------------------------------------

for ($run = 1; $run -le 3; $run++) {

    $raceCommand = 'python M03_Resources\race_test.py --verbose'

    $raceOutput = @(
        python M03_Resources\race_test.py --verbose 2>&1 |
        ForEach-Object { "$_" }
    )

    $raceCode = $LASTEXITCODE

    Add-ReportSection "Race test run $run" $raceCommand $raceCode $raceOutput

    $passed = @(
        $raceOutput |
        Where-Object { $_ -cmatch '^PASSED' }
    ).Count -gt 0

    $elapsedMatch = [regex]::Match(
        ($raceOutput -join "`n"),
        'wall clock ([0-9]+(?:\.[0-9]+)?)s'
    )

    $withinTimeLimit = $false

    if ($elapsedMatch.Success) {
        $elapsedSeconds = [double]::Parse(
            $elapsedMatch.Groups[1].Value,
            [Globalization.CultureInfo]::InvariantCulture
        )

        $withinTimeLimit = $elapsedSeconds -le 10
    }

    if ($raceCode -ne 0 -or -not $passed -or -not $withinTimeLimit) {

        $script:failures++

        $reason = if (-not $elapsedMatch.Success) {
            'the 400-buyer wall-clock time was not reported'
        }
        elseif (-not $withinTimeLimit) {
            "the 400-buyer test took $elapsedSeconds seconds, over the 10-second limit"
        }
        else {
            'the race test did not pass'
        }

        Add-Content -Encoding utf8 -Path $reportPath -Value (
            "Race test run $run failed: $reason."
        )
    }
    else {
        Add-Content -Encoding utf8 -Path $reportPath -Value (
            "Race test run $run passed in $elapsedSeconds seconds (10-second limit)."
        )
    }
}

# --------------------------------------------------
# Overall result
# --------------------------------------------------

if ($script:failures -eq 0) {

    Add-Content -Encoding utf8 -Path $reportPath -Value @(
        '',
        '## Overall result',
        '',
        'PASSED: all SQL checks and all three race-test runs passed.'
    )

    Write-Host 'PASSED: all SQL checks and all three race-test runs passed.'
}
else {

    Add-Content -Encoding utf8 -Path $reportPath -Value @(
        '',
        '## Overall result',
        '',
        "FAILED: $($script:failures) test group(s) failed."
    )

    Write-Host "FAILED: $($script:failures) test group(s) failed."
}

Write-Host "Test report saved to: $reportPath"

if ($script:failures -gt 0) {
    exit 1
}
