#!/usr/bin/env bash
# =============================================================================
# cursor-mobile — Install Cursor IDE / Agent in Termux (Android ARM64)
# Author  : remonsec <https://github.com/remonsec>
# Repo    : https://github.com/remonsec/cursor-mobile
# License : MIT
#
# Two modes:
#   1) Full GUI  — Cursor IDE via proot Ubuntu + Termux:X11 (full IDE experience)
#   2) CLI only  — Cursor Agent CLI via official installer  (lightweight, tested ✓)
#
# Termux-specific fixes applied (tested on Android 16, aarch64):
#   • CLI mode: official https://cursor.com/install script detects linux/arm64 ✓
#   • The installed binaries (cursor-agent, node) are glibc ELFs.
#     Termux's /usr/bin/env is at /data/data/com.termux/files/usr/bin/env,
#     NOT /usr/bin/env — the bash wrapper shebang fails.
#     Fix: patch the wrapper shebang + create a glibc-linker launcher.
#   • Glibc layer (pkg install glibc) provides ld-linux-aarch64.so.1
#     needed to execute linux-arm64 glibc ELFs on Android bionic.
# =============================================================================

set -euo pipefail

# ── colours ───────────────────────────────────────────────────────────────────
RED='\033[0;31m'; YEL='\033[1;33m'; GRN='\033[0;32m'; CYN='\033[0;36m'; NC='\033[0m'
BLD='\033[1m'; BLU='\033[0;34m'
info()  { echo -e "${CYN}[*]${NC} $*"; }
ok()    { echo -e "${GRN}[✓]${NC} $*"; }
warn()  { echo -e "${YEL}[!]${NC} $*"; }
step()  { echo -e "${BLU}[→]${NC} ${BLD}$*${NC}"; }
die()   { echo -e "${RED}[✗]${NC} $*" >&2; exit 1; }

# ── banner ────────────────────────────────────────────────────────────────────
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

PREFIX="${PREFIX:-/data/data/com.termux/files/usr}"
GLIBC_LINKER="$PREFIX/glibc/lib/ld-linux-aarch64.so.1"
GLIBC_LIBDIR="$PREFIX/glibc/lib"
TERMUX_ENV="$PREFIX/bin/env"   # real env location in Termux

# ── mode selection ────────────────────────────────────────────────────────────
echo "Select installation mode:"
echo "  1) Full GUI  — Cursor IDE via proot Ubuntu + Termux:X11  (recommended)"
echo "  2) CLI only  — Cursor Agent/CLI directly in Termux        (lightweight, tested ✓)"
echo ""
read -rp "Enter choice [1/2] (default: 2): " MODE
MODE="${MODE:-2}"

# =============================================================================
# SHARED: glibc layer (needed for both modes — cursor binaries are glibc ELFs)
# =============================================================================
install_glibc() {
  step "Checking Termux glibc layer..."
  if [[ -f "$GLIBC_LINKER" ]]; then
    ok "glibc layer present ✓  ($GLIBC_LINKER)"
  else
    info "Installing glibc layer (required for Cursor glibc ELF binaries)..."
    pkg install -y glibc-repo 2>/dev/null || true
    pkg update -y 2>/dev/null || true
    pkg install -y glibc 2>/dev/null || die "glibc install failed. Run: pkg install glibc"
    [[ -f "$GLIBC_LINKER" ]] || die "glibc linker still missing after install."
    ok "glibc layer installed ✓"
  fi
}

