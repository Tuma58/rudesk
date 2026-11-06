#!/usr/bin/env bash
# shellcheck shell=bash

configure_ufw() {
  [[ "${RUDESK_SETUP_UFW:-0}" == "1" ]] || return 0

  ensure_cmd ufw
  log "Настройка UFW..."

  # Не рушим SSH, если ufw ещё не активен
  if ! ufw status | grep -qi "Status: active"; then
    ufw allow OpenSSH >/dev/null 2>&1 || ufw allow 22/tcp >/dev/null 2>&1 || true
  fi

  ufw allow 21115:21119/tcp comment 'rudesk rustdesk tcp' >/dev/null
  ufw allow 21116/udp comment 'rudesk rustdesk udp' >/dev/null

  if ! ufw status | grep -qi "Status: active"; then
    warn "Включаю UFW (ssh уже разрешён, если удалось)."
    ufw --force enable >/dev/null
  else
    ufw reload >/dev/null || true
  fi

  ok "Порты RustDesk открыты в UFW"
}
