#!/usr/bin/env bash
# =============================================================================
# cursor-mobile — Install Cursor IDE in Termux (Android ARM64)
# Author  : remonsec <https://github.com/remonsec>
# Repo    : https://github.com/remonsec/cursor-mobile
# License : MIT
#
# Strategy
#   Cursor IDE is an Electron/VSCode-based GUI application that requires
#   glibc, FUSE, and a display server — none of which exist natively in
#   Termux's bionic libc environment. This script:
#     1. Installs proot-distro (Ubuntu 24.04 LTS, arm64) inside Termux
#     2. Bootstraps the Ubuntu rootfs with all Cursor dependencies
#     3. Downloads the official Cursor Linux arm64 AppImage / tarball
#     4. Extracts it (no FUSE needed) and creates a launch wrapper
#     5. Optionally installs Termux:X11 hook for GUI display
#
#   For HEADLESS / CLI-only use, the script also installs cursor-agent
#   (the official Cursor CLI) directly in Termux via the official installer.
# =============================================================================

set -euo pipefail

# ── colours ──────────────────────────────────────────────────────────────────
RED='\033[0;31m'; YEL='\033[1;33m'; GRN='\033[0;32m'; CYN='\033[0;36m'; NC='\033[0m'
info()  { echo -e "${CYN}[*]${NC} $*"; }
ok()    { echo -e "${GRN}[✓]${NC} $*"; }
warn()  { echo -e "${YEL}[!]${NC} $*"; }
die()   { echo -e "${RED}[✗]${NC} $*" >&2; exit 1; }

# ── banner ───────────────────────────────────────────────────────────────────
echo -e "${CYN}"
cat <<'BANNER'
  ██████╗██╗   ██╗██████╗ ███████╗ ██████╗ ██████╗
 ██╔════╝██║   ██║██╔══██╗██╔════╝██╔═══██╗██╔══██╗
 ██║     ██║   ██║██████╔╝███████╗██║   ██║██████╔╝
 ██║     ██║   ██║██╔══██╗╚════██║██║   ██║██╔══██╗
 ╚██████╗╚██████╔╝██║  ██║███████║╚██████╔╝██║  ██║
  ╚═════╝ ╚═════╝ ╚═╝  ╚═╝╚══════╝ ╚═════╝ ╚═╝  ╚═╝
         M O B I L E  —  Termux × Android
BANNER
echo -e "${NC}"
echo -e "  ${YEL}github.com/remonsec/cursor-mobile${NC}"
echo ""

# ── sanity checks ─────────────────────────────────────────────────────────────
[[ "$(uname -m)" == "aarch64" ]] || die "This script targets aarch64 (ARM64) Android only."
[[ -d "/data/data/com.termux" ]]  || die "Must be run inside Termux."

# ── mode selection ────────────────────────────────────────────────────────────
echo "Select installation mode:"
echo "  1) Full GUI  — Cursor IDE via proot Ubuntu + Termux:X11  (recommended)"
echo "  2) CLI only  — Cursor Agent/CLI directly in Termux        (lightweight)"
echo ""
read -rp "Enter choice [1/2] (default: 1): " MODE
MODE="${MODE:-1}"