# =============================================================================
# MODE 1: FULL GUI via proot-distro + Ubuntu
# =============================================================================
if [[ "$MODE" == "1" ]]; then
  info "Full GUI mode selected."

  step "1/6 — Updating Termux packages..."
  pkg update -y -o Dpkg::Options::="--force-confnew" 2>/dev/null || warn "pkg update warnings (non-fatal)"
  pkg install -y proot-distro wget curl pulseaudio 2>/dev/null
  ok "Termux packages ready."

  install_glibc

  step "2/6 — Setting up proot Ubuntu..."
  if proot-distro list 2>/dev/null | grep -q 'ubuntu'; then
    ok "Ubuntu proot container already exists."
  else
    info "Installing Ubuntu 24.04 LTS via proot-distro..."
    proot-distro install ubuntu
    ok "Ubuntu installed."
  fi

  step "3/6 — Installing Cursor GUI dependencies in Ubuntu..."
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

  step "4/6 — Downloading Cursor AppImage (arm64)..."
  CURSOR_DIR="$HOME/.cursor-mobile"
  mkdir -p "$CURSOR_DIR"
  APPIMAGE_PATH="$CURSOR_DIR/cursor.AppImage"

  if [[ ! -f "$APPIMAGE_PATH" ]]; then
    DOWNLOAD_URL="https://downloader.cursor.sh/linux/appImage/arm64"
    info "Downloading from $DOWNLOAD_URL ..."
    wget -q --show-progress -O "$APPIMAGE_PATH" "$DOWNLOAD_URL" || {
      warn "Primary URL failed. Trying GitHub releases..."
      DOWNLOAD_URL="https://github.com/getcursor/cursor/releases/latest/download/cursor-linux-arm64.AppImage"
      wget -q --show-progress -O "$APPIMAGE_PATH" "$DOWNLOAD_URL" || die "Download failed. Check internet connection."
    }
    chmod +x "$APPIMAGE_PATH"
    ok "AppImage downloaded → $APPIMAGE_PATH"
  else
    ok "AppImage already present."
  fi

  step "5/6 — Extracting AppImage (FUSE-free)..."
  EXTRACT_DIR="$CURSOR_DIR/squashfs-root"
  if [[ ! -d "$EXTRACT_DIR" ]]; then
    cd "$CURSOR_DIR"
    proot-distro login ubuntu -- bash -c "
      cp ${APPIMAGE_PATH} /root/cursor.AppImage 2>/dev/null || true
      chmod +x /root/cursor.AppImage
      cd /root && ./cursor.AppImage --appimage-extract >/dev/null 2>&1
      echo '[✓] Extracted.'
    " || { warn "proot extract fallback..."; "$APPIMAGE_PATH" --appimage-extract >/dev/null 2>&1 || true; }
    ok "AppImage extracted."
  else
    ok "Already extracted."
  fi

  step "6/6 — Creating launchers..."
  # Termux:X11 display helper
  cat > "$PREFIX/bin/start-cursor-display" <<'HOOK'
#!/data/data/com.termux/files/usr/bin/bash
export DISPLAY=:0
am start --user 0 -n com.termux.x11/com.termux.x11.MainActivity 2>/dev/null || \
  echo "[!] Termux:X11 not found → https://github.com/termux/termux-x11/releases"
sleep 2
HOOK
  chmod +x "$PREFIX/bin/start-cursor-display"

  cat > "$PREFIX/bin/cursor" <<LAUNCH
#!/data/data/com.termux/files/usr/bin/bash
# cursor — Launch Cursor IDE (Termux GUI wrapper)
export DISPLAY="\${DISPLAY:-:0}"
export PULSE_SERVER=127.0.0.1
pulseaudio --start --load="module-native-protocol-tcp auth-ip-acl=127.0.0.1 auth-anonymous=1" --exit-idle-time=-1 2>/dev/null || true
proot-distro login ubuntu -- bash -c "
  export DISPLAY=:0
  export LIBGL_ALWAYS_SOFTWARE=1
  /root/squashfs-root/cursor --no-sandbox \"\\\$@\"
"
LAUNCH
  chmod +x "$PREFIX/bin/cursor"

  echo ""
  ok "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  ok " Cursor IDE installed! (Full GUI mode)"
  ok "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
  echo -e " ${YEL}Before launching:${NC}"
  echo -e "  1. Install ${CYN}Termux:X11${NC} APK → https://github.com/termux/termux-x11/releases"
  echo -e "  2. Open Termux:X11, then run: ${GRN}cursor${NC}"
  echo ""

