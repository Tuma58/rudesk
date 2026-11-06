#!/usr/bin/env bash
# Обновление бинарников/unit-файлов rudesk из дерева этого репозитория
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export RUDESK_ROOT="${ROOT}"

# shellcheck disable=SC1091
source "${RUDESK_ROOT}/lib/common.sh"
# shellcheck disable=SC1091
source "${RUDESK_ROOT}/lib/os.sh"
# shellcheck disable=SC1091
source "${RUDESK_ROOT}/lib/verify.sh"
# shellcheck disable=SC1091
source "${RUDESK_ROOT}/lib/deploy.sh"

require_root "$@"

if [[ ! -f "${RUDESK_OPT_DIR}/rudesk.env" ]]; then
  die "rudesk не установлен (${RUDESK_OPT_DIR}/rudesk.env отсутствует). Сначала install.sh"
fi

# shellcheck disable=SC1091
source "${RUDESK_OPT_DIR}/rudesk.env"
RUDESK_HOST="${RUDESK_HOST:?}"
RUDESK_BEHIND_NAT="${RUDESK_BEHIND_NAT:-0}"
RUDESK_LAN_IP="${RUDESK_LAN_IP:-}"
RUDESK_ALWAYS_RELAY=0
[[ "${ALWAYS_USE_RELAY:-N}" == "Y" ]] && RUDESK_ALWAYS_RELAY=1

detect_arch
verify_vendor
install_binaries
install_systemd_units
wait_for_key
write_connection_info
ok "Обновление завершено"
