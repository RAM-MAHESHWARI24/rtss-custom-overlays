<#
.SYNOPSIS
    Quick HUD switcher and FPS cap controller CLI.
#>

[CmdletBinding()]
param(
    [Parameter(Position=0)]
    [string]$Preset = "",

    [Parameter(Position=1)]
    [string]$FpsLimit = ""
)

function Find-Rtss {
    $candidates = @(
        "c:\UserInstalledProgram\RivaTuner Statistics Server",
        "C:\Program Files (x86)\RivaTuner Statistics Server",
        "C:\Program Files\RivaTuner Statistics Server",
        (Get-Item $PSScriptRoot).Parent.FullName
    )
    foreach ($c in $candidates) {
        if (Test-Path (Join-Path $c "RTSS.exe")) {
            return (Resolve-Path $c).Path
        }
    }
    return $null
}

$rtssPath = Find-Rtss
if (-not $rtssPath) {
    Write-Host "[-] RTSS installation not detected. Run install.bat first." -ForegroundColor Red
    exit 1
}

$editorCfg = Join-Path $rtssPath "Plugins\Client\OverlayEditor.cfg"
$globalProfile = Join-Path $rtssPath "Profiles\Global"
$enc = [System.Text.Encoding]::GetEncoding(1252)

$presets = @{
    "1" = @{ Name = "Panoramic Transparent Top Bar (Flagship)"; File = "Arctic-Edge-TopCenter.ovl"; Hotkey = "Ctrl+Shift+8" }
    "2" = @{ Name = "Panoramic Jumbo Top Bar (-38pt XL)";      File = "Legion-TopCenter-XL.ovl";     Hotkey = "Ctrl+Shift+7" }
    "3" = @{ Name = "Hardware Dual-Tone Compact Card";         File = "Legion-RTX3070-130FPS.ovl";  Hotkey = "Ctrl+Shift+1" }
    "4" = @{ Name = "Legion Cyber Neon Compact Card";          File = "Neon-Circuit-Compact.ovl";   Hotkey = "Ctrl+Shift+2" }
    "5" = @{ Name = "Legion Stealth Arctic Card";              File = "Legion-Stealth-Arctic.ovl";  Hotkey = "N/A" }
    "6" = @{ Name = "Legion Tactical Amber Card";              File = "Legion-Tactical-Amber.ovl";  Hotkey = "N/A" }
}

if ([string]::IsNullOrWhiteSpace($Preset)) {
    Clear-Host
    Write-Host "========================================================================" -ForegroundColor Cyan
    Write-Host "                RTSS Custom HUD Preset Switcher CLI                     " -ForegroundColor White
    Write-Host "========================================================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host " Available Presets:" -ForegroundColor Yellow
    foreach ($k in ($presets.Keys | Sort-Object)) {
        $p = $presets[$k]
        Write-Host "   [$k] $($p.Name)  (In-game hotkey: $($p.Hotkey))" -ForegroundColor White
    }
    Write-Host ""
    $Preset = Read-Host "Select Preset [1-6]"
}

if ($presets.ContainsKey($Preset)) {
    $selected = $presets[$Preset]
    $newCfg = "[Settings]`r`nLayout=$($selected.File)`r`n"
    [System.IO.File]::WriteAllText($editorCfg, $newCfg, $enc)
    Write-Host "[✓] Activated: $($selected.Name) ($($selected.File))" -ForegroundColor Green
} else {
    Write-Host "[-] Invalid preset selection." -ForegroundColor Red
    exit 1
}

if (-not [string]::IsNullOrWhiteSpace($FpsLimit) -and (Test-Path $globalProfile)) {
    $lines = [System.IO.File]::ReadAllLines($globalProfile, $enc)
    $out = @()
    foreach ($l in $lines) {
        if ($l -match "^\s*Limit\s*=") {
            $out += "Limit = $FpsLimit"
        } else {
            $out += $l
        }
    }
    [System.IO.File]::WriteAllLines($globalProfile, $out, $enc)
    Write-Host "[✓] Global FPS Limit set to: $FpsLimit FPS" -ForegroundColor Green
}

Write-Host ""
Write-Host "Changes saved. (If game is active, press the assigned in-game hotkey to instant-refresh)." -ForegroundColor Cyan

