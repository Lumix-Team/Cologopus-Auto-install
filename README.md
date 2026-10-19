# 🚀 Calagopus Panel Auto-Installer | by Lumina Team

[![Ubuntu Support](https://img.shields.io/badge/Ubuntu-20.04%20%7C%2022.04%20%7C%2024.04-E95420?logo=ubuntu&logoColor=white)](https://ubuntu.com/)
[![Docker](https://img.shields.io/badge/Docker-All--in--One-2496ED?logo=docker&logoColor=white)](https://www.docker.com/)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](https://github.com/Lumix-Team/Cologopus-Auto-install/blob/main/LICENSE)
[![Maintained by](https://img.shields.io/badge/Maintained%20by-Lumina%20Team-8A2BE2)](https://github.com/Lumix-Team/Cologopus-Auto-install)

🌐 **Languages / Языки:** [English](#-english) | [Русский](#-русский)

---

## 🇬🇧 English

### 📖 About the Script
An automated, version-independent bash script by **Lumina Team** for deploying the latest version of **Calagopus Panel** (Heavy All-in-One stack with Extensions & Wings support) on Ubuntu servers.

### ✨ Key Features
* **Always Up-to-Date:** Dynamically pulls the latest `main` branch configurations and container images without being locked to a specific release version.
* **Bilingual Interface:** Choose between **English** and **Russian** at startup (or pass it via CLI arguments).
* **Full Stack Deployment:** Automatically installs and configures Docker, Docker Compose, PostgreSQL, Valkey, Calagopus Panel, and Wings.
* **Nginx Reverse Proxy & WebSockets:** Configures Nginx with full WebSocket support for server consoles and isolates port `8000` to `127.0.0.1` for security.
* **Safe for Multi-Site VDS:** Does not overwrite or delete existing Nginx configurations (safe to run alongside **Azuriom** or other websites).
* **Auto-SSL & Renewal Bot:** Automatically issues a free Let's Encrypt SSL certificate via Certbot and configures `certbot.timer` with a deploy hook to auto-reload Nginx.
* **Anti-Timeout Protection:** Tunes Docker concurrency and uses an automatic retry loop to prevent `connection timed out` errors on VDS with slow links to `ghcr.io`.

### 💻 Supported Systems
* **OS:** Ubuntu `20.04 LTS`, `22.04 LTS`, `24.04 LTS` (and Debian 11/12 derivatives)
* **Architecture:** `x86_64` (amd64) / `aarch64` (arm64)
* **Privileges:** `root` or `sudo` access

### 🚀 Installation Commands

**Option 1: Interactive Mode (Select language, domain, and email during setup)**
```bash
curl -fsSL [https://raw.githubusercontent.com/Lumix-Team/Cologopus-Auto-install/main/install_calagopus.sh](https://raw.githubusercontent.com/Lumix-Team/Cologopus-Auto-install/main/install_calagopus.sh) | sudo bash
```

**Option 2: Unattended / One-Line Mode (No prompts)**
```bash
# Syntax: ... | sudo bash -s -- [DOMAIN] [EMAIL] [LANG: en/ru]
curl -fsSL [https://raw.githubusercontent.com/Lumix-Team/Cologopus-Auto-install/main/install_calagopus.sh](https://raw.githubusercontent.com/Lumix-Team/Cologopus-Auto-install/main/install_calagopus.sh) | sudo bash -s -- panel.example.com admin@example.com en
```

### 🔄 How to Update Panel in the Future
```bash
cd /opt/calagopus-panel && docker compose pull && docker compose up -d
```

### 📄 License
Distributed under the **MIT License**. See the [`LICENSE`](https://github.com/Lumix-Team/Cologopus-Auto-install/blob/main/LICENSE) file for more information.

### 🤖 AI Disclosure
> This script and documentation were developed and optimized by **Lumina Team** with the assistance of Artificial Intelligence (AI).

---

## 🇷🇺 Русский

### 📖 О скрипте
Автоматический скрипт от **Lumina Team** для быстрой установки самой последней версии игровой панели управления **Calagopus Panel** (стек Heavy All-in-One с поддержкой расширений и демона Wings) со всеми зависимостями.

### ✨ Что делает скрипт
* **Независимость от версии:** Всегда скачивает актуальные образы и конфигурации напрямую из официальной ветки `main` — скрипт не устареет при выходе обновлений панели.
* **Два языка интерфейса:** Выбор между **русским** и **английским** языком в начале установки.
* **Установка в один клик:** Автоматически устанавливает Docker, Docker Compose, базу данных PostgreSQL, кэш Valkey, панель Calagopus и демон Wings.
* **Авто-настройка Nginx:** Создает конфигурацию обратного прокси для вашего домена с поддержкой WebSockets (для работы консоли серверов) и закрывает порт `8000` от внешнего доступа.
* **Безопасность для соседних сайтов:** Не удаляет существующие конфиги Nginx (полностью совместим с установленным на том же сервере сайтом **Azuriom**).
* **SSL-сертификат и бот автопродления:** Автоматически выпускает бесплатный SSL-сертификат Let's Encrypt (Certbot) и активирует системный таймер `certbot.timer` с автоперезагрузкой Nginx после продления.
* **Защита от обрывов сети:** Оптимизирует потоки загрузки Docker и использует цикл автоматической докачки (Retry Loop), предотвращая сбои `connection timed out` на VDS со слабым каналом до GitHub.

### 💻 Поддерживаемые системы
* **ОС:** Ubuntu `20.04 LTS`, `22.04 LTS`, `24.04 LTS` (также совместим с Debian 11/12)
* **Архитектура:** `x86_64` (amd64) / `aarch64` (arm64)
* **Права:** Требуется запуск от имени `root` (или через `sudo`)

### 🚀 Команды для установки

**Вариант 1: Интерактивная установка (скрипт сам спросит язык, домен и почту)**
```bash
curl -fsSL [https://raw.githubusercontent.com/Lumix-Team/Cologopus-Auto-install/main/install_calagopus.sh](https://raw.githubusercontent.com/Lumix-Team/Cologopus-Auto-install/main/install_calagopus.sh) | sudo bash
```

**Вариант 2: Полностью автоматическая установка в одну строку (без вопросов)**
```bash
# Синтаксис: ... | sudo bash -s -- [ДОМЕН] [EMAIL] [ЯЗЫК: ru/en]
curl -fsSL [https://raw.githubusercontent.com/Lumix-Team/Cologopus-Auto-install/main/install_calagopus.sh](https://raw.githubusercontent.com/Lumix-Team/Cologopus-Auto-install/main/install_calagopus.sh) | sudo bash -s -- panel.example.com admin@example.com ru
```

### 🔄 Как обновить панель в будущем
```bash
cd /opt/calagopus-panel && docker compose pull && docker compose up -d
```

### 📄 Лицензия
Проект распространяется под лицензией **MIT License**. Подробности смотрите в файле [`LICENSE`](https://github.com/Lumix-Team/Cologopus-Auto-install/blob/main/LICENSE).

### 🤖 Примечание о разработке
> Данный скрипт и документация разработаны командой **Lumina Team** с использованием технологий искусственного интеллекта (ИИ).
