#!/usr/bin/env bash
#
# PGClock Installer for Pasarguard
# https://github.com/Mrclocks/PGClock
#
set -euo pipefail

readonly SCRIPT_VERSION="1.1.0"
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
  log_line "${C_CYAN}${C_BOLD}║${C_RESET}                     ${C_DIM}نسخه ${SCRIPT_VERSION}${C_RESET}                         ${C_CYAN}${C_BOLD}║${C_RESET}"
  log_line "${C_CYAN}${C_BOLD}╚══════════════════════════════════════════════════════════════╝${C_RESET}"
  log_blank
}

ok()   { log_line "${C_GREEN}✔${C_RESET}  $*"; }
info() { log_line "${C_BLUE}→${C_RESET}  $*"; }
warn() { log_line "${C_YELLOW}!${C_RESET}  $*"; }
fail() { log_line "${C_RED}✖${C_RESET}  $*"; exit 1; }

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || fail "ابزار «$1» یافت نشد. ابتدا نصب کنید: apt update && apt install -y $1"
}

require_root() {
  if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
    fail "این اسکریپت باید با root اجرا شود. دوباره با sudo امتحان کنید."
  fi
}

check_system() {
  info "بررسی پیش‌نیازها..."
  need_cmd wget
  need_cmd curl
  need_cmd python3
  need_cmd grep
  need_cmd sed
  need_cmd mktemp

  if [[ ! -f "$ENV_FILE" ]]; then
    warn "فایل ${ENV_FILE} پیدا نشد. مسیر را بررسی کنید؛ ادامه می‌دهیم."
  fi

  if ! command -v pasarguard >/dev/null 2>&1; then
    warn "دستور pasarguard پیدا نشد. در پایان ممکن است نیاز به ریستارت دستی داشته باشید."
  fi

  ok "پیش‌نیازها آماده است"
}

ensure_target_dir() {
  info "ساخت مسیر قالب..."
  mkdir -p "$TARGET_DIR"
  ok "مسیر ${TARGET_DIR} آماده است"
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
  info "دریافت فایل از GitHub..."
  wget -N -O "$dest" "$url" || fail "دانلود قالب ناموفق بود. اتصال اینترنت یا آدرس را بررسی کنید."
  [[ -s "$dest" ]] || fail "فایل دریافت‌شده خالی است."
  ok "فایل index.html دریافت شد"
}

apply_brand_pro() {
  local src="$1"
  local dest="$2"

  info "اعمال تنظیمات برند PGClock Pro..."
  BRAND_NAME="${BRAND_NAME:-}" BRAND_SUBTITLE="${BRAND_SUBTITLE:-}" BRAND_LOGO="${BRAND_LOGO:-}" \
  python3 - "$src" "$dest" <<'PY'
import os
import re
import sys

src, dest = sys.argv[1], sys.argv[2]
name = os.environ.get("BRAND_NAME", "").strip()
subtitle = os.environ.get("BRAND_SUBTITLE", "").strip()
logo = os.environ.get("BRAND_LOGO", "").strip()

with open(src, "r", encoding="utf-8") as f:
    html = f.read()

def js_quote(value: str) -> str:
    return (
        value.replace("\\", "\\\\")
        .replace('"', '\\"')
        .replace("\r", "")
        .replace("\n", "\\n")
    )

def html_text(value: str) -> str:
    return value.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")

block = re.search(r"var DEFAULT_BRAND = \{.*?\n  \};", html, re.DOTALL)
if not block:
    sys.stderr.write("DEFAULT_BRAND block not found in template.\n")
    sys.exit(1)

segment = block.group(0)

if name:
    segment = re.sub(r'(name:\s*")[^"]*(")', r"\1" + js_quote(name) + r"\2", segment, count=1)
    html = re.sub(
        r'(<h1 class="brand-title" id="brand-title">)[^<]*(</h1>)',
        r"\1" + html_text(name) + r"\2",
        html,
        count=1,
    )

if subtitle:
    esc = js_quote(subtitle)
    segment = re.sub(r'(fa:\s*")[^"]*(")', r"\1" + esc + r"\2", segment, count=1)
    segment = re.sub(r'(en:\s*")[^"]*(")', r"\1" + esc + r"\2", segment, count=1)
    html = re.sub(
        r'(<p class="brand-sub" id="brand-subtitle">)[^<]*(</p>)',
        r"\1" + html_text(subtitle) + r"\2",
        html,
        count=1,
    )

if logo:
    segment = re.sub(r'(logoUrl:\s*")[^"]*(")', r"\1" + js_quote(logo) + r"\2", segment, count=1)

html = html[: block.start()] + segment + html[block.end() :]

with open(dest, "w", encoding="utf-8") as f:
    f.write(html)
PY
  ok "تنظیمات برند در فایل HTML اعمال شد"
}

configure_env() {
  info "به‌روزرسانی ${ENV_FILE}..."

  local tmp
  tmp="$(mktemp)"

  if [[ -f "$ENV_FILE" ]]; then
    cp "$ENV_FILE" "$tmp"
  else
    : > "$tmp"
    warn "فایل .env ساخته شد."
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

  ok "تنظیمات .env اعمال شد"
}