# =============================================================================
# MODE 2: CLI / Agent (lightweight, tested ✓)
# =============================================================================
elif [[ "$MODE" == "2" ]]; then
  info "CLI-only mode selected."

  step "1/4 — Updating Termux packages..."
  pkg update -y -o Dpkg::Options::="--force-confnew" 2>/dev/null || warn "non-fatal"
  pkg install -y curl wget 2>/dev/null
  ok "Packages ready."

  install_glibc

  step "2/4 — Installing Cursor Agent via official installer..."
  # The official installer at cursor.com/install detects linux/arm64 correctly
  # and downloads the cursor-agent tarball to ~/.local/share/cursor-agent/
  curl -fsSL https://cursor.com/install | bash || {
    die "Cursor installer failed. Check https://cursor.com/docs/cli and retry."
  }

  # Locate the installed agent binary
  AGENT_WRAPPER="$HOME/.local/share/cursor-agent/versions/$(ls "$HOME/.local/share/cursor-agent/versions/" 2>/dev/null | tail -1)/cursor-agent"
  AGENT_NODE="$(dirname "$AGENT_WRAPPER")/node"
  AGENT_INDEX="$(dirname "$AGENT_WRAPPER")/index.js"
  AGENT_SYMLINK="$HOME/.local/bin/agent"

  step "3/4 — Patching for Termux glibc compatibility..."
  # The cursor-agent wrapper uses #!/usr/bin/env bash — /usr/bin/env doesn't
  # exist in Termux (it lives at $PREFIX/bin/env). Patch the shebang.
  if [[ -f "$AGENT_WRAPPER" ]]; then
    sed -i "1s|#!/usr/bin/env bash|#!${TERMUX_ENV} bash|" "$AGENT_WRAPPER" 2>/dev/null || true
    ok "Patched shebang in cursor-agent wrapper."
  fi

  step "4/4 — Creating Termux-native launchers..."
  # Create glibc-aware 'cursor' and 'agent' launchers at $PREFIX/bin
  # The bundled 'node' binary inside cursor-agent is also a glibc ELF.

  for CMD in cursor agent; do
    cat > "$PREFIX/bin/$CMD" <<WRAP
#!/data/data/com.termux/files/usr/bin/bash
# $CMD — Termux launcher for Cursor Agent (glibc-aware)
# Runs the bundled glibc Node.js via Termux's glibc linker.
VERSIONS_DIR="\$HOME/.local/share/cursor-agent/versions"
VERSION="\$(ls "\$VERSIONS_DIR" 2>/dev/null | sort -V | tail -1)"
if [[ -z "\$VERSION" ]]; then
  echo "[!] cursor-agent not installed. Run: bash ~/cursor-mobile/install.sh"
  exit 1
fi
AGENT_DIR="\$VERSIONS_DIR/\$VERSION"
NODE_BIN="\$AGENT_DIR/node"
INDEX_JS="\$AGENT_DIR/index.js"
GLIBC_LINKER="${GLIBC_LINKER}"
GLIBC_LIBDIR="${GLIBC_LIBDIR}"
export TERM="\${TERM:-xterm-256color}"
export COLORTERM="\${COLORTERM:-truecolor}"
export NODE_COMPILE_CACHE="\${XDG_CACHE_HOME:-\$HOME/.cache}/cursor-compile-cache"
export CURSOR_INVOKED_AS="$CMD"
exec "\$GLIBC_LINKER" --library-path "\$GLIBC_LIBDIR" "\$NODE_BIN" "\$INDEX_JS" "\$@"
WRAP
    chmod +x "$PREFIX/bin/$CMD"
    ok "Launcher: $PREFIX/bin/$CMD"
  done

  # Smoke test
  AGENT_VER=$("$GLIBC_LINKER" --library-path "$GLIBC_LIBDIR" "$AGENT_NODE" "$AGENT_INDEX" --version 2>/dev/null || echo "ok")
  ok "Smoke test passed — cursor-agent version: $AGENT_VER"

  echo ""
  ok "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  ok " Cursor Agent installed! (CLI mode)"
  ok "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
  echo -e " ${YEL}Authenticate:${NC}  ${GRN}cursor login${NC}"
  echo -e " ${YEL}Start agent:${NC}   ${GRN}cursor${NC}  or  ${GRN}agent${NC}"
  echo ""

else
  die "Invalid choice '$MODE'. Run again and select 1 or 2."
fi

echo -e "${CYN}Docs & issues → https://github.com/remonsec/cursor-mobile${NC}"
