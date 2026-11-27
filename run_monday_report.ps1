
# run_monday_report.ps1
# For Adwoa. Writes the four Monday report files into report_pack.
# Every run adds one line to logs\monday_report_log.md.
# If a run fails, the log opens in Notepad.
#
# RUN from the project folder:
# powershell -NoProfile -ExecutionPolicy Bypass -File .\run_monday_report.ps1

Set-Location $PSScriptRoot

New-Item -ItemType Directory -Force 'logs', 'report_pack' | Out-Null
$log = Join-Path $PSScriptRoot 'logs\monday_report_log.md'

function Say($status, $message) {
    $line = "{0} | {1} | {2}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $status, $message
    Add-Content -Encoding utf8 -Path $log -Value $line
    Write-Host $line
}

function Stop-With($message, $details) {
    Say 'FAILED' $message

    foreach ($d in $details) {
        Add-Content -Encoding utf8 -Path $log -Value "    $d"
    }

    Add-Content -Encoding utf8 -Path $log -Value "    If this keeps happening, send this file to the person who looks after the database."

    Start-Process notepad.exe $log
    exit 1
}

# 1. Start the database
$out = docker start kloudkart 2>&1 | ForEach-Object { "$_" }

if ($LASTEXITCODE -ne 0) {
    Stop-With 'The database is not running. Open Docker Desktop, wait until it says Engine running, then run this again.' $out
}

Start-Sleep -Seconds 3

# 2. Generate the Monday report pack
$out = docker exec -w /lab -i kloudkart psql -U postgres -v ON_ERROR_STOP=1 -f sql/build/05_report_pack.sql 2>&1 | ForEach-Object { "$_" }
$code = $LASTEXITCODE

$errors = @($out | Where-Object { $_ -match 'ERROR:|Permission denied|could not open' })

if ($code -ne 0 -or $errors.Count -gt 0) {
    $hint = 'The report could not be written. If the report files are open in Excel, close them and run this again.'
    Stop-With $hint ($errors + $out | Select-Object -First 6)
}

# 3. Verify the reported row counts
$copies = (@($out | Where-Object { $_ -match '^COPY' }) -join ', ')

if ($copies -notmatch '^COPY 100, COPY \d+, COPY \d+, COPY 1$') {
    Stop-With 'The report was written but the row counts look wrong, so do not use these files.' $out
}

# 4. Record success
Say 'OK' "Four files written to report_pack ($copies)"

Write-Host 'Done. Your files are in report_pack.'
Write-Host 'The log is logs\monday_report_log.md'
