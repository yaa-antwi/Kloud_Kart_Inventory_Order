@echo off
setlocal
rem Writes the four Monday report files into sql\report_pack. Double-click to run.
cd /d "%~dp0"

set "DOCKER=docker"
where docker >nul 2>nul
if errorlevel 1 (
  if exist "%LOCALAPPDATA%\Programs\DockerDesktop\resources\bin\docker.exe" (
    set "DOCKER=%LOCALAPPDATA%\Programs\DockerDesktop\resources\bin\docker.exe"
  ) else (
    echo Docker was not found. Start or install Docker Desktop, then try again.
    goto :failed
  )
)

"%DOCKER%" info >nul 2>nul
if errorlevel 1 (
  echo Docker Desktop is not ready. Start it and wait until the engine is running.
  goto :failed
)

if not exist "sql\report_pack\" mkdir "sql\report_pack"
if errorlevel 1 (
  echo Could not create the sql\report_pack folder.
  goto :failed
)

"%DOCKER%" start kloudkart
if errorlevel 1 (
  echo Could not start the kloudkart container. Check that it exists in Docker Desktop.
  goto :failed
)

"%DOCKER%" exec -w /lab -i kloudkart psql -U postgres -v ON_ERROR_STOP=1 -f sql/build/05_report_pack.sql
if errorlevel 1 (
  echo.
  echo The report query failed. Read the PostgreSQL error above.
  goto :failed
)

for %%F in (monday_top_100.csv monday_customer_summary.csv monday_monthly_running_total.csv monday_notes.csv) do (
  if not exist "sql\report_pack\%%F" (
    echo Expected report file was not created: sql\report_pack\%%F
    goto :failed
  )
)

echo.
echo Done. The four report files are in:
echo %CD%\sql\report_pack
goto :finish

:failed
echo.
echo The Monday report did not complete successfully.
pause
exit /b 1

:finish
pause
exit /b 0