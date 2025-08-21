#!/bin/bash
#
# Usage:
#   sudo bash create_user.sh user1 "ssh-rsa AAAA..." is_sudo1 [user2 "ssh-rsa BBB..." is_sudo2] ...
#   
# Example:
#   sudo bash create_user.sh andrey "ssh-rsa AAAAB3Nza... user@host" true maks "ssh-rsa BBB..." false
#

set -e  

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

declare -A SUDO_PASSWORDS

log() { echo -e "${BLUE}[INFO]${NC} $*"; }
success() { echo -e "${GREEN}[OK]${NC} $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
error() { echo -e "${RED}[ERR]${NC} $*"; }


check_root() {
    if [ "$(id -u)" -ne 0 ]; then
        error "Этот скрипт должен быть запущен от имени root или с sudo"
        exit 1
    fi
}

create_users() {
    log "Создание пользователей с SSH ключами..."
    
    if [ $# -lt 3 ] || [ $(($# % 3)) -ne 0 ]; then
        error "Неверное количество параметров. Использование: $0 user1 \"ssh-key1\" is_sudo1 [user2 \"ssh-key2\" is_sudo2] ..."
        exit 1
    fi
    
    while [ $# -ge 3 ]; do
        local username=$1
        local ssh_key=$2
        local is_sudo=$3
        shift 3
        
        log "Обработка пользователя: $username"
        
        if id "$username" &>/dev/null; then
            log "Пользователь $username уже существует"
        else
            adduser --gecos "" --disabled-password "$username"
            success "Создан пользователь $username"
        fi
        
        if [ "$is_sudo" = "true" ]; then
            SUDO_PASSWORD=$(openssl rand -base64 12)
            echo "$username:$SUDO_PASSWORD" | chpasswd
            usermod -aG sudo "$username"
            SUDO_PASSWORDS["$username"]="$SUDO_PASSWORD"
            log "Добавлен $username в группу sudo с сгенерированным паролем"
        fi
        
        if [ -n "$ssh_key" ]; then
            mkdir -p "/home/$username/.ssh"
            echo "$ssh_key" >> "/home/$username/.ssh/authorized_keys"
            chmod 700 "/home/$username/.ssh"
            chmod 600 "/home/$username/.ssh/authorized_keys"
            chown -R "$username":"$username" "/home/$username/.ssh"
            success "Добавлен SSH публичный ключ для $username"
        else
            warn "Пустой SSH ключ для $username. Пожалуйста, добавьте SSH ключи вручную."
        fi
    done
}

configure_ssh() {
    log "Настройка SSH для аутентификации по ключам..."
    
    cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak
    
    cat > /etc/ssh/sshd_config << EOF
Port 22
Protocol 2
HostKey /etc/ssh/ssh_host_rsa_key
HostKey /etc/ssh/ssh_host_ecdsa_key
HostKey /etc/ssh/ssh_host_ed25519_key

LoginGraceTime 30s
PermitRootLogin no
StrictModes yes
MaxAuthTries 3
MaxSessions 5

PasswordAuthentication no
ChallengeResponseAuthentication no
UsePAM yes

PubkeyAuthentication yes
AuthorizedKeysFile .ssh/authorized_keys

SyslogFacility AUTH
LogLevel INFO

X11Forwarding no
PrintMotd no
AcceptEnv LANG LC_*
Subsystem sftp /usr/lib/openssh/sftp-server
EOF
    
    passwd -l root
    
    systemctl restart sshd
    
    warn "ВАЖНО: Убедитесь, что вы можете получить доступ к серверу с помощью SSH ключа, прежде чем закрыть эту сессию"
}

main() {
    check_root
    create_users "$@"
    configure_ssh
    
    success "==================================================="
    success "Создание пользователей и настройка SSH завершены!"
    success "==================================================="
    
    if [ ${#SUDO_PASSWORDS[@]} -gt 0 ]; then
        log "Пользователи sudo и их пароли:"
        for username in "${!SUDO_PASSWORDS[@]}"; do
            warn "$username: ${SUDO_PASSWORDS[$username]}"
        done
    fi
    warn "ВАЖНО: Убедитесь, что вы можете получить доступ к серверу с помощью SSH ключа, прежде чем закрыть эту сессию"

}

main "$@"