<div align="center">

<h1>📱 cursor-mobile</h1>

<p><strong>Run Cursor IDE on Android — inside Termux</strong></p>

<p>
  <img alt="Platform" src="https://img.shields.io/badge/platform-Android%20ARM64-green?logo=android">
  <img alt="Shell" src="https://img.shields.io/badge/shell-Bash-blue?logo=gnubash">
  <img alt="License" src="https://img.shields.io/badge/license-MIT-blue">
  <img alt="Maintained" src="https://img.shields.io/badge/maintained-yes-brightgreen">
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
> Cursor IDE is an Electron/VSCode-based application built for desktop Linux (glibc + X11/Wayland).
> This installer bridges that gap via `proot-distro` (Ubuntu) + Termux:X11 for the **full GUI**,
> or the official Cursor CLI for a **headless/agent workflow** — no root required.

---

## 📋 Requirements

| Requirement | Details |
|---|---|
| **Device** | Android 7+ (ARM64 / aarch64) |
| **App** | [Termux](https://f-droid.org/packages/com.termux/) from **F-Droid** (not Play Store) |
| **RAM** | ≥ 3 GB recommended (4 GB+ with zRAM is ideal) |
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

Or one-liner:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/remonsec/cursor-mobile/main/install.sh)
```

---

## 🎛 Installation Modes

### Mode 1 — Full GUI (Recommended)

Installs Cursor IDE with full graphical interface using `proot-distro` (Ubuntu 24.04 arm64) + Termux:X11.

```
[Termux:X11 APK] ←─ display ──→ [proot Ubuntu] ←─ runs ──→ [Cursor AppImage]
                                       ↑
                              [ Termux Launcher wrapper ]
                                   `cursor` command
```

**After install:**
1. Open the **Termux:X11** app on your Android home screen
2. In Termux, run: `cursor`
3. Sign in with your Cursor account

### Mode 2 — CLI / Agent (Lightweight)

Installs the **official Cursor CLI** (`cursor`) directly in Termux — no GUI, no proot.
Ideal for headless workflows, SSH, or AI agent scripting.

```bash
cursor login          # authenticate
cursor agent          # start the AI agent
cursor -p "review this code"   # one-shot mode
```

---

## 🔧 How it Works

```
install.sh
 ├─ [Mode 1]
 │   ├─ pkg install proot-distro wget curl pulseaudio
 │   ├─ proot-distro install ubuntu          ← Ubuntu 24.04 LTS arm64 rootfs
 │   ├─ apt install <Cursor GUI deps>        ← GTK3, NSS, libasound2, etc.
 │   ├─ wget cursor.AppImage (arm64)         ← Official Cursor Linux arm64 build
 │   ├─ cursor.AppImage --appimage-extract   ← Extract without FUSE
 │   ├─ pulseaudio --start                  ← Audio daemon for Termux
 │   └─ /usr/bin/cursor (wrapper script)    ← `cursor` launch command
 │
 └─ [Mode 2]
     ├─ curl cursor.com/install | bash       ← Official Cursor CLI installer
     └─ `cursor` CLI available in PATH
```

### Why proot instead of native Termux?

Cursor's binary stack requires:
- **glibc** — Termux uses Android's bionic libc (incompatible)
- **FUSE** — Not available without root on Android
- **X11/Wayland** — Android has neither natively

`proot-distro` provides a full glibc-based Ubuntu userspace without root. Termux:X11 provides the X11 display server as a native Android app. The AppImage is extracted (bypassing FUSE) and run directly from the rootfs.

---

## 🖥 GUI Setup (Termux:X11)

1. **Download** Termux:X11 APK from [GitHub Releases](https://github.com/termux/termux-x11/releases)
2. **Install** it on your Android device
3. **Grant** display-over-apps permission if prompted
4. **Open** Termux:X11 first, then run `cursor` in Termux

```bash
# Inside Termux — launch Cursor with display
export DISPLAY=:0
cursor
```

> [!TIP]
> For the best experience, use a Bluetooth keyboard + mouse, or pair a monitor via USB-C/HDMI adapter.

---

## 🗂 File Locations

| Path | Purpose |
|---|---|
| `~/.cursor-mobile/cursor.AppImage` | Downloaded Cursor AppImage |
| `~/.cursor-mobile/squashfs-root/` | Extracted Cursor application files |
| `$PREFIX/bin/cursor` | Launch wrapper (Termux PATH) |
| `$PREFIX/bin/start-cursor-display` | Termux:X11 display helper |

---

## 🐛 Troubleshooting

### "cursor: command not found"
```bash
echo $PATH        # ensure $PREFIX/bin is in PATH
source ~/.bashrc
```

### Black screen / no display
- Make sure Termux:X11 is **open and running** before launching `cursor`
- Try: `export DISPLAY=:0 && cursor`

### AppImage download fails
Manually download from Cursor's website and place it at `~/.cursor-mobile/cursor.AppImage`:
```bash
# Check for ARM64 build on cursor.com/downloads
wget -O ~/.cursor-mobile/cursor.AppImage <your-download-url>
chmod +x ~/.cursor-mobile/cursor.AppImage
```

### Out of memory
Cursor is RAM-heavy. Enable zRAM or close other apps:
```bash
# Check available memory
free -h
```

### proot-distro: Ubuntu already exists
```bash
proot-distro remove ubuntu   # wipe and reinstall
proot-distro install ubuntu
bash install.sh
```

---

## 🔄 Updating Cursor

```bash
rm ~/.cursor-mobile/cursor.AppImage
rm -rf ~/.cursor-mobile/squashfs-root
bash install.sh   # re-runs the download + extract
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
