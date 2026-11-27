
# run_everything.ps1
# Runs the whole project from a clean load, in order.
# Records each step and writes failure details to Markdown files.
#
# WARNING: Step 2 deletes everything in the public schema and reloads it.
#
# RUN from the project folder:
# powershell -NoProfile -ExecutionPolicy Bypass -File .\run_everything.ps1

Set-Location $PSScriptRoot

$logDir  = Join-Path $PSScriptRoot 'logs'
$failDir = Join-Path $logDir 'failures'

New-Item -ItemType Directory -Force $logDir, $failDir, 'sql\build_outputs', 'sql\report', 'sql\report_pack' | Out-Null

$runLog = Join-Path $logDir 'run_log.md'

$env:DATABASE_URL = 'postgresql://postgres:kloudkart@localhost:5432/postgres'
$env:PYTHONIOENCODING = 'utf-8'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$script:failures = 0
$script:lastOut = @()

function Write-Log($status, $step, $message) {
    $line = "{0} | {1,-6} | {2} | {3}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $status, $step, $message
    Add-Content -Encoding utf8 -Path $runLog -Value $line
    Write-Host $line
}

function Fail($step, $message, $lines) {
    $script:failures++

    $file = Join-Path $failDir ("{0}_{1}.md" -f (Get-Date -Format 'yyyyMMdd_HHmmss'), $step)

    Set-Content -Encoding utf8 -Path $file -Value $lines

    Write-Log 'FAILED' $step "$message (details: $file)"
}

function Run-Sql($step, $workdir, $file) {
    $out = docker exec -w $workdir -i kloudkart psql -U postgres -v ON_ERROR_STOP=1 -f $file 2>&1 | ForEach-Object { "$_" }

    $code = $LASTEXITCODE
    $script:lastOut = $out
    $errors = @($out | Where-Object { $_ -match 'ERROR:' })

    if ($code -ne 0 -or $errors.Count -gt 0) {
        $first = if ($errors.Count -gt 0) { $errors[0] } else { "psql stopped with exit code $code" }
        Fail $step $first $out
        return $false
    }

    Write-Log 'OK' $step 'ran without errors'
    return $true
}

# 1. Start the database
$out = docker start kloudkart 2>&1 | ForEach-Object { "$_" }

if ($LASTEXITCODE -ne 0) {
    Fail '01_start' 'Could not start the database. Check Docker Desktop and the kloudkart container.' $out
    exit 1
}

Start-Sleep -Seconds 5
Write-Log 'OK' '01_start' 'database is running'

# 2. Reset and load fresh data (DESTRUCTIVE)
$out = docker exec -i kloudkart psql -U postgres -v ON_ERROR_STOP=1 -c "DROP SCHEMA public CASCADE; CREATE SCHEMA public;" 2>&1 | ForEach-Object { "$_" }

if ($LASTEXITCODE -ne 0) {
    Fail '02_reset' 'Could not reset the database' $out
    exit 1
}

Write-Log 'OK' '02_reset' 'database reset'

if (-not (Run-Sql '02_schema' '/lab/M03_Resources' 'schema.sql')) { exit 1 }
if (-not (Run-Sql '02_load' '/lab/M03_Resources' 'load.sql')) { exit 1 }

# 3. Build
if (-not (Run-Sql '03_build' '/lab' 'sql/build/run_all.sql')) { exit 1 }

# 4. Checks
if (Run-Sql '04_checks' '/lab' 'sql/build/99_checks.sql') {

    $checkFile = 'sql\build_outputs\02_checks.md'

    if (-not (Test-Path $checkFile)) {
        Fail '04_checks' 'Expected check output file was not found.' @("Missing file: $checkFile")
    }
    else {
        $bad = @(Get-Content $checkFile | Where-Object { $_ -match '\|\s*f\s*$' })

        if ($bad.Count -gt 0) {
            Fail '04_checks' "$($bad.Count) check(s) did not pass" $bad
        }
        else {
            Write-Log 'OK' '04_checks' 'no failed check rows were found in the output file'
        }
    }
}

# 5. Race test - three runs
$raceReport = Join-Path $logDir ("race_tests_{0}.md" -f (Get-Date -Format 'yyyyMMdd_HHmmss'))
Set-Content -Encoding utf8 -Path $raceReport -Value @(
    '# Race test results',
    '',
    "Started: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')",
    ''
)

for ($run = 1; $run -le 3; $run++) {

    $lines = python M03_Resources\race_test.py --verbose 2>&1 | ForEach-Object { "$_" }
    $code = $LASTEXITCODE

    Add-Content -Encoding utf8 -Path $raceReport -Value (@("## Run $run", "", '```text') + $lines + @('```', ''))
    Set-Content -Encoding utf8 -Path "sql\build_outputs\03_race_test_run$run.md" -Value (@("# Race test, run $run", "", "Written: $(Get-Date -Format 'yyyy-MM-dd HH:mm')", "", '```text') + $lines + '```')

    $passed = @($lines | Where-Object { $_ -cmatch '^PASSED' }).Count -gt 0
    $bad = @($lines | Where-Object { $_ -cmatch 'FAIL|Traceback|ERROR' -or $_ -match '\b[1-9]\d* errored' })

    if ($code -eq 0 -and $passed -and $bad.Count -eq 0) {
        Write-Log 'OK' "05_race_run$run" "PASSED (full report: $raceReport)"
    }
    else {
        Fail "05_race_run$run" "race test did not pass cleanly (full report: $raceReport)" $lines
    }
}

# 6. Before and after
if (-not (Run-Sql '06_before_after' '/lab' 'sql/report/01_before_after.sql')) {
    Write-Log 'WARN' '06_before_after' 'before-and-after script failed; see failure log'
}

# 7. Report pack
if (Run-Sql '07_report_pack' '/lab' 'sql/build/05_report_pack.sql') {

    $copies = (@($script:lastOut | Where-Object { $_ -match '^COPY' }) -join ', ')

    if ($copies -ne 'COPY 100, COPY 40420, COPY 485040, COPY 1') {
        Fail '07_report_pack' "Unexpected row counts: $copies" $script:lastOut
    }
    else {
        Write-Log 'OK' '07_report_pack' 'four files written with the expected row counts'
    }
}

# 8. Final status
if ($script:failures -eq 0) {
    Write-Log 'DONE' 'all' 'every step passed'
}
else {
    Write-Log 'DONE' 'all' "$($script:failures) step(s) failed. Read logs\failures."
    exit 1
}
