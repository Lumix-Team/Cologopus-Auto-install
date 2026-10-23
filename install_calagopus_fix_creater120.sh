
#!/usr/bin/env bash
# ==============================================================================
#  🚀 LUMIX TEAM — Calagopus Panel Auto-Installer
#  Version: 2.0 (Refined & Optimized)
#  Repository: https://github.com/Lumix-Team/Cologopus-Auto-install
#  License: MIT
#  
#  Usage: sudo bash install_calagopus.sh [DOMAIN] [EMAIL]
# ==============================================================================

set -euo pipefail

# --- CONFIGURATION & COLORS ---
INSTALL_DIR="/opt/calagopus-panel"
COMPOSE_URL="https://raw.githubusercontent.com/calagopus/panel/main/compose.heavy.aio.yml"

# Color Palette
C_RESET='\033[0m'
C_RED='\033[1;31m'
C_GREEN='\033[1;32m'
C_YELLOW='\033[1;33m'
C_BLUE='\033[1;34m'
C_PURPLE='\033[1;35m'
C_CYAN='\033[1;36m'
C_WHITE='\033[1;37m'

# --- HELPER FUNCTIONS ---

log_info()    { echo -e "${C_CYAN}[INFO]${C_RESET} $1"; }
log_success() { echo -e "${C_GREEN}[OK]${C_RESET}   $1"; }
log_warn()    { echo -e "${C_YELLOW}[WARN]${C_RESET} $1"; }
log_error()   { echo -e "${C_RED}[ERROR]${C_RESET} $1"; }

