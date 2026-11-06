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

detect_lan_ip() {
  local ip=""
  if command -v ip >/dev/null 2>&1; then
    ip="$(ip -4 route get 1.1.1.1 2>/dev/null | awk '{for (i=1;i<=NF;i++) if ($i=="src") {print $(i+1); exit}}' || true)"
  fi
  if [[ -z "${ip}" ]] && command -v hostname >/dev/null 2>&1; then
    ip="$(hostname -I 2>/dev/null | awk '{print $1}' || true)"
  fi
  printf '%s' "${ip}"
}

ask_server_host() {
  local choice wanip prompt_extra="${1:-}"
  echo "Адрес сервера для клиентов RustDesk (то, что увидит интернет):"
  if [[ -n "${prompt_extra}" ]]; then
    echo "  ${prompt_extra}"
  fi
  echo "  1) Автоопределить публичный IP"
  echo "  2) Указать домен или публичный IP вручную"
  read -r -p "Выбор [1/2]: " choice || true
  case "${choice}" in
    2)
      read -r -p "Домен или публичный IP: " wanip
      [[ -n "${wanip}" ]] || die "Адрес не может быть пустым."
      ;;
    *)
      wanip="$(detect_wan_ip)"
      if [[ -z "${wanip}" ]]; then
        warn "Не удалось определить WAN IP автоматически."
        read -r -p "Введите домен или публичный IP вручную: " wanip
        [[ -n "${wanip}" ]] || die "Адрес не может быть пустым."
      else
        ok "Обнаружен публичный IP: ${wanip}"
        if ! confirm "Использовать ${wanip}?"; then
          read -r -p "Введите домен или публичный IP: " wanip
          [[ -n "${wanip}" ]] || die "Адрес не может быть пустым."
        fi
      fi
      ;;
  esac
  RUDESK_HOST="${wanip}"
}

run_wizard() {
  echo
  printf '%s' "${C_BOLD}"
  echo "=== Мастер установки rudesk (RustDesk Server OSS) ==="
  printf '%s\n' "${C_RESET}"

  RUDESK_BEHIND_NAT=0
  RUDESK_LAN_IP=""

  echo "Где стоит этот сервер?"
  echo "  1) Публичный VPS / сервер с белым IP (облако)"
  echo "  2) За NAT / роутером (дом, офис, лаборатория)"
  local place
  read -r -p "Выбор [1/2]: " place || true
  case "${place}" in
    2)
      RUDESK_BEHIND_NAT=1
      echo
      ok "Режим: сервер за NAT"
      echo "Клиенты будут подключаться к публичному IP/домену роутера."
      echo "На роутере нужно пробросить порты на локальный IP этой машины."
      echo

      local lan
      lan="$(detect_lan_ip)"
      if [[ -n "${lan}" ]]; then
        ok "Обнаружен локальный IP: ${lan}"
        if confirm "Пробросить порты на ${lan}?"; then
          RUDESK_LAN_IP="${lan}"
        fi
      fi
      if [[ -z "${RUDESK_LAN_IP}" ]]; then
        read -r -p "Локальный (LAN) IP этого сервера в вашей сети: " lan
        [[ -n "${lan}" ]] || die "LAN IP не может быть пустым."
        RUDESK_LAN_IP="${lan}"
      fi

      ask_server_host "За NAT укажите белый IP роутера или домен (DDNS), не ${RUDESK_LAN_IP}."
      print_port_forward_table "${RUDESK_LAN_IP}"
      echo
      warn "Запишите таблицу проброса. Без этих правил снаружи сервер будет недоступен."
      if ! confirm "Порты на роутере уже проброшены или пробросите сразу после установки?"; then
        warn "Можно продолжить установку, но клиенты с интернета заработают только после проброса."
        confirm "Всё равно продолжить?" || die "Установка отменена. Сначала настройте Port Forwarding на роутере."
      fi
      ;;
    *)
      RUDESK_BEHIND_NAT=0
      echo
      ok "Режим: публичный VPS"
      ask_server_host
      echo
      echo "Откройте входящие порты в панели хостинга (Security Group / Firewall):"
      echo "  TCP 21115-21119, UDP 21116"
      echo "  Минимум: TCP 21115-21117 и UDP 21116"
      ;;
  esac

  RUDESK_SETUP_UFW=0
  echo
  if [[ "${RUDESK_BEHIND_NAT}" == "1" ]]; then
    echo "Файрвол UFW на самой машине (дополнительно к пробросу на роутере):"
    echo "  Имеет смысл включить, если на сервере ещё нет своего firewall."
  else
    echo "Файрвол UFW на сервере (дополнительно к правилам в панели хостинга):"
    echo "  Рекомендуется ответить y на чистом VPS — скрипт поставит ufw,"
    echo "  разрешит SSH и порты RustDesk (21115-21119/tcp, 21116/udp)."
  fi
  if confirm "Настроить UFW?"; then
    RUDESK_SETUP_UFW=1
  fi

  RUDESK_ALWAYS_RELAY=0
  echo
  echo "Режим always-relay нужен редко (когда P2P не работает)."
  if [[ "${RUDESK_BEHIND_NAT}" == "1" ]]; then
    echo "За строгим NAT иногда помогает, но сначала проверьте проброс UDP 21116."
  else
    echo "Для личного сервера обычно отвечайте N."
  fi
  if confirm "Включить ALWAYS_USE_RELAY?"; then
    RUDESK_ALWAYS_RELAY=1
  fi

  echo
  log "Параметры:"
  echo "  Режим:         $([[ ${RUDESK_BEHIND_NAT} -eq 1 ]] && echo 'за NAT' || echo 'публичный VPS')"
  echo "  Хост (клиенты): ${RUDESK_HOST}"
  if [[ "${RUDESK_BEHIND_NAT}" == "1" ]]; then
    echo "  LAN IP:         ${RUDESK_LAN_IP}"
  fi
  echo "  UFW:            $([[ ${RUDESK_SETUP_UFW} -eq 1 ]] && echo да || echo нет)"
  echo "  Always relay:   $([[ ${RUDESK_ALWAYS_RELAY} -eq 1 ]] && echo да || echo нет)"
  echo
  confirm "Начать установку?" || die "Установка отменена."
}