restart_pasarguard() {
  info "ری‌استارت سرویس Pasarguard..."
  if command -v pasarguard >/dev/null 2>&1; then
    if pasarguard restart; then
      ok "Pasarguard با موفقیت ری‌استارت شد"
    else
      warn "ری‌استارت خودکار ناموفق بود. دستی اجرا کنید: pasarguard restart"
    fi
  else
    warn "دستور pasarguard در دسترس نیست. پس از نصب دستی ری‌استارت کنید."
  fi
}

print_menu() {
  log_line "${C_BOLD}انتخاب قالب:${C_RESET}"
  log_blank
  log_line "  ${C_GREEN}1${C_RESET}) ${C_BOLD}PGClock Lite${C_RESET}   ${C_DIM}نسخه سبک و سریع${C_RESET}"
  log_line "  ${C_CYAN}2${C_RESET}) ${C_BOLD}PGClock${C_RESET}        ${C_DIM}نسخه استاندارد (پیشنهادی)${C_RESET}"
  log_line "  ${C_YELLOW}3${C_RESET}) ${C_BOLD}PGClock Pro${C_RESET}     ${C_DIM}شخصی‌سازی نام برند، شعار و لوگو${C_RESET}"
  log_line "  ${C_RED}0${C_RESET}) ${C_BOLD}خروج${C_RESET}"
  log_blank
}

prompt_pro_branding() {
  local brand_name brand_subtitle brand_logo

  log_line "${C_YELLOW}${C_BOLD}─── شخصی‌سازی PGClock Pro ───${C_RESET}"
  log_blank
  log_line "${C_DIM}Enter برای رد کردن هر مورد و استفاده از مقدار پیش‌فرض${C_RESET}"
  log_blank

  read_tty "$(printf '%b' "${C_BOLD}نام برند${C_RESET} (مثال: MrClock): ")" brand_name
  brand_name="${brand_name:-}"

  read_tty "$(printf '%b' "${C_BOLD}شعار / کپشن${C_RESET} (مثال: پنل اشتراک): ")" brand_subtitle
  brand_subtitle="${brand_subtitle:-}"

  while true; do
    read_tty "$(printf '%b' "${C_BOLD}آدرس URL لوگو${C_RESET} (https://...): ")" brand_logo
    brand_logo="${brand_logo:-}"
    if [[ -z "$brand_logo" ]]; then
      break
    fi
    if validate_logo_url "$brand_logo"; then
      ok "آدرس لوگو معتبر است"
      break
    fi
    warn "آدرس لوگو نامعتبر است یا در دسترس نیست. URL کامل https:// وارد کنید یا Enter بزنید تا رد شود."
  done

  export BRAND_NAME="$brand_name"
  export BRAND_SUBTITLE="$brand_subtitle"
  export BRAND_LOGO="$brand_logo"
}

install_lite() {
  info "نصب ${C_BOLD}PGClock Lite${C_RESET}..."
  download_template "$URL_LITE" "$TARGET_FILE"
}

install_standard() {
  info "نصب ${C_BOLD}PGClock${C_RESET}..."
  download_template "$URL_STANDARD" "$TARGET_FILE"
}

install_pro() {
  local tmp_file

  info "نصب ${C_BOLD}PGClock Pro${C_RESET}..."
  prompt_pro_branding

  tmp_file="$(mktemp)"
  download_template "$URL_PRO" "$tmp_file"
  apply_brand_pro "$tmp_file" "$TARGET_FILE"
  rm -f "$tmp_file"
}

print_success_box() {
  local edition="$1"
  log_blank
  log_line "${C_GREEN}${C_BOLD}╔══════════════════════════════════════════════════════════════╗${C_RESET}"
  log_line "${C_GREEN}${C_BOLD}║${C_RESET}                     ${C_WHITE}${C_BOLD}نصب با موفقیت انجام شد${C_RESET}                     ${C_GREEN}${C_BOLD}║${C_RESET}"
  log_line "${C_GREEN}${C_BOLD}╠══════════════════════════════════════════════════════════════╣${C_RESET}"
  log_line "${C_GREEN}${C_BOLD}║${C_RESET}  ${C_BOLD}قالب:${C_RESET} ${edition}"
  log_line "${C_GREEN}${C_BOLD}║${C_RESET}  ${C_BOLD}مسیر:${C_RESET} ${TARGET_FILE}"
  log_line "${C_GREEN}${C_BOLD}║${C_RESET}  ${C_BOLD}env:${C_RESET}  ${ENV_FILE}"
  log_line "${C_GREEN}${C_BOLD}╠══════════════════════════════════════════════════════════════╣${C_RESET}"
  log_line "${C_GREEN}${C_BOLD}║${C_RESET}  صفحه اشتراک کاربران آماده است.                             ${C_GREEN}${C_BOLD}║${C_RESET}"
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
    read_tty "$(printf '%b' "${C_BOLD}گزینه مورد نظر را وارد کنید [0-3]: ${C_RESET}")" choice
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
        info "نصب لغو شد."
        exit 0
        ;;
      *)
        warn "گزینه نامعتبر است. عدد 0 تا 3 وارد کنید."
        log_blank
        ;;
    esac
  done

  configure_env
  restart_pasarguard
  print_success_box "$edition"
}

main "$@"
