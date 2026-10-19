#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
#  LUMINA TEAM — Calagopus Panel Auto-Installer (Docker AIO + Nginx + SSL)
#  Repository: https://github.com/Lumix-Team/Cologopus-Auto-install
#  License: MIT License (c) Lumina Team
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
echo -e "${CYAN}               ✨  L U M I N A   T E A M  ✨                  ${NC}"
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
  DONE_TITLE="✅ Installation successfully completed by Lumina Team!"
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
  DONE_TITLE="✅ Установка от Lumina Team полностью завершена!"
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
ructure pack: Minecolonies Original
[19:23:19] [Structurize IO Worker #0/INFO]: Registered structure pack: Nordic Spruce
[19:23:19] [Structurize IO Worker #0/INFO]: Registered structure pack: Medieval Spruce
[19:23:19] [Structurize IO Worker #0/INFO]: Registered structure pack: Medieval Oak
[19:23:19] [Structurize IO Worker #0/INFO]: Registered structure pack: Medieval Dark Oak
[19:23:19] [Structurize IO Worker #0/INFO]: Registered structure pack: Medieval Birch
[19:23:19] [Structurize IO Worker #0/INFO]: Registered structure pack: Lost Mesa City
[19:23:19] [Structurize IO Worker #0/INFO]: Registered structure pack: Jungle Treehouse
[19:23:19] [Structurize IO Worker #0/INFO]: Registered structure pack: Incan
[19:23:19] [Structurize IO Worker #0/INFO]: Registered structure pack: Fortress
[19:23:19] [Structurize IO Worker #0/INFO]: Registered structure pack: Dark Oak Treehouse
[19:23:19] [Structurize IO Worker #0/INFO]: Registered structure pack: Colonial
[19:23:19] [Structurize IO Worker #0/INFO]: Registered structure pack: Cavern
[19:23:19] [Structurize IO Worker #0/INFO]: Registered structure pack: Caledonia
[19:23:19] [Structurize IO Worker #0/INFO]: Registered structure pack: Urban Birch
[19:23:19] [Structurize IO Worker #0/INFO]: Registered structure pack: Ancient Athens
[19:23:19] [Structurize IO Worker #0/INFO]: Registered structure pack: Urban Savanna
[19:23:19] [Structurize IO Worker #0/INFO]: Registered structure pack: NooBas_pr
[19:23:19] [Structurize IO Worker #0/WARN]: Finished discovering Client Structure packs
[19:23:57] [Render thread/INFO]: Released client Flux Networks cache
[19:23:57] [Render thread/INFO]: Removed all colony views
[19:23:57] [Render thread/INFO]: Connecting to play.lumixcraft.ru, 4096
[19:23:58] [Render thread/INFO]: Injecting existing registry data into this CLIENT instance
[19:23:59] [Netty Client IO #17/INFO]: Energy blacklist loaded: 1 block entries, 0 item entries
[19:23:59] [Netty Client IO #17/WARN]: Configuration file SimpleCommentedConfig:{pathfinding=SimpleCommentedConfig:{minimumrailstopath=8, pathNodeLimitMultiplier=1.0}, requestSystem=SimpleCommentedConfig:{creativeresolve=false}, permissions=SimpleCommentedConfig:{enablecolonyprotection=true, turnoffexplosionsincolonies=DAMAGE_ENTITIES, permissioneventbypassminpermlevel=2}, claims=SimpleCommentedConfig:{initialColonySize=4, maxColonySize=20, maxdistancefromworldspawn=30000, minColonyDistance=8, mindistancefromworldspawn=0}, combat=SimpleCommentedConfig:{minimumnumberofnightsbetweenraids=10, guardhealthmult=1.0, barbarianhordedifficulty=5, dobarbariansbreakthroughwalls=true, guardDamageMultiplier=1.0, mobattackcitizens=true, averagenumberofnightsbetweenraids=14, pvp_mode=false, shouldraiderbreakdoors=true, dobarbariansspawn=true, maxBarbarianSize=80}, compatibility=SimpleCommentedConfig:{auditcraftingtags=false, debuginventories=false, blueprintbuildmode=false}, research=SimpleCommentedConfig:{researchcreativecompletion=true, researchresetcost=[minecolonies:ancienttome:1], researchdebuglog=false}, commands=SimpleCommentedConfig:{canplayerusecolonytpcommand=false, canplayerusehometpcommand=false, canplayeruseresetcommand=false, canplayeruseallytownhallteleport=true, canplayerusekillcitizenscommand=false, canplayerusertpcommand=false, canplayerusemodifycitizenscommand=false, canplayerusedeletecolonycommand=false, canplayeruseshowcolonyinfocommand=true, canplayeruseaddofficercommand=true}, gameplay=SimpleCommentedConfig:{nosupplyplacementrestrictions=false, foodmodifier=1.0, loadtime=20, maxcitizenpercolony=250, diseasemodifier=5, enableindevelopmentfeatures=false, colonyloadstrictness=3, initialcitizenamount=4, allowinfinitecolonies=false, forceloadcolony=true, luckyblockchance=1, skyraiders=false, alwaysrendernametag=true, maxtreesize=400, minthleveltoteleport=3, allowinfinitesupplychests=false, allowotherdimcolonies=true, workersalwaysworkinrain=false}} is not correct. Correcting
[19:23:59] [Netty Client IO #17/INFO]: Loading "Dimension Access Manager" SERVER Config
[19:23:59] [Netty Client IO #17/INFO]: default_dimension_access_type = GRANTED
[19:23:59] [Netty Client IO #17/INFO]: dimension_command_permission_level = 4
[19:23:59] [Netty Client IO #17/INFO]: "Dimension Access Manager" SERVER Config loaded
[19:23:59] [Netty Client IO #17/INFO]: Connected to a modded server.
[19:24:00] [Render thread/INFO]: Reloading pipeline on dimension change: NamespacedId{namespace='compactmachines', name='compact_world'} => NamespacedId{namespace='compactmachines', name='compact_world'}
[19:24:00] [Render thread/INFO]: Destroying pipeline NamespacedId{namespace='compactmachines', name='compact_world'}
[19:24:00] [Render thread/INFO]: Creating pipeline for dimension NamespacedId{namespace='compactmachines', name='compact_world'}
[19:24:00] [Render thread/INFO]: Started 6 worker threads
[19:24:00] [Render thread/INFO]: [System] [CHAT] [DE Render Patcher] You're running a beta version of Draconic Evolution Render Patcher. If you encounter a bug or crash, please report it on GitHub Issues.
[19:24:22] [Render thread/INFO]: Finished discovering Ores 0 0
[19:24:22] [Render thread/INFO]: Finished discovering saplings 0
[19:24:22] [Render thread/INFO]: Finished discovering plantables 0
[19:24:22] [Render thread/INFO]: Finished discovering food 485 520
[19:24:22] [Render thread/INFO]: Finished discovering fuel 2462
[19:24:22] [Render thread/INFO]: Finished discovering flowers 0
[19:24:22] [Render thread/INFO]: Finished discovering items 28129
[19:24:22] [Render thread/INFO]: Synchronized 91 saplings
[19:24:22] [Render thread/INFO]: Synchronized 111 ore blocks with 73 smeltable ores
[19:24:22] [Render thread/INFO]: Synchronized 19 plantables
[19:24:22] [Render thread/INFO]: Synchronized 213 flowers
[19:24:22] [Render thread/INFO]: Synchronized 555 food types with 520 edible
[19:24:22] [Render thread/INFO]: Synchronized 2462 fuel types
[19:24:22] [Render thread/INFO]: Synchronized 192 monsters
[19:24:22] [Render thread/INFO]: Loading quests from data
[19:24:22] [Render thread/INFO]: Finished loading quests from data
[19:24:22] [Render thread/INFO]: Processing login packet
[19:24:22] [Render thread/INFO]: World area mode: distance_and_time
[19:24:22] [Render thread/INFO]: World max difficulty: 250.0
[19:24:22] [Render thread/INFO]: Synced Flute Songs
[19:24:22] [Render thread/INFO]: Synced Captured Mobs settings
[19:24:22] [Render thread/INFO]: Synced Globe data
[19:24:22] [Render thread/INFO]: Synced Hourglass data
[19:24:22] [Render thread/INFO]: Starting sync for enchanting_stats
[19:24:22] [Render thread/INFO]: Registered 34 enchanting_stats.
[19:24:22] [Render thread/INFO]: Starting sync for data_models
[19:24:22] [Render thread/INFO]: Registered 184 data_models.
[19:24:22] [Render thread/INFO]: Starting sync for model_tiers
[19:24:22] [Render thread/INFO]: Registered 5 model_tiers.
[19:24:22] [Render thread/INFO]: Starting sync for rarities
[19:24:22] [Render thread/INFO]: Registered 6 rarities.
[19:24:22] [Render thread/INFO]: Starting sync for affixes
[19:24:22] [Render thread/INFO]: Registered 81 affixes.
[19:24:22] [Render thread/WARN]: Insufficient number of affixes to satisfy the loot rules (ignoring backup rules) of rarity apotheosis:mythic for category helmetRequired: 3; Provided: 2
[19:24:22] [Render thread/WARN]: Insufficient number of affixes to satisfy the loot rules (ignoring backup rules) of rarity apotheosis:mythic for category bootsRequired: 3; Provided: 2
[19:24:22] [Render thread/WARN]: Insufficient number of affixes to satisfy the loot rules (ignoring backup rules) of rarity apotheosis:ancient for category bowRequired: 5; Provided: 4
[19:24:22] [Render thread/WARN]: Insufficient number of affixes to satisfy the loot rules (ignoring backup rules) of rarity apotheosis:ancient for category crossbowRequired: 5; Provided: 4
[19:24:22] [Render thread/WARN]: Insufficient number of affixes to satisfy the loot rules (ignoring backup rules) of rarity apotheosis:ancient for category pickaxeRequired: 5; Provided: 4
[19:24:22] [Render thread/WARN]: Insufficient number of affixes to satisfy the loot rules (ignoring backup rules) of rarity apotheosis:ancient for category shovelRequired: 5; Provided: 4
[19:24:22] [Render thread/WARN]: Insufficient number of affixes to satisfy the loot rules (ignoring backup rules) of rarity apotheosis:ancient for category shieldRequired: 5; Provided: 4
[19:24:22] [Render thread/WARN]: Insufficient number of affixes to satisfy the loot rules (ignoring backup rules) of rarity apotheosis:ancient for category helmetRequired: 4; Provided: 2
[19:24:22] [Render thread/WARN]: Insufficient number of affixes to satisfy the loot rules (ignoring backup rules) of rarity apotheosis:ancient for category bootsRequired: 4; Provided: 2
[19:24:22] [Render thread/INFO]: Starting sync for gems
[19:24:22] [Render thread/INFO]: Registered 19 gems.
[19:24:22] [Render thread/INFO]: Loaded 19 singularities from the server
[19:24:22] [Render thread/INFO]: Loaded 14 jetpacks from the server
[19:24:22] [Render thread/INFO]: Released client Flux Networks cache
[19:24:22] [Render thread/INFO]: Removed all colony views
[19:24:22] [Render thread/INFO]: Unloading synced configs from server
[19:24:23] [Render thread/INFO]: Stopping worker threads
[19:24:23] [Render thread/WARN]: Client logged off. Resetting Pack Meta and Reloading State
[19:24:23] [Render thread/INFO]: Reset 0 configs to their client-side state.
[19:24:23] [Structurize IO Worker #0/INFO]: Registered structure pack: Warped Netherlands
[19:24:23] [Structurize IO Worker #0/INFO]: Registered structure pack: Stalactite Caves
[19:24:23] [Structurize IO Worker #0/INFO]: Registered structure pack: Space Wars
[19:24:23] [Structurize IO Worker #0/INFO]: Registered structure pack: Shire
[19:24:23] [Structurize IO Worker #0/INFO]: Registered structure pack: Desert Oasis
[19:24:23] [Structurize IO Worker #0/INFO]: Registered structure pack: Pagoda
[19:24:23] [Structurize IO Worker #0/INFO]: Registered structure pack: Minecolonies Original
[19:24:23] [Structurize IO Worker #0/INFO]: Registered structure pack: Nordic Spruce
[19:24:23] [Structurize IO Worker #0/INFO]: Registered structure pack: Medieval Spruce
[19:24:23] [Structurize IO Worker #0/INFO]: Registered structure pack: Medieval Oak
[19:24:23] [Structurize IO Worker #0/INFO]: Registered structure pack: Medieval Dark Oak
[19:24:23] [Structurize IO Worker #0/INFO]: Registered structure pack: Medieval Birch
[19:24:23] [Structurize IO Worker #0/INFO]: Registered structure pack: Lost Mesa City
[19:24:23] [Structurize IO Worker #0/INFO]: Registered structure pack: Jungle Treehouse
[19:24:23] [Structurize IO Worker #0/INFO]: Registered structure pack: Incan
[19:24:23] [Structurize IO Worker #0/INFO]: Registered structure pack: Fortress
[19:24:23] [Structurize IO Worker #0/INFO]: Registered structure pack: Dark Oak Treehouse
[19:24:23] [Structurize IO Worker #0/INFO]: Registered structure pack: Colonial
[19:24:23] [Structurize IO Worker #0/INFO]: Registered structure pack: Cavern
[19:24:23] [Structurize IO Worker #0/INFO]: Registered structure pack: Caledonia
[19:24:23] [Structurize IO Worker #0/INFO]: Registered structure pack: Urban Birch
[19:24:23] [Structurize IO Worker #0/INFO]: Registered structure pack: Ancient Athens
[19:24:23] [Structurize IO Worker #0/INFO]: Registered structure pack: Urban Savanna
[19:24:23] [Structurize IO Worker #0/INFO]: Registered structure pack: NooBas_pr
[19:24:23] [Structurize IO Worker #0/WARN]: Finished discovering Client Structure packs
[19:24:34] [Netty Client IO #19/ERROR]: Channels [supplementaries:channel,soph_upgrade_addons:main_channel,ponder:main,structure_gel:main,corgilib:network,silentlib:network,compactmachines:main,domum_ornamentum:net-channel,tacz:handshake,cataclysm:main_channel,gundb:main,alexsmobs:main_channel,bmaddon:main,extrabotany:main,cosmeticarmorreworked:main,evolvedmekanism:evolvedmekanism,animus:main,mythicbotany:netchannel,enlightened_end:enlightened_end,botanicalmachinery:netchannel,moonlight:channel,merequester:network,mekanism_extras:mekanism_extras,movingelevators:main,lightmanscurrency:network,botania:main,polymorph:main,minecolonies:net-channel,framedblocks:main,supermartijn642configlib:sync_configs,quark:main,scalinghealth:network,cyclic:main_channel,crazyae2addons:main,compactmachines:room_tracking,akashictome:main,tacz:network,weaversparadise:weaversparadise,waystones:network,torchmaster:main,alexscaves:main_channel,betterblockz:main,buildinggadgets2:main_network_channel,sophisticatedbackpacks:channel,tinted_dyes:tinted_dyes,chipped:main,simplebedrockmodel:network,lionfishapi:main_channel,forge:tier_sorting,leaderboards:main,bloodmagic:main,mbtool:main,myotus:network,mekanism:mekanism,sophisticatedstorage:channel,dungeonnowloading:main,ftb_ph:ftb_ph,gravitationalmodulatingunittweaks:channel,ars_additions:main,flib:main_channel,mekanismgenerators:mekanismgenerators,productivebees:buzzinga,citadel:main_channel,simplelogin:main,amendments:channel,curios:main,lumixmachinical:main,wcwt:main,solcarrot:main,structurize:net-channel,crashutilities:network,ae2utility:main,fluxnetworks:network,curiotiab:main,sophisticatedcore:channel,patchouli:main,storagedrawers:main,multipiston:net-channel,trashcans:main,zeta:main,ldlib:networking,ars_elemental:main] rejected vanilla connections
[19:24:34] [Netty Client IO #18/ERROR]: Channels [supplementaries:channel,soph_upgrade_addons:main_channel,ponder:main,structure_gel:main,corgilib:network,silentlib:network,compactmachines:main,domum_ornamentum:net-channel,tacz:handshake,cataclysm:main_channel,gundb:main,alexsmobs:main_channel,bmaddon:main,extrabotany:main,cosmeticarmorreworked:main,evolvedmekanism:evolvedmekanism,animus:main,mythicbotany:netchannel,enlightened_end:enlightened_end,botanicalmachinery:netchannel,moonlight:channel,merequester:network,mekanism_extras:mekanism_extras,movingelevators:main,lightmanscurrency:network,botania:main,polymorph:main,minecolonies:net-channel,framedblocks:main,supermartijn642configlib:sync_configs,quark:main,scalinghealth:network,cyclic:main_channel,crazyae2addons:main,compactmachines:room_tracking,akashictome:main,tacz:network,weaversparadise:weaversparadise,waystones:network,torchmaster:main,alexscaves:main_channel,betterblockz:main,buildinggadgets2:main_network_channel,sophisticatedbackpacks:channel,tinted_dyes:tinted_dyes,chipped:main,simplebedrockmodel:network,lionfishapi:main_channel,forge:tier_sorting,leaderboards:main,bloodmagic:main,mbtool:main,myotus:network,mekanism:mekanism,sophisticatedstorage:channel,dungeonnowloading:main,ftb_ph:ftb_ph,gravitationalmodulatingunittweaks:channel,ars_additions:main,flib:main_channel,mekanismgenerators:mekanismgenerators,productivebees:buzzinga,citadel:main_channel,simplelogin:main,amendments:channel,curios:main,lumixmachinical:main,wcwt:main,solcarrot:main,structurize:net-channel,crashutilities:network,ae2utility:main,fluxnetworks:network,curiotiab:main,sophisticatedcore:channel,patchouli:main,storagedrawers:main,multipiston:net-channel,trashcans:main,zeta:main,ldlib:networking,ars_elemental:main] rejected vanilla connections
[19:24:36] [Render thread/INFO]: This line is printed by an example mod mixin from Forge!
[19:24:36] [Render thread/INFO]: MC Version: GmlServer
[19:24:36] [Render thread/INFO]: This line is printed by an example mod mixin from Forge!
[19:24:36] [Render thread/INFO]: MC Version: GmlServer
[19:24:36] [Render thread/INFO]: This line is printed by an example mod mixin from Forge!
[19:24:36] [Render thread/INFO]: MC Version: GmlServer
[19:24:38] [Render thread/WARN]: Mod(s) [oculus] are modifying Embeddium class me.jellysquid.mods.sodium.client.gui.SodiumGameOptionPages, which may cause instability.
[19:24:38] [Render thread/WARN]: Mod(s) [oculus] are modifying Embeddium class me.jellysquid.mods.sodium.client.gui.options.OptionImpl, which may cause instability.
[19:24:38] [Render thread/WARN]: OptionGroup must contain at least one option. ignoring empty group...
[19:24:38] [Render thread/INFO]: [FANCYMENU] ScreenCustomizationLayer registered: me.jellysquid.mods.sodium.client.gui.SodiumOptionsGUI
[19:24:38] [Render thread/INFO]: [FANCYMENU] ScreenCustomizationLayer registered: org.embeddedt.embeddium.gui.EmbeddiumVideoOptionsScreen
[19:24:41] [Render thread/INFO]: Flushed changes to Minecraft configuration
[19:24:43] [Render thread/INFO]: This line is printed by an example mod mixin from Forge!
[19:24:43] [Render thread/INFO]: MC Version: GmlServer
[19:24:43] [Render thread/INFO]: This line is printed by an example mod mixin from Forge!
[19:24:43] [Render thread/INFO]: MC Version: GmlServer
[19:24:43] [Render thread/INFO]: This line is printed by an example mod mixin from Forge!
[19:24:43] [Render thread/INFO]: MC Version: GmlServer
[19:24:43] [Netty Client IO #3/ERROR]: Channels [supplementaries:channel,soph_upgrade_addons:main_channel,ponder:main,structure_gel:main,corgilib:network,silentlib:network,compactmachines:main,domum_ornamentum:net-channel,tacz:handshake,cataclysm:main_channel,gundb:main,alexsmobs:main_channel,bmaddon:main,extrabotany:main,cosmeticarmorreworked:main,evolvedmekanism:evolvedmekanism,animus:main,mythicbotany:netchannel,enlightened_end:enlightened_end,botanicalmachinery:netchannel,moonlight:channel,merequester:network,mekanism_extras:mekanism_extras,movingelevators:main,lightmanscurrency:network,botania:main,polymorph:main,minecolonies:net-channel,framedblocks:main,supermartijn642configlib:sync_configs,quark:main,scalinghealth:network,cyclic:main_channel,crazyae2addons:main,compactmachines:room_tracking,akashictome:main,tacz:network,weaversparadise:weaversparadise,waystones:network,torchmaster:main,alexscaves:main_channel,betterblockz:main,buildinggadgets2:main_network_channel,sophisticatedbackpacks:channel,tinted_dyes:tinted_dyes,chipped:main,simplebedrockmodel:network,lionfishapi:main_channel,forge:tier_sorting,leaderboards:main,bloodmagic:main,mbtool:main,myotus:network,mekanism:mekanism,sophisticatedstorage:channel,dungeonnowloading:main,ftb_ph:ftb_ph,gravitationalmodulatingunittweaks:channel,ars_additions:main,flib:main_channel,mekanismgenerators:mekanismgenerators,productivebees:buzzinga,citadel:main_channel,simplelogin:main,amendments:channel,curios:main,lumixmachinical:main,wcwt:main,solcarrot:main,structurize:net-channel,crashutilities:network,ae2utility:main,fluxnetworks:network,curiotiab:main,sophisticatedcore:channel,patchouli:main,storagedrawers:main,multipiston:net-channel,trashcans:main,zeta:main,ldlib:networking,ars_elemental:main] rejected vanilla connections
[19:24:43] [Netty Client IO #22/ERROR]: Channels [supplementaries:channel,soph_upgrade_addons:main_channel,ponder:main,structure_gel:main,corgilib:network,silentlib:network,compactmachines:main,domum_ornamentum:net-channel,tacz:handshake,cataclysm:main_channel,gundb:main,alexsmobs:main_channel,bmaddon:main,extrabotany:main,cosmeticarmorreworked:main,evolvedmekanism:evolvedmekanism,animus:main,mythicbotany:netchannel,enlightened_end:enlightened_end,botanicalmachinery:netchannel,moonlight:channel,merequester:network,mekanism_extras:mekanism_extras,movingelevators:main,lightmanscurrency:network,botania:main,polymorph:main,minecolonies:net-channel,framedblocks:main,supermartijn642configlib:sync_configs,quark:main,scalinghealth:network,cyclic:main_channel,crazyae2addons:main,compactmachines:room_tracking,akashictome:main,tacz:network,weaversparadise:weaversparadise,waystones:network,torchmaster:main,alexscaves:main_channel,betterblockz:main,buildinggadgets2:main_network_channel,sophisticatedbackpacks:channel,tinted_dyes:tinted_dyes,chipped:main,simplebedrockmodel:network,lionfishapi:main_channel,forge:tier_sorting,leaderboards:main,bloodmagic:main,mbtool:main,myotus:network,mekanism:mekanism,sophisticatedstorage:channel,dungeonnowloading:main,ftb_ph:ftb_ph,gravitationalmodulatingunittweaks:channel,ars_additions:main,flib:main_channel,mekanismgenerators:mekanismgenerators,productivebees:buzzinga,citadel:main_channel,simplelogin:main,amendments:channel,curios:main,lumixmachinical:main,wcwt:main,solcarrot:main,structurize:net-channel,crashutilities:network,ae2utility:main,fluxnetworks:network,curiotiab:main,sophisticatedcore:channel,patchouli:main,storagedrawers:main,multipiston:net-channel,trashcans:main,zeta:main,ldlib:networking,ars_elemental:main] rejected vanilla connections
[19:24:46] [Render thread/INFO]: Released client Flux Networks cache
[19:24:46] [Render thread/INFO]: Removed all colony views
[19:24:46] [Render thread/INFO]: Connecting to play.lumixcraft.ru, 4096
[19:24:48] [Render thread/INFO]: Injecting existing registry data into this CLIENT instance
[19:24:49] [Netty Client IO #1/INFO]: Energy blacklist loaded: 1 block entries, 0 item entries
[19:24:49] [Netty Client IO #1/WARN]: Configuration file SimpleCommentedConfig:{pathfinding=SimpleCommentedConfig:{minimumrailstopath=8, pathNodeLimitMultiplier=1.0}, requestSystem=SimpleCommentedConfig:{creativeresolve=false}, permissions=SimpleCommentedConfig:{enablecolonyprotection=true, turnoffexplosionsincolonies=DAMAGE_ENTITIES, permissioneventbypassminpermlevel=2}, claims=SimpleCommentedConfig:{initialColonySize=4, maxColonySize=20, maxdistancefromworldspawn=30000, minColonyDistance=8, mindistancefromworldspawn=0}, combat=SimpleCommentedConfig:{minimumnumberofnightsbetweenraids=10, guardhealthmult=1.0, barbarianhordedifficulty=5, dobarbariansbreakthroughwalls=true, guardDamageMultiplier=1.0, mobattackcitizens=true, averagenumberofnightsbetweenraids=14, pvp_mode=false, shouldraiderbreakdoors=true, dobarbariansspawn=true, maxBarbarianSize=80}, compatibility=SimpleCommentedConfig:{auditcraftingtags=false, debuginventories=false, blueprintbuildmode=false}, research=SimpleCommentedConfig:{researchcreativecompletion=true, researchresetcost=[minecolonies:ancienttome:1], researchdebuglog=false}, commands=SimpleCommentedConfig:{canplayerusecolonytpcommand=false, canplayerusehometpcommand=false, canplayeruseresetcommand=false, canplayeruseallytownhallteleport=true, canplayerusekillcitizenscommand=false, canplayerusertpcommand=false, canplayerusemodifycitizenscommand=false, canplayerusedeletecolonycommand=false, canplayeruseshowcolonyinfocommand=true, canplayeruseaddofficercommand=true}, gameplay=SimpleCommentedConfig:{nosupplyplacementrestrictions=false, foodmodifier=1.0, loadtime=20, maxcitizenpercolony=250, diseasemodifier=5, enableindevelopmentfeatures=false, colonyloadstrictness=3, initialcitizenamount=4, allowinfinitecolonies=false, forceloadcolony=true, luckyblockchance=1, skyraiders=false, alwaysrendernametag=true, maxtreesize=400, minthleveltoteleport=3, allowinfinitesupplychests=false, allowotherdimcolonies=true, workersalwaysworkinrain=false}} is not correct. Correcting
[19:24:49] [Netty Client IO #1/INFO]: Loading "Dimension Access Manager" SERVER Config
[19:24:49] [Netty Client IO #1/INFO]: default_dimension_access_type = GRANTED
[19:24:49] [Netty Client IO #1/INFO]: dimension_command_permission_level = 4
[19:24:49] [Netty Client IO #1/INFO]: "Dimension Access Manager" SERVER Config loaded
[19:24:49] [Netty Client IO #1/INFO]: Connected to a modded server.
[19:24:49] [Render thread/INFO]: Reloading pipeline on dimension change: NamespacedId{namespace='compactmachines', name='compact_world'} => NamespacedId{namespace='compactmachines', name='compact_world'}
[19:24:49] [Render thread/INFO]: Destroying pipeline NamespacedId{namespace='compactmachines', name='compact_world'}
[19:24:49] [Render thread/INFO]: Creating pipeline for dimension NamespacedId{namespace='compactmachines', name='compact_world'}
[19:24:49] [Render thread/INFO]: Started 6 worker threads
[19:24:50] [Render thread/INFO]: [System] [CHAT] [DE Render Patcher] You're running a beta version of Draconic Evolution Render Patcher. If you encounter a bug or crash, please report it on GitHub Issues.
[19:25:02] [Render thread/INFO]: Finished discovering Ores 0 0
[19:25:02] [Render thread/INFO]: Finished discovering saplings 0
[19:25:02] [Render thread/INFO]: Finished discovering plantables 0
[19:25:02] [Render thread/INFO]: Finished discovering food 485 520
[19:25:02] [Render thread/INFO]: Finished discovering fuel 2462
[19:25:02] [Render thread/INFO]: Finished discovering flowers 0
[19:25:02] [Render thread/INFO]: Finished discovering items 28129
[19:25:02] [Render thread/INFO]: Synchronized 91 saplings
[19:25:02] [Render thread/INFO]: Synchronized 111 ore blocks with 73 smeltable ores
[19:25:02] [Render thread/INFO]: Synchronized 19 plantables
[19:25:02] [Render thread/INFO]: Synchronized 213 flowers
[19:25:02] [Render thread/INFO]: Synchronized 555 food types with 520 edible
[19:25:02] [Render thread/INFO]: Synchronized 2462 fuel types
[19:25:02] [Render thread/INFO]: Synchronized 192 monsters
[19:25:02] [Render thread/INFO]: Loading quests from data
[19:25:02] [Render thread/INFO]: Finished loading quests from data
[19:25:02] [Render thread/INFO]: Processing login packet
[19:25:02] [Render thread/INFO]: World area mode: distance_and_time
[19:25:02] [Render thread/INFO]: World max difficulty: 250.0
[19:25:02] [Render thread/INFO]: Synced Flute Songs
[19:25:02] [Render thread/INFO]: Synced Captured Mobs settings
[19:25:02] [Render thread/INFO]: Synced Globe data
[19:25:02] [Render thread/INFO]: Synced Hourglass data
[19:25:02] [Render thread/INFO]: Starting sync for enchanting_stats
[19:25:02] [Render thread/INFO]: Registered 34 enchanting_stats.
[19:25:02] [Render thread/INFO]: Starting sync for data_models
[19:25:02] [Render thread/INFO]: Registered 184 data_models.
[19:25:02] [Render thread/INFO]: Starting sync for model_tiers
[19:25:02] [Render thread/INFO]: Registered 5 model_tiers.
[19:25:02] [Render thread/INFO]: Starting sync for rarities
[19:25:02] [Render thread/INFO]: Registered 6 rarities.
[19:25:02] [Render thread/INFO]: Starting sync for affixes
[19:25:02] [Render thread/INFO]: Registered 81 affixes.
[19:25:02] [Render thread/WARN]: Insufficient number of affixes to satisfy the loot rules (ignoring backup rules) of rarity apotheosis:mythic for category helmetRequired: 3; Provided: 2
[19:25:02] [Render thread/WARN]: Insufficient number of affixes to satisfy the loot rules (ignoring backup rules) of rarity apotheosis:mythic for category bootsRequired: 3; Provided: 2
[19:25:02] [Render thread/WARN]: Insufficient number of affixes to satisfy the loot rules (ignoring backup rules) of rarity apotheosis:ancient for category bowRequired: 5; Provided: 4
[19:25:02] [Render thread/WARN]: Insufficient number of affixes to satisfy the loot rules (ignoring backup rules) of rarity apotheosis:ancient for category crossbowRequired: 5; Provided: 4
[19:25:02] [Render thread/WARN]: Insufficient number of affixes to satisfy the loot rules (ignoring backup rules) of rarity apotheosis:ancient for category pickaxeRequired: 5; Provided: 4
[19:25:02] [Render thread/WARN]: Insufficient number of affixes to satisfy the loot rules (ignoring backup rules) of rarity apotheosis:ancient for category shovelRequired: 5; Provided: 4
[19:25:02] [Render thread/WARN]: Insufficient number of affixes to satisfy the loot rules (ignoring backup rules) of rarity apotheosis:ancient for category shieldRequired: 5; Provided: 4
[19:25:02] [Render thread/WARN]: Insufficient number of affixes to satisfy the loot rules (ignoring backup rules) of rarity apotheosis:ancient for category helmetRequired: 4; Provided: 2
[19:25:02] [Render thread/WARN]: Insufficient number of affixes to satisfy the loot rules (ignoring backup rules) of rarity apotheosis:ancient for category bootsRequired: 4; Provided: 2
[19:25:02] [Render thread/INFO]: Starting sync for gems
[19:25:02] [Render thread/INFO]: Registered 19 gems.
[19:25:02] [Render thread/INFO]: Loaded 19 singularities from the server
[19:25:02] [Render thread/INFO]: Loaded 14 jetpacks from the server
[19:25:02] [Render thread/INFO]: Released client Flux Networks cache
[19:25:02] [Render thread/INFO]: Removed all colony views
[19:25:02] [Render thread/INFO]: Unloading synced configs from server
[19:25:03] [Render thread/INFO]: Stopping worker threads
[19:25:03] [Render thread/WARN]: Client logged off. Resetting Pack Meta and Reloading State
[19:25:03] [Render thread/INFO]: Reset 0 configs to their client-side state.
[19:25:03] [Structurize IO Worker #0/INFO]: Registered structure pack: Warped Netherlands
[19:25:03] [Structurize IO Worker #0/INFO]: Registered structure pack: Stalactite Caves
[19:25:03] [Structurize IO Worker #0/INFO]: Registered structure pack: Space Wars
[19:25:03] [Structurize IO Worker #0/INFO]: Registered structure pack: Shire
[19:25:03] [Structurize IO Worker #0/INFO]: Registered structure pack: Desert Oasis
[19:25:03] [Structurize IO Worker #0/INFO]: Registered structure pack: Pagoda
[19:25:03] [Structurize IO Worker #0/INFO]: Registered structure pack: Minecolonies Original
[19:25:03] [Structurize IO Worker #0/INFO]: Registered structure pack: Nordic Spruce
[19:25:03] [Structurize IO Worker #0/INFO]: Registered structure pack: Medieval Spruce
[19:25:03] [Structurize IO Worker #0/INFO]: Registered structure pack: Medieval Oak
[19:25:03] [Structurize IO Worker #0/INFO]: Registered structure pack: Medieval Dark Oak
[19:25:03] [Structurize IO Worker #0/INFO]: Registered structure pack: Medieval Birch
[19:25:03] [Structurize IO Worker #0/INFO]: Registered structure pack: Lost Mesa City
[19:25:03] [Structurize IO Worker #0/INFO]: Registered structure pack: Jungle Treehouse
[19:25:03] [Structurize IO Worker #0/INFO]: Registered structure pack: Incan
[19:25:03] [Structurize IO Worker #0/INFO]: Registered structure pack: Fortress
[19:25:03] [Structurize IO Worker #0/INFO]: Registered structure pack: Dark Oak Treehouse
[19:25:03] [Structurize IO Worker #0/INFO]: Registered structure pack: Colonial
[19:25:03] [Structurize IO Worker #0/INFO]: Registered structure pack: Cavern
[19:25:03] [Structurize IO Worker #0/INFO]: Registered structure pack: Caledonia
[19:25:03] [Structurize IO Worker #0/INFO]: Registered structure pack: Urban Birch
[19:25:03] [Structurize IO Worker #0/INFO]: Registered structure pack: Ancient Athens
[19:25:03] [Structurize IO Worker #0/INFO]: Registered structure pack: Urban Savanna
[19:25:03] [Structurize IO Worker #0/INFO]: Registered structure pack: NooBas_pr
[19:25:03] [Structurize IO Worker #0/WARN]: Finished discovering Client Structure packs
[19:25:41] [Render thread/INFO]: Released client Flux Networks cache
[19:25:41] [Render thread/INFO]: Removed all colony views
[19:25:41] [Render thread/INFO]: Connecting to play2.lumixcraft.ru, 25567
[19:25:43] [Render thread/INFO]: [FANCYMENU] ScreenCustomizationLayer registered: edit_server_screen
[19:26:04] [Netty Client IO #4/ERROR]: Channels [supplementaries:channel,soph_upgrade_addons:main_channel,ponder:main,structure_gel:main,corgilib:network,silentlib:network,compactmachines:main,domum_ornamentum:net-channel,tacz:handshake,cataclysm:main_channel,gundb:main,alexsmobs:main_channel,bmaddon:main,extrabotany:main,cosmeticarmorreworked:main,evolvedmekanism:evolvedmekanism,animus:main,mythicbotany:netchannel,enlightened_end:enlightened_end,botanicalmachinery:netchannel,moonlight:channel,merequester:network,mekanism_extras:mekanism_extras,movingelevators:main,lightmanscurrency:network,botania:main,polymorph:main,minecolonies:net-channel,framedblocks:main,supermartijn642configlib:sync_configs,quark:main,scalinghealth:network,cyclic:main_channel,crazyae2addons:main,compactmachines:room_tracking,akashictome:main,tacz:network,weaversparadise:weaversparadise,waystones:network,torchmaster:main,alexscaves:main_channel,betterblockz:main,buildinggadgets2:main_network_channel,sophisticatedbackpacks:channel,tinted_dyes:tinted_dyes,chipped:main,simplebedrockmodel:network,lionfishapi:main_channel,forge:tier_sorting,leaderboards:main,bloodmagic:main,mbtool:main,myotus:network,mekanism:mekanism,sophisticatedstorage:channel,dungeonnowloading:main,ftb_ph:ftb_ph,gravitationalmodulatingunittweaks:channel,ars_additions:main,flib:main_channel,mekanismgenerators:mekanismgenerators,productivebees:buzzinga,citadel:main_channel,simplelogin:main,amendments:channel,curios:main,lumixmachinical:main,wcwt:main,solcarrot:main,structurize:net-channel,crashutilities:network,ae2utility:main,fluxnetworks:network,curiotiab:main,sophisticatedcore:channel,patchouli:main,storagedrawers:main,multipiston:net-channel,trashcans:main,zeta:main,ldlib:networking,ars_elemental:main] rejected vanilla connections
[19:26:04] [Netty Client IO #7/ERROR]: Channels [supplementaries:channel,soph_upgrade_addons:main_channel,ponder:main,structure_gel:main,corgilib:network,silentlib:network,compactmachines:main,domum_ornamentum:net-channel,tacz:handshake,cataclysm:main_channel,gundb:main,alexsmobs:main_channel,bmaddon:main,extrabotany:main,cosmeticarmorreworked:main,evolvedmekanism:evolvedmekanism,animus:main,mythicbotany:netchannel,enlightened_end:enlightened_end,botanicalmachinery:netchannel,moonlight:channel,merequester:network,mekanism_extras:mekanism_extras,movingelevators:main,lightmanscurrency:network,botania:main,polymorph:main,minecolonies:net-channel,framedblocks:main,supermartijn642configlib:sync_configs,quark:main,scalinghealth:network,cyclic:main_channel,crazyae2addons:main,compactmachines:room_tracking,akashictome:main,tacz:network,weaversparadise:weaversparadise,waystones:network,torchmaster:main,alexscaves:main_channel,betterblockz:main,buildinggadgets2:main_network_channel,sophisticatedbackpacks:channel,tinted_dyes:tinted_dyes,chipped:main,simplebedrockmodel:network,lionfishapi:main_channel,forge:tier_sorting,leaderboards:main,bloodmagic:main,mbtool:main,myotus:network,mekanism:mekanism,sophisticatedstorage:channel,dungeonnowloading:main,ftb_ph:ftb_ph,gravitationalmodulatingunittweaks:channel,ars_additions:main,flib:main_channel,mekanismgenerators:mekanismgenerators,productivebees:buzzinga,citadel:main_channel,simplelogin:main,amendments:channel,curios:main,lumixmachinical:main,wcwt:main,solcarrot:main,structurize:net-channel,crashutilities:network,ae2utility:main,fluxnetworks:network,curiotiab:main,sophisticatedcore:channel,patchouli:main,storagedrawers:main,multipiston:net-channel,trashcans:main,zeta:main,ldlib:networking,ars_elemental:main] rejected vanilla connections
[19:26:46] [Netty Client IO #9/ERROR]: Channels [supplementaries:channel,soph_upgrade_addons:main_channel,ponder:main,structure_gel:main,corgilib:network,silentlib:network,compactmachines:main,domum_ornamentum:net-channel,tacz:handshake,cataclysm:main_channel,gundb:main,alexsmobs:main_channel,bmaddon:main,extrabotany:main,cosmeticarmorreworked:main,evolvedmekanism:evolvedmekanism,animus:main,mythicbotany:netchannel,enlightened_end:enlightened_end,botanicalmachinery:netchannel,moonlight:channel,merequester:network,mekanism_extras:mekanism_extras,movingelevators:main,lightmanscurrency:network,botania:main,polymorph:main,minecolonies:net-channel,framedblocks:main,supermartijn642configlib:sync_configs,quark:main,scalinghealth:network,cyclic:main_channel,crazyae2addons:main,compactmachines:room_tracking,akashictome:main,tacz:network,weaversparadise:weaversparadise,waystones:network,torchmaster:main,alexscaves:main_channel,betterblockz:main,buildinggadgets2:main_network_channel,sophisticatedbackpacks:channel,tinted_dyes:tinted_dyes,chipped:main,simplebedrockmodel:network,lionfishapi:main_channel,forge:tier_sorting,leaderboards:main,bloodmagic:main,mbtool:main,myotus:network,mekanism:mekanism,sophisticatedstorage:channel,dungeonnowloading:main,ftb_ph:ftb_ph,gravitationalmodulatingunittweaks:channel,ars_additions:main,flib:main_channel,mekanismgenerators:mekanismgenerators,productivebees:buzzinga,citadel:main_channel,simplelogin:main,amendments:channel,curios:main,lumixmachinical:main,wcwt:main,solcarrot:main,structurize:net-channel,crashutilities:network,ae2utility:main,fluxnetworks:network,curiotiab:main,sophisticatedcore:channel,patchouli:main,storagedrawers:main,multipiston:net-channel,trashcans:main,zeta:main,ldlib:networking,ars_elemental:main] rejected vanilla connections
[19:26:46] [Netty Client IO #10/ERROR]: Channels [supplementaries:channel,soph_upgrade_addons:main_channel,ponder:main,structure_gel:main,corgilib:network,silentlib:network,compactmachines:main,domum_ornamentum:net-channel,tacz:handshake,cataclysm:main_channel,gundb:main,alexsmobs:main_channel,bmaddon:main,extrabotany:main,cosmeticarmorreworked:main,evolvedmekanism:evolvedmekanism,animus:main,mythicbotany:netchannel,enlightened_end:enlightened_end,botanicalmachinery:netchannel,moonlight:channel,merequester:network,mekanism_extras:mekanism_extras,movingelevators:main,lightmanscurrency:network,botania:main,polymorph:main,minecolonies:net-channel,framedblocks:main,supermartijn642configlib:sync_configs,quark:main,scalinghealth:network,cyclic:main_channel,crazyae2addons:main,compactmachines:room_tracking,akashictome:main,tacz:network,weaversparadise:weaversparadise,waystones:network,torchmaster:main,alexscaves:main_channel,betterblockz:main,buildinggadgets2:main_network_channel,sophisticatedbackpacks:channel,tinted_dyes:tinted_dyes,chipped:main,simplebedrockmodel:network,lionfishapi:main_channel,forge:tier_sorting,leaderboards:main,bloodmagic:main,mbtool:main,myotus:network,mekanism:mekanism,sophisticatedstorage:channel,dungeonnowloading:main,ftb_ph:ftb_ph,gravitationalmodulatingunittweaks:channel,ars_additions:main,flib:main_channel,mekanismgenerators:mekanismgenerators,productivebees:buzzinga,citadel:main_channel,simplelogin:main,amendments:channel,curios:main,lumixmachinical:main,wcwt:main,solcarrot:main,structurize:net-channel,crashutilities:network,ae2utility:main,fluxnetworks:network,curiotiab:main,sophisticatedcore:channel,patchouli:main,storagedrawers:main,multipiston:net-channel,trashcans:main,zeta:main,ldlib:networking,ars_elemental:main] rejected vanilla connections
[19:26:46] [Netty Client IO #13/ERROR]: Channels [supplementaries:channel,soph_upgrade_addons:main_channel,ponder:main,structure_gel:main,corgilib:network,silentlib:network,compactmachines:main,domum_ornamentum:net-channel,tacz:handshake,cataclysm:main_channel,gundb:main,alexsmobs:main_channel,bmaddon:main,extrabotany:main,cosmeticarmorreworked:main,evolvedmekanism:evolvedmekanism,animus:main,mythicbotany:netchannel,enlightened_end:enlightened_end,botanicalmachinery:netchannel,moonlight:channel,merequester:network,mekanism_extras:mekanism_extras,movingelevators:main,lightmanscurrency:network,botania:main,polymorph:main,minecolonies:net-channel,framedblocks:main,supermartijn642configlib:sync_configs,quark:main,scalinghealth:network,cyclic:main_channel,crazyae2addons:main,compactmachines:room_tracking,akashictome:main,tacz:network,weaversparadise:weaversparadise,waystones:network,torchmaster:main,alexscaves:main_channel,betterblockz:main,buildinggadgets2:main_network_channel,sophisticatedbackpacks:channel,tinted_dyes:tinted_dyes,chipped:main,simplebedrockmodel:network,lionfishapi:main_channel,forge:tier_sorting,leaderboards:main,bloodmagic:main,mbtool:main,myotus:network,mekanism:mekanism,sophisticatedstorage:channel,dungeonnowloading:main,ftb_ph:ftb_ph,gravitationalmodulatingunittweaks:channel,ars_additions:main,flib:main_channel,mekanismgenerators:mekanismgenerators,productivebees:buzzinga,citadel:main_channel,simplelogin:main,amendments:channel,curios:main,lumixmachinical:main,wcwt:main,solcarrot:main,structurize:net-channel,crashutilities:network,ae2utility:main,fluxnetworks:network,curiotiab:main,sophisticatedcore:channel,patchouli:main,storagedrawers:main,multipiston:net-channel,trashcans:main,zeta:main,ldlib:networking,ars_elemental:main] rejected vanilla connections
[19:26:47] [Render thread/INFO]: Released client Flux Networks cache
[19:26:47] [Render thread/INFO]: Removed all colony views
[19:26:47] [Render thread/INFO]: Connecting to xenon-1.swapnodes.wtf, 10887
[19:26:49] [Render thread/INFO]: Injecting existing registry data into this CLIENT instance
[19:26:51] [Netty Client IO #11/INFO]: Energy blacklist loaded: 1 block entries, 0 item entries
[19:26:51] [Netty Client IO #11/WARN]: Configuration file SimpleCommentedConfig:{pathfinding=SimpleCommentedConfig:{minimumrailstopath=8, pathNodeLimitMultiplier=1.0}, requestSystem=SimpleCommentedConfig:{creativeresolve=false}, permissions=SimpleCommentedConfig:{enablecolonyprotection=true, turnoffexplosionsincolonies=DAMAGE_ENTITIES, permissioneventbypassminpermlevel=2}, claims=SimpleCommentedConfig:{initialColonySize=4, maxColonySize=20, maxdistancefromworldspawn=30000, minColonyDistance=8, mindistancefromworldspawn=0}, combat=SimpleCommentedConfig:{minimumnumberofnightsbetweenraids=10, guardhealthmult=1.0, barbarianhordedifficulty=5, dobarbariansbreakthroughwalls=true, guardDamageMultiplier=1.0, mobattackcitizens=true, averagenumberofnightsbetweenraids=14, pvp_mode=false, shouldraiderbreakdoors=true, dobarbariansspawn=true, maxBarbarianSize=80}, compatibility=SimpleCommentedConfig:{auditcraftingtags=false, debuginventories=false, blueprintbuildmode=false}, research=SimpleCommentedConfig:{researchcreativecompletion=true, researchresetcost=[minecolonies:ancienttome:1], researchdebuglog=false}, commands=SimpleCommentedConfig:{canplayerusecolonytpcommand=false, canplayerusehometpcommand=false, canplayeruseresetcommand=false, canplayeruseallytownhallteleport=true, canplayerusekillcitizenscommand=false, canplayerusertpcommand=false, canplayerusemodifycitizenscommand=false, canplayerusedeletecolonycommand=false, canplayeruseshowcolonyinfocommand=true, canplayeruseaddofficercommand=true}, gameplay=SimpleCommentedConfig:{nosupplyplacementrestrictions=false, foodmodifier=1.0, loadtime=20, maxcitizenpercolony=250, diseasemodifier=5, enableindevelopmentfeatures=false, colonyloadstrictness=3, initialcitizenamount=4, allowinfinitecolonies=false, forceloadcolony=true, luckyblockchance=1, skyraiders=false, alwaysrendernametag=true, maxtreesize=400, minthleveltoteleport=3, allowinfinitesupplychests=false, allowotherdimcolonies=true, workersalwaysworkinrain=false}} is not correct. Correcting
[19:26:51] [Netty Client IO #11/INFO]: Loading "Dimension Access Manager" SERVER Config
[19:26:51] [Netty Client IO #11/INFO]: default_dimension_access_type = GRANTED
[19:26:51] [Netty Client IO #11/INFO]: dimension_command_permission_level = 4
[19:26:51] [Netty Client IO #11/INFO]: "Dimension Access Manager" SERVER Config loaded
[19:26:51] [Netty Client IO #11/INFO]: Connected to a modded server.
[19:26:51] [Render thread/INFO]: Reloading pipeline on dimension change: NamespacedId{namespace='compactmachines', name='compact_world'} => NamespacedId{namespace='compactmachines', name='compact_world'}
[19:26:51] [Render thread/INFO]: Destroying pipeline NamespacedId{namespace='compactmachines', name='compact_world'}
[19:26:51] [Render thread/INFO]: Creating pipeline for dimension NamespacedId{namespace='compactmachines', name='compact_world'}
[19:26:51] [Render thread/INFO]: Started 6 worker threads
[19:26:52] [Render thread/INFO]: [System] [CHAT] [DE Render Patcher] You're running a beta version of Draconic Evolution Render Patcher. If you encounter a bug or crash, please report it on GitHub Issues.
[19:27:09] [Render thread/INFO]: Finished discovering Ores 0 0
[19:27:09] [Render thread/INFO]: Finished discovering saplings 0
[19:27:09] [Render thread/INFO]: Finished discovering plantables 0
[19:27:09] [Render thread/INFO]: Finished discovering food 485 520
[19:27:09] [Render thread/INFO]: Finished discovering fuel 2462
[19:27:09] [Render thread/INFO]: Finished discovering flowers 0
[19:27:09] [Render thread/INFO]: Finished discovering items 28129
[19:27:09] [Render thread/INFO]: Synchronized 91 saplings
[19:27:09] [Render thread/INFO]: Synchronized 111 ore blocks with 73 smeltable ores
[19:27:09] [Render thread/INFO]: Synchronized 19 plantables
[19:27:09] [Render thread/INFO]: Synchronized 213 flowers
[19:27:09] [Render thread/INFO]: Synchronized 555 food types with 520 edible
[19:27:09] [Render thread/INFO]: Synchronized 2462 fuel types
[19:27:09] [Render thread/INFO]: Synchronized 192 monsters
[19:27:09] [Render thread/INFO]: Loading quests from data
[19:27:09] [Render thread/INFO]: Finished loading quests from data
[19:27:09] [Render thread/INFO]: Processing login packet
[19:27:09] [Render thread/INFO]: World area mode: distance_and_time
[19:27:09] [Render thread/INFO]: World max difficulty: 250.0
[19:27:10] [Render thread/INFO]: Synced Flute Songs
[19:27:10] [Render thread/INFO]: Synced Captured Mobs settings
[19:27:10] [Render thread/INFO]: Synced Globe data
[19:27:10] [Render thread/INFO]: Synced Hourglass data
[19:27:10] [Render thread/INFO]: Starting sync for enchanting_stats
[19:27:10] [Render thread/INFO]: Registered 34 enchanting_stats.
[19:27:10] [Render thread/INFO]: Starting sync for data_models
[19:27:10] [Render thread/INFO]: Registered 184 data_models.
[19:27:10] [Render thread/INFO]: Starting sync for model_tiers
[19:27:10] [Render thread/INFO]: Registered 5 model_tiers.
[19:27:10] [Render thread/INFO]: Starting sync for rarities
[19:27:10] [Render thread/INFO]: Registered 6 rarities.
[19:27:10] [Render thread/INFO]: Starting sync for affixes
[19:27:10] [Render thread/INFO]: Registered 81 affixes.
[19:27:10] [Render thread/WARN]: Insufficient number of affixes to satisfy the loot rules (ignoring backup rules) of rarity apotheosis:mythic for category helmetRequired: 3; Provided: 2
[19:27:10] [Render thread/WARN]: Insufficient number of affixes to satisfy the loot rules (ignoring backup rules) of rarity apotheosis:mythic for category bootsRequired: 3; Provided: 2
[19:27:10] [Render thread/WARN]: Insufficient number of affixes to satisfy the loot rules (ignoring backup rules) of rarity apotheosis:ancient for category bowRequired: 5; Provided: 4
[19:27:10] [Render thread/WARN]: Insufficient number of affixes to satisfy the loot rules (ignoring backup rules) of rarity apotheosis:ancient for category crossbowRequired: 5; Provided: 4
[19:27:10] [Render thread/WARN]: Insufficient number of affixes to satisfy the loot rules (ignoring backup rules) of rarity apotheosis:ancient for category pickaxeRequired: 5; Provided: 4
[19:27:10] [Render thread/WARN]: Insufficient number of affixes to satisfy the loot rules (ignoring backup rules) of rarity apotheosis:ancient for category shovelRequired: 5; Provided: 4
[19:27:10] [Render thread/WARN]: Insufficient number of affixes to satisfy the loot rules (ignoring backup rules) of rarity apotheosis:ancient for category shieldRequired: 5; Provided: 4
[19:27:10] [Render thread/WARN]: Insufficient number of affixes to satisfy the loot rules (ignoring backup rules) of rarity apotheosis:ancient for category helmetRequired: 4; Provided: 2
[19:27:10] [Render thread/WARN]: Insufficient number of affixes to satisfy the loot rules (ignoring backup rules) of rarity apotheosis:ancient for category bootsRequired: 4; Provided: 2
[19:27:10] [Render thread/INFO]: Starting sync for gems
[19:27:10] [Render thread/INFO]: Registered 19 gems.
[19:27:10] [Render thread/INFO]: Loaded 19 singularities from the server
[19:27:10] [Render thread/INFO]: Loaded 14 jetpacks from the server
[19:27:10] [Render thread/INFO]: Released client Flux Networks cache
[19:27:10] [Render thread/INFO]: Removed all colony views
[19:27:11] [Render thread/INFO]: Unloading synced configs from server
[19:27:11] [Render thread/INFO]: Stopping worker threads
[19:27:12] [Render thread/WARN]: Client logged off. Resetting Pack Meta and Reloading State
[19:27:12] [Render thread/INFO]: Reset 0 configs to their client-side state.
[19:27:12] [Structurize IO Worker #0/INFO]: Registered structure pack: Warped Netherlands
[19:27:12] [Structurize IO Worker #0/INFO]: Registered structure pack: Stalactite Caves
[19:27:12] [Structurize IO Worker #0/INFO]: Registered structure pack: Space Wars
[19:27:12] [Structurize IO Worker #0/INFO]: Registered structure pack: Shire
[19:27:12] [Structurize IO Worker #0/INFO]: Registered structure pack: Desert Oasis
[19:27:12] [Structurize IO Worker #0/INFO]: Registered structure pack: Pagoda
[19:27:12] [Structurize IO Worker #0/INFO]: Registered structure pack: Minecolonies Original
[19:27:12] [Structurize IO Worker #0/INFO]: Registered structure pack: Nordic Spruce
[19:27:12] [Structurize IO Worker #0/INFO]: Registered structure pack: Medieval Spruce
[19:27:12] [Structurize IO Worker #0/INFO]: Registered structure pack: Medieval Oak
[19:27:12] [Structurize IO Worker #0/INFO]: Registered structure pack: Medieval Dark Oak
[19:27:12] [Structurize IO Worker #0/INFO]: Registered structure pack: Medieval Birch
[19:27:12] [Structurize IO Worker #0/INFO]: Registered structure pack: Lost Mesa City
[19:27:12] [Structurize IO Worker #0/INFO]: Registered structure pack: Jungle Treehouse
[19:27:12] [Structurize IO Worker #0/INFO]: Registered structure pack: Incan
[19:27:12] [Structurize IO Worker #0/INFO]: Registered structure pack: Fortress
[19:27:12] [Structurize IO Worker #0/INFO]: Registered structure pack: Dark Oak Treehouse
[19:27:12] [Structurize IO Worker #0/INFO]: Registered structure pack: Colonial
[19:27:12] [Structurize IO Worker #0/INFO]: Registered structure pack: Cavern
[19:27:12] [Structurize IO Worker #0/INFO]: Registered structure pack: Caledonia
[19:27:12] [Structurize IO Worker #0/INFO]: Registered structure pack: Urban Birch
[19:27:12] [Structurize IO Worker #0/INFO]: Registered structure pack: Ancient Athens
[19:27:12] [Structurize IO Worker #0/INFO]: Registered structure pack: Urban Savanna
[19:27:12] [Structurize IO Worker #0/INFO]: Registered structure pack: NooBas_pr
[19:27:12] [Structurize IO Worker #0/WARN]: Finished discovering Client Structure packs
[19:27:27] [Netty Client IO #12/ERROR]: Channels [supplementaries:channel,soph_upgrade_addons:main_channel,ponder:main,structure_gel:main,corgilib:network,silentlib:network,compactmachines:main,domum_ornamentum:net-channel,tacz:handshake,cataclysm:main_channel,gundb:main,alexsmobs:main_channel,bmaddon:main,extrabotany:main,cosmeticarmorreworked:main,evolvedmekanism:evolvedmekanism,animus:main,mythicbotany:netchannel,enlightened_end:enlightened_end,botanicalmachinery:netchannel,moonlight:channel,merequester:network,mekanism_extras:mekanism_extras,movingelevators:main,lightmanscurrency:network,botania:main,polymorph:main,minecolonies:net-channel,framedblocks:main,supermartijn642configlib:sync_configs,quark:main,scalinghealth:network,cyclic:main_channel,crazyae2addons:main,compactmachines:room_tracking,akashictome:main,tacz:network,weaversparadise:weaversparadise,waystones:network,torchmaster:main,alexscaves:main_channel,betterblockz:main,buildinggadgets2:main_network_channel,sophisticatedbackpacks:channel,tinted_dyes:tinted_dyes,chipped:main,simplebedrockmodel:network,lionfishapi:main_channel,forge:tier_sorting,leaderboards:main,bloodmagic:main,mbtool:main,myotus:network,mekanism:mekanism,sophisticatedstorage:channel,dungeonnowloading:main,ftb_ph:ftb_ph,gravitationalmodulatingunittweaks:channel,ars_additions:main,flib:main_channel,mekanismgenerators:mekanismgenerators,productivebees:buzzinga,citadel:main_channel,simplelogin:main,amendments:channel,curios:main,lumixmachinical:main,wcwt:main,solcarrot:main,structurize:net-channel,crashutilities:network,ae2utility:main,fluxnetworks:network,curiotiab:main,sophisticatedcore:channel,patchouli:main,storagedrawers:main,multipiston:net-channel,trashcans:main,zeta:main,ldlib:networking,ars_elemental:main] rejected vanilla connections
[19:27:27] [Netty Client IO #14/ERROR]: Channels [supplementaries:channel,soph_upgrade_addons:main_channel,ponder:main,structure_gel:main,corgilib:network,silentlib:network,compactmachines:main,domum_ornamentum:net-channel,tacz:handshake,cataclysm:main_channel,gundb:main,alexsmobs:main_channel,bmaddon:main,extrabotany:main,cosmeticarmorreworked:main,evolvedmekanism:evolvedmekanism,animus:main,mythicbotany:netchannel,enlightened_end:enlightened_end,botanicalmachinery:netchannel,moonlight:channel,merequester:network,mekanism_extras:mekanism_extras,movingelevators:main,lightmanscurrency:network,botania:main,polymorph:main,minecolonies:net-channel,framedblocks:main,supermartijn642configlib:sync_configs,quark:main,scalinghealth:network,cyclic:main_channel,crazyae2addons:main,compactmachines:room_tracking,akashictome:main,tacz:network,weaversparadise:weaversparadise,waystones:network,torchmaster:main,alexscaves:main_channel,betterblockz:main,buildinggadgets2:main_network_channel,sophisticatedbackpacks:channel,tinted_dyes:tinted_dyes,chipped:main,simplebedrockmodel:network,lionfishapi:main_channel,forge:tier_sorting,leaderboards:main,bloodmagic:main,mbtool:main,myotus:network,mekanism:mekanism,sophisticatedstorage:channel,dungeonnowloading:main,ftb_ph:ftb_ph,gravitationalmodulatingunittweaks:channel,ars_additions:main,flib:main_channel,mekanismgenerators:mekanismgenerators,productivebees:buzzinga,citadel:main_channel,simplelogin:main,amendments:channel,curios:main,lumixmachinical:main,wcwt:main,solcarrot:main,structurize:net-channel,crashutilities:network,ae2utility:main,fluxnetworks:network,curiotiab:main,sophisticatedcore:channel,patchouli:main,storagedrawers:main,multipiston:net-channel,trashcans:main,zeta:main,ldlib:networking,ars_elemental:main] rejected vanilla connections
[19:27:30] [Netty Client IO #18/ERROR]: Channels [supplementaries:channel,soph_upgrade_addons:main_channel,ponder:main,structure_gel:main,corgilib:network,silentlib:network,compactmachines:main,domum_ornamentum:net-channel,tacz:handshake,cataclysm:main_channel,gundb:main,alexsmobs:main_channel,bmaddon:main,extrabotany:main,cosmeticarmorreworked:main,evolvedmekanism:evolvedmekanism,animus:main,mythicbotany:netchannel,enlightened_end:enlightened_end,botanicalmachinery:netchannel,moonlight:channel,merequester:network,mekanism_extras:mekanism_extras,movingelevators:main,lightmanscurrency:network,botania:main,polymorph:main,minecolonies:net-channel,framedblocks:main,supermartijn642configlib:sync_configs,quark:main,scalinghealth:network,cyclic:main_channel,crazyae2addons:main,compactmachines:room_tracking,akashictome:main,tacz:network,weaversparadise:weaversparadise,waystones:network,torchmaster:main,alexscaves:main_channel,betterblockz:main,buildinggadgets2:main_network_channel,sophisticatedbackpacks:channel,tinted_dyes:tinted_dyes,chipped:main,simplebedrockmodel:network,lionfishapi:main_channel,forge:tier_sorting,leaderboards:main,bloodmagic:main,mbtool:main,myotus:network,mekanism:mekanism,sophisticatedstorage:channel,dungeonnowloading:main,ftb_ph:ftb_ph,gravitationalmodulatingunittweaks:channel,ars_additions:main,flib:main_channel,mekanismgenerators:mekanismgenerators,productivebees:buzzinga,citadel:main_channel,simplelogin:main,amendments:channel,curios:main,lumixmachinical:main,wcwt:main,solcarrot:main,structurize:net-channel,crashutilities:network,ae2utility:main,fluxnetworks:network,curiotiab:main,sophisticatedcore:channel,patchouli:main,storagedrawers:main,multipiston:net-channel,trashcans:main,zeta:main,ldlib:networking,ars_elemental:main] rejected vanilla connections
[19:27:30] [Netty Client IO #19/ERROR]: Channels [supplementaries:channel,soph_upgrade_addons:main_channel,ponder:main,structure_gel:main,corgilib:network,silentlib:network,compactmachines:main,domum_ornamentum:net-channel,tacz:handshake,cataclysm:main_channel,gundb:main,alexsmobs:main_channel,bmaddon:main,extrabotany:main,cosmeticarmorreworked:main,evolvedmekanism:evolvedmekanism,animus:main,mythicbotany:netchannel,enlightened_end:enlightened_end,botanicalmachinery:netchannel,moonlight:channel,merequester:network,mekanism_extras:mekanism_extras,movingelevators:main,lightmanscurrency:network,botania:main,polymorph:main,minecolonies:net-channel,framedblocks:main,supermartijn642configlib:sync_configs,quark:main,scalinghealth:network,cyclic:main_channel,crazyae2addons:main,compactmachines:room_tracking,akashictome:main,tacz:network,weaversparadise:weaversparadise,waystones:network,torchmaster:main,alexscaves:main_channel,betterblockz:main,buildinggadgets2:main_network_channel,sophisticatedbackpacks:channel,tinted_dyes:tinted_dyes,chipped:main,simplebedrockmodel:network,lionfishapi:main_channel,forge:tier_sorting,leaderboards:main,bloodmagic:main,mbtool:main,myotus:network,mekanism:mekanism,sophisticatedstorage:channel,dungeonnowloading:main,ftb_ph:ftb_ph,gravitationalmodulatingunittweaks:channel,ars_additions:main,flib:main_channel,mekanismgenerators:mekanismgenerators,productivebees:buzzinga,citadel:main_channel,simplelogin:main,amendments:channel,curios:main,lumixmachinical:main,wcwt:main,solcarrot:main,structurize:net-channel,crashutilities:network,ae2utility:main,fluxnetworks:network,curiotiab:main,sophisticatedcore:channel,patchouli:main,storagedrawers:main,multipiston:net-channel,trashcans:main,zeta:main,ldlib:networking,ars_elemental:main] rejected vanilla connections
[19:27:30] [Netty Client IO #20/ERROR]: Channels [supplementaries:channel,soph_upgrade_addons:main_channel,ponder:main,structure_gel:main,corgilib:network,silentlib:network,compactmachines:main,domum_ornamentum:net-channel,tacz:handshake,cataclysm:main_channel,gundb:main,alexsmobs:main_channel,bmaddon:main,extrabotany:main,cosmeticarmorreworked:main,evolvedmekanism:evolvedmekanism,animus:main,mythicbotany:netchannel,enlightened_end:enlightened_end,botanicalmachinery:netchannel,moonlight:channel,merequester:network,mekanism_extras:mekanism_extras,movingelevators:main,lightmanscurrency:network,botania:main,polymorph:main,minecolonies:net-channel,framedblocks:main,supermartijn642configlib:sync_configs,quark:main,scalinghealth:network,cyclic:main_channel,crazyae2addons:main,compactmachines:room_tracking,akashictome:main,tacz:network,weaversparadise:weaversparadise,waystones:network,torchmaster:main,alexscaves:main_channel,betterblockz:main,buildinggadgets2:main_network_channel,sophisticatedbackpacks:channel,tinted_dyes:tinted_dyes,chipped:main,simplebedrockmodel:network,lionfishapi:main_channel,forge:tier_sorting,leaderboards:main,bloodmagic:main,mbtool:main,myotus:network,mekanism:mekanism,sophisticatedstorage:channel,dungeonnowloading:main,ftb_ph:ftb_ph,gravitationalmodulatingunittweaks:channel,ars_additions:main,flib:main_channel,mekanismgenerators:mekanismgenerators,productivebees:buzzinga,citadel:main_channel,simplelogin:main,amendments:channel,curios:main,lumixmachinical:main,wcwt:main,solcarrot:main,structurize:net-channel,crashutilities:network,ae2utility:main,fluxnetworks:network,curiotiab:main,sophisticatedcore:channel,patchouli:main,storagedrawers:main,multipiston:net-channel,trashcans:main,zeta:main,ldlib:networking,ars_elemental:main] rejected vanilla connections
[19:27:31] [Render thread/INFO]: Released client Flux Networks cache
[19:27:31] [Render thread/INFO]: Removed all colony views
[19:27:31] [Render thread/INFO]: Connecting to xenon-1.swapnodes.wtf, 10887
[19:27:33] [Render thread/INFO]: Injecting existing registry data into this CLIENT instance
[19:27:34] [Netty Client IO #21/INFO]: Energy blacklist loaded: 1 block entries, 0 item entries
[19:27:34] [Netty Client IO #21/WARN]: Configuration file SimpleCommentedConfig:{pathfinding=SimpleCommentedConfig:{minimumrailstopath=8, pathNodeLimitMultiplier=1.0}, requestSystem=SimpleCommentedConfig:{creativeresolve=false}, permissions=SimpleCommentedConfig:{enablecolonyprotection=true, turnoffexplosionsincolonies=DAMAGE_ENTITIES, permissioneventbypassminpermlevel=2}, claims=SimpleCommentedConfig:{initialColonySize=4, maxColonySize=20, maxdistancefromworldspawn=30000, minColonyDistance=8, mindistancefromworldspawn=0}, combat=SimpleCommentedConfig:{minimumnumberofnightsbetweenraids=10, guardhealthmult=1.0, barbarianhordedifficulty=5, dobarbariansbreakthroughwalls=true, guardDamageMultiplier=1.0, mobattackcitizens=true, averagenumberofnightsbetweenraids=14, pvp_mode=false, shouldraiderbreakdoors=true, dobarbariansspawn=true, maxBarbarianSize=80}, compatibility=SimpleCommentedConfig:{auditcraftingtags=false, debuginventories=false, blueprintbuildmode=false}, research=SimpleCommentedConfig:{researchcreativecompletion=true, researchresetcost=[minecolonies:ancienttome:1], researchdebuglog=false}, commands=SimpleCommentedConfig:{canplayerusecolonytpcommand=false, canplayerusehometpcommand=false, canplayeruseresetcommand=false, canplayeruseallytownhallteleport=true, canplayerusekillcitizenscommand=false, canplayerusertpcommand=false, canplayerusemodifycitizenscommand=false, canplayerusedeletecolonycommand=false, canplayeruseshowcolonyinfocommand=true, canplayeruseaddofficercommand=true}, gameplay=SimpleCommentedConfig:{nosupplyplacementrestrictions=false, foodmodifier=1.0, loadtime=20, maxcitizenpercolony=250, diseasemodifier=5, enableindevelopmentfeatures=false, colonyloadstrictness=3, initialcitizenamount=4, allowinfinitecolonies=false, forceloadcolony=true, luckyblockchance=1, skyraiders=false, alwaysrendernametag=true, maxtreesize=400, minthleveltoteleport=3, allowinfinitesupplychests=false, allowotherdimcolonies=true, workersalwaysworkinrain=false}} is not correct. Correcting
[19:27:34] [Netty Client IO #21/INFO]: Loading "Dimension Access Manager" SERVER Config
[19:27:34] [Netty Client IO #21/INFO]: default_dimension_access_type = GRANTED
[19:27:34] [Netty Client IO #21/INFO]: dimension_command_permission_level = 4
[19:27:34] [Netty Client IO #21/INFO]: "Dimension Access Manager" SERVER Config loaded
[19:27:34] [Netty Client IO #21/INFO]: Connected to a modded server.
[19:27:35] [Render thread/INFO]: Reloading pipeline on dimension change: NamespacedId{namespace='compactmachines', name='compact_world'} => NamespacedId{namespace='compactmachines', name='compact_world'}
[19:27:35] [Render thread/INFO]: Destroying pipeline NamespacedId{namespace='compactmachines', name='compact_world'}
[19:27:35] [Render thread/INFO]: Creating pipeline for dimension NamespacedId{namespace='compactmachines', name='compact_world'}
[19:27:35] [Render thread/INFO]: Started 6 worker threads
[19:27:35] [Render thread/INFO]: [System] [CHAT] [DE Render Patcher] You're running a beta version of Draconic Evolution Render Patcher. If you encounter a bug or crash, please report it on GitHub Issues.
[19:27:50] [Render thread/INFO]: Finished discovering Ores 0 0
[19:27:50] [Render thread/INFO]: Finished discovering saplings 0
[19:27:50] [Render thread/INFO]: Finished discovering plantables 0
[19:27:50] [Render thread/INFO]: Finished discovering food 485 520
[19:27:50] [Render thread/INFO]: Finished discovering fuel 2462
[19:27:50] [Render thread/INFO]: Finished discovering flowers 0
[19:27:50] [Render thread/INFO]: Finished discovering items 28129
[19:27:50] [Render thread/INFO]: Synchronized 91 saplings
[19:27:50] [Render thread/INFO]: Synchronized 111 ore blocks with 73 smeltable ores
[19:27:50] [Render thread/INFO]: Synchronized 19 plantables
[19:27:50] [Render thread/INFO]: Synchronized 213 flowers
[19:27:50] [Render thread/INFO]: Synchronized 555 food types with 520 edible
[19:27:50] [Render thread/INFO]: Synchronized 2462 fuel types
[19:27:50] [Render thread/INFO]: Synchronized 192 monsters
[19:27:50] [Render thread/INFO]: Loading quests from data
[19:27:50] [Render thread/INFO]: Finished loading quests from data
[19:27:50] [Render thread/INFO]: Processing login packet
[19:27:50] [Render thread/INFO]: World area mode: distance_and_time
[19:27:50] [Render thread/INFO]: World max difficulty: 250.0
[19:27:50] [Render thread/INFO]: Synced Flute Songs
[19:27:50] [Render thread/INFO]: Synced Captured Mobs settings
[19:27:50] [Render thread/INFO]: Synced Globe data
[19:27:50] [Render thread/INFO]: Synced Hourglass data
[19:27:50] [Render thread/INFO]: Starting sync for enchanting_stats
[19:27:50] [Render thread/INFO]: Registered 34 enchanting_stats.
[19:27:50] [Render thread/INFO]: Starting sync for data_models
[19:27:50] [Render thread/INFO]: Registered 184 data_models.
[19:27:50] [Render thread/INFO]: Starting sync for model_tiers
[19:27:50] [Render thread/INFO]: Registered 5 model_tiers.
[19:27:50] [Render thread/INFO]: Starting sync for rarities
[19:27:50] [Render thread/INFO]: Registered 6 rarities.
[19:27:50] [Render thread/INFO]: Starting sync for affixes
[19:27:50] [Render thread/INFO]: Registered 81 affixes.
[19:27:50] [Render thread/WARN]: Insufficient number of affixes to satisfy the loot rules (ignoring backup rules) of rarity apotheosis:mythic for category helmetRequired: 3; Provided: 2
[19:27:50] [Render thread/WARN]: Insufficient number of affixes to satisfy the loot rules (ignoring backup rules) of rarity apotheosis:mythic for category bootsRequired: 3; Provided: 2
[19:27:50] [Render thread/WARN]: Insufficient number of affixes to satisfy the loot rules (ignoring backup rules) of rarity apotheosis:ancient for category bowRequired: 5; Provided: 4
[19:27:50] [Render thread/WARN]: Insufficient number of affixes to satisfy the loot rules (ignoring backup rules) of rarity apotheosis:ancient for category crossbowRequired: 5; Provided: 4
[19:27:50] [Render thread/WARN]: Insufficient number of affixes to satisfy the loot rules (ignoring backup rules) of rarity apotheosis:ancient for category pickaxeRequired: 5; Provided: 4
[19:27:50] [Render thread/WARN]: Insufficient number of affixes to satisfy the loot rules (ignoring backup rules) of rarity apotheosis:ancient for category shovelRequired: 5; Provided: 4
[19:27:50] [Render thread/WARN]: Insufficient number of affixes to satisfy the loot rules (ignoring backup rules) of rarity apotheosis:ancient for category shieldRequired: 5; Provided: 4
[19:27:50] [Render thread/WARN]: Insufficient number of affixes to satisfy the loot rules (ignoring backup rules) of rarity apotheosis:ancient for category helmetRequired: 4; Provided: 2
[19:27:50] [Render thread/WARN]: Insufficient number of affixes to satisfy the loot rules (ignoring backup rules) of rarity apotheosis:ancient for category bootsRequired: 4; Provided: 2
[19:27:50] [Render thread/INFO]: Starting sync for gems
[19:27:50] [Render thread/INFO]: Registered 19 gems.
[19:27:50] [Render thread/INFO]: Loaded 19 singularities from the server
[19:27:50] [Render thread/INFO]: Loaded 14 jetpacks from the server
[19:27:50] [Render thread/INFO]: Released client Flux Networks cache
[19:27:50] [Render thread/INFO]: Removed all colony views
[19:27:50] [Render thread/INFO]: Unloading synced configs from server
[19:27:51] [Render thread/INFO]: Stopping worker threads
[19:27:51] [Render thread/WARN]: Client logged off. Resetting Pack Meta and Reloading State
[19:27:51] [Structurize IO Worker #0/INFO]: Registered structure pack: Warped Netherlands
[19:27:51] [Structurize IO Worker #0/INFO]: Registered structure pack: Stalactite Caves
[19:27:51] [Structurize IO Worker #0/INFO]: Registered structure pack: Space Wars
[19:27:51] [Structurize IO Worker #0/INFO]: Registered structure pack: Shire
[19:27:51] [Structurize IO Worker #0/INFO]: Registered structure pack: Desert Oasis
[19:27:51] [Structurize IO Worker #0/INFO]: Registered structure pack: Pagoda
[19:27:51] [Structurize IO Worker #0/INFO]: Registered structure pack: Minecolonies Original
[19:27:51] [Structurize IO Worker #0/INFO]: Registered structure pack: Nordic Spruce
[19:27:51] [Structurize IO Worker #0/INFO]: Registered structure pack: Medieval Spruce
[19:27:51] [Structurize IO Worker #0/INFO]: Registered structure pack: Medieval Oak
[19:27:51] [Structurize IO Worker #0/INFO]: Registered structure pack: Medieval Dark Oak
[19:27:51] [Structurize IO Worker #0/INFO]: Registered structure pack: Medieval Birch
[19:27:51] [Structurize IO Worker #0/INFO]: Registered structure pack: Lost Mesa City
[19:27:51] [Structurize IO Worker #0/INFO]: Registered structure pack: Jungle Treehouse
[19:27:51] [Structurize IO Worker #0/INFO]: Registered structure pack: Incan
[19:27:51] [Structurize IO Worker #0/INFO]: Registered structure pack: Fortress
[19:27:51] [Structurize IO Worker #0/INFO]: Registered structure pack: Dark Oak Treehouse
[19:27:51] [Structurize IO Worker #0/INFO]: Registered structure pack: Colonial
[19:27:51] [Structurize IO Worker #0/INFO]: Registered structure pack: Cavern
[19:27:51] [Structurize IO Worker #0/INFO]: Registered structure pack: Caledonia
[19:27:51] [Structurize IO Worker #0/INFO]: Registered structure pack: Urban Birch
[19:27:51] [Structurize IO Worker #0/INFO]: Registered structure pack: Ancient Athens
[19:27:51] [Structurize IO Worker #0/INFO]: Registered structure pack: Urban Savanna
[19:27:51] [Structurize IO Worker #0/INFO]: Registered structure pack: NooBas_pr
[19:27:51] [Structurize IO Worker #0/WARN]: Finished discovering Client Structure packs
[19:29:24] [Render thread/INFO]: Released client Flux Networks cache
[19:29:24] [Render thread/INFO]: Removed all colony views
[19:29:24] [Render thread/INFO]: Connecting to play.lumixcraft.ru, 4096
[19:29:25] [Render thread/INFO]: Injecting existing registry data into this CLIENT instance
[19:29:26] [Netty Client IO #23/INFO]: Energy blacklist loaded: 1 block entries, 0 item entries
[19:29:27] [Netty Client IO #23/WARN]: Configuration file SimpleCommentedConfig:{pathfinding=SimpleCommentedConfig:{minimumrailstopath=8, pathNodeLimitMultiplier=1.0}, requestSystem=SimpleCommentedConfig:{creativeresolve=false}, permissions=SimpleCommentedConfig:{enablecolonyprotection=true, turnoffexplosionsincolonies=DAMAGE_ENTITIES, permissioneventbypassminpermlevel=2}, claims=SimpleCommentedConfig:{initialColonySize=4, maxColonySize=20, maxdistancefromworldspawn=30000, minColonyDistance=8, mindistancefromworldspawn=0}, combat=SimpleCommentedConfig:{minimumnumberofnightsbetweenraids=10, guardhealthmult=1.0, barbarianhordedifficulty=5, dobarbariansbreakthroughwalls=true, guardDamageMultiplier=1.0, mobattackcitizens=true, averagenumberofnightsbetweenraids=14, pvp_mode=false, shouldraiderbreakdoors=true, dobarbariansspawn=true, maxBarbarianSize=80}, compatibility=SimpleCommentedConfig:{auditcraftingtags=false, debuginventories=false, blueprintbuildmode=false}, research=SimpleCommentedConfig:{researchcreativecompletion=true, researchresetcost=[minecolonies:ancienttome:1], researchdebuglog=false}, commands=SimpleCommentedConfig:{canplayerusecolonytpcommand=false, canplayerusehometpcommand=false, canplayeruseresetcommand=false, canplayeruseallytownhallteleport=true, canplayerusekillcitizenscommand=false, canplayerusertpcommand=false, canplayerusemodifycitizenscommand=false, canplayerusedeletecolonycommand=false, canplayeruseshowcolonyinfocommand=true, canplayeruseaddofficercommand=true}, gameplay=SimpleCommentedConfig:{nosupplyplacementrestrictions=false, foodmodifier=1.0, loadtime=20, maxcitizenpercolony=250, diseasemodifier=5, enableindevelopmentfeatures=false, colonyloadstrictness=3, initialcitizenamount=4, allowinfinitecolonies=false, forceloadcolony=true, luckyblockchance=1, skyraiders=false, alwaysrendernametag=true, maxtreesize=400, minthleveltoteleport=3, allowinfinitesupplychests=false, allowotherdimcolonies=true, workersalwaysworkinrain=false}} is not correct. Correcting
[19:29:27] [Netty Client IO #23/INFO]: Loading "Dimension Access Manager" SERVER Config
[19:29:27] [Netty Client IO #23/INFO]: default_dimension_access_type = GRANTED
[19:29:27] [Netty Client IO #23/INFO]: dimension_command_permission_level = 4
[19:29:27] [Netty Client IO #23/INFO]: "Dimension Access Manager" SERVER Config loaded
[19:29:27] [Netty Client IO #23/INFO]: Connected to a modded server.
[19:29:27] [Render thread/INFO]: Reloading pipeline on dimension change: NamespacedId{namespace='compactmachines', name='compact_world'} => NamespacedId{namespace='compactmachines', name='compact_world'}
[19:29:27] [Render thread/INFO]: Destroying pipeline NamespacedId{namespace='compactmachines', name='compact_world'}
[19:29:27] [Render thread/INFO]: Creating pipeline for dimension NamespacedId{namespace='compactmachines', name='compact_world'}
[19:29:27] [Render thread/INFO]: Started 6 worker threads
[19:29:27] [Render thread/INFO]: [System] [CHAT] [DE Render Patcher] You're running a beta version of Draconic Evolution Render Patcher. If you encounter a bug or crash, please report it on GitHub Issues.
[19:29:43] [Render thread/INFO]: Finished discovering Ores 0 0
[19:29:43] [Render thread/INFO]: Finished discovering saplings 0
[19:29:43] [Render thread/INFO]: Finished discovering plantables 0
[19:29:43] [Render thread/INFO]: Finished discovering food 485 520
[19:29:43] [Render thread/INFO]: Finished discovering fuel 2462
[19:29:43] [Render thread/INFO]: Finished discovering flowers 0
[19:29:43] [Render thread/INFO]: Finished discovering items 28129
[19:29:43] [Render thread/INFO]: Synchronized 91 saplings
[19:29:43] [Render thread/INFO]: Synchronized 111 ore blocks with 73 smeltable ores
[19:29:43] [Render thread/INFO]: Synchronized 19 plantables
[19:29:43] [Render thread/INFO]: Synchronized 213 flowers
[19:29:43] [Render thread/INFO]: Synchronized 555 food types with 520 edible
[19:29:43] [Render thread/INFO]: Synchronized 2462 fuel types
[19:29:43] [Render thread/INFO]: Synchronized 192 monsters
[19:29:43] [Render thread/INFO]: Loading quests from data
[19:29:43] [Render thread/INFO]: Finished loading quests from data
[19:29:43] [Render thread/INFO]: Processing login packet
[19:29:43] [Render thread/INFO]: World area mode: distance_and_time
[19:29:43] [Render thread/INFO]: World max difficulty: 250.0
[19:29:43] [Render thread/INFO]: Synced Flute Songs
[19:29:43] [Render thread/INFO]: Synced Captured Mobs settings
[19:29:43] [Render thread/INFO]: Synced Globe data
[19:29:43] [Render thread/INFO]: Synced Hourglass data
[19:29:43] [Render thread/INFO]: Starting sync for enchanting_stats
[19:29:43] [Render thread/INFO]: Registered 34 enchanting_stats.
[19:29:43] [Render thread/INFO]: Starting sync for data_models
[19:29:43] [Render thread/INFO]: Registered 184 data_models.
[19:29:43] [Render thread/INFO]: Starting sync for model_tiers
[19:29:43] [Render thread/INFO]: Registered 5 model_tiers.
[19:29:43] [Render thread/INFO]: Starting sync for rarities
[19:29:43] [Render thread/INFO]: Registered 6 rarities.
[19:29:43] [Render thread/INFO]: Starting sync for affixes
[19:29:43] [Render thread/INFO]: Registered 81 affixes.
[19:29:43] [Render thread/WARN]: Insufficient number of affixes to satisfy the loot rules (ignoring backup rules) of rarity apotheosis:mythic for category helmetRequired: 3; Provided: 2
[19:29:43] [Render thread/WARN]: Insufficient number of affixes to satisfy the loot rules (ignoring backup rules) of rarity apotheosis:mythic for category bootsRequired: 3; Provided: 2
[19:29:43] [Render thread/WARN]: Insufficient number of affixes to satisfy the loot rules (ignoring backup rules) of rarity apotheosis:ancient for category bowRequired: 5; Provided: 4
[19:29:43] [Render thread/WARN]: Insufficient number of affixes to satisfy the loot rules (ignoring backup rules) of rarity apotheosis:ancient for category crossbowRequired: 5; Provided: 4
[19:29:43] [Render thread/WARN]: Insufficient number of affixes to satisfy the loot rules (ignoring backup rules) of rarity apotheosis:ancient for category pickaxeRequired: 5; Provided: 4
[19:29:43] [Render thread/WARN]: Insufficient number of affixes to satisfy the loot rules (ignoring backup rules) of rarity apotheosis:ancient for category shovelRequired: 5; Provided: 4
[19:29:43] [Render thread/WARN]: Insufficient number of affixes to satisfy the loot rules (ignoring backup rules) of rarity apotheosis:ancient for category shieldRequired: 5; Provided: 4
[19:29:43] [Render thread/WARN]: Insufficient number of affixes to satisfy the loot rules (ignoring backup rules) of rarity apotheosis:ancient for category helmetRequired: 4; Provided: 2
[19:29:43] [Render thread/WARN]: Insufficient number of affixes to satisfy the loot rules (ignoring backup rules) of rarity apotheosis:ancient for category bootsRequired: 4; Provided: 2
[19:29:43] [Render thread/INFO]: Starting sync for gems
[19:29:43] [Render thread/INFO]: Registered 19 gems.
[19:29:43] [Render thread/INFO]: Loaded 19 singularities from the server
[19:29:43] [Render thread/INFO]: Loaded 14 jetpacks from the server
[19:29:43] [Render thread/INFO]: Released client Flux Networks cache
[19:29:43] [Render thread/INFO]: Removed all colony views
[19:29:43] [Render thread/INFO]: Unloading synced configs from server
[19:29:44] [Render thread/INFO]: Stopping worker threads
[19:29:44] [Render thread/WARN]: Client logged off. Resetting Pack Meta and Reloading State
[19:29:44] [Structurize IO Worker #0/INFO]: Registered structure pack: Warped Netherlands
[19:29:44] [Structurize IO Worker #0/INFO]: Registered structure pack: Stalactite Caves
[19:29:44] [Structurize IO Worker #0/INFO]: Registered structure pack: Space Wars
[19:29:44] [Structurize IO Worker #0/INFO]: Registered structure pack: Shire
[19:29:44] [Structurize IO Worker #0/INFO]: Registered structure pack: Desert Oasis
[19:29:44] [Structurize IO Worker #0/INFO]: Registered structure pack: Pagoda
[19:29:44] [Structurize IO Worker #0/INFO]: Registered structure pack: Minecolonies Original
[19:29:44] [Structurize IO Worker #0/INFO]: Registered structure pack: Nordic Spruce
[19:29:44] [Structurize IO Worker #0/INFO]: Registered structure pack: Medieval Spruce
[19:29:44] [Structurize IO Worker #0/INFO]: Registered structure pack: Medieval Oak
[19:29:44] [Structurize IO Worker #0/INFO]: Registered structure pack: Medieval Dark Oak
[19:29:44] [Structurize IO Worker #0/INFO]: Registered structure pack: Medieval Birch
[19:29:44] [Structurize IO Worker #0/INFO]: Registered structure pack: Lost Mesa City
[19:29:44] [Structurize IO Worker #0/INFO]: Registered structure pack: Jungle Treehouse
[19:29:44] [Structurize IO Worker #0/INFO]: Registered structure pack: Incan
[19:29:44] [Structurize IO Worker #0/INFO]: Registered structure pack: Fortress
[19:29:44] [Structurize IO Worker #0/INFO]: Registered structure pack: Dark Oak Treehouse
[19:29:44] [Structurize IO Worker #0/INFO]: Registered structure pack: Colonial
[19:29:44] [Structurize IO Worker #0/INFO]: Registered structure pack: Cavern
[19:29:44] [Structurize IO Worker #0/INFO]: Registered structure pack: Caledonia
[19:29:44] [Structurize IO Worker #0/INFO]: Registered structure pack: Urban Birch
[19:29:44] [Structurize IO Worker #0/INFO]: Registered structure pack: Ancient Athens
[19:29:44] [Structurize IO Worker #0/INFO]: Registered structure pack: Urban Savanna
[19:29:44] [Structurize IO Worker #0/INFO]: Registered structure pack: NooBas_pr
[19:29:44] [Structurize IO Worker #0/WARN]: Finished discovering Client Structure packs
[19:30:12] [Netty Client IO #3/ERROR]: Channels [supplementaries:channel,soph_upgrade_addons:main_channel,ponder:main,structure_gel:main,corgilib:network,silentlib:network,compactmachines:main,domum_ornamentum:net-channel,tacz:handshake,cataclysm:main_channel,gundb:main,alexsmobs:main_channel,bmaddon:main,extrabotany:main,cosmeticarmorreworked:main,evolvedmekanism:evolvedmekanism,animus:main,mythicbotany:netchannel,enlightened_end:enlightened_end,botanicalmachinery:netchannel,moonlight:channel,merequester:network,mekanism_extras:mekanism_extras,movingelevators:main,lightmanscurrency:network,botania:main,polymorph:main,minecolonies:net-channel,framedblocks:main,supermartijn642configlib:sync_configs,quark:main,scalinghealth:network,cyclic:main_channel,crazyae2addons:main,compactmachines:room_tracking,akashictome:main,tacz:network,weaversparadise:weaversparadise,waystones:network,torchmaster:main,alexscaves:main_channel,betterblockz:main,buildinggadgets2:main_network_channel,sophisticatedbackpacks:channel,tinted_dyes:tinted_dyes,chipped:main,simplebedrockmodel:network,lionfishapi:main_channel,forge:tier_sorting,leaderboards:main,bloodmagic:main,mbtool:main,myotus:network,mekanism:mekanism,sophisticatedstorage:channel,dungeonnowloading:main,ftb_ph:ftb_ph,gravitationalmodulatingunittweaks:channel,ars_additions:main,flib:main_channel,mekanismgenerators:mekanismgenerators,productivebees:buzzinga,citadel:main_channel,simplelogin:main,amendments:channel,curios:main,lumixmachinical:main,wcwt:main,solcarrot:main,structurize:net-channel,crashutilities:network,ae2utility:main,fluxnetworks:network,curiotiab:main,sophisticatedcore:channel,patchouli:main,storagedrawers:main,multipiston:net-channel,trashcans:main,zeta:main,ldlib:networking,ars_elemental:main] rejected vanilla connections
[19:30:12] [Netty Client IO #1/ERROR]: Channels [supplementaries:channel,soph_upgrade_addons:main_channel,ponder:main,structure_gel:main,corgilib:network,silentlib:network,compactmachines:main,domum_ornamentum:net-channel,tacz:handshake,cataclysm:main_channel,gundb:main,alexsmobs:main_channel,bmaddon:main,extrabotany:main,cosmeticarmorreworked:main,evolvedmekanism:evolvedmekanism,animus:main,mythicbotany:netchannel,enlightened_end:enlightened_end,botanicalmachinery:netchannel,moonlight:channel,merequester:network,mekanism_extras:mekanism_extras,movingelevators:main,lightmanscurrency:network,botania:main,polymorph:main,minecolonies:net-channel,framedblocks:main,supermartijn642configlib:sync_configs,quark:main,scalinghealth:network,cyclic:main_channel,crazyae2addons:main,compactmachines:room_tracking,akashictome:main,tacz:network,weaversparadise:weaversparadise,waystones:network,torchmaster:main,alexscaves:main_channel,betterblockz:main,buildinggadgets2:main_network_channel,sophisticatedbackpacks:channel,tinted_dyes:tinted_dyes,chipped:main,simplebedrockmodel:network,lionfishapi:main_channel,forge:tier_sorting,leaderboards:main,bloodmagic:main,mbtool:main,myotus:network,mekanism:mekanism,sophisticatedstorage:channel,dungeonnowloading:main,ftb_ph:ftb_ph,gravitationalmodulatingunittweaks:channel,ars_additions:main,flib:main_channel,mekanismgenerators:mekanismgenerators,productivebees:buzzinga,citadel:main_channel,simplelogin:main,amendments:channel,curios:main,lumixmachinical:main,wcwt:main,solcarrot:main,structurize:net-channel,crashutilities:network,ae2utility:main,fluxnetworks:network,curiotiab:main,sophisticatedcore:channel,patchouli:main,storagedrawers:main,multipiston:net-channel,trashcans:main,zeta:main,ldlib:networking,ars_elemental:main] rejected vanilla connections
[19:30:12] [Netty Client IO #2/INFO]: На сервере есть дополнительные моды, которые могут быть нужны на клиенте: chunkactivitytracker@1.0.1, tab@5.5.0, fastleafdecay@32, toofast@0.4.3.5, jei_structures@1.8, does_it_tick@1.1.4
[19:30:12] [Netty Client IO #2/INFO]: Client has mods that are missing on server: [fastboot, flerovium, checkers, mekanismtieredoutlines, melody, cameraoverhaul, fastipping, fullbrightnesstoggle, badoptimizations, searchables, drippyloadingscreen, ftbq_better_fluids, derenderpatcher, betterthirdperson, arcfix]
[19:30:12] [Netty Client IO #22/ERROR]: Channels [supplementaries:channel,soph_upgrade_addons:main_channel,ponder:main,structure_gel:main,corgilib:network,silentlib:network,compactmachines:main,domum_ornamentum:net-channel,tacz:handshake,cataclysm:main_channel,gundb:main,alexsmobs:main_channel,bmaddon:main,extrabotany:main,cosmeticarmorreworked:main,evolvedmekanism:evolvedmekanism,animus:main,mythicbotany:netchannel,enlightened_end:enlightened_end,botanicalmachinery:netchannel,moonlight:channel,merequester:network,mekanism_extras:mekanism_extras,movingelevators:main,lightmanscurrency:network,botania:main,polymorph:main,minecolonies:net-channel,framedblocks:main,supermartijn642configlib:sync_configs,quark:main,scalinghealth:network,cyclic:main_channel,crazyae2addons:main,compactmachines:room_tracking,akashictome:main,tacz:network,weaversparadise:weaversparadise,waystones:network,torchmaster:main,alexscaves:main_channel,betterblockz:main,buildinggadgets2:main_network_channel,sophisticatedbackpacks:channel,tinted_dyes:tinted_dyes,chipped:main,simplebedrockmodel:network,lionfishapi:main_channel,forge:tier_sorting,leaderboards:main,bloodmagic:main,mbtool:main,myotus:network,mekanism:mekanism,sophisticatedstorage:channel,dungeonnowloading:main,ftb_ph:ftb_ph,gravitationalmodulatingunittweaks:channel,ars_additions:main,flib:main_channel,mekanismgenerators:mekanismgenerators,productivebees:buzzinga,citadel:main_channel,simplelogin:main,amendments:channel,curios:main,lumixmachinical:main,wcwt:main,solcarrot:main,structurize:net-channel,crashutilities:network,ae2utility:main,fluxnetworks:network,curiotiab:main,sophisticatedcore:channel,patchouli:main,storagedrawers:main,multipiston:net-channel,trashcans:main,zeta:main,ldlib:networking,ars_elemental:main] rejected vanilla connections
[19:30:14] [Render thread/INFO]: Released client Flux Networks cache
[19:30:14] [Render thread/INFO]: Removed all colony views
[19:30:14] [Render thread/INFO]: Connecting to play.lumixcraft.ru, 4004
[19:30:18] [Render thread/INFO]: Released client Flux Networks cache
[19:30:18] [Render thread/INFO]: Removed all colony views
[19:30:18] [Render thread/INFO]: Connecting to play.lumixcraft.ru, 4096
[19:30:19] [Render thread/INFO]: Injecting existing registry data into this CLIENT instance
[19:30:20] [Netty Client IO #4/INFO]: Energy blacklist loaded: 1 block entries, 0 item entries
[19:30:20] [Netty Client IO #4/WARN]: Configuration file SimpleCommentedConfig:{pathfinding=SimpleCommentedConfig:{minimumrailstopath=8, pathNodeLimitMultiplier=1.0}, requestSystem=SimpleCommentedConfig:{creativeresolve=false}, permissions=SimpleCommentedConfig:{enablecolonyprotection=true, turnoffexplosionsincolonies=DAMAGE_ENTITIES, permissioneventbypassminpermlevel=2}, claims=SimpleCommentedConfig:{initialColonySize=4, maxColonySize=20, maxdistancefromworldspawn=30000, minColonyDistance=8, mindistancefromworldspawn=0}, combat=SimpleCommentedConfig:{minimumnumberofnightsbetweenraids=10, guardhealthmult=1.0, barbarianhordedifficulty=5, dobarbariansbreakthroughwalls=true, guardDamageMultiplier=1.0, mobattackcitizens=true, averagenumberofnightsbetweenraids=14, pvp_mode=false, shouldraiderbreakdoors=true, dobarbariansspawn=true, maxBarbarianSize=80}, compatibility=SimpleCommentedConfig:{auditcraftingtags=false, debuginventories=false, blueprintbuildmode=false}, research=SimpleCommentedConfig:{researchcreativecompletion=true, researchresetcost=[minecolonies:ancienttome:1], researchdebuglog=false}, commands=SimpleCommentedConfig:{canplayerusecolonytpcommand=false, canplayerusehometpcommand=false, canplayeruseresetcommand=false, canplayeruseallytownhallteleport=true, canplayerusekillcitizenscommand=false, canplayerusertpcommand=false, canplayerusemodifycitizenscommand=false, canplayerusedeletecolonycommand=false, canplayeruseshowcolonyinfocommand=true, canplayeruseaddofficercommand=true}, gameplay=SimpleCommentedConfig:{nosupplyplacementrestrictions=false, foodmodifier=1.0, loadtime=20, maxcitizenpercolony=250, diseasemodifier=5, enableindevelopmentfeatures=false, colonyloadstrictness=3, initialcitizenamount=4, allowinfinitecolonies=false, forceloadcolony=true, luckyblockchance=1, skyraiders=false, alwaysrendernametag=true, maxtreesize=400, minthleveltoteleport=3, allowinfinitesupplychests=false, allowotherdimcolonies=true, workersalwaysworkinrain=false}} is not correct. Correcting
[19:30:20] [Netty Client IO #4/INFO]: Loading "Dimension Access Manager" SERVER Config
[19:30:20] [Netty Client IO #4/INFO]: default_dimension_access_type = GRANTED
[19:30:20] [Netty Client IO #4/INFO]: dimension_command_permission_level = 4
[19:30:20] [Netty Client IO #4/INFO]: "Dimension Access Manager" SERVER Config loaded
[19:30:20] [Netty Client IO #4/INFO]: Connected to a modded server.
[19:30:20] [Render thread/INFO]: Reloading pipeline on dimension change: NamespacedId{namespace='compactmachines', name='compact_world'} => NamespacedId{namespace='compactmachines', name='compact_world'}
[19:30:20] [Render thread/INFO]: Destroying pipeline NamespacedId{namespace='compactmachines', name='compact_world'}
[19:30:20] [Render thread/INFO]: Creating pipeline for dimension NamespacedId{namespace='compactmachines', name='compact_world'}
[19:30:20] [Render thread/INFO]: Started 6 worker threads
[19:30:20] [Render thread/INFO]: [System] [CHAT] [DE Render Patcher] You're running a beta version of Draconic Evolution Render Patcher. If you encounter a bug or crash, please report it on GitHub Issues.
[19:30:36] [Render thread/INFO]: Finished discovering Ores 0 0
[19:30:36] [Render thread/INFO]: Finished discovering saplings 0
[19:30:36] [Render thread/INFO]: Finished discovering plantables 0
[19:30:36] [Render thread/INFO]: Finished discovering food 485 520
[19:30:36] [Render thread/INFO]: Finished discovering fuel 2462
[19:30:36] [Render thread/INFO]: Finished discovering flowers 0
[19:30:36] [Render thread/INFO]: Finished discovering items 28129
[19:30:36] [Render thread/INFO]: Synchronized 91 saplings
[19:30:36] [Render thread/INFO]: Synchronized 111 ore blocks with 73 smeltable ores
[19:30:36] [Render thread/INFO]: Synchronized 19 plantables
[19:30:36] [Render thread/INFO]: Synchronized 213 flowers
[19:30:36] [Render thread/INFO]: Synchronized 555 food types with 520 edible
[19:30:36] [Render thread/INFO]: Synchronized 2462 fuel types
[19:30:36] [Render thread/INFO]: Synchronized 192 monsters
[19:30:36] [Render thread/INFO]: Loading quests from data
[19:30:36] [Render thread/INFO]: Finished loading quests from data
[19:30:36] [Render thread/INFO]: Processing login packet
[19:30:36] [Render thread/INFO]: World area mode: distance_and_time
[19:30:36] [Render thread/INFO]: World max difficulty: 250.0
[19:30:36] [Render thread/INFO]: Synced Flute Songs
[19:30:36] [Render thread/INFO]: Synced Captured Mobs settings
[19:30:36] [Render thread/INFO]: Synced Globe data
[19:30:36] [Render thread/INFO]: Synced Hourglass data
[19:30:36] [Render thread/INFO]: Starting sync for enchanting_stats
[19:30:36] [Render thread/INFO]: Registered 34 enchanting_stats.
[19:30:36] [Render thread/INFO]: Starting sync for data_models
[19:30:36] [Render thread/INFO]: Registered 184 data_models.
[19:30:36] [Render thread/INFO]: Starting sync for model_tiers
[19:30:36] [Render thread/INFO]: Registered 5 model_tiers.
[19:30:36] [Render thread/INFO]: Starting sync for rarities
[19:30:36] [Render thread/INFO]: Registered 6 rarities.
[19:30:36] [Render thread/INFO]: Starting sync for affixes
[19:30:36] [Render thread/INFO]: Registered 81 affixes.
[19:30:36] [Render thread/WARN]: Insufficient number of affixes to satisfy the loot rules (ignoring backup rules) of rarity apotheosis:mythic for category helmetRequired: 3; Provided: 2
[19:30:36] [Render thread/WARN]: Insufficient number of affixes to satisfy the loot rules (ignoring backup rules) of rarity apotheosis:mythic for category bootsRequired: 3; Provided: 2
[19:30:36] [Render thread/WARN]: Insufficient number of affixes to satisfy the loot rules (ignoring backup rules) of rarity apotheosis:ancient for category bowRequired: 5; Provided: 4
[19:30:36] [Render thread/WARN]: Insufficient number of affixes to satisfy the loot rules (ignoring backup rules) of rarity apotheosis:ancient for category crossbowRequired: 5; Provided: 4
[19:30:36] [Render thread/WARN]: Insufficient number of affixes to satisfy the loot rules (ignoring backup rules) of rarity apotheosis:ancient for category pickaxeRequired: 5; Provided: 4
[19:30:36] [Render thread/WARN]: Insufficient number of affixes to satisfy the loot rules (ignoring backup rules) of rarity apotheosis:ancient for category shovelRequired: 5; Provided: 4
[19:30:36] [Render thread/WARN]: Insufficient number of affixes to satisfy the loot rules (ignoring backup rules) of rarity apotheosis:ancient for category shieldRequired: 5; Provided: 4
[19:30:36] [Render thread/WARN]: Insufficient number of affixes to satisfy the loot rules (ignoring backup rules) of rarity apotheosis:ancient for category helmetRequired: 4; Provided: 2
[19:30:36] [Render thread/WARN]: Insufficient number of affixes to satisfy the loot rules (ignoring backup rules) of rarity apotheosis:ancient for category bootsRequired: 4; Provided: 2
[19:30:36] [Render thread/INFO]: Starting sync for gems
[19:30:36] [Render thread/INFO]: Registered 19 gems.
[19:30:36] [Render thread/INFO]: Loaded 19 singularities from the server
[19:30:36] [Render thread/INFO]: Loaded 14 jetpacks from the server
[19:30:36] [Render thread/INFO]: Released client Flux Networks cache
[19:30:36] [Render thread/INFO]: Removed all colony views
[19:30:37] [Render thread/INFO]: Unloading synced configs from server
[19:30:37] [Render thread/INFO]: Stopping worker threads
[19:30:37] [Render thread/WARN]: Client logged off. Resetting Pack Meta and Reloading State
[19:30:37] [Structurize IO Worker #0/INFO]: Registered structure pack: Warped Netherlands
[19:30:37] [Structurize IO Worker #0/INFO]: Registered structure pack: Stalactite Caves
[19:30:37] [Structurize IO Worker #0/INFO]: Registered structure pack: Space Wars
[19:30:37] [Structurize IO Worker #0/INFO]: Registered structure pack: Shire
[19:30:37] [Structurize IO Worker #0/INFO]: Registered structure pack: Desert Oasis
[19:30:37] [Structurize IO Worker #0/INFO]: Registered structure pack: Pagoda
[19:30:37] [Structurize IO Worker #0/INFO]: Registered structure pack: Minecolonies Original
[19:30:37] [Structurize IO Worker #0/INFO]: Registered structure pack: Nordic Spruce
[19:30:37] [Structurize IO Worker #0/INFO]: Registered structure pack: Medieval Spruce
[19:30:37] [Structurize IO Worker #0/INFO]: Registered structure pack: Medieval Oak
[19:30:37] [Structurize IO Worker #0/INFO]: Registered structure pack: Medieval Dark Oak
[19:30:37] [Structurize IO Worker #0/INFO]: Registered structure pack: Medieval Birch
[19:30:37] [Structurize IO Worker #0/INFO]: Registered structure pack: Lost Mesa City
[19:30:37] [Structurize IO Worker #0/INFO]: Registered structure pack: Jungle Treehouse
[19:30:37] [Structurize IO Worker #0/INFO]: Registered structure pack: Incan
[19:30:37] [Structurize IO Worker #0/INFO]: Registered structure pack: Fortress
[19:30:37] [Structurize IO Worker #0/INFO]: Registered structure pack: Dark Oak Treehouse
[19:30:37] [Structurize IO Worker #0/INFO]: Registered structure pack: Colonial
[19:30:37] [Structurize IO Worker #0/INFO]: Registered structure pack: Cavern
[19:30:37] [Structurize IO Worker #0/INFO]: Registered structure pack: Caledonia
[19:30:37] [Structurize IO Worker #0/INFO]: Registered structure pack: Urban Birch
[19:30:37] [Structurize IO Worker #0/INFO]: Registered structure pack: Ancient Athens
[19:30:37] [Structurize IO Worker #0/INFO]: Registered structure pack: Urban Savanna
[19:30:37] [Structurize IO Worker #0/INFO]: Registered structure pack: NooBas_pr
[19:30:37] [Structurize IO Worker #0/WARN]: Finished discovering Client Structure packs
[19:31:17] [Render thread/INFO]: Released client Flux Networks cache
[19:31:17] [Render thread/INFO]: Removed all colony views
[19:31:17] [Render thread/INFO]: Connecting to play.lumixcraft.ru, 4096
[19:31:18] [Render thread/INFO]: Injecting existing registry data into this CLIENT instance
[19:31:19] [Netty Client IO #7/INFO]: Energy blacklist loaded: 1 block entries, 0 item entries
[19:31:19] [Netty Client IO #7/WARN]: Configuration file SimpleCommentedConfig:{pathfinding=SimpleCommentedConfig:{minimumrailstopath=8, pathNodeLimitMultiplier=1.0}, requestSystem=SimpleCommentedConfig:{creativeresolve=false}, permissions=SimpleCommentedConfig:{enablecolonyprotection=true, turnoffexplosionsincolonies=DAMAGE_ENTITIES, permissioneventbypassminpermlevel=2}, claims=SimpleCommentedConfig:{initialColonySize=4, maxColonySize=20, maxdistancefromworldspawn=30000, minColonyDistance=8, mindistancefromworldspawn=0}, combat=SimpleCommentedConfig:{minimumnumberofnightsbetweenraids=10, guardhealthmult=1.0, barbarianhordedifficulty=5, dobarbariansbreakthroughwalls=true, guardDamageMultiplier=1.0, mobattackcitizens=true, averagenumberofnightsbetweenraids=14, pvp_mode=false, shouldraiderbreakdoors=true, dobarbariansspawn=true, maxBarbarianSize=80}, compatibility=SimpleCommentedConfig:{auditcraftingtags=false, debuginventories=false, blueprintbuildmode=false}, research=SimpleCommentedConfig:{researchcreativecompletion=true, researchresetcost=[minecolonies:ancienttome:1], researchdebuglog=false}, commands=SimpleCommentedConfig:{canplayerusecolonytpcommand=false, canplayerusehometpcommand=false, canplayeruseresetcommand=false, canplayeruseallytownhallteleport=true, canplayerusekillcitizenscommand=false, canplayerusertpcommand=false, canplayerusemodifycitizenscommand=false, canplayerusedeletecolonycommand=false, canplayeruseshowcolonyinfocommand=true, canplayeruseaddofficercommand=true}, gameplay=SimpleCommentedConfig:{nosupplyplacementrestrictions=false, foodmodifier=1.0, loadtime=20, maxcitizenpercolony=250, diseasemodifier=5, enableindevelopmentfeatures=false, colonyloadstrictness=3, initialcitizenamount=4, allowinfinitecolonies=false, forceloadcolony=true, luckyblockchance=1, skyraiders=false, alwaysrendernametag=true, maxtreesize=400, minthleveltoteleport=3, allowinfinitesupplychests=false, allowotherdimcolonies=true, workersalwaysworkinrain=false}} is not correct. Correcting
[19:31:19] [Netty Client IO #7/INFO]: Loading "Dimension Access Manager" SERVER Config
[19:31:19] [Netty Client IO #7/INFO]: default_dimension_access_type = GRANTED
[19:31:19] [Netty Client IO #7/INFO]: dimension_command_permission_level = 4
[19:31:19] [Netty Client IO #7/INFO]: "Dimension Access Manager" SERVER Config loaded
[19:31:20] [Netty Client IO #7/INFO]: Connected to a modded server.
[19:31:20] [Render thread/INFO]: Reloading pipeline on dimension change: NamespacedId{namespace='compactmachines', name='compact_world'} => NamespacedId{namespace='compactmachines', name='compact_world'}
[19:31:20] [Render thread/INFO]: Destroying pipeline NamespacedId{namespace='compactmachines', name='compact_world'}
[19:31:20] [Render thread/INFO]: Creating pipeline for dimension NamespacedId{namespace='compactmachines', name='compact_world'}
[19:31:20] [Render thread/INFO]: Started 6 worker threads
[19:31:20] [Render thread/INFO]: [System] [CHAT] [DE Render Patcher] You're running a beta version of Draconic Evolution Render Patcher. If you encounter a bug or crash, please report it on GitHub Issues.
[19:31:33] [Render thread/INFO]: Finished discovering Ores 0 0
[19:31:33] [Render thread/INFO]: Finished discovering saplings 0
[19:31:33] [Render thread/INFO]: Finished discovering plantables 0
[19:31:33] [Render thread/INFO]: Finished discovering food 485 520
[19:31:33] [Render thread/INFO]: Finished discovering fuel 2462
[19:31:33] [Render thread/INFO]: Finished discovering flowers 0
[19:31:33] [Render thread/INFO]: Finished discovering items 28129
[19:31:33] [Render thread/INFO]: Synchronized 91 saplings
[19:31:33] [Render thread/INFO]: Synchronized 111 ore blocks with 73 smeltable ores
[19:31:33] [Render thread/INFO]: Synchronized 19 plantables
[19:31:33] [Render thread/INFO]: Synchronized 213 flowers
[19:31:33] [Render thread/INFO]: Synchronized 555 food types with 520 edible
[19:31:33] [Render thread/INFO]: Synchronized 2462 fuel types
[19:31:33] [Render thread/INFO]: Synchronized 192 monsters
[19:31:33] [Render thread/INFO]: Loading quests from data
[19:31:33] [Render thread/INFO]: Finished loading quests from data
[19:31:33] [Render thread/INFO]: Processing login packet
[19:31:33] [Render thread/INFO]: World area mode: distance_and_time
[19:31:33] [Render thread/INFO]: World max difficulty: 250.0
[19:31:33] [Render thread/INFO]: Synced Flute Songs
[19:31:33] [Render thread/INFO]: Synced Captured Mobs settings
[19:31:33] [Render thread/INFO]: Synced Globe data
[19:31:33] [Render thread/INFO]: Synced Hourglass data
[19:31:33] [Render thread/INFO]: Starting sync for enchanting_stats
[19:31:33] [Render thread/INFO]: Registered 34 enchanting_stats.
[19:31:33] [Render thread/INFO]: Starting sync for data_models
[19:31:33] [Render thread/INFO]: Registered 184 data_models.
[19:31:33] [Render thread/INFO]: Starting sync for model_tiers
[19:31:33] [Render thread/INFO]: Registered 5 model_tiers.
[19:31:33] [Render thread/INFO]: Starting sync for rarities
[19:31:33] [Render thread/INFO]: Registered 6 rarities.
[19:31:33] [Render thread/INFO]: Starting sync for affixes
[19:31:33] [Render thread/INFO]: Registered 81 affixes.
[19:31:33] [Render thread/WARN]: Insufficient number of affixes to satisfy the loot rules (ignoring backup rules) of rarity apotheosis:mythic for category helmetRequired: 3; Provided: 2
[19:31:33] [Render thread/WARN]: Insufficient number of affixes to satisfy the loot rules (ignoring backup rules) of rarity apotheosis:mythic for category bootsRequired: 3; Provided: 2
[19:31:33] [Render thread/WARN]: Insufficient number of affixes to satisfy the loot rules (ignoring backup rules) of rarity apotheosis:ancient for category bowRequired: 5; Provided: 4
[19:31:33] [Render thread/WARN]: Insufficient number of affixes to satisfy the loot rules (ignoring backup rules) of rarity apotheosis:ancient for category crossbowRequired: 5; Provided: 4
[19:31:33] [Render thread/WARN]: Insufficient number of affixes to satisfy the loot rules (ignoring backup rules) of rarity apotheosis:ancient for category pickaxeRequired: 5; Provided: 4
[19:31:33] [Render thread/WARN]: Insufficient number of affixes to satisfy the loot rules (ignoring backup rules) of rarity apotheosis:ancient for category shovelRequired: 5; Provided: 4
[19:31:33] [Render thread/WARN]: Insufficient number of affixes to satisfy the loot rules (ignoring backup rules) of rarity apotheosis:ancient for category shieldRequired: 5; Provided: 4
[19:31:33] [Render thread/WARN]: Insufficient number of affixes to satisfy the loot rules (ignoring backup rules) of rarity apotheosis:ancient for category helmetRequired: 4; Provided: 2
[19:31:33] [Render thread/WARN]: Insufficient number of affixes to satisfy the loot rules (ignoring backup rules) of rarity apotheosis:ancient for category bootsRequired: 4; Provided: 2
[19:31:33] [Render thread/INFO]: Starting sync for gems
[19:31:33] [Render thread/INFO]: Registered 19 gems.
[19:31:33] [Render thread/INFO]: Loaded 19 singularities from the server
[19:31:33] [Render thread/INFO]: Loaded 14 jetpacks from the server
[19:31:33] [Render thread/INFO]: Released client Flux Networks cache
[19:31:33] [Render thread/INFO]: Removed all colony views
[19:31:33] [Render thread/INFO]: Unloading synced configs from server
[19:31:33] [Render thread/INFO]: Stopping worker threads
[19:31:33] [Render thread/WARN]: Client logged off. Resetting Pack Meta and Reloading State
[19:31:33] [Structurize IO Worker #0/INFO]: Registered structure pack: Warped Netherlands
[19:31:33] [Structurize IO Worker #0/INFO]: Registered structure pack: Stalactite Caves
[19:31:33] [Structurize IO Worker #0/INFO]: Registered structure pack: Space Wars
[19:31:33] [Structurize IO Worker #0/INFO]: Registered structure pack: Shire
[19:31:33] [Structurize IO Worker #0/INFO]: Registered structure pack: Desert Oasis
[19:31:33] [Structurize IO Worker #0/INFO]: Registered structure pack: Pagoda
[19:31:33] [Structurize IO Worker #0/INFO]: Registered structure pack: Minecolonies Original
[19:31:33] [Structurize IO Worker #0/INFO]: Registered structure pack: Nordic Spruce
[19:31:33] [Structurize IO Worker #0/INFO]: Registered structure pack: Medieval Spruce
[19:31:33] [Structurize IO Worker #0/INFO]: Registered structure pack: Medieval Oak
[19:31:33] [Structurize IO Worker #0/INFO]: Registered structure pack: Medieval Dark Oak
[19:31:33] [Structurize IO Worker #0/INFO]: Registered structure pack: Medieval Birch
[19:31:33] [Structurize IO Worker #0/INFO]: Registered structure pack: Lost Mesa City
[19:31:33] [Structurize IO Worker #0/INFO]: Registered structure pack: Jungle Treehouse
[19:31:33] [Structurize IO Worker #0/INFO]: Registered structure pack: Incan
[19:31:33] [Structurize IO Worker #0/INFO]: Registered structure pack: Fortress
[19:31:33] [Structurize IO Worker #0/INFO]: Registered structure pack: Dark Oak Treehouse
[19:31:33] [Structurize IO Worker #0/INFO]: Registered structure pack: Colonial
[19:31:33] [Structurize IO Worker #0/INFO]: Registered structure pack: Cavern
[19:31:33] [Structurize IO Worker #0/INFO]: Registered structure pack: Caledonia
[19:31:33] [Structurize IO Worker #0/INFO]: Registered structure pack: Urban Birch
[19:31:33] [Structurize IO Worker #0/INFO]: Registered structure pack: Ancient Athens
[19:31:33] [Structurize IO Worker #0/INFO]: Registered structure pack: Urban Savanna
[19:31:33] [Structurize IO Worker #0/INFO]: Registered structure pack: NooBas_pr
[19:31:33] [Structurize IO Worker #0/WARN]: Finished discovering Client Structure packs