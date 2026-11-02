@echo off
rem The intranet box usually runs Policy Restricted, so .ps1 files are refused.
rem Launch one with -ExecutionPolicy Bypass (prefer PowerShell 7 when installed).
setlocal
set "SCRIPT=%~dp0install-plugin.ps1"
where pwsh >nul 2>nul
if %ERRORLEVEL%==0 (
  pwsh -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT%" %*
) else (
  powershell -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT%" %*
)
exit /b %ERRORLEVEL%
