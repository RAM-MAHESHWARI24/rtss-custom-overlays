# 🎮 RivaTuner Statistics Server (RTSS) Modern HUD Suite

A curated suite of modern, high-framerate, see-through HUD overlays for **RivaTuner Statistics Server (RTSS)**. Engineered for high-resolution displays (1440p / 1600p / 4K) with real-time dynamic thermal throttling alerts, accurate dual-channel RAM calculation, zero clutter, and instantaneous in-game hotkey switching.

---

## ⚡ Quick Start: 1-Click Installation

1. **Download or Clone this Repository**:
   ```powershell
   git clone https://github.com/your-username/rtss-custom-overlays.git
   cd rtss-custom-overlays
   ```
2. **Run the Installer**:
   - Double-click **`install.bat`**, or run in PowerShell:
     ```powershell
     .\install.ps1
     ```
3. The script will:
   - **Auto-detect** your RTSS installation (or prompt you if installed in a custom location).
   - Create a **timestamped backup** of your existing configuration.
   - Deploy all `.ovl` and `.ovx` layouts to `RTSS\Plugins\Client\Overlays\`.
   - Configure **in-game hotkeys** in `HotkeyHandler.cfg`.
   - Set the default active overlay to the **Panoramic Transparent Top Bar**.
   - Optimize `Profiles\Global` so overlays render with 100% see-through floating transparency (no legacy brown box).

---

## ⌨️ In-Game Keyboard Shortcuts

Switch layouts seamlessly inside any DirectX 11, DirectX 12, Vulkan, or OpenGL game without opening RTSS:

| Hotkey | Layout / Action | Description |
| :--- | :--- | :--- |
| <kbd>Ctrl</kbd> + <kbd>Shift</kbd> + <kbd>8</kbd> | **Panoramic Transparent Top Bar** | **[Flagship]** Wide 4-zone floating top bar, dynamic thermal alerts, clean telemetry. |
| <kbd>Ctrl</kbd> + <kbd>Shift</kbd> + <kbd>7</kbd> | **Panoramic Jumbo Top Bar** | Extra-large -38pt variant for high-DPI displays or couch gaming. |
| <kbd>Ctrl</kbd> + <kbd>Shift</kbd> + <kbd>1</kbd> | **Hardware Dual-Tone Card** | High-density top-left card with GPU/CPU split cards. |
| <kbd>Ctrl</kbd> + <kbd>Shift</kbd> + <kbd>2</kbd> | **Legion Cyber Neon Card** | Top-left cyber-neon card with emerald & cyan accents. |
| <kbd>Ctrl</kbd> + <kbd>Shift</kbd> + <kbd>9</kbd> | **Toggle HUD On / Off** | Instant hide/show HUD toggle. |
| <kbd>Ctrl</kbd> + <kbd>Shift</kbd> + <kbd>L</kbd> | **Toggle Framerate Limiter** | Enable/disable the 130 FPS (or custom) cap on the fly. |

---

## 🖥️ Layout Showcase

### 1. 🌟 Panoramic Transparent Top Bar (`Arctic-Edge-TopCenter.ovl`)
*Default active layout. Mapped to <kbd>Ctrl</kbd> + <kbd>Shift</kbd> + <kbd>8</kbd>.*

```text
 128 FPS  1%L 94 FPS |  RTX 3070  64°C  52%  |  6800H  76°C  31%  |  VRAM 3.8 / 8.0 GB (47%)
 AVG 127  0.1%L 81   |  POWER     128W       |  POWER  38W        |  RAM  11.2 / 32.0 GB (35%)
