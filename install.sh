#!/usr/bin/env bash
# rudesk — интерактивная установка персонального RustDesk Server OSS
# Все бинарники и unit-файлы поставляются из этого репозитория (vendor/).
set -euo pipefail

bootstrap_from_archive() {
  # shellcheck disable=SC1091
  if [[ -f "${1:-}/repo.conf" ]]; then
    # shellcheck source=/dev/null
    source "${1}/repo.conf"
  fi

  if [[ -z "${RUDESK_ARCHIVE_URL:-}" ]]; then
    cat >&2 <<'EOF'
[x] Скрипт запущен без дерева репозитория (нет vendor/ и lib/).

Установите одной командой из README — она скачивает архив ЭТОГО репозитория
(со всеми вендорными бинарниками) и запускает install.sh локально.

Либо клонируйте репозиторий и выполните:  sudo bash install.sh
Либо задайте RUDESK_ARCHIVE_URL на archive/.tar.gz этого же репозитория.
EOF
    exit 1
  fi

  local tmp
  tmp="$(mktemp -d /tmp/rudesk.XXXXXX)"
  echo "[*] Загрузка архива этого репозитория: ${RUDESK_ARCHIVE_URL}"
  curl -fsSL "${RUDESK_ARCHIVE_URL}" -o "${tmp}/rudesk.tar.gz"
  mkdir -p "${tmp}/src"
  tar -xzf "${tmp}/rudesk.tar.gz" -C "${tmp}/src" --strip-components=1
  export RUDESK_ROOT="${tmp}/src"
  export RUDESK_BOOTSTRAP_TMP="${tmp}"
}

resolve_root() {
  local src="${BASH_SOURCE[0]:-}"
  if [[ -n "${src}" && "${src}" != "-" && "${src}" != "bash" && "${src}" != /dev/fd/* ]]; then
    local dir
    dir="$(cd "$(dirname "${src}")" && pwd)"
    if [[ -d "${dir}/vendor/rustdesk-server" && -d "${dir}/lib" ]]; then
      export RUDESK_ROOT="${dir}"
      return 0
    fi
  fi

  if [[ -n "${RUDESK_ROOT:-}" && -d "${RUDESK_ROOT}/vendor/rustdesk-server" ]]; then
    return 0
  fi

  bootstrap_from_archive "$(pwd)"
}

resolve_root
# shellcheck disable=SC1091
source "${RUDESK_ROOT}/lib/common.sh"
# shellcheck disable=SC1091
source "${RUDESK_ROOT}/lib/os.sh"
# shellcheck disable=SC1091
source "${RUDESK_ROOT}/lib/verify.sh"
# shellcheck disable=SC1091
source "${RUDESK_ROOT}/lib/wizard.sh"
# shellcheck disable=SC1091
source "${RUDESK_ROOT}/lib/firewall.sh"
# shellcheck disable=SC1091
source "${RUDESK_ROOT}/lib/deploy.sh"

cleanup() {
  if [[ -n "${RUDESK_BOOTSTRAP_TMP:-}" && -d "${RUDESK_BOOTSTRAP_TMP}" ]]; then
    rm -rf "${RUDESK_BOOTSTRAP_TMP}"
  fi
}
trap cleanup EXIT

main() {
  require_root "$@"
  detect_os
  detect_arch
  verify_vendor
  install_base_apt
  run_wizard
  install_ufw_apt
  install_binaries
  install_systemd_units
  configure_ufw
  wait_for_key
  write_connection_info
}

main "$@"
