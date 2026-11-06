# rudesk

Интерактивная установка персонального [RustDesk Server OSS](https://github.com/rustdesk/rustdesk-server) (`hbbs` + `hbbr`) на чистый VPS **Debian / Ubuntu**.

Все необходимые бинарники лежат в этом репозитории (`vendor/`). Установщик **не скачивает** артефакты с Docker Hub, сторонних installer-репозиториев или upstream GitHub в момент установки — это исключает битые ссылки со временем.

## Установка одной командой

После публикации репозитория на GitHub подставьте своего владельца (`Tuma58`) и выполните на VPS от root:

```bash
curl -fsSL https://github.com/Tuma58/rudesk/archive/refs/heads/main.tar.gz | tar xz && sudo bash rudesk-main/install.sh
```

Команда скачивает **архив этого репозитория** (скрипты + вендорные `hbbs`/`hbbr`) и запускает мастер установки.

Локально из клона:

```bash
sudo bash install.sh
```

## Что делает установщик

1. Проверяет Debian/Ubuntu и архитектуру (`amd64` / `arm64`)
2. Сверяет SHA256 бинарников из `vendor/rustdesk-server/`
3. Спрашивает адрес сервера (публичный IP или домен), UFW и опцию always-relay
4. Ставит `hbbs`/`hbbr` в `/opt/rudesk/bin` и включает systemd-сервисы `rudesk-hbbs` / `rudesk-hbbr`
5. Пишет параметры клиента в `/opt/rudesk/CONNECTION.txt`

## Порты

| Порт | Протокол | Назначение |
|------|----------|------------|
| 21115 | TCP | NAT type test |
| 21116 | TCP/UDP | ID / hole punching |
| 21117 | TCP | Relay |
| 21118–21119 | TCP | Web-клиент (опционально) |

Откройте их у облачного провайдера (security group / firewall). Мастер может настроить UFW на самом сервере.

## Клиент RustDesk

После установки откройте `/opt/rudesk/CONNECTION.txt` или вывод в консоли и в клиенте:

**Settings → Network**

- **ID server** = ваш IP или домен  
- **Key** = публичный ключ с сервера  

Клиент: [rustdesk/rustdesk](https://github.com/rustdesk/rustdesk)

## Обновление и удаление

Обновление из нового снимка **этого** репозитория (снова скачайте архив/клон, затем):

```bash
sudo bash update.sh
```

Удаление:

```bash
sudo bash /opt/rudesk/uninstall.sh
```

## Состав репозитория

```text
install.sh / update.sh / uninstall.sh
lib/                 # логика установщика
systemd/             # unit-файлы
vendor/rustdesk-server/
  VERSION            # сейчас 1.1.16
  SHA256SUMS
  amd64/hbbs hbbr
  arm64/hbbs hbbr
  LICENSE            # AGPL-3.0 upstream
  SOURCE.txt
```

## Обновление вендорных бинарников (для мейнтейнеров)

На машине разработчика, не на пользовательском VPS:

1. Скачать release zip с upstream RustDesk Server OSS  
2. Положить `hbbs`/`hbbr` в `vendor/rustdesk-server/{amd64,arm64}/`  
3. Обновить `VERSION` и пересчитать `SHA256SUMS`  
4. Закоммитить в **этот** репозиторий  

После этого пользователи получают новые бинарники вместе с архивом rudesk — без зависимости от живых URL upstream.

## Требования

- Чистый VPS: Debian 11+ или Ubuntu 22.04+
- root / sudo
- Архитектура x86_64 или aarch64
