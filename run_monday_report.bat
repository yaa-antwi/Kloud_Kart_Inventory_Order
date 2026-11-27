@echo off
rem Writes the four Monday report files into sql\report_pack. Double-click to run.
cd /d "%~dp0"
if not exist sql\report_pack mkdir sql\report_pack
docker start kloudkart >nul
docker exec -w /lab -i kloudkart psql -U postgres -v ON_ERROR_STOP=1 -f sql/build/05_report_pack.sql
if errorlevel 1 (
  echo.
  echo Something went wrong. Check that Docker Desktop says Engine running, then try again.
) else (
  echo.
  echo Done. The four files are in the folder sql\report_pack.
)
pause