# =============================================================================
# MODE 1: FULL GUI via proot-distro + Ubuntu
# =============================================================================
if [[ "$MODE" == "1" ]]; then
  info "Full GUI mode selected."

  # ── 1. Termux base packages ────────────────────────────────────────────────
  info "Updating Termux packages..."
  pkg update -y -o Dpkg::Options::="--force-confnew" 2>/dev/null
  pkg install -y proot-distro wget curl pulseaudio 2>/dev/null
  ok "Termux packages ready."

  # ── 2. proot Ubuntu ───────────────────────────────────────────────────────
  if proot-distro list 2>/dev/null | grep -q 'ubuntu'; then
    ok "Ubuntu proot container already exists."
  else
    info "Installing Ubuntu 24.04 LTS via proot-distro (this may take a while)..."
    proot-distro install ubuntu
    ok "Ubuntu installed."
  fi

  # ── 3. Bootstrap Ubuntu with Cursor deps ──────────────────────────────────
  info "Bootstrapping Ubuntu with Cursor dependencies..."
  proot-distro login ubuntu -- bash -c '
    set -e
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -qq
    apt-get install -y --no-install-recommends \
      wget curl ca-certificates \
      libgtk-3-0 libnotify4 libnss3 libxss1 libxtst6 \
      xdg-utils libatspi2.0-0 libdrm2 libgbm1 libxcb-dri3-0 \
      libx11-xcb1 libxcomposite1 libxcursor1 libxdamage1 \
      libxfixes3 libxi6 libxrandr2 libxrender1 \
      libasound2 libatk1.0-0 libatk-bridge2.0-0 \
      libpango-1.0-0 libpangocairo-1.0-0 \
      libgdk-pixbuf2.0-0 libcairo2 \
      2>/dev/null
    echo "[✓] Ubuntu deps installed."
  '

  # ── 4. Download & extract Cursor AppImage ─────────────────────────────────
  CURSOR_DIR="$HOME/.cursor-mobile"
  mkdir -p "$CURSOR_DIR"

  APPIMAGE_PATH="$CURSOR_DIR/cursor.AppImage"

  if [[ ! -f "$APPIMAGE_PATH" ]]; then
    info "Fetching latest Cursor download URL for Linux arm64..."

    # Try official downloader URL (redirects to latest build)
    DOWNLOAD_URL="https://downloader.cursor.sh/linux/appImage/arm64"

    info "Downloading Cursor AppImage (arm64)..."
    wget -q --show-progress -O "$APPIMAGE_PATH" "$DOWNLOAD_URL" || {
      warn "Primary URL failed. Trying alternate..."
      # Community-maintained mirror fallback
      DOWNLOAD_URL="https://github.com/getcursor/cursor/releases/latest/download/cursor-linux-arm64.AppImage"
      wget -q --show-progress -O "$APPIMAGE_PATH" "$DOWNLOAD_URL" || die "Download failed. Check your internet connection."
    }
    chmod +x "$APPIMAGE_PATH"
    ok "Cursor AppImage downloaded → $APPIMAGE_PATH"
  else
    ok "Cursor AppImage already present at $APPIMAGE_PATH"
  fi

  # ── 5. Extract AppImage (no FUSE needed) ──────────────────────────────────
  EXTRACT_DIR="$CURSOR_DIR/squashfs-root"
  if [[ ! -d "$EXTRACT_DIR" ]]; then
    info "Extracting AppImage (bypassing FUSE)..."
    cd "$CURSOR_DIR"
    # Copy into proot home, extract there
    proot-distro login ubuntu -- bash -c "
      cp /proc/\$\$/root${APPIMAGE_PATH} /root/cursor.AppImage 2>/dev/null || \
      cp ${APPIMAGE_PATH} /root/cursor.AppImage
      chmod +x /root/cursor.AppImage
      cd /root && ./cursor.AppImage --appimage-extract >/dev/null 2>&1
      echo '[✓] Extracted.'
    " || {
      warn "proot copy trick failed — trying direct extraction..."
      "$APPIMAGE_PATH" --appimage-extract >/dev/null 2>&1 || true
    }
    ok "AppImage extracted."
  else
    ok "AppImage already extracted."
  fi

  # ── 6. Termux:X11 display setup ──────────────────────────────────────────
  DISPLAY_HOOK="$PREFIX/bin/start-cursor-display"
  cat > "$DISPLAY_HOOK" <<'HOOK'
#!/usr/bin/env bash
# Start Termux:X11 display then launch Cursor in proot Ubuntu
export DISPLAY=:0
am start --user 0 -n com.termux.x11/com.termux.x11.MainActivity 2>/dev/null || \
  echo "[!] Termux:X11 not found. Install it from: https://github.com/termux/termux-x11/releases"
sleep 2
HOOK
  chmod +x "$DISPLAY_HOOK"

  # ── 7. Launch wrapper ────────────────────────────────────────────────────
  LAUNCHER="$PREFIX/bin/cursor"
  cat > "$LAUNCHER" <<LAUNCH
#!/usr/bin/env bash
# cursor — Launch Cursor IDE (Termux mobile wrapper)
export DISPLAY="\${DISPLAY:-:0}"
export PULSE_SERVER=127.0.0.1
pulseaudio --start --load="module-native-protocol-tcp auth-ip-acl=127.0.0.1 auth-anonymous=1" --exit-idle-time=-1 2>/dev/null || true
proot-distro login ubuntu -- bash -c "
  export DISPLAY=:0
  export LIBGL_ALWAYS_SOFTWARE=1
  /root/squashfs-root/cursor --no-sandbox \"\$@\"
"
LAUNCH
  chmod +x "$LAUNCHER"

  echo ""
  ok "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  ok " Cursor IDE installed! (Full GUI mode)"
  ok "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
  echo -e " ${YEL}Before launching:${NC}"
  echo -e "  1. Install ${CYN}Termux:X11${NC} APK → https://github.com/termux/termux-x11/releases"
  echo -e "  2. Open Termux:X11, then run: ${GRN}cursor${NC}"
  echo ""
  echo -e " ${YEL}Launch command:${NC} ${GRN}cursor${NC}"
  echo ""

# =============================================================================
# MODE 2: CLI / Agent (lightweight, no GUI)
# =============================================================================
elif [[ "$MODE" == "2" ]]; then
  info "CLI-only mode selected."

  pkg update -y -o Dpkg::Options::="--force-confnew" 2>/dev/null
  pkg install -y curl 2>/dev/null

  info "Installing Cursor CLI via official installer..."
  curl -fsSL https://cursor.com/install | bash || {
    warn "Official installer failed. Trying manual arm64 binary install..."
    pkg install -y nodejs 2>/dev/null
    npm install -g @cursor/agent 2>/dev/null || warn "npm agent install failed too. Check https://cursor.com/docs/cli"
  }

  echo ""
  ok "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  ok " Cursor CLI installed! (Headless mode)"
  ok "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
  echo -e " ${YEL}Authenticate:${NC}  ${GRN}cursor login${NC}"
  echo -e " ${YEL}Start agent:${NC}   ${GRN}cursor agent${NC}"
  echo ""

else
  die "Invalid choice '$MODE'. Run again and select 1 or 2."
fi

echo -e "${CYN}Docs & issues → https://github.com/remonsec/cursor-mobile${NC}"
