
Set-Location $PSScriptRoot

# Folders and report
$logDir = Join-Path $PSScriptRoot 'logs'
$buildOutputDir = Join-Path $PSScriptRoot 'sql\build_outputs'

New-Item -ItemType Directory -Force $logDir, $buildOutputDir | Out-Null

$started = Get-Date
$reportPath = Join-Path $logDir ("build_run_{0}.md" -f $started.ToString('yyyyMMdd_HHmmss_fff'))
$summaryPath = Join-Path $buildOutputDir '01_build_summary.md'

# Build command
$buildArgs = @(
    'exec',
    '-w', '/lab',
    '-i', 'kloudkart',
    'psql',
    '-U', 'postgres',
    '-v', 'ON_ERROR_STOP=1',
    '-f', 'sql/build/run_all.sql'
)

$command = "docker $($buildArgs -join ' ')"

# Remove an old summary so it cannot be mistaken for this run
if (Test-Path $summaryPath) {
    Remove-Item $summaryPath -Force
}

# Execute the build
$output = @(
    & docker @buildArgs 2>&1 |
        ForEach-Object {
            $line = "$_"
            Write-Host $line
            $line
        }
)

$exitCode = $LASTEXITCODE

# Verify the build summary
$summaryExists = Test-Path $summaryPath

# Write the report
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
    "Build summary created: $summaryExists",
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

if (-not $summaryExists) {
    Write-Error "Build command completed, but the expected summary was not created: $summaryPath"
    exit 1
}

Write-Host 'PASSED: SQL build completed and the build summary was created.'
