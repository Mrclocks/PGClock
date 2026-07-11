#!/usr/bin/env bash
#
# PGClock Installer for Pasarguard
# https://github.com/Mrclocks/PGClock
#
set -euo pipefail

readonly SCRIPT_VERSION="1.2.1"
readonly TARGET_DIR="/var/lib/pasarguard/templates/subscription"
readonly TARGET_FILE="${TARGET_DIR}/index.html"
readonly ENV_FILE="/opt/pasarguard/.env"
readonly INSTALLER_RAW="https://raw.githubusercontent.com/Mrclocks/PGClock/main/install.sh"

readonly URL_LITE="https://raw.githubusercontent.com/Mrclocks/PGClockLite/main/index.html"
readonly URL_STANDARD="https://raw.githubusercontent.com/Mrclocks/PGClock/main/index.html"
readonly URL_PRO="https://raw.githubusercontent.com/Mrclocks/PGClockPRO/main/index.html"

# When run via "curl | bash", stdin is the pipe — re-download and re-run from a real file.
if [[ ! -t 0 ]] && [[ -z "${PGCLOCK_INSTALL_REEXEC:-}" ]]; then
  tmpfile="$(mktemp /tmp/pgclock-install-XXXXXX.sh)"
  cleanup() { rm -f "$tmpfile"; }
  trap cleanup EXIT
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL "$INSTALLER_RAW" -o "$tmpfile"
  else
    wget -qO "$tmpfile" "$INSTALLER_RAW"
  fi
  chmod 700 "$tmpfile"
  export PGCLOCK_INSTALL_REEXEC=1
  exec bash "$tmpfile" "$@"
fi

if [[ -t 1 ]]; then
  readonly C_RESET='\033[0m'
  readonly C_BOLD='\033[1m'
  readonly C_DIM='\033[2m'
  readonly C_RED='\033[31m'
  readonly C_GREEN='\033[32m'
  readonly C_YELLOW='\033[33m'
  readonly C_BLUE='\033[34m'
  readonly C_CYAN='\033[36m'
  readonly C_WHITE='\033[97m'
else
  readonly C_RESET='' C_BOLD='' C_DIM='' C_RED='' C_GREEN='' C_YELLOW='' C_BLUE='' C_CYAN='' C_WHITE=''
fi

log_line() { printf '%b\n' "$1"; }
log_blank() { printf '\n'; }

read_tty() {
  local prompt=$1
  local __var=$2
  local input=""
  if [[ -r /dev/tty ]]; then
    IFS= read -r -p "$prompt" input </dev/tty || true
  else
    IFS= read -r -p "$prompt" input || true
  fi
  printf -v "$__var" '%s' "$input"
}

print_banner() {
  log_blank
  log_line "${C_CYAN}${C_BOLD}╔══════════════════════════════════════════════════════════════╗${C_RESET}"
  log_line "${C_CYAN}${C_BOLD}║${C_RESET}              ${C_WHITE}${C_BOLD}PGClock Installer for Pasarguard${C_RESET}              ${C_CYAN}${C_BOLD}║${C_RESET}"
  log_line "${C_CYAN}${C_BOLD}║${C_RESET}                        ${C_DIM}Version ${SCRIPT_VERSION}${C_RESET}                        ${C_CYAN}${C_BOLD}║${C_RESET}"
  log_line "${C_CYAN}${C_BOLD}╚══════════════════════════════════════════════════════════════╝${C_RESET}"
  log_blank
}

ok()   { log_line "${C_GREEN}✔${C_RESET}  $*"; }
info() { log_line "${C_BLUE}→${C_RESET}  $*"; }
warn() { log_line "${C_YELLOW}!${C_RESET}  $*"; }
fail() { log_line "${C_RED}✖${C_RESET}  $*"; exit 1; }

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || fail "Required command not found: $1. Install it with: apt update && apt install -y $1"
}

require_root() {
  if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
    fail "This script must run as root. Try again with sudo."
  fi
}

check_system() {
  info "Checking prerequisites..."
  need_cmd wget
  need_cmd curl
  need_cmd python3
  need_cmd grep
  need_cmd sed
  need_cmd mktemp

  if [[ ! -f "$ENV_FILE" ]]; then
    warn "${ENV_FILE} not found. Continuing anyway."
  fi

  if ! command -v pasarguard >/dev/null 2>&1; then
    warn "pasarguard command not found. You may need to restart the service manually."
  fi

  ok "Prerequisites OK"
}

ensure_target_dir() {
  info "Creating template directory..."
  mkdir -p "$TARGET_DIR"
  ok "Directory ready: ${TARGET_DIR}"
}

