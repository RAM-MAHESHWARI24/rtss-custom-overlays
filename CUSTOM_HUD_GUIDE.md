# RivaTuner Statistics Server (RTSS) Custom HUD Architecture & Engineering Manual
> **Author**: Antigravity Pair-Programming Suite  
> **Target Audience**: Human Engineers & Autonomous AI Agents  
> **Environment**: Windows 11 / RTSS 7.3.x+ / DirectX 11 & 12, Vulkan, OpenGL  
> **Primary Reference Project**: Lenovo Legion (Ryzen 7 6800H + NVIDIA RTX 3070 Laptop GPU, 32GB RAM, 2560×1600 Display)

---

## Table of Contents
1. [System Architecture & Ecosystem](#1-system-architecture--ecosystem)
2. [File Formats: `.ovl` vs `.ovx`](#2-file-formats-ovl-vs-ovx)
3. [Deep-Dive: RTSS Hypertext Engine & Tag Specification](#3-deep-dive-rtss-hypertext-engine--tag-specification)
   - [3.1 Font Rasterization & Sizing](#31-font-rasterization--sizing)
   - [3.2 The Screen Centering & Anchor System](#32-the-screen-centering--anchor-system)
   - [3.3 Dynamic Color-Coding Engine](#33-dynamic-color-coding-engine)
   - [3.4 Real-Time Frametime & Oscilloscope Graphs](#34-real-time-frametime--oscilloscope-graphs)
   - [3.5 Native Telemetry Macros & HAL Data Sources](#35-native-telemetry-macros--hal-data-sources)
4. [Critical Pitfalls & Root Cause Solutions](#4-critical-pitfalls--root-cause-solutions)
   - [The Legacy Brown Box & Orange Wire Bug](#41-the-legacy-brown-box--orange-wire-bug)
   - [The "Zoom Slider Ignored" Mystery](#42-the-zoom-slider-ignored-mystery)
   - [Why Overlays Fly Off-Screen When Scaled](#43-why-overlays-fly-off-screen-when-scaled)
   - [The "Solid Cyan Progress Bar" Graph Error](#44-the-solid-cyan-progress-bar-graph-error)
   - [True 100% See-Through Floating Transparency](#45-true-100-see-through-floating-transparency)
   - [Dynamic RAM vs Hardcoded Capacity](#46-dynamic-ram-vs-hardcoded-capacity)
5. [The Standard Engineering Templates](#5-the-standard-engineering-templates)
   - [Template A: Panoramic Transparent Top-Center Bar](#51-template-a-panoramic-transparent-top-center-bar)
   - [Template B: Compact High-Density Cyber Glass Card](#52-template-b-compact-high-density-cyber-glass-card)
6. [Compilation, Hotkeys & Preset Management](#6-compilation-hotkeys--preset-management)
   - [Compiling `.ovl` and `.ovx` via PowerShell](#61-compiling-ovl-and-ovx-via-powershell)
   - [In-Game Hotkey Configuration (`HotkeyHandler.cfg`)](#62-in-game-hotkey-configuration-hotkeyhandlercfg)
   - [The 1-Click Interactive Switcher CLI](#63-the-1-click-interactive-switcher-cli)

---

## 1. System Architecture & Ecosystem

RTSS does not use standard Windows desktop presentation (WPF, Electron, or WinForms) for its in-game HUD. Instead, it hooks the game engine's graphics rendering pipeline (DirectX 9–12, Vulkan, OpenGL) and injects a custom rasterized 3D surface into the active swapchain immediately before presentation.

```text
┌────────────────────────────────────────────────────────┐
│              Game Render Pipeline (3D Engine)          │
└──────────────────────────┬─────────────────────────────┘
                           │ Presents Frame
                           ▼
┌────────────────────────────────────────────────────────┐
│                   RTSS Graphics Hook                   │
│  - Captures swapchain backbuffer                       │
│  - Evaluates Shared Memory & Active Profiles           │
│  - Profiles\Global: Disables legacy box & wire layers │
└──────────────────────────┬─────────────────────────────┘
                           │
             ┌─────────────┴─────────────┐
             ▼                           ▼
┌─────────────────────────┐ ┌────────────────────────────┐
│   OverlayEditor.dll     │ │    HotkeyHandler.dll       │
│  - Parses .ovl text     │ │  - Listens for raw input   │
│  - Queries HAL sensors  │ │  - Swaps active layout     │
│  - Emits raster stream  │ │  - Toggles limiter/OSD     │
└─────────────────────────┘ └────────────────────────────┘
```

### Core Configuration Files & Directories
- **`Profiles\Global`**: Core engine configuration. Controls base colors, framerate limits, frame pacing, and legacy background boxes.
- **`Plugins\Client\OverlayEditor.cfg`**: Contains a single pointer determining which `.ovl` layout file is actively rendered:
  ```ini
  [Settings]
  Layout=Arctic-Edge-TopCenter.ovl
  ```
- **`Plugins\Client\HotkeyHandler.cfg`**: Configures the 4 direct hardware overlay switching hotkeys, OSD toggle, and framerate limiter toggle.
- **`Plugins\Client\Overlays\`**: Directory holding user `.ovl` plaintext layout files.

---

## 2. File Formats: `.ovl` vs `.ovx`

RTSS supports two overlay file extensions:

### `.ovl` (Overlay Plaintext Layout)
- **Format**: Standard INI format encoded strictly in **Windows-1252 (ANSI)**.
- **Encoding Note**: UTF-8 with BOM or UTF-16 will cause RTSS font parser failures or broken degree characters (`°` becomes `Â°`). Always save with Windows-1252 encoding.
- **Structure**:
  - `[Master]`: Defines global font face, height, weight, and zoom behavior.
  - `[Settings]`: Profile name, refresh period, and user setting locks.
  - `[General]`: Total counts of data sources, tables, and layers.
  - `[Source0..N]`: Internal HAL telemetry providers (temps, clocks, usage, power).
  - `[Layer0..N]`: Visual display layers containing formatted hypertext strings.

### `.ovx` (Compressed RTSS Array Container)
- **Format**: Binary CSZArray container starting with the 4-byte magic signature `0x535A4130` (`SZA0`).
- **Use Case**: Used by RTSS internal preset engines and profile packs for one-click installation.
- **Binary Header Structure**:
  ```text
  Offset 0x00 - 0x03 : 0x535A4130 (Magic Signature 'SZA0')
  Offset 0x04 - 0x07 : uint32 dwTotalSize (12 + 8 + dwEntrySize)
  Offset 0x08 - 0x0B : uint32 dwNumEntries (Always 1 for single overlay)
  Offset 0x0C - 0x0F : uint32 dwEntrySize (dwSizeData + strlen(Name) + 1)
  Offset 0x10 - 0x13 : uint32 dwSizeData (Byte length of .ovl content)
  Offset 0x14 - EOF  : [.ovl byte data] followed by [ASCII null-terminated filename]
  ```

---

## 3. Deep-Dive: RTSS Hypertext Engine & Tag Specification

RTSS renders text and embedded telemetry through a specialized tag-based hypertext language. Tags are enclosed within angle brackets `<...>`.

### 3.1 Font Rasterization & Sizing

In `[Master]`, font parameters define how RTSS generates its DirectX texture atlas:

```ini
[Master]
Implementation=2
FontFace=Bahnschrift
FontHeight=-32
FontWeight=700
ZoomRatio=1
```

- **`Implementation=2`**: Strictly enables **Raster3D** mode (DirectX texture-mapped fonts with anti-aliasing). `Implementation=1` is legacy GDI rasterizer (slow, pixelated).
- **`FontFace`**: Font family installed in Windows (`Bahnschrift` is recommended for gaming HUDs: condensed, geometric, high readability at quick glance).
- **`FontHeight`**: Height in pixels. Negative values represent logical character point height matching GDI `CreateFont` semantics:
  - `-14` to `-16`: Microscopic / stock (illegible on 2560×1600 or 4K laptop displays).
  - `-28` to `-32`: **Optimal High-Res Gaming HUD** (prominent, bold, readable without squinting).
  - `-38` to `-42`: **Jumbo Edition** (maximum glance visibility from a distance).
- **`FontWeight`**: `400` = Regular, `600` = Semi-Bold, `700` = **Bold**.
- **Relative In-Line Sizing (`<S>` Tag)**:
  - `<S=120>`: Scales subsequent text to **120%** of master font size.
  - `<S=-75>`: Scales subsequent text to **75%** of master font size.
  - `<S>`: Resets scaling back to master default.
  - *Example*: `<S=120><FR><S><S=-75> FPS<S>` renders `130` in large bold text and `FPS` in smaller subscript.

---

### 3.2 The Screen Centering & Anchor System

Older RTSS overlays used fixed character cell offsets (`PositionX = -118`, `PositionY = 0`). This breaks when users change resolutions or UI zoom: doubling zoom doubles the pixel offset, throwing the HUD completely off-screen.

To build an overlay that is mathematically locked to the screen center, use **Sticky Positions** and **Extent Origins**.

#### The Sticky Position Matrix (`<P>` Tag)
Sticky positions calculate anchor coordinates directly from the GPU backbuffer dimensions:

| Sticky ID | Screen Anchor Point | GPU Formula |
|:---:|:---:|:---:|
| `<P0>` | Top-Left | `(0, 0)` |
| **`<P1>`** | **Top-Center** | **`(ScreenWidth / 2, 0)`** |
| `<P2>` | Top-Right | `(ScreenWidth, 0)` |
| `<P3>` | Middle-Left | `(0, ScreenHeight / 2)` |
| `<P4>` | Dead-Center | `(ScreenWidth / 2, ScreenHeight / 2)` |
| `<P5>` | Middle-Right | `(ScreenWidth, ScreenHeight / 2)` |
| `<P6>` | Bottom-Left | `(0, ScreenHeight)` |
| `<P7>` | Bottom-Center | `(ScreenWidth / 2, ScreenHeight)` |
| `<P8>` | Bottom-Right | `(ScreenWidth, ScreenHeight)` |

#### The Extent Origin Matrix (`<E>` Tag)
When defining layer bounds via `ExtentX` (width) and `ExtentY` (height), `ExtentOrigin` specifies which point on the HUD box is pinned to the anchor:

```text
0 (Top-Left)    ──  1 (Top-Center)    ──  2 (Top-Right)
      │                     │                   │
3 (Mid-Left)    ──  4 (Dead-Center)   ──  5 (Mid-Right)
      │                     │                   │
6 (Bottom-Left) ──  7 (Bottom-Center) ──  8 (Bottom-Right)
```

#### The Formula for Flawless Top-Center HUDs
In the layer configuration:
```ini
PositionSticky=1
ExtentX=-120
ExtentY=-2
ExtentOrigin=1
FixedAlignment=1
```
1. `PositionSticky = 1` locks the anchor to `(ScreenWidth / 2, 0)`.
2. `ExtentOrigin = 1` pins the **top-center of the HUD box** to that anchor.
3. As the HUD box expands or contracts, it expands symmetrically outward to the left and right.
4. **Result**: The HUD will **never** fly off-screen, regardless of resolution (1080p, 1440p, 1600p, 4K) or display scaling.

---

### 3.3 Dynamic Color-Coding Engine

RTSS supports both static hex colors and dynamic, sensor-driven color switching:

#### Static Colors
- Syntax: `<C=RRGGBB>` or `<C=AARRGGBB>`
- Reset: `<C>` restores the default layer color.
- *Recommended Cyber Palette*:
  - Electric Cyan: `<C=00E5FF>` (Primary Framerate)
  - Vivid Lime: `<C=88FF20>` (1% Low / Smoothness)
  - NVIDIA Emerald: `<C=76E000>` (GPU Telemetry)
  - Intel/Ryzen Azure: `<C=20B8FF>` (CPU Telemetry)
  - Ice White: `<C=F0F8FF>` (Frametime / Numbers)
  - Muted Platinum: `<C=B8D4E8>` (Secondary Labels)
  - Subtle Glass Dividers: `<C=60A0D0FF>│<C>` (Translucent Divider)

#### Dynamic Color Ranges
Colors can automatically transition based on live hardware thresholds.

**Syntax**:
```text
<C=COLOR1,,MAX1,COLOR2,MIN2,MAX2,COLOR3,MIN3,(DATA_SOURCE,FLAGS)>
```

**Production Implementation for GPU Temperature**:
- Normal: `< 75°C` -> Neon Green (`76E000`)
- High Load: `75°C – 84°C` -> Amber Yellow (`FFB800`)
- Throttle Warning: `≥ 85°C` (NVIDIA 86°C Limit) -> Warning Red (`FF2A2A`)
```text
<C=76E000,,75,FFB800,75,85,FF2A2A,85,(GPU1 temperature,0)>%GPU1 temperature%°C<C>
```

**Production Implementation for CPU Temperature**:
- Normal: `< 80°C` -> Electric Cyan (`20B8FF`)
- High Load: `80°C – 89°C` -> Amber Yellow (`FFB800`)
- Throttle Warning: `≥ 90°C` (AMD 95°C Limit) -> Warning Red (`FF2A2A`)
```text
<C=20B8FF,,80,FFB800,80,90,FF2A2A,90,(CPU temperature,0)>%CPU temperature%°C<C>
```

---

### 3.4 Real-Time Frametime & Oscilloscope Graphs

Live pacing graphs are embedded directly into text strings using the `<G>` tag:

```text
<G=Source,Width,Height,Margin,Min,Max,Flags>
```

#### Parameter Breakdown
- **`Source`**: Internal data source (`Frametime`, `Framerate`, etc.).
- **`Width`**: 
  - Positive integer = Width in pixels.
  - Negative integer (e.g. `-14`) = **Width in character cells**.
- **`Height`**:
  - Positive integer = Height in pixels.
  - Negative integer (e.g. `-1` or `-2`) = **Height in text rows**.
- **`Margin`**: Padding in pixels (typically `0` or `1`).
- **`Min` / `Max`**: Graph scale floor and ceiling in milliseconds:
  - For frametime at 130 FPS (target 7.7 ms), setting `Min=0` and `Max=33` (30 FPS boundary) ensures normal frame pacing stays in the lower quarter of the graph, making spikes immediately visible.
- **`Flags` (Bitmask)**:
  - `0x00` (`0`): **Thin Line Waveform** (1-pixel oscilloscope line; clean, zero distortion).
  - `0x01` (`1`): **Filled Graph** (Fills area below line with solid color; *Caution*: in multi-row text this renders as a thick solid bar).
  - `0x10` (`16`): Draw background grid.

**Clean Waveform Trace Tag**:
```text
<C=00E5FF><G=Frametime,-12,-1,0,0,33,0><C>
```

---

### 3.5 Native Telemetry Macros & HAL Data Sources

#### Built-in RTSS Engine Macros
- `<FR>`: Instantaneous framerate (FPS).
- `<FR10L>`: **1.0% Low Framerate** (Critical stutter / frame pacing indicator).
- `<FR01L>`: **0.1% Low Framerate** (Micro-stutter / sudden hitch indicator).
- `<FRAVG>`: Session average framerate.
- `<FT>`: Instantaneous frametime in milliseconds ($1000 \div \text{FPS}$).
- `<FTM>`: Peak frametime in milliseconds.

#### Hardware Abstraction Layer (HAL) Sources
Configured in `[Source0..N]` sections. HAL sources poll hardware sensors directly without requiring third-party monitoring software:

```ini
[Source0]
Name=CPU temperature
Units=°C
Format=%.0f
Formula=
Provider=HAL
ID=CPU temperature

[Source4]
Name=RAM usage
Units=GB
Format=%.1f
Formula=x/1024
Provider=HAL
ID=RAM usage

[Source7]
Name=GPU1 temperature
Units=°C
Format=%.0f
Formula=
Provider=HAL
ID=GPU1 temperature

[Source10]
Name=GPU1 power
Units=W
Format=%.0f
Formula=
Provider=HAL
ID=GPU1 power
```

---

## 4. Critical Pitfalls & Root Cause Solutions

### 4.1 The Legacy Brown Box & Orange Wire Bug
- **Symptom**: An ugly brown box with an orange wire graph appears across the screen behind custom HUDs.
- **Root Cause**: Default RTSS profiles enable legacy overlay elements in `Profiles\Global`.
- **Solution**: Edit [`Profiles\Global`](file:///c:/UserInstalledProgram/RivaTuner%20Statistics%20Server/Profiles/Global) and set:
  ```ini
  EnableBgnd = 0
  EnableFill = 0
  EnableFrametimeHistory = 0
  BaseColor = 00FFFFFF
  ```

### 4.2 The "Zoom Slider Ignored" Mystery
- **Symptom**: Adjusting the "On-Screen Display zoom" slider in the RTSS GUI does not change the HUD size.
- **Root Cause**: In `[Settings]`, `LockUserSettings=1` instructs RTSS to hardcode `<FNT=Bahnschrift,-32,700,1>` into the render stream. This intentionally overrides the GUI slider to preserve layout proportions.
- **Solution**: Set the native `FontHeight` directly in `[Master]` (`-32` for large, `-38` for jumbo) rather than relying on GDI zoom scaling.

### 4.3 Why Overlays Fly Off-Screen When Scaled
- **Symptom**: When DPI scaling or zoom is applied, the HUD shifts completely off the right or left edge of the display.
- **Root Cause**: Using fixed character-column offsets (`PositionX = -118`). At $2\times$ zoom, 118 character cells equal 4,000+ pixels, blowing past 2560px screen boundaries.
- **Solution**: Use `PositionSticky = 1` and `ExtentOrigin = 1`. The GPU backbuffer anchors the center point natively.

### 4.4 The "Solid Cyan Progress Bar" Graph Error
- **Symptom**: The frametime graph renders as a thick, solid block of cyan, misaligning adjacent text lines.
- **Root Cause**: Specifying `Height = -2` inside line 1 of a multi-row string with `Flags = 1` (FILLED). The filled area draws a solid rectangle down across line 2.
- **Solution**: Use `Height = -1` and `Flags = 0` (Line waveform only), or omit the graph for a minimalist, ultra-clean numerical HUD.

### 4.5 True 100% See-Through Floating Transparency
- **Symptom**: A dark tinted rectangle or box surrounds the text, blocking the game view.
- **Root Cause**: Having a background layer (`Layer0`) with `BgndColor = D80A0E18`.
- **Solution**: Remove the background layer entirely or omit `BgndColor` and `BorderColor`. RTSS automatically applies its DirectX 3D outline compensation around font glyphs (`Profiles\Global` -> `OutlineCompensation = 1`, `OutlineFactor = 240`), making text perfectly legible over any bright or dark game background with zero obstruction.

### 4.6 Dynamic RAM vs Hardcoded Capacity
- **Symptom**: RAM usage is displayed as `RAM 12.1 / 16GB (39% USED)`.
- **Root Cause**: The layout had `/16GB` hardcoded in the text string, while the laptop actually had 32GB RAM installed ($12.1 \div 32 = 38\%$).
- **Solution**: Format memory as `RAM %RAM usage% / 32.0 GB (%RAM usage percent%%)` so that capacity and usage percentages match physically and mathematically.

---

## 5. The Standard Engineering Templates

### 5.1 Template A: Panoramic Transparent Top-Center Bar
The flagship layout: 100% see-through floating text, 4 symmetrical telemetry zones, dynamic thermal colors, and no MHz clutter.

```ini
[Master]
Implementation=2
FontFace=Bahnschrift
FontHeight=-32
FontWeight=700
ZoomRatio=1
[Settings]
Name=Panoramic Streamlined Bar (-32pt)
RefreshPeriod=500
LockUserSettings=1
EmbeddedImage=
PingAddr=
[General]
Sources=15
Tables=0
Layers=2

[Source0]
Name=CPU temperature
Units=°C
Format=%.0f
Provider=HAL
ID=CPU temperature
[Source1]
Name=CPU usage
Units=%
Format=%.0f
Provider=HAL
ID=CPU usage
[Source3]
Name=CPU power
Units=W
Format=%.0f
Provider=HAL
ID=CPU power
[Source4]
Name=RAM usage
Units=GB
Format=%.1f
Formula=x/1024
Provider=HAL
ID=RAM usage
[Source5]
Name=RAM usage percent
Units=%
Format=%.0f
Provider=HAL
ID=RAM usage percent
[Source7]
Name=GPU1 temperature
Units=°C
Format=%.0f
Provider=HAL
ID=GPU1 temperature
[Source8]
Name=GPU1 usage
Units=%
Format=%.0f
Provider=HAL
ID=GPU1 usage
[Source10]
Name=GPU1 power
Units=W
Format=%.0f
Provider=HAL
ID=GPU1 power
[Source12]
Name=GPU1 memory usage
Units=GB
Format=%.1f
Formula=x/1024
Provider=HAL
ID=GPU1 memory usage
[Source14]
Name=GPU1 memory usage percent
Units=%
Format=%.0f
Provider=HAL
ID=GPU1 memory usage percent

[Layer0]
Name=Panoramic Transparent Telemetry
Text=<C=00E5FF><S=120><FR><S><S=-75> FPS<S><C>  <C=88FF20>1%L <FR10L><S=-75> FPS<S><C>  <C=60A0D0FF>│<C>  <C=76E000>RTX 3070<C>  <C=76E000,,75,FFB800,75,85,FF2A2A,85,(GPU1 temperature,0)>%GPU1 temperature%°C<C>  <C=76E000>%GPU1 usage%<S=-75>%<S><C>  <C=60A0D0FF>│<C>  <C=20B8FF>RYZEN 7<C>   <C=20B8FF,,80,FFB800,80,90,FF2A2A,90,(CPU temperature,0)>%CPU temperature%°C<C>  <C=20B8FF>%CPU usage%<S=-75>%<S><C>  <C=60A0D0FF>│<C>  <C=76E000>VRAM  %GPU1 memory usage% / 8.0 GB (%GPU1 memory usage percent%<S=-75>%<S>)<C>\n<C=20B8FF>AVG <FRAVG><S=-75> FPS<S><C>  <C=88FF20>0.1%L <FR01L><S=-75> FPS<S><C>  <C=60A0D0FF>│<C>  <C=70A0C0>GPU PWR<C>   <C=B8D4E8>%GPU1 power%W<C>        <C=60A0D0FF>│<C>  <C=70A0C0>CPU PWR<C>   <C=B8D4E8>%CPU power%W<C>        <C=60A0D0FF>│<C>  <C=20B8FF>RAM  %RAM usage% / 32.0 GB (%RAM usage percent%<S=-75>%<S>)<C>
PositionSticky=1
ExtentX=-116
ExtentY=-2
ExtentOrigin=1
FixedAlignment=1

[Layer1]
Name=Cursor Placeholder
Text=" \b"
PositionSticky=1
ExtentX=0
ExtentY=0
ExtentOrigin=0
```

---

## 6. Compilation, Hotkeys & Preset Management

### 6.1 Compiling `.ovl` and `.ovx` via PowerShell
To generate production-ready `.ovl` and `.ovx` files programmatically, use this verified script snippet:

```powershell
$win1252 = [System.Text.Encoding]::GetEncoding(1252)

function Build-RTSSOverlay {
    param(
        [string]$BasePath,
        [string]$BaseName,
        [string]$IniContent
    )
    $normalized = ($IniContent -replace "`r`n", "`n") -replace "`n", "`r`n"
    if (-not $normalized.EndsWith("`r`n")) { $normalized += "`r`n" }
    $ovlBytes = $win1252.GetBytes($normalized)

    # Write .ovl
    $ovlPath = Join-Path $BasePath "$BaseName.ovl"
    [System.IO.File]::WriteAllBytes($ovlPath, $ovlBytes)

    # Write SZA0 .ovx container
    $entryNameBytes = [System.Text.Encoding]::ASCII.GetBytes("$BaseName.ovl`0")
    $dwSizeData = [uint32]$ovlBytes.Length
    $dwEntrySize = [uint32]($dwSizeData + $entryNameBytes.Length)
    $dwTotalSize = [uint32](12 + 8 + $dwEntrySize)
    $dwSign = [uint32]0x535A4130
    $dwNumEntries = [uint32]1

    $ms = New-Object System.IO.MemoryStream
    $bw = New-Object System.IO.BinaryWriter($ms)
    $bw.Write($dwSign)
    $bw.Write($dwTotalSize)
    $bw.Write($dwNumEntries)
    $bw.Write($dwEntrySize)
    $bw.Write($dwSizeData)
    $bw.Write($ovlBytes)
    $bw.Write($entryNameBytes)
    $bw.Flush()

    $ovxPath = Join-Path $BasePath "$BaseName.ovx"
    [System.IO.File]::WriteAllBytes($ovxPath, $ms.ToArray())
    $bw.Close(); $ms.Close()
}
```

---

### 6.2 In-Game Hotkey Configuration (`HotkeyHandler.cfg`)
RTSS's `HotkeyHandler` plugin provides 4 dedicated overlay modifier slots (`OVM1`–`OVM4`):

```ini
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
OVM4Desc=Panoramic Waveform Top Bar
OVM4Message=Load
OVM4Params=Legion-TopCenter-XL.ovl
```

#### Hotkey Hex Encoding Table
Hotkeys are 32-bit hex words: `0xMMMMKKKK` where `MMMM` is the modifier mask and `KKKK` is the Windows Virtual-Key code.
- `Ctrl + Shift` = `0x0003`
- `Key 1` = `0x0031` -> `00030031`
- `Key 2` = `0x0032` -> `00030032`
- `Key 7` = `0x0037` -> `00030037`
- `Key 8` = `0x0038` -> `00030038`
- `Key 9` = `0x0039` -> `00030039`
- `Key L` = `0x004C` -> `0003004C`

---

### 6.3 The 1-Click Interactive Switcher CLI

To allow humans and scripts to switch layouts on the fly without touching GUI menus, run:

```bat
c:\UserInstalledProgram\RivaTuner Statistics Server\Profiles\fpscap-presets\Switch-HUD.bat
```

Or pass preset parameters directly from the terminal:
```powershell
# Activate Flagship Transparent Top Bar
.\Switch-HUD.ps1 1

# Activate Jumbo -38pt Edition
.\Switch-HUD.ps1 2

# Activate Dual-Tone Compact Card
.\Switch-HUD.ps1 3
```

---

## 7. Quick Customization Checklist for Other Machines

When tailoring this HUD for another PC or laptop, update these specific values:

1. **GPU Name & Memory Capacity**:
   - Replace `RTX 3070` with target GPU model (e.g. `RTX 4080`, `Radeon 7900M`).
   - Change `8.0 GB` to physical VRAM size.
2. **GPU Thermal Throttle Threshold**:
   - NVIDIA Mobile Ampere/Ada: Keep `85°C` throttle threshold.
   - Desktop GPUs: Set warning threshold to `78°C – 82°C`.
3. **CPU Name & Thermal Throttle Threshold**:
   - Replace `RYZEN 7` with `i7-13700H`, `RYZEN 9`, etc.
   - Change throttle warning color threshold to match CPU TjMax (Intel laptops: `95°C`, AMD Zen 4: `95°C`, AMD Zen 3: `90°C`).
4. **Physical RAM Capacity**:
   - Replace `32.0 GB` with system total (`16.0 GB`, `64.0 GB`).
5. **Display Width & Font Scaling**:
   - For 1080p: Use `FontHeight = -24` and `ExtentX = -100`.
   - For 1440p / 1600p: Use `FontHeight = -32` and `ExtentX = -116`.
   - For 4K: Use `FontHeight = -42` and `ExtentX = -124`.
