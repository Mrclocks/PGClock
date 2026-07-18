#!/usr/bin/env bash
#
# PGClock Installer for Pasarguard
# https://github.com/Mrclocks/PGClock
#
set -euo pipefail

readonly SCRIPT_VERSION="1.4.1"
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

hr() {
  log_line "${C_CYAN}${C_BOLD}================================================================${C_RESET}"
}

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
  hr
  log_line "${C_WHITE}${C_BOLD}  PGClock Installer for Pasarguard${C_RESET}"
  log_line "${C_DIM}  Version ${SCRIPT_VERSION}${C_RESET}"
  hr
  log_blank
}

ok()   { log_line "${C_GREEN}[OK]${C_RESET}  $*"; }
info() { log_line "${C_BLUE}[>>]${C_RESET}  $*"; }
warn() { log_line "${C_YELLOW}[!!]${C_RESET}  $*"; }
fail() { log_line "${C_RED}[ERR]${C_RESET} $*"; exit 1; }

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
  export BRAND_NAME="${BRAND_NAME:-}"
  export BRAND_SUBTITLE="${BRAND_SUBTITLE:-}"
  export BRAND_LOGO="${BRAND_LOGO:-}"

  python3 - "$file" <<'PY' || return 1
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

if original_len < 1000 or "</html>" not in html.lower():
    sys.stderr.write("Downloaded file does not look like a complete HTML template.\n")
    sys.exit(1)

BRAND_OBJECT_KEYS = ("DEFAULT_BRAND", "MRCLOCK_DEFAULT_BRAND", "PANEL_DEFAULT_BRAND")
LOGO_KEYS = ("logoUrl", "logo", "logoURL", "logo_url")

def js_quote(value: str) -> str:
    return (
        value.replace("\\", "\\\\")
        .replace('"', '\\"')
        .replace("\r", "")
        .replace("\n", "\\n")
    )

def html_text(value: str) -> str:
    return value.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")

def attr_quote(value: str) -> str:
    return value.replace("&", "&amp;").replace('"', "&quot;")

def extract_braced_object(text: str, open_index: int):
    depth = 0
    i = open_index
    in_str = None
    esc = False
    while i < len(text):
        ch = text[i]
        if in_str:
            if esc:
                esc = False
            elif ch == "\\":
                esc = True
            elif ch == in_str:
                in_str = None
        else:
            if ch in ('"', "'"):
                in_str = ch
            elif ch == "{":
                depth += 1
            elif ch == "}":
                depth -= 1
                if depth == 0:
                    end = i + 1
                    while end < len(text) and text[end] in " \t\r\n":
                        end += 1
                    if end < len(text) and text[end] == ";":
                        end += 1
                    return open_index, end
        i += 1
    return None

def find_brand_object(text: str):
    for key in BRAND_OBJECT_KEYS:
        match = re.search(
            rf"(?:var|const|let)\s+{re.escape(key)}\s*=\s*(\{{)",
            text,
        )
        if not match:
            continue
        bounds = extract_braced_object(text, match.start(1))
        if bounds:
            return key, bounds
    return None, None

def replace_quoted_field(block: str, field: str, value: str):
    pattern = rf'({re.escape(field)}\s*:\s*")(?:[^"\\]|\\.)*(")'
    return re.subn(
        pattern,
        lambda m: m.group(1) + js_quote(value) + m.group(2),
        block,
        count=1,
    )

def patch_brand_object(block: str):
    updated = block

    if name:
        updated, count = replace_quoted_field(updated, "name", name)
        if count != 1:
            sys.stderr.write('Could not find brand field "name" in the template.\n')
            sys.exit(1)

    if subtitle:
        if re.search(r"subtitle\s*:\s*\{", updated):
            updated, fa_count = replace_quoted_field(updated, "fa", subtitle)
            updated, en_count = replace_quoted_field(updated, "en", subtitle)
            if fa_count != 1 or en_count != 1:
                sys.stderr.write('Could not find subtitle.fa / subtitle.en in the template.\n')
                sys.exit(1)
        else:
            updated, count = replace_quoted_field(updated, "subtitle", subtitle)
            if count != 1:
                sys.stderr.write('Could not find a subtitle field in the template.\n')
                sys.exit(1)

    if logo:
        for key in LOGO_KEYS:
            updated, count = replace_quoted_field(updated, key, logo)
            if count == 1:
                break
        else:
            sys.stderr.write('Could not find a logo URL field (logoUrl / logo) in the template.\n')
            sys.exit(1)

    return updated

