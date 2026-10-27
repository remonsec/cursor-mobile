<div align="center">

<h1>📱 cursor-mobile</h1>

<p><strong>Run Cursor IDE on Android — inside Termux</strong></p>

<p>
  <img alt="Platform" src="https://img.shields.io/badge/platform-Android%20ARM64-green?logo=android">
  <img alt="Shell" src="https://img.shields.io/badge/shell-Bash-blue?logo=gnubash">
  <img alt="License" src="https://img.shields.io/badge/license-MIT-blue">
  <img alt="Author" src="https://img.shields.io/badge/author-remonsec-orange">
</p>

<p>
  <a href="#-quick-start">Quick Start</a> •
  <a href="#-installation-modes">Modes</a> •
  <a href="#-requirements">Requirements</a> •
  <a href="#-how-it-works">How it Works</a> •
  <a href="#-troubleshooting">Troubleshooting</a>
</p>

</div>

---

> [!NOTE]
> Cursor's binaries are compiled for glibc + Linux. This installer handles Android compatibility automatically — installing the Termux glibc layer and creating native launchers. **No root required.**

---

## 📋 Requirements

| Requirement | Details |
|---|---|
| **Device** | Android 7+ (ARM64 / aarch64) |
| **App** | [Termux](https://f-droid.org/packages/com.termux/) from **F-Droid** (not Play Store) |
| **RAM** | ≥ 3 GB recommended (4 GB+ with zRAM ideal) |
| **Storage** | ≥ 4 GB free internal storage |
| **Network** | Required for first-time download |
| **GUI only** | [Termux:X11](https://github.com/termux/termux-x11/releases) APK installed |

> [!IMPORTANT]
> Use the **F-Droid** version of Termux. The Play Store version is outdated and will break package installs.

---

## ⚡ Quick Start

```bash
pkg update && pkg install -y wget
wget https://raw.githubusercontent.com/remonsec/cursor-mobile/main/install.sh
bash install.sh
```

One-liner:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/remonsec/cursor-mobile/main/install.sh)
```

---

## 🎛 Installation Modes

### Mode 1 — Full GUI

Installs Cursor IDE with full graphical interface via `proot-distro` (Ubuntu 24.04 arm64) + Termux:X11.

```
[Termux:X11 APK] ←─ display ──→ [proot Ubuntu] ←─ runs ──→ [Cursor AppImage]
                                       ↑
                              [ $PREFIX/bin/cursor wrapper ]
```

**After install:**
1. Open the **Termux:X11** app on your device
2. In Termux, run: `cursor`
3. Sign in with your Cursor account

### Mode 2 — CLI / Agent

Installs the **official Cursor Agent CLI** directly in Termux — no GUI, no proot.
Ideal for headless workflows, SSH sessions, or AI agent pipelines.

```bash
cursor login          # authenticate
cursor                # start the agent
agent                 # alias
```

---

## 🔧 How it Works

```
install.sh
 ├─ [Mode 1 — GUI]
 │   ├─ pkg install proot-distro wget curl pulseaudio glibc
 │   ├─ proot-distro install ubuntu     ← Ubuntu 24.04 LTS arm64 rootfs
 │   ├─ apt install <GUI deps>          ← GTK3, NSS, X11 libs, etc.
 │   ├─ wget cursor.AppImage (arm64)    ← Official Cursor Linux arm64 build
 │   ├─ AppImage --appimage-extract     ← Extract without FUSE (unavailable on Android)
 │   └─ $PREFIX/bin/cursor              ← Launch wrapper via proot + PulseAudio
 │
 └─ [Mode 2 — CLI]
     ├─ pkg install glibc               ← glibc layer for linux-arm64 ELF binaries
     ├─ curl cursor.com/install | bash  ← Official installer, detects linux/arm64
     ├─ shebang patched in wrapper      ← /usr/bin/env → $PREFIX/bin/env
     └─ $PREFIX/bin/cursor|agent        ← Launchers invoke bundled node via glibc linker
```

### Why glibc is needed

Cursor's binaries — including the bundled Node.js in CLI mode — are compiled for glibc (`ld-linux-aarch64.so.1`). Termux uses Android's bionic libc, which cannot execute these binaries directly. The [Termux glibc package](https://github.com/termux/termux-packages/tree/master/packages/glibc) provides the required dynamic linker. The launchers installed by this script handle the invocation transparently.

---

## 🖥 GUI Setup (Termux:X11)

1. **Download** Termux:X11 APK from [GitHub Releases](https://github.com/termux/termux-x11/releases)
2. **Install** it on your Android device
3. **Grant** display-over-apps permission if prompted
4. **Open** Termux:X11 first, then run `cursor` in Termux

```bash
export DISPLAY=:0
cursor
```

> [!TIP]
> For the best experience, use a Bluetooth keyboard + mouse or connect a monitor via USB-C/HDMI.

---

## 🗂 File Locations

| Path | Purpose |
|---|---|
| `~/.cursor-mobile/cursor.AppImage` | Downloaded Cursor AppImage (GUI mode) |
| `~/.cursor-mobile/squashfs-root/` | Extracted Cursor files (GUI mode) |
| `~/.local/share/cursor-agent/` | Cursor Agent installation (CLI mode) |
| `$PREFIX/bin/cursor` | Termux launcher |
| `$PREFIX/bin/agent` | Cursor Agent alias |
| `$PREFIX/bin/start-cursor-display` | Termux:X11 display helper |

---

## 🐛 Troubleshooting

### `cursor: command not found`
```bash
echo $PATH   # $PREFIX/bin must be present
```

### Black screen / no display (GUI mode)
- Ensure Termux:X11 is open **before** running `cursor`
- Set display manually: `export DISPLAY=:0 && cursor`

### AppImage download fails
Download manually and place at `~/.cursor-mobile/cursor.AppImage`:
```bash
wget -O ~/.cursor-mobile/cursor.AppImage <url-from-cursor.com/downloads>
chmod +x ~/.cursor-mobile/cursor.AppImage
```

### Out of memory
```bash
free -h   # check available RAM; close background apps
```

### Reinstall Ubuntu container
```bash
proot-distro remove ubuntu
proot-distro install ubuntu
bash install.sh
```

---

## 🔄 Updating

**CLI mode** — re-run the installer to get the latest agent version:
```bash
bash install.sh
```

**GUI mode** — delete the AppImage and re-run:
```bash
rm ~/.cursor-mobile/cursor.AppImage
rm -rf ~/.cursor-mobile/squashfs-root
bash install.sh
```

---

## 📜 License

MIT © [remonsec](https://github.com/remonsec)

---

<div align="center">
Made for hackers who code on phones 📱⚡
<br>
<a href="https://twitter.com/remonsec">@remonsec</a> • <a href="https://github.com/remonsec">GitHub</a>
</div>
