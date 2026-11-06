#!/usr/bin/env bash
# shellcheck shell=bash

detect_wan_ip() {
  local ip=""
  if command -v dig >/dev/null 2>&1; then
    ip="$(dig +short myip.opendns.com @resolver1.opendns.com 2>/dev/null | head -n1 || true)"
  fi
  if [[ -z "${ip}" ]] && command -v curl >/dev/null 2>&1; then
    ip="$(curl -4 -fsS --max-time 5 https://ifconfig.me/ip 2>/dev/null || true)"
  fi
  if [[ -z "${ip}" ]] && command -v curl >/dev/null 2>&1; then
    ip="$(curl -4 -fsS --max-time 5 https://api.ipify.org 2>/dev/null || true)"
  fi
  printf '%s' "${ip}"
}

run_wizard() {
  echo
  printf '%s' "${C_BOLD}"
  echo "=== Мастер установки rudesk (RustDesk Server OSS) ==="
  printf '%s\n' "${C_RESET}"

  local choice wanip
  echo "Адрес сервера для клиентов RustDesk:"
  echo "  1) Автоопределить публичный IP"
  echo "  2) Указать домен или IP вручную"
  read -r -p "Выбор [1/2]: " choice || true
  case "${choice}" in
    2)
      read -r -p "Домен или IP: " wanip
      [[ -n "${wanip}" ]] || die "Адрес не может быть пустым."
      ;;
    *)
      wanip="$(detect_wan_ip)"
      if [[ -z "${wanip}" ]]; then
        warn "Не удалось определить WAN IP автоматически."
        read -r -p "Введите домен или IP вручную: " wanip
        [[ -n "${wanip}" ]] || die "Адрес не может быть пустым."
      else
        ok "Обнаружен IP: ${wanip}"
        if ! confirm "Использовать ${wanip}?"; then
          read -r -p "Введите домен или IP: " wanip
          [[ -n "${wanip}" ]] || die "Адрес не может быть пустым."
        fi
      fi
      ;;
  esac
  RUDESK_HOST="${wanip}"

  RUDESK_SETUP_UFW=0
  if confirm "Открыть порты RustDesk через UFW (21115-21119/tcp, 21116/udp)?"; then
    RUDESK_SETUP_UFW=1
  fi

  RUDESK_ALWAYS_RELAY=0
  if confirm "Принудительно использовать relay (ALWAYS_USE_RELAY)? Обычно не нужно."; then
    RUDESK_ALWAYS_RELAY=1
  fi

  echo
  log "Параметры:"
  echo "  Хост:          ${RUDESK_HOST}"
  echo "  UFW:           $([[ ${RUDESK_SETUP_UFW} -eq 1 ]] && echo да || echo нет)"
  echo "  Always relay:  $([[ ${RUDESK_ALWAYS_RELAY} -eq 1 ]] && echo да || echo нет)"
  echo
  confirm "Начать установку?" || die "Установка отменена."
}
