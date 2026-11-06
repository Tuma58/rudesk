#!/usr/bin/env bash
# shellcheck shell=bash

set -euo pipefail

RUDESK_OPT_DIR="${RUDESK_OPT_DIR:-/opt/rudesk}"
RUDESK_DATA_DIR="${RUDESK_DATA_DIR:-/var/lib/rudesk}"
RUDESK_LOG_DIR="${RUDESK_LOG_DIR:-/var/log/rudesk}"
RUDESK_BIN_DIR="${RUDESK_OPT_DIR}/bin"

# На минимальных VPS PATH часто без /usr/sbin — ufw/systemctl живут там
export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:${PATH:-}"

if [[ -t 1 ]]; then
  C_RESET=$'\033[0m'
  C_BOLD=$'\033[1m'
  C_GREEN=$'\033[32m'
  C_YELLOW=$'\033[33m'
  C_RED=$'\033[31m'
  C_CYAN=$'\033[36m'
else
  C_RESET="" C_BOLD="" C_GREEN="" C_YELLOW="" C_RED="" C_CYAN=""
fi

log()  { printf '%s[*]%s %s\n' "$C_CYAN" "$C_RESET" "$*"; }
ok()   { printf '%s[+]%s %s\n' "$C_GREEN" "$C_RESET" "$*"; }
warn() { printf '%s[!]%s %s\n' "$C_YELLOW" "$C_RESET" "$*"; }
die()  { printf '%s[x]%s %s\n' "$C_RED" "$C_RESET" "$*" >&2; exit 1; }

require_root() {
  if [[ "${EUID}" -ne 0 ]]; then
    if command -v sudo >/dev/null 2>&1; then
      log "Нужны права root — перезапуск через sudo..."
      exec sudo -E env "RUDESK_ROOT=${RUDESK_ROOT:-}" "RUDESK_ARCHIVE_URL=${RUDESK_ARCHIVE_URL:-}" bash "$0" "$@"
    fi
    die "Запустите от root или с sudo."
  fi
}

confirm() {
  local prompt="${1:-Продолжить?}"
  local reply
  read -r -p "${prompt} [y/N]: " reply || true
  [[ "${reply}" =~ ^[YyДд]$ ]]
}

ensure_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "Не найдена команда: $1"
}

# ufw ставится в /usr/sbin; без sbin в PATH command -v «не видит» уже установленный пакет
rudesk_ufw_bin() {
  if command -v ufw >/dev/null 2>&1; then
    command -v ufw
  elif [[ -x /usr/sbin/ufw ]]; then
    printf '%s\n' /usr/sbin/ufw
  elif [[ -x /sbin/ufw ]]; then
    printf '%s\n' /sbin/ufw
  else
    return 1
  fi
}
