@echo off
setlocal
cd /d "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0switch-hud.ps1" %*
if %ERRORLEVEL% NEQ 0 pause

