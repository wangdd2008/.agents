@echo off
rem Install every plugin under plugin\ one by one. Safe to re-run.
rem Payload directories are flat (scoped names use '+' instead of '/'), because
rem cmd's `for /d` does not descend into scope folders.
setlocal
set "RC=0"
for /d %%D in ("%~dp0plugin\*") do (
  if exist "%%~fD\package.json" (
    echo.
    call "%~dp0install.cmd" -Payload "%%~fD"
    if errorlevel 1 set "RC=1"
  ) else (
    echo skip %%~nxD ^(no package.json^)
  )
)
echo.
if not "%RC%"=="0" (
  echo Some plugins failed - see the messages above.
  exit /b 1
)
echo All plugins installed. Restart dsh to load them.
exit /b 0
