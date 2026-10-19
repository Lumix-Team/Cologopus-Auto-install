#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
#  LUMIX TEAM — Calagopus Panel Auto-Installer (Docker AIO + Nginx + SSL)
#  Repository: https://github.com/Lumix-Team/Cologopus-Auto-install
#  License: MIT License (c) Lumix Team
#  Developed with the assistance of AI | Разработано с использованием ИИ
#  Usage / Использование: sudo bash install_calagopus.sh [DOMAIN] [EMAIL] [en|ru]
# ==============================================================================

# Цвета для оформления
PURPLE='\033[1;35m'
CYAN='\033[1;36m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
RED='\033[1;31m'
NC='\033[0m'

echo -e "${PURPLE}==============================================================${NC}"
echo -e "${CYAN}                ✨  L U M I X   T E A M  ✨                   ${NC}"
echo -e "${PURPLE}       Calagopus Panel Auto-Installer (Docker + Nginx + SSL)  ${NC}"
echo -e "${PURPLE}==============================================================${NC}"

# Аргументы командной строки: $1 = DOMAIN, $2 = EMAIL, $3 = LANG (en/ru)
DOMAIN="${1:-}"
EMAIL="${2:-}"
LANG_CHOICE="${3:-}"

# Выбор языка / Language selection
if [[ -z "$LANG_CHOICE" ]]; then
  echo ""
  echo "Select language / Выберите язык:"
  echo "  1) Русский (RU)"
  echo "  2) English (EN)"
  read -rp "Enter 1 or 2 / Введите 1 или 2 [default/по умолчанию: 1]: " LANG_INPUT < /dev/tty
  case "${LANG_INPUT:-1}" in
    2|en|EN|eng) LANG_CHOICE="en" ;;
    *) LANG_CHOICE="ru" ;;
  esac
fi

# Локализация сообщений / Localization strings
if [[ "$LANG_CHOICE" == "en" ]]; then
  ERR_ROOT="❌ Error: Please run this script as root (e.g., sudo bash $0)"
  PROMPT_DOMAIN="Enter your panel domain (e.g., panel.example.com): "
  PROMPT_EMAIL="Enter your Email (for Let's Encrypt SSL notifications): "
  ERR_EMPTY="❌ Error: Domain and Email are required to issue an SSL certificate!"
  STEP1="=== [1/6] Updating system and installing packages (Nginx, Certbot) ==="
  STEP2="=== [2/6] Installing and optimizing Docker ==="
  DOCKER_SKIP="Docker is already installed, skipping..."
  STEP3="=== [3/6] Downloading the latest Calagopus stack ==="
  COMPOSE_KEEP="compose.yml already exists, keeping existing keys..."
  STEP4="=== [4/6] Pulling latest images (with timeout protection) and starting ==="
  ERR_PULL="❌ Failed to pull Docker images after 5 attempts. Check your VDS network."
  RETRY_MSG="⚠️ Connection timed out. Retrying pull"
  STEP5="=== [5/6] Configuring Nginx reverse proxy for"
  STEP6="=== [6/6] Issuing SSL certificate and enabling auto-renewal bot ==="
  DONE_TITLE="✅ Installation successfully completed by Lumix Team!"
  DONE_URL="🌐 Panel URL:"
  DONE_SSL="🔒 SSL Auto-Renewal is active (timer: systemctl status certbot.timer)"
  DONE_DIR="📂 Working directory:"
  DONE_UPD="🔄 Command to update panel in the future:"
else
  ERR_ROOT="❌ Ошибка: Запустите скрипт от имени root (например: sudo bash $0)"
  PROMPT_DOMAIN="Введите ваш домен для панели (например, panel.example.com): "
  PROMPT_EMAIL="Введите ваш Email (для уведомлений Let's Encrypt): "
  ERR_EMPTY="❌ Ошибка: Домен и Email обязательны для выпуска SSL-сертификата!"
  STEP1="=== [1/6] Обновление системы и установка пакетов (Nginx, Certbot) ==="
  STEP2="=== [2/6] Установка и оптимизация Docker ==="
  DOCKER_SKIP="Docker уже установлен, пропускаем..."
  STEP3="=== [3/6] Загрузка актуального стека Calagopus ==="
  COMPOSE_KEEP="Конфигурация compose.yml уже существует, сохраняем текущие ключи..."
  STEP4="=== [4/6] Загрузка последних образов (с защитой от тайм-аута) и запуск ==="
  ERR_PULL="❌ Не удалось скачать образы после 5 попыток. Проверьте интернет-канал VDS."
  RETRY_MSG="⚠️ Обрыв соединения. Попытка докачки"
  STEP5="=== [5/6] Настройка обратного прокси Nginx для"
  STEP6="=== [6/6] Получение SSL-сертификата и настройка бота автопродления ==="
  DONE_TITLE="✅ Установка от Lumix Team полностью завершена!"
  DONE_URL="🌐 Панель управления доступна по адресу:"
  DONE_SSL="🔒 Автопродление SSL активно (таймер: systemctl status certbot.timer)"
  DONE_DIR="📂 Рабочая директория панели:"
  DONE_UPD="🔄 Команда для обновления панели в будущем:"
