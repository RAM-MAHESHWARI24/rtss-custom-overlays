@echo off
setlocal
title RTSS Custom HUD Installer

:: Change working directory to script directory
cd /d "%~dp0"

echo ========================================================================
echo          RivaTuner Statistics Server (RTSS) Custom HUD Suite             
echo                      Automated Setup Launcher                            
echo ========================================================================
echo.

:: Execute PowerShell installer with execution policy bypass
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0install.ps1" %*

if %ERRORLEVEL% NEQ 0 (
    echo.
    echo [!] An error occurred during installation (Exit code: %ERRORLEVEL%).
    pause
    exit /b %ERRORLEVEL%
)

echo.
pause
