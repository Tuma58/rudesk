#!/usr/bin/env bash
# Удаление rudesk с сервера
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "${ROOT}/lib/common.sh" ]]; then
  # shellcheck disable=SC1091
  source "${ROOT}/lib/common.sh"
elif [[ -f /opt/rudesk/lib/common.sh ]]; then
  # shellcheck disable=SC1091
  source /opt/rudesk/lib/common.sh
else
  echo "Не найден lib/common.sh" >&2
  exit 1
fi

require_root "$@"

log "Остановка сервисов..."
systemctl stop rudesk-hbbs.service rudesk-hbbr.service 2>/dev/null || true
systemctl disable rudesk-hbbs.service rudesk-hbbr.service 2>/dev/null || true
rm -f /etc/systemd/system/rudesk-hbbs.service /etc/systemd/system/rudesk-hbbr.service
systemctl daemon-reload
systemctl reset-failed 2>/dev/null || true

log "Удаление ${RUDESK_OPT_DIR}..."
rm -rf "${RUDESK_OPT_DIR}"

if [[ -d "${RUDESK_DATA_DIR}" ]]; then
  if confirm "Удалить данные и ключи (${RUDESK_DATA_DIR})?"; then
    rm -rf "${RUDESK_DATA_DIR}"
    ok "Данные удалены"
  else
    warn "Данные оставлены в ${RUDESK_DATA_DIR}"
  fi
fi

rm -rf "${RUDESK_LOG_DIR}" 2>/dev/null || true
ok "rudesk удалён"
