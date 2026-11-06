#!/usr/bin/env bash
# shellcheck shell=bash

configure_ufw() {
  [[ "${RUDESK_SETUP_UFW:-0}" == "1" ]] || return 0

  local ufw_bin
  ufw_bin="$(rudesk_ufw_bin)" || die "ufw не найден. Установите: apt-get install -y ufw"

  log "Настройка UFW (${ufw_bin})..."

  # Не рушим SSH, если ufw ещё не активен
  if ! "${ufw_bin}" status | grep -qi "Status: active"; then
    "${ufw_bin}" allow OpenSSH >/dev/null 2>&1 || "${ufw_bin}" allow 22/tcp >/dev/null 2>&1 || true
  fi

  "${ufw_bin}" allow 21115:21119/tcp comment 'rudesk rustdesk tcp' >/dev/null
  "${ufw_bin}" allow 21116/udp comment 'rudesk rustdesk udp' >/dev/null

  if ! "${ufw_bin}" status | grep -qi "Status: active"; then
    warn "Включаю UFW (ssh уже разрешён, если удалось)."
    "${ufw_bin}" --force enable >/dev/null
  else
    "${ufw_bin}" reload >/dev/null || true
  fi

  ok "Порты RustDesk открыты в UFW"
}