```
- **100% See-Through**: Floating DirectX-rasterized text with 3D drop-shadow / outline compensation.
- **Symmetrical 4-Zone Matrix**:
  - **Zone 1 (FPS)**: Real-time framerate, 1% Low, Average FPS, and 0.1% Low.
  - **Zone 2 (GPU)**: Model name, temperature with color warning, usage %, and power draw in Watts.
  - **Zone 3 (CPU)**: Processor model, temperature with color warning, usage %, and power draw in Watts.
  - **Zone 4 (Memory)**: Physical VRAM usage + capacity, System RAM usage + capacity with exact % used.
- **Dynamic Thermal Throttling Color Alerts**:
  - **GPU**: 🟢 `<75°C` (Cool) &nbsp;|&nbsp; 🟡 `75–84°C` (Warm) &nbsp;|&nbsp; 🔴 `≥85°C` (Thermal Throttle Warning)
  - **CPU**: 🔵 `<80°C` (Cool) &nbsp;|&nbsp; 🟡 `80–89°C` (Warm) &nbsp;|&nbsp; 🔴 `≥90°C` (Thermal Throttle Warning)
- **Zero Clutter**: Redundant latency (ms) and core/memory MHz clocks removed.

---

### 2. 🔠 Panoramic Jumbo Top Bar (`Legion-TopCenter-XL.ovl`)
*Mapped to <kbd>Ctrl</kbd> + <kbd>Shift</kbd> + <kbd>7</kbd>.*
- Same streamlined 4-zone layout, rendered in jumbo **-38pt bold** for maximum legibility on 2560×1440, 2560×1600, or 4K displays.

---

### 3. 🛡️ Hardware Dual-Tone Compact Card (`Legion-RTX3070-130FPS.ovl`)
*Mapped to <kbd>Ctrl</kbd> + <kbd>Shift</kbd> + <kbd>1</kbd>.*
- High-density cyber glass card anchored to the top-left screen corner.
- Full breakdown including framerate pacing, GPU stats, CPU package power, and memory footprints.

---

### 4. ⚡ Legion Cyber Neon Card (`Neon-Circuit-Compact.ovl`)
*Mapped to <kbd>Ctrl</kbd> + <kbd>Shift</kbd> + <kbd>2</kbd>.*
- High-contrast electric emerald and cyber cyan palette.

---

## 🛠️ CLI Preset Switcher (`switch-hud.bat`)

If you prefer switching layouts via script, desktop shortcut, or terminal:

```powershell
# Interactive menu:
.\switch-hud.ps1

# Switch to Panoramic Top Bar:
.\switch-hud.ps1 1

# Switch to Jumbo Top Bar and set global FPS limit to 144:
.\switch-hud.ps1 2 144
```

---

## 📖 Deep Customization & Architecture Manual

Looking to build your own custom layout, understand RTSS hypertext syntax, or teach an AI coding agent how to build RTSS overlays?

Check out **[`CUSTOM_HUD_GUIDE.md`](CUSTOM_HUD_GUIDE.md)** in this repository:
- Complete RTSS tag reference (`<P>`, `<E>`, `<C=...>`, `<G=...>`).
- Screen centering math and extent calculations.
- Dynamic color formula reference.
- Detailed root cause analysis of historical RTSS bugs (legacy brown box, solid cyan graph bug, zoom slider overrides).
- Instructions for modifying hardware models (Intel/AMD/NVIDIA), TDP limits, and RAM sizes.

---

## 🔧 30-Second Hardware Portability Guide

If you are using this suite on a different PC or laptop:

1. Open `overlays\Arctic-Edge-TopCenter.ovl` in any text editor.
2. Search and replace:
   - `RTX 3070` ➔ Your GPU (e.g. `RTX 4080`, `RX 7800 XT`).
   - `8.0 GB` ➔ Your GPU VRAM capacity.
   - `6800H` ➔ Your CPU (e.g. `13700H`, `7800X3D`).
   - `32.0 GB` ➔ Your physical system RAM capacity (e.g. `16.0 GB`, `64.0 GB`).
3. Re-run `install.bat` to deploy the modified profile.

---

## 📜 License
MIT License. Free for personal, non-commercial, and commercial gaming setups.