validate_logo_url() {
  local url="$1"
  [[ -n "$url" ]] || return 0
  [[ "$url" =~ ^https?://[^[:space:]]+$ ]] || return 1
  curl -fsSIL --max-time 12 --retry 1 "$url" >/dev/null 2>&1
}

download_template() {
  local url="$1"
  local dest="$2"
  info "Downloading template from GitHub..."
  wget -N -O "$dest" "$url" || fail "Download failed. Check your internet connection and the URL."
  [[ -s "$dest" ]] || fail "Downloaded file is empty."
  ok "index.html downloaded"
}

apply_brand_pro() {
  local file="$1"

  info "Applying PGClock Pro brand settings..."
  BRAND_NAME="${BRAND_NAME:-}" BRAND_SUBTITLE="${BRAND_SUBTITLE:-}" BRAND_LOGO="${BRAND_LOGO:-}" \
  python3 - "$file" <<'PY'
import os
import re
import sys

path = sys.argv[1]
name = os.environ.get("BRAND_NAME", "").strip()
subtitle = os.environ.get("BRAND_SUBTITLE", "").strip()
logo = os.environ.get("BRAND_LOGO", "").strip()

with open(path, "r", encoding="utf-8") as f:
    html = f.read()

original_len = len(html)
if original_len < 1000:
    sys.stderr.write("Template file looks too small or incomplete.\n")
    sys.exit(1)

def js_quote(value: str) -> str:
    return (
        value.replace("\\", "\\\\")
        .replace('"', '\\"')
        .replace("\r", "")
        .replace("\n", "\\n")
    )

def html_text(value: str) -> str:
    return value.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")

def find_brand_block(text: str):
    marker = "var DEFAULT_BRAND = {"
    start = text.find(marker)
    if start == -1:
        return None
    brace = text.find("{", start)
    if brace == -1:
        return None
    depth = 0
    for i in range(brace, len(text)):
        ch = text[i]
        if ch == "{":
            depth += 1
        elif ch == "}":
            depth -= 1
            if depth == 0:
                end = i + 1
                if end < len(text) and text[end] == ";":
                    end += 1
                return start, end
    return None

bounds = find_brand_block(html)
if not bounds:
    sys.stderr.write("DEFAULT_BRAND block not found in template.\n")
    sys.exit(1)

start, end = bounds
segment = html[start:end]

if name:
    segment = re.sub(
        r'(name:\s*")(?:[^"\\]|\\.)*(")',
        lambda m: m.group(1) + js_quote(name) + m.group(2),
        segment,
        count=1,
    )
    html = re.sub(
        r'(<h1 class="brand-title" id="brand-title">)[^<]*(</h1>)',
        lambda m: m.group(1) + html_text(name) + m.group(2),
        html,
        count=1,
    )

if subtitle:
    esc = js_quote(subtitle)
    segment = re.sub(
        r'(fa:\s*")(?:[^"\\]|\\.)*(")',
        lambda m: m.group(1) + esc + m.group(2),
        segment,
        count=1,
    )
    segment = re.sub(
        r'(en:\s*")(?:[^"\\]|\\.)*(")',
        lambda m: m.group(1) + esc + m.group(2),
        segment,
        count=1,
    )
    html = re.sub(
        r'(<p class="brand-sub" id="brand-subtitle">)[^<]*(</p>)',
        lambda m: m.group(1) + html_text(subtitle) + m.group(2),
        html,
        count=1,
    )

if logo:
    segment = re.sub(
        r'(logoUrl:\s*")(?:[^"\\]|\\.)*(")',
        lambda m: m.group(1) + js_quote(logo) + m.group(2),
        segment,
        count=1,
    )

html = html[:start] + segment + html[end:]

if len(html) < original_len * 0.95:
    sys.stderr.write("Refusing to write: output looks truncated.\n")
    sys.exit(1)

with open(path, "w", encoding="utf-8", newline="") as f:
    f.write(html)
PY
  ok "Brand settings applied to HTML"
}

configure_env() {
  info "Updating ${ENV_FILE}..."

  local tmp
  tmp="$(mktemp)"

  if [[ -f "$ENV_FILE" ]]; then
    cp "$ENV_FILE" "$tmp"
  else
    : > "$tmp"
    warn ".env file created."
  fi

  set_env_value() {
    local key="$1"
    local value="$2"
    if grep -q "^${key}=" "$tmp"; then
      sed -i "s|^${key}=.*|${key}=${value}|" "$tmp"
    else
      printf '\n%s=%s\n' "$key" "$value" >> "$tmp"
    fi
  }

  set_env_value 'CUSTOM_TEMPLATES_DIRECTORY' '"/var/lib/pasarguard/templates/"'
  set_env_value 'SUBSCRIPTION_PAGE_TEMPLATE' '"subscription/index.html"'

  sed -i '/./,$!d' "$tmp"
  install -m 600 "$tmp" "$ENV_FILE"
  rm -f "$tmp"

  ok ".env updated"
}

restart_pasarguard() {
  info "Restarting Pasarguard..."
  if command -v pasarguard >/dev/null 2>&1; then
    if pasarguard restart; then
      ok "Pasarguard restarted successfully"
    else
      warn "Automatic restart failed. Run manually: pasarguard restart"
    fi
  else
    warn "pasarguard command not available. Restart the service manually after install."
  fi
}

print_menu() {
  log_line "${C_BOLD}Select a template:${C_RESET}"
  log_blank
  log_line "  ${C_GREEN}1${C_RESET}) ${C_BOLD}PGClock Lite${C_RESET}   ${C_DIM}Lightweight and fast${C_RESET}"
  log_line "  ${C_CYAN}2${C_RESET}) ${C_BOLD}PGClock${C_RESET}        ${C_DIM}Standard edition (recommended)${C_RESET}"
  log_line "  ${C_YELLOW}3${C_RESET}) ${C_BOLD}PGClock Pro${C_RESET}     ${C_DIM}Custom brand name, tagline, and logo${C_RESET}"
  log_line "  ${C_RED}0${C_RESET}) ${C_BOLD}Exit${C_RESET}"
  log_blank
}

prompt_pro_branding() {
  local brand_name brand_subtitle brand_logo

  log_line "${C_YELLOW}${C_BOLD}─── PGClock Pro Brand Setup ───${C_RESET}"
  log_blank
  log_line "${C_DIM}Press Enter to skip any field and keep the default value${C_RESET}"
  log_blank

  read_tty "$(printf '%b' "${C_BOLD}Brand name${C_RESET} (e.g. MrClock): ")" brand_name
  brand_name="${brand_name:-}"

  read_tty "$(printf '%b' "${C_BOLD}Tagline / caption${C_RESET} (e.g. Subscription panel): ")" brand_subtitle
  brand_subtitle="${brand_subtitle:-}"

  while true; do
    read_tty "$(printf '%b' "${C_BOLD}Logo URL${C_RESET} (https://...): ")" brand_logo
    brand_logo="${brand_logo:-}"
    if [[ -z "$brand_logo" ]]; then
      break
    fi
    if validate_logo_url "$brand_logo"; then
      ok "Logo URL is valid"
      break
    fi
    warn "Invalid or unreachable logo URL. Enter a full https:// URL, or press Enter to skip."
  done

  export BRAND_NAME="$brand_name"
  export BRAND_SUBTITLE="$brand_subtitle"
  export BRAND_LOGO="$brand_logo"
}

install_lite() {
  info "Installing ${C_BOLD}PGClock Lite${C_RESET}..."
  download_template "$URL_LITE" "$TARGET_FILE"
}

install_standard() {
  info "Installing ${C_BOLD}PGClock${C_RESET}..."
  download_template "$URL_STANDARD" "$TARGET_FILE"
}

install_pro() {
  info "Installing ${C_BOLD}PGClock Pro${C_RESET}..."
  prompt_pro_branding
  download_template "$URL_PRO" "$TARGET_FILE"
  apply_brand_pro "$TARGET_FILE"
}

print_success_box() {
  local edition="$1"
  log_blank
  log_line "${C_GREEN}${C_BOLD}╔══════════════════════════════════════════════════════════════╗${C_RESET}"
  log_line "${C_GREEN}${C_BOLD}║${C_RESET}                    ${C_WHITE}${C_BOLD}Installation complete${C_RESET}                     ${C_GREEN}${C_BOLD}║${C_RESET}"
  log_line "${C_GREEN}${C_BOLD}╠══════════════════════════════════════════════════════════════╣${C_RESET}"
  log_line "${C_GREEN}${C_BOLD}║${C_RESET}  ${C_BOLD}Template:${C_RESET} ${edition}"
  log_line "${C_GREEN}${C_BOLD}║${C_RESET}  ${C_BOLD}Path:${C_RESET}     ${TARGET_FILE}"
  log_line "${C_GREEN}${C_BOLD}║${C_RESET}  ${C_BOLD}Env:${C_RESET}      ${ENV_FILE}"
  log_line "${C_GREEN}${C_BOLD}╠══════════════════════════════════════════════════════════════╣${C_RESET}"
  log_line "${C_GREEN}${C_BOLD}║${C_RESET}  Your subscription page is ready.                           ${C_GREEN}${C_BOLD}║${C_RESET}"
  log_line "${C_GREEN}${C_BOLD}╚══════════════════════════════════════════════════════════════╝${C_RESET}"
  log_blank
}

main() {
  local choice edition

  print_banner
  require_root
  check_system
  ensure_target_dir

  while true; do
    print_menu
    read_tty "$(printf '%b' "${C_BOLD}Enter your choice [0-3]: ${C_RESET}")" choice
    choice="${choice:-}"

    case "$choice" in
      1)
        install_lite
        edition="PGClock Lite"
        break
        ;;
      2)
        install_standard
        edition="PGClock"
        break
        ;;
      3)
        install_pro
        edition="PGClock Pro"
        break
        ;;
      0)
        info "Installation cancelled."
        exit 0
        ;;
      *)
        warn "Invalid choice. Please enter a number from 0 to 3."
        log_blank
        ;;
    esac
  done

  configure_env
  restart_pasarguard
  print_success_box "$edition"
}

main "$@"
