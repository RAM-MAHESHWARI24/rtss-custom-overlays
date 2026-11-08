<#
.SYNOPSIS
    Installs custom RTSS HUD layouts, configures multi-layout in-game hotkeys,
    and enables true transparent rendering for RivaTuner Statistics Server.

.DESCRIPTION
    Interactive & automated setup script that:
    1. Auto-detects or prompts for the RTSS installation directory.
    2. Gracefully handles running RTSS instances.
    3. Creates timestamped backups of existing configuration files.
    4. Deploys custom .ovl and .ovx overlay presets.
    5. Configures in-game hotkeys (Ctrl+Shift+1, 2, 7, 8, 9, L).
    6. Optimizes global profile for seamless see-through transparency.
    7. Optionally launches/restarts RTSS.
#>

[CmdletBinding()]
param(
    [Parameter(Position=0)]
    [string]$RtssPath = "",

    [Parameter()]
    [switch]$Silent = $false,

    [Parameter()]
    [switch]$NoRestart = $false
)

$ErrorActionPreference = "Stop"

function Write-Header {
    Clear-Host
    Write-Host "========================================================================" -ForegroundColor Cyan
    Write-Host "         RivaTuner Statistics Server (RTSS) Custom HUD Suite            " -ForegroundColor White
    Write-Host "            Automated Layout Deployment & Hotkey Configurator           " -ForegroundColor Yellow
    Write-Host "========================================================================" -ForegroundColor Cyan
    Write-Host ""
}

function Find-RtssPath {
    param([string]$SuggestedPath)

    if (-not [string]::IsNullOrWhiteSpace($SuggestedPath) -and (Test-Path (Join-Path $SuggestedPath "RTSS.exe"))) {
        return (Resolve-Path $SuggestedPath).Path
    }

    # 1. Check parent directory if script is inside RTSS subfolder
    $parentCandidate = (Get-Item $PSScriptRoot).Parent.FullName
    if (Test-Path (Join-Path $parentCandidate "RTSS.exe")) {
        return (Resolve-Path $parentCandidate).Path
    }

    # 2. Check Registry
    $regPaths = @(
        "HKLM:\SOFTWARE\WOW6432Node\Micro-Star International\RivaTuner Statistics Server",
        "HKLM:\SOFTWARE\Micro-Star International\RivaTuner Statistics Server",
        "HKCU:\SOFTWARE\Unwinder\RTSS"
    )
    foreach ($reg in $regPaths) {
        if (Test-Path $reg) {
            $val = (Get-ItemProperty -Path $reg -ErrorAction SilentlyContinue).InstallPath
            if (-not [string]::IsNullOrWhiteSpace($val) -and (Test-Path (Join-Path $val "RTSS.exe"))) {
                return (Resolve-Path $val).Path
            }
        }
    }

    # 3. Check Standard Default Installation Directories
    $commonDirs = @(
        "C:\UserInstalledProgram\RivaTuner Statistics Server",
        "C:\Program Files (x86)\RivaTuner Statistics Server",
        "C:\Program Files\RivaTuner Statistics Server",
        "D:\Program Files (x86)\RivaTuner Statistics Server",
        "D:\Program Files\RivaTuner Statistics Server",
        "E:\Program Files (x86)\RivaTuner Statistics Server"
    )
    foreach ($dir in $commonDirs) {
        if (Test-Path (Join-Path $dir "RTSS.exe")) {
            return (Resolve-Path $dir).Path
        }
    }

    return $null
}

# --- Execution Entry Point ---
Write-Header

$sourceOverlaysDir = Join-Path $PSScriptRoot "overlays"
if (-not (Test-Path $sourceOverlaysDir)) {
    Write-Host "[-] Error: 'overlays' folder not found at: $sourceOverlaysDir" -ForegroundColor Red
    exit 1
}

# 1. Determine RTSS Installation Path
$detectedPath = Find-RtssPath -SuggestedPath $RtssPath
$targetPath = ""

