#!/usr/bin/env bash
set -euo pipefail

# Definició de colors ANSI per a la sortida visual
GREEN="\e[32m"
YELLOW="\e[33m"
BLUE="\e[34m"
RED="\e[31m"
RESET="\e[0m"

echo -e "${BLUE}[*] Iniciant el procés de bastionat i hardening (M5021)...${RESET}"

# Flag de control per al reinici condicionat de l'SSH
SSH_RESTART_NEEDED=false

# ==============================================================================
# FASE 1: Complexitat de contrasenyes (libpam-pwquality)
# ==============================================================================
echo -e "\n${YELLOW}[FASE 1] Verificació de paquets i complexitat de contrasenyes${RESET}"

if ! dpkg -s libpam-pwquality &>/dev/null; then
    apt-get update && apt-get install -y libpam-pwquality
    echo -e "${GREEN}[+] Paquet libpam-pwquality instal·lat correctament.${RESET}"
else
    echo -e "${BLUE}[i] El paquet libpam-pwquality ja estava instal·lat.${RESET}"
fi

PWQ_CONF="/etc/security/pwquality.conf"
TEMP_PWQ=$(mktemp)
cat <<EOF > "$TEMP_PWQ"
minlen = 12
dcredit = -1
ucredit = -1
lcredit = -1
ocredit = -1
minclass = 4
EOF

if [ ! -f "$PWQ_CONF" ] || ! cmp -s "$TEMP_PWQ" "$PWQ_CONF"; then
    cp "$TEMP_PWQ" "$PWQ_CONF"
    echo -e "${GREEN}[+] Canvis aplicats a $PWQ_CONF (Complexitat configurada).${RESET}"
else
    echo -e "${BLUE}[i] La configuració de pwquality no requereix canvis.${RESET}"
fi
rm -f "$TEMP_PWQ"

# ==============================================================================
# FASE 2: Cicle de vida de les credencials (/etc/login.defs)
# ==============================================================================
echo -e "\n${YELLOW}[FASE 2] Configuració del cicle de vida de credencials (/etc/login.defs)${RESET}"
LOGIN_DEFS="/etc/login.defs"

update_login_def() {
    local key="$1"
    local val="$2"
    if grep -qE "^#?${key}[[:space:]]+" "$LOGIN_DEFS"; then
        local current
        current=$(grep -E "^${key}[[:space:]]+" "$LOGIN_DEFS" | awk '{print $2}')
        if [ "$current" != "$val" ]; then
            sed -i -E "s/^#?(${key}[[:space:]]+).*/\1 ${val}/" "$LOGIN_DEFS"
            echo -e "${GREEN}[+] Modificat ${key}: ${current:-cap} -> ${val}${RESET}"
        else
            echo -e "${BLUE}[i] ${key} ja estava configurat a ${val}.${RESET}"
        fi
    else
        echo "${key}   ${val}" >> "$LOGIN_DEFS"
        echo -e "${GREEN}[+] Afegit ${key} = ${val} a login.defs${RESET}"
    fi
}

update_login_def "PASS_MAX_DAYS" "90"
update_login_def "PASS_MIN_DAYS" "7"
update_login_def "PASS_WARN_AGE" "14"

# ==============================================================================
# FASE 3: Enduriment del servei SSH directament a /etc/ssh/sshd_config
# ==============================================================================
echo -e "\n${YELLOW}[FASE 3] Modificació del fitxer principal /etc/ssh/sshd_config (Port 2222)${RESET}"
SSH_CONF="/etc/ssh/sshd_config"

update_ssh_config() {
    local key="$1"
    local val="$2"
    if grep -qE "^#?[[:space:]]*${key}[[:space:]]+" "$SSH_CONF"; then
        local current
        current=$(grep -E "^[[:space:]]*${key}[[:space:]]+" "$SSH_CONF" | awk '{print $2}')
        if [ "$current" != "$val" ]; then
            sed -i -E "s/^#?[[:space:]]*(${key}[[:space:]]+).*/\1 ${val}/" "$SSH_CONF"
            echo -e "${GREEN}[+] Modificat ${key} a sshd_config: ${current:-cap} -> ${val}${RESET}"
            SSH_RESTART_NEEDED=true
        else
            echo -e "${BLUE}[i] ${key} ja estava configurat a ${val} a sshd_config.${RESET}"
        fi
    else
        echo "${key} ${val}" >> "$SSH_CONF"
        echo -e "${GREEN}[+] Afegit ${key} = ${val} a $SSH_CONF${RESET}"
        SSH_RESTART_NEEDED=true
    fi
}

update_ssh_config "Port" "2222"
update_ssh_config "PermitRootLogin" "no"
update_ssh_config "MaxAuthTries" "3"

# ==============================================================================
# FASE 4: Validació i aplicació condicional del servei
# ==============================================================================
echo -e "\n${YELLOW}[FASE 4] Validació de sintaxi i gestió del servei SSH${RESET}"

if sshd -t; then
    echo -e "${GREEN}[+] Sintaxi del dimoni SSH correctament validada.${RESET}"
else
    echo -e "${RED}[!] Error crític: La sintaxi de l'SSH presenta errors.${RESET}"
    exit 1
fi

if [ "$SSH_RESTART_NEEDED" = true ]; then
    echo -e "${YELLOW}[*] Canvis detectats a l'SSH. Reiniciant el servei...${RESET}"
    systemctl restart ssh
    echo -e "${GREEN}[+] Servei SSH reiniciat correctament al nou port (2222).${RESET}"
else
    echo -e "${BLUE}[i] No hi ha hagut modificacions a l'SSH; s'omet el reinici del servei per evitar talls innecessaris.${RESET}"
fi

echo -e "\n${GREEN}[SUCCESS] El procés de bastionat s'ha executat amb èxit.${RESET}"