fi

# Проверка прав root
if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}${ERR_ROOT}${NC}"
  exit 1
fi

if [[ -z "$DOMAIN" ]]; then
  read -rp "$PROMPT_DOMAIN" DOMAIN < /dev/tty
fi

if [[ -z "$EMAIL" ]]; then
  read -rp "$PROMPT_EMAIL" EMAIL < /dev/tty
fi

if [[ -z "$DOMAIN" || -z "$EMAIL" ]]; then
  echo -e "${RED}${ERR_EMPTY}${NC}"
  exit 1
fi

echo -e "${CYAN}${STEP1}${NC}"
export DEBIAN_FRONTEND=noninteractive
apt-get update && apt-get upgrade -y
apt-get install -y curl git ca-certificates gnupg lsb-release nginx certbot python3-certbot-nginx openssl

systemctl enable --now nginx

echo -e "${CYAN}${STEP2}${NC}"
if ! command -v docker &> /dev/null; then
    curl -fsSL https://get.docker.com | CHANNEL=stable bash
    systemctl enable --now docker
else
    echo "$DOCKER_SKIP"
fi

# Оптимизация загрузки слоев Docker для VDS со слабым каналом до ghcr.io
mkdir -p /etc/docker
if [ ! -f /etc/docker/daemon.json ]; then
cat > /etc/docker/daemon.json <<EOF
{
  "max-concurrent-downloads": 2,
  "max-download-attempts": 10
}
EOF
systemctl restart docker
fi

echo -e "${CYAN}${STEP3}${NC}"
INSTALL_DIR="/opt/calagopus-panel"
mkdir -p "$INSTALL_DIR"
cd "$INSTALL_DIR"

if [ ! -f compose.yml ]; then
    curl -fL --retry 5 --retry-delay 3 https://raw.githubusercontent.com/calagopus/panel/main/compose.heavy.aio.yml -o compose.yml
    RANDOM_KEY=$(openssl rand -hex 16)
    sed -i "s/CHANGEME/$RANDOM_KEY/g" compose.yml
    sed -i 's/"8000:8000"/"127.0.0.1:8000:8000"/g' compose.yml
else
    echo "$COMPOSE_KEEP"
fi

if [ ! -f wings-config.yml ]; then
    echo 'app_name: Calagopus' > wings-config.yml
fi

echo -e "${CYAN}${STEP4}${NC}"
MAX_RETRIES=5
COUNT=1
until docker compose pull; do
    if [ "$COUNT" -ge "$MAX_RETRIES" ]; then
        echo -e "${RED}${ERR_PULL}${NC}"
        exit 1
    fi
    echo -e "${YELLOW}${RETRY_MSG} $((COUNT+1))/${MAX_RETRIES} (5s)...${NC}"
    sleep 5
    COUNT=$((COUNT+1))
done

docker compose up -d

echo -e "${CYAN}${STEP5} ${DOMAIN} ===${NC}"
cat > "/etc/nginx/sites-available/${DOMAIN}.conf" <<EOF
server {
    listen 80;
    listen [::]:80;
    server_name ${DOMAIN};

    client_max_body_size 100M;

    location / {
        proxy_pass http://127.0.0.1:8000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_buffering off;
        proxy_request_buffering off;
    }
}
EOF

ln -sf "/etc/nginx/sites-available/${DOMAIN}.conf" "/etc/nginx/sites-enabled/${DOMAIN}.conf"

nginx -t && systemctl reload nginx

echo -e "${CYAN}${STEP6}${NC}"
certbot --nginx -d "$DOMAIN" --non-interactive --agree-tos -m "$EMAIL" --redirect

mkdir -p /etc/letsencrypt/renewal-hooks/deploy
cat > /etc/letsencrypt/renewal-hooks/deploy/reload-nginx.sh << 'EOF'
#!/usr/bin/env bash
systemctl reload nginx
EOF
chmod +x /etc/letsencrypt/renewal-hooks/deploy/reload-nginx.sh

systemctl enable --now certbot.timer

echo -e "${PURPLE}==============================================================${NC}"
echo -e "${GREEN}${DONE_TITLE}${NC}"
echo -e "${DONE_URL} ${CYAN}https://${DOMAIN}${NC}"
echo -e "${DONE_SSL}"
echo -e "${DONE_DIR} ${INSTALL_DIR}"
echo -e "${DONE_UPD}"
echo -e "   cd ${INSTALL_DIR} && docker compose pull && docker compose up -d"
echo -e "${PURPLE}==============================================================${NC}"