print_header() {
    clear
    echo -e "${C_PURPLE}"
    cat << 'EOF'
     _                     _     _______                     
    | |                   (_)   |__   __|                    
    | |    _   _ _ __ ___  _ _  __ | | ___  __ _ _ __ ___  ___ 
    | |   | | | | '_ ` _ \| | \/ / | |/ _ \/ _` | '_ ` _ \/ __|
    | |___| |_| | | | | | | | >  <  | |  __/ (_| | | | | | \__ \
    |______\__,_|_| |_| |_|_/_/\_\ |_|\___|\__,_|_| |_| |_|___/

                AUTO-INSTALLER & FIX
                                                       
           ✨ Powered by LUMIX TEAM ✨
EOF
    echo -e "${C_RESET}"
    echo -e "${C_WHITE}   Automated Docker + Nginx + SSL Installer for Calagopus${C_RESET}"
    echo -e "${C_PURPLE}──────────────────────────────────────────────────────────────${C_RESET}"
    echo ""
}

show_progress() {
    local step=$1
    local total=$2
    local msg=$3
    local width=40
    local filled=$(( (step * width) / total ))
    local empty=$(( width - filled ))
    
    printf "\r${C_CYAN}[%-${width}s] %d%% ${C_RESET}%s" "$(printf '#%.0s' $(seq 1 $filled))$(printf '.%.0s' $(seq 1 $empty))" "$(( (step * 100) / total ))" "$msg"
}

check_root() {
    if [ "$EUID" -ne 0 ]; then
        log_error "Please run this script as root (sudo bash $0)"
        exit 1
    fi
}

get_input() {
    local var_name=$1
    local prompt_msg=$2
    local default_val=${3:-}
    
    if [[ -z "${!var_name:-}" ]]; then
        read -rp "$prompt_msg" input_val
        if [[ -n "$input_val" ]]; then
            eval "$var_name='$input_val'"
        elif [[ -n "$default_val" ]]; then
            eval "$var_name='$default_val'"
        fi
    fi
}

# --- MAIN INSTALLATION LOGIC ---

main() {
    print_header
    check_root

    # 1. Input Handling
    DOMAIN="${1:-}"
    EMAIL="${2:-}"

    get_input DOMAIN "🌐 Enter panel domain (e.g., panel.example.com): "
    get_input EMAIL "📧 Enter email for SSL (e.g., admin@example.com): "

    if [[ -z "$DOMAIN" || -z "$EMAIL" ]]; then
        log_error "Domain and Email are required!"
        exit 1
    fi

    # 2. System Preparation
    show_progress 1 6 "Updating system packages..."
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -qq > /dev/null 2>&1
    apt-get upgrade -y -qq > /dev/null 2>&1
    apt-get install -y -qq curl git ca-certificates gnupg lsb-release nginx certbot python3-certbot-nginx openssl > /dev/null 2>&1
    systemctl enable --now nginx > /dev/null 2>&1
    log_success "System updated & Nginx installed."

    # 3. Docker Installation
    show_progress 2 6 "Configuring Docker environment..."
    if ! command -v docker &> /dev/null; then
        curl -fsSL https://get.docker.com | CHANNEL=stable bash > /dev/null 2>&1
        systemctl enable --now docker
    else
        log_warn "Docker detected, skipping installation."
    fi

    # Optimize Docker for stability
    mkdir -p /etc/docker
    if [ ! -f /etc/docker/daemon.json ]; then
        cat > /etc/docker/daemon.json <<EOF
{
  "max-concurrent-downloads": 3,
  "max-download-attempts": 10,
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  }
}
EOF
        systemctl restart docker
    fi
    log_success "Docker optimized."

    # 4. Calagopus Stack Download
    show_progress 3 6 "Downloading Calagopus stack..."
    mkdir -p "$INSTALL_DIR"
    cd "$INSTALL_DIR"

    if [ ! -f compose.yml ]; then
        if ! curl -fL --retry 3 --retry-delay 2 "$COMPOSE_URL" -o compose.yml; then
            log_error "Failed to download compose file. Check internet connection."
            exit 1
        fi
        
        # Secure the installation
        RANDOM_KEY=$(openssl rand -hex 16)
        sed -i "s/CHANGEME/$RANDOM_KEY/g" compose.yml
        # Bind to localhost only for security behind Nginx
        sed -i 's/"8000:8000"/"127.0.0.1:8000:8000"/g' compose.yml
        log_success "Configuration generated with secure keys."
    else
        log_warn "Existing compose.yml found. Keeping current configuration."
    fi

    # Wings config fallback
    [ ! -f wings-config.yml ] && echo 'app_name: Calagopus' > wings-config.yml

    # 5. Pull & Start Containers
    show_progress 4 6 "Pulling images (this may take a while)..."
    MAX_RETRIES=5
    COUNT=1
    until docker compose pull > /dev/null 2>&1; do
        if [ "$COUNT" -ge "$MAX_RETRIES" ]; then
            log_error "Failed to pull images after 5 attempts."
            exit 1
        fi
        sleep 5
        COUNT=$((COUNT+1))
    done
    
    docker compose up -d > /dev/null 2>&1
    log_success "Containers started successfully."

    # 6. Nginx Configuration
    show_progress 5 6 "Setting up Reverse Proxy..."
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
    nginx -t > /dev/null 2>&1 && systemctl reload nginx
    log_success "Nginx configured for ${DOMAIN}."

    # 7. SSL Certification
    show_progress 6 6 "Issuing SSL Certificate..."
    certbot --nginx -d "$DOMAIN" --non-interactive --agree-tos -m "$EMAIL" --redirect > /dev/null 2>&1
    
    # Auto-reload Nginx on cert renewal
    mkdir -p /etc/letsencrypt/renewal-hooks/deploy
    cat > /etc/letsencrypt/renewal-hooks/deploy/reload-nginx.sh << 'EOF'
#!/usr/bin/env bash
systemctl reload nginx
EOF
    chmod +x /etc/letsencrypt/renewal-hooks/deploy/reload-nginx.sh
    systemctl enable --now certbot.timer > /dev/null 2>&1
    log_success "SSL Active & Auto-renewal enabled."

    # --- FINAL OUTPUT ---
    echo ""
    echo -e "${C_PURPLE}══════════════════════════════════════════════════════════${C_RESET}"
    echo -e "${C_GREEN} ✅ INSTALLATION COMPLETED SUCCESSFULLY!${C_RESET}"
    echo -e "${C_PURPLE}══════════════════════════════════════════════════════════${C_RESET}"
    echo ""
    echo -e "   ${C_WHITE}Panel URL:${C_RESET}    ${C_CYAN}https://${DOMAIN}${C_RESET}"
    echo -e "   ${C_WHITE}Directory:${C_RESET}    ${C_YELLOW}${INSTALL_DIR}${C_RESET}"
    echo -e "   ${C_WHITE}SSL Status:${C_RESET}   ${C_GREEN}Active (Auto-renew)${C_RESET}"
    echo ""
    echo -e "   ${C_BLUE}💡 Tip:${C_RESET} To update the panel in the future, run:"
    echo -e "   ${C_WHITE}cd ${INSTALL_DIR} && docker compose pull && docker compose up -d${C_RESET}"
    echo ""
    echo -e "   ${C_PURPLE}Thank you for choosing Lumix Team!${C_RESET}"
    echo -e "${C_PURPLE}══════════════════════════════════════════════════════════${C_RESET}"
    echo ""
}

main "$@"
