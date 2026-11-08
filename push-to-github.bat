@echo off
setlocal
cd /d "%~dp0"
echo ========================================================================
echo           Pushing RTSS Custom Overlays to GitHub
echo           Target: https://github.com/RAM-MAHESHWARI24/rtss-custom-overlays
echo ========================================================================
echo.

git push -u origin main

if %ERRORLEVEL% NEQ 0 (
    echo.
    echo [!] Push failed or authentication is needed.
    echo.
    echo Next Steps:
    echo 1. Ensure you created the repository 'rtss-custom-overlays' on GitHub:
    echo    https://github.com/new
    echo    (Leave 'Initialize this repository with a README' UNCHECKED)
    echo 2. If prompted by Windows Git Credential Manager, sign in via browser.
    echo.
) else (
    echo.
    echo ========================================================================
    echo [✓] Successfully published to:
    echo     https://github.com/RAM-MAHESHWARI24/rtss-custom-overlays
    echo ========================================================================
)
echo.
pause