def patch_html_fallback(text: str):
    if name:
        text, n = re.subn(
            rf'(<[^>]*\bid=["\']brand-title["\'][^>]*>)([^<]*)(</[^>]+>)',
            lambda m: m.group(1) + html_text(name) + m.group(3),
            text,
            count=1,
        )
        if n == 0:
            text, _ = re.subn(
                r"(<title>)([^<]*)(</title>)",
                lambda m: m.group(1) + html_text(name) + m.group(3),
                text,
                count=1,
            )

    if subtitle:
        text, _ = re.subn(
            rf'(<[^>]*\bid=["\']brand-subtitle["\'][^>]*>)([^<]*)(</[^>]+>)',
            lambda m: m.group(1) + html_text(subtitle) + m.group(3),
            text,
            count=1,
        )

    if logo:
        text, n = re.subn(
            rf'(<[^>]*\bid=["\']brand-img["\'][^>]*\ssrc=["\'])([^"\']*)(["\'])',
            lambda m: m.group(1) + attr_quote(logo) + m.group(3),
            text,
            count=1,
        )
        if n == 0:
            text, _ = re.subn(
                rf'(<[^>]*\bid=["\']brand-img["\'][^>]*)(>)',
                lambda m: m.group(1) + ' src="' + attr_quote(logo) + '"' + m.group(2),
                text,
                count=1,
            )

    return text

brand_key, bounds = find_brand_object(html)
if not brand_key:
    sys.stderr.write(
        "Brand config object not found. Expected one of: "
        + ", ".join(BRAND_OBJECT_KEYS)
        + "\n"
    )
    sys.exit(1)

start, end = bounds
block = html[start:end]
html = html[:start] + patch_brand_object(block) + html[end:]
html = patch_html_fallback(html)

if find_brand_object(html)[0] is None:
    sys.stderr.write("Brand config object missing after patch.\n")
    sys.exit(1)

if re.search(r"\};RAND\s*=", html):
    sys.stderr.write("Template JavaScript was corrupted during branding.\n")
    sys.exit(1)

if len(html) < original_len * 0.90:
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
  local answer

  log_blank
  log_line "${C_BOLD}Restart Pasarguard?${C_RESET}"
  log_line "${C_DIM}If you previously used other templates, a restart is not required.${C_RESET}"
  log_line "${C_DIM}If this is your first install, you should restart.${C_RESET}"
  log_blank
  read_tty "$(printf '%b' "${C_BOLD}Restart now? [Y/n]: ${C_RESET}")" answer
  answer="${answer:-y}"

  case "${answer,,}" in
    y|yes)
      ;;
    *)
      info "Skipped Pasarguard restart. Run manually later if needed: pasarguard restart"
      return 0
      ;;
  esac

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

  log_line "${C_YELLOW}${C_BOLD}--- PGClock Pro Brand Setup ---${C_RESET}"
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
  local backup

  info "Installing ${C_BOLD}PGClock Pro${C_RESET}..."
  prompt_pro_branding

  download_template "$URL_PRO" "$TARGET_FILE"

  backup="${TARGET_FILE}.bak"
  cp "$TARGET_FILE" "$backup"
  if ! apply_brand_pro "$TARGET_FILE"; then
    mv "$backup" "$TARGET_FILE"
    fail "Pro branding failed. Restored the downloaded Pro template."
  fi
  rm -f "$backup"
}

print_success_box() {
  local edition="$1"
  log_blank
  hr
  log_line "${C_GREEN}${C_BOLD}  Installation complete${C_RESET}"
  log_blank
  log_line "  ${C_BOLD}Template:${C_RESET} ${edition}"
  log_line "  ${C_BOLD}Path:${C_RESET}     ${TARGET_FILE}"
  log_line "  ${C_BOLD}Env:${C_RESET}      ${ENV_FILE}"
  log_blank
  log_line "  Your subscription page is ready."
  hr
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
