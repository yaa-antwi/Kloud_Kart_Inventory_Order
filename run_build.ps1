Set-Location $PSScriptRoot

$logDir = Join-Path $PSScriptRoot 'logs'
New-Item -ItemType Directory -Force $logDir | Out-Null

$started = Get-Date
$reportPath = Join-Path $logDir ("build_run_{0}.md" -f $started.ToString('yyyyMMdd_HHmmss_fff'))
$command = 'docker exec -w /lab -i kloudkart psql -U postgres -v ON_ERROR_STOP=1 -f sql/build/run_all.sql'

$output = @(
    & docker exec -w /lab -i kloudkart psql -U postgres -v ON_ERROR_STOP=1 -f sql/build/run_all.sql 2>&1 |
        ForEach-Object {
            $line = "$_"
            Write-Host $line
            $line
        }
)
$exitCode = $LASTEXITCODE

$report = @(
    '# SQL build run',
    '',
    "Started: $($started.ToString('yyyy-MM-dd HH:mm:ss'))",
    '',
    'Command:',
    '```powershell',
    $command,
    '```',
    '',
    "Exit code: $exitCode",
    '',
    '## Command output',
    '',
    '```text'
) + $output + @('```', '')

Set-Content -Encoding utf8 -Path $reportPath -Value $report
Write-Host "Markdown log saved to: $reportPath"

if ($exitCode -ne 0) {
    exit $exitCode
}