if ($detectedPath) {
    if ($Silent) {
        $targetPath = $detectedPath
    } else {
        Write-Host "[+] Detected RTSS installation at:" -ForegroundColor Green
        Write-Host "    $detectedPath" -ForegroundColor White
        Write-Host ""
        $answer = Read-Host "Use this path? [Y/n] (or type a custom path)"
        if ([string]::IsNullOrWhiteSpace($answer) -or $answer.Trim().ToLower() -eq "y" -or $answer.Trim().ToLower() -eq "yes") {
            $targetPath = $detectedPath
        } elseif ($answer.Trim().ToLower() -ne "n") {
            if (Test-Path (Join-Path $answer "RTSS.exe")) {
                $targetPath = (Resolve-Path $answer).Path
            } else {
                Write-Host "[-] Specified path does not contain RTSS.exe. Falling back to prompt." -ForegroundColor Yellow
            }
        }
    }
}

while ([string]::IsNullOrWhiteSpace($targetPath)) {
    Write-Host ""
    $inputPath = Read-Host "Enter your RTSS installation directory (e.g. C:\Program Files (x86)\RivaTuner Statistics Server)"
    if ([string]::IsNullOrWhiteSpace($inputPath)) {
        Write-Host "[-] Path cannot be empty." -ForegroundColor Red
        continue
    }
    if (Test-Path (Join-Path $inputPath "RTSS.exe")) {
        $targetPath = (Resolve-Path $inputPath).Path
    } else {
        Write-Host "[-] RTSS.exe was not found in: $inputPath. Please check the path and retry." -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "[✓] Target RTSS Path: $targetPath" -ForegroundColor Green
Write-Host ""

# 2. Check for Running RTSS Processes
$rtssProcesses = Get-Process -Name "RTSS", "RTSSHooks64", "RTSSHooks" -ErrorAction SilentlyContinue
$wasRunning = ($rtssProcesses.Count -gt 0)

if ($wasRunning) {
    Write-Host "[!] RivaTuner Statistics Server is currently running." -ForegroundColor Yellow
    if (-not $Silent) {
        $closeChoice = Read-Host "Close RTSS now to apply files and avoid file locks? [Y/n]"
        if ([string]::IsNullOrWhiteSpace($closeChoice) -or $closeChoice.Trim().ToLower() -eq "y" -or $closeChoice.Trim().ToLower() -eq "yes") {
            Write-Host "[*] Stopping RTSS processes..." -ForegroundColor Cyan
            Stop-Process -Name "RTSS" -Force -ErrorAction SilentlyContinue
            Start-Sleep -Seconds 1
        }
    } else {
        Stop-Process -Name "RTSS" -Force -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 1
    }
}

# 3. Create Backup
$backupDirName = "Backup_CustomHUD_" + (Get-Date -Format "yyyyMMdd_HHmmss")
$backupDir = Join-Path $targetPath $backupDirName
New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
Write-Host "[+] Created configuration backup at: $backupDirName" -ForegroundColor Cyan

$cfgFiles = @(
    "Plugins\Client\HotkeyHandler.cfg",
    "Plugins\Client\OverlayEditor.cfg",
    "Profiles\Global"
)
foreach ($cfg in $cfgFiles) {
    $fullCfgPath = Join-Path $targetPath $cfg
    if (Test-Path $fullCfgPath) {
        $destBackup = Join-Path $backupDir (Split-Path $cfg -Leaf)
        Copy-Item -Path $fullCfgPath -Destination $destBackup -Force
    }
}

# 4. Deploy Overlays
$destOverlaysDir = Join-Path $targetPath "Plugins\Client\Overlays"
if (-not (Test-Path $destOverlaysDir)) {
    New-Item -ItemType Directory -Path $destOverlaysDir -Force | Out-Null
}

$overlayFiles = Get-ChildItem -Path $sourceOverlaysDir -File
Write-Host "[*] Copying $($overlayFiles.Count) custom overlay files to $destOverlaysDir..." -ForegroundColor Cyan

foreach ($f in $overlayFiles) {
    Copy-Item -Path $f.FullName -Destination (Join-Path $destOverlaysDir $f.Name) -Force
    Write-Host "    -> Installed $($f.Name)" -ForegroundColor DarkGray
}

# 5. Configure In-Game Hotkeys (HotkeyHandler.cfg)
$hotkeyCfgPath = Join-Path $targetPath "Plugins\Client\HotkeyHandler.cfg"
$hotkeyContent = @"
[Settings]
OSDToggleHotkey=00030039
LimiterToggleHotkey=0003004C
OVM1Hotkey=00030031
OVM1Desc=Hardware Dual-Tone Compact Card
OVM1Message=Load
OVM1Params=Legion-RTX3070-130FPS.ovl
OVM2Hotkey=00030032
OVM2Desc=Legion Cyber Neon Compact Card
OVM2Message=Load
OVM2Params=Neon-Circuit-Compact.ovl
OVM3Hotkey=00030038
OVM3Desc=Panoramic Transparent Top Bar
OVM3Message=Load
OVM3Params=Arctic-Edge-TopCenter.ovl
OVM4Hotkey=00030037
OVM4Desc=Panoramic Jumbo Top Bar
OVM4Message=Load
OVM4Params=Legion-TopCenter-XL.ovl
"@

$enc = [System.Text.Encoding]::GetEncoding(1252)
[System.IO.File]::WriteAllText($hotkeyCfgPath, $hotkeyContent, $enc)
Write-Host "[✓] Configured in-game hotkey profile in HotkeyHandler.cfg" -ForegroundColor Green

# 6. Set Default Active Overlay (OverlayEditor.cfg)
$overlayEditorCfgPath = Join-Path $targetPath "Plugins\Client\OverlayEditor.cfg"
$editorContent = @"
[Settings]
Layout=Arctic-Edge-TopCenter.ovl
"@
[System.IO.File]::WriteAllText($overlayEditorCfgPath, $editorContent, $enc)
Write-Host "[✓] Set active default overlay to 'Arctic-Edge-TopCenter.ovl'" -ForegroundColor Green

# 7. Optimize Global Profile for Transparent Top Bar
$globalProfilePath = Join-Path $targetPath "Profiles\Global"
if (Test-Path $globalProfilePath) {
    $globalLines = [System.IO.File]::ReadAllLines($globalProfilePath, $enc)
    $modified = $false
    $newLines = @()

    foreach ($line in $globalLines) {
        if ($line -match "^\s*EnableBgnd\s*=") {
            $newLines += "EnableBgnd = 0"
            $modified = $true
        } elseif ($line -match "^\s*EnableFill\s*=") {
            $newLines += "EnableFill = 0"
            $modified = $true
        } elseif ($line -match "^\s*EnableFrametimeHistory\s*=") {
            $newLines += "EnableFrametimeHistory = 0"
            $modified = $true
        } else {
            $newLines += $line
        }
    }

    if ($modified) {
        [System.IO.File]::WriteAllLines($globalProfilePath, $newLines, $enc)
        Write-Host "[✓] Optimized Profiles\Global (disabled legacy RTSS brown box & orange wire)" -ForegroundColor Green
    }
}

# 8. Finished Summary
Write-Host ""
Write-Host "========================================================================" -ForegroundColor Cyan
Write-Host "                     SUCCESSFULLY DEPLOYED!                             " -ForegroundColor Green
Write-Host "========================================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host " In-Game Hotkeys Ready:" -ForegroundColor Yellow
Write-Host "   Ctrl + Shift + 8  ->  Panoramic Transparent Top Bar (Flagship 4-Zone)" -ForegroundColor White
Write-Host "   Ctrl + Shift + 7  ->  Panoramic Jumbo Top Bar (Extra Large -38pt)" -ForegroundColor White
Write-Host "   Ctrl + Shift + 1  ->  Hardware Dual-Tone Compact Card" -ForegroundColor White
Write-Host "   Ctrl + Shift + 2  ->  Legion Cyber Neon Compact Card" -ForegroundColor White
Write-Host "   Ctrl + Shift + 9  ->  Toggle HUD Overlay On / Off" -ForegroundColor White
Write-Host "   Ctrl + Shift + L  ->  Toggle Framerate Limiter On / Off" -ForegroundColor White
Write-Host ""
Write-Host " Backups saved to: $backupDirName" -ForegroundColor DarkGray
Write-Host ""

# 9. Optional RTSS Restart
if (-not $NoRestart) {
    if ($Silent -and $wasRunning) {
        Start-Process (Join-Path $targetPath "RTSS.exe")
    } elseif (-not $Silent) {
        $startAnswer = Read-Host "Launch / Restart RivaTuner Statistics Server now? [Y/n]"
        if ([string]::IsNullOrWhiteSpace($startAnswer) -or $startAnswer.Trim().ToLower() -eq "y" -or $startAnswer.Trim().ToLower() -eq "yes") {
            Write-Host "[*] Launching RTSS..." -ForegroundColor Cyan
            Start-Process (Join-Path $targetPath "RTSS.exe")
        }
    }
}

Write-Host "Done! Enjoy your clean, high-performance in-game HUD." -ForegroundColor Green

