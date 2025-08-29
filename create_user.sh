#!/bin/bash
#
# Usage:
#   Создание обычных пользователей:
#      sudo bash create_user.sh --user user1 "ssh-rsa AAAA..." is_sudo1 [--no-docker] [--user user2 "ssh-rsa BBB..." is_sudo2] ... [--configure-ssh]
#   Обычные пользователи: $0 --user username \"ssh-key\" is_sudo [--no-docker] [--user ...] [--configure-ssh]"
#   Сервисные пользователи: $0 --service [--no-docker] service1 [service2 ...] [--configure-ssh]"
#   Смешанный режим: $0 --user admin \"ssh-key\" true --service onedev --service --no-docker restricted_service [--configure-ssh]"
# 
#   Флаги:"
#       --configure-ssh    Настроить SSH для аутентификации по ключам (отключить пароли)"
#       --no-docker        Не добавлять следующих пользователей в группу docker (действует только на следующий --user или --service)" [--configure-ssh]
#   
#   Создание сервисных пользователей:
#     sudo bash create_user.sh --service service1 [--no-docker] [service2] ... [--configure-ssh]
#   
# Examples:
#   sudo bash create_user.sh --user andrey "ssh-rsa AAAAB3Nza... user@host" true --user maks "ssh-rsa BBB..." false --configure-ssh
#   sudo bash create_user.sh --service onedev signoz jenkins
#   sudo bash create_user.sh --user admin "ssh-rsa AAA..." true --service onedev --no-docker --user dev "ssh-rsa BBB..." false --configure-ssh
#   sudo bash create_user.sh --user restricted "ssh-rsa CCC..." false --no-docker
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

add_user_to_docker_group() {
    local username=$1
    
    if ! getent group docker >/dev/null 2>&1; then
        groupadd docker
        log "Создана группа docker"
    fi
    
    usermod -aG docker "${username}"
    success "Пользователь ${username} добавлен в группу docker"
}

create_service_user() {
    local username=$1
    local add_to_docker=${2:-true}
    
    log "Настройка сервисного пользователя ${username}..."
    
    if ! id "${username}" >/dev/null 2>&1; then
        adduser --disabled-password --gecos "" "${username}"
        success "Создан сервисный пользователь ${username}"
        
        passwd -l "${username}" >/dev/null 2>&1
        log "Пароль для ${username} заблокирован"
    else
        log "Пользователь ${username} уже существует"
        
        if ! passwd -S "${username}" | grep -q "L"; then
            passwd -l "${username}" >/dev/null 2>&1
            log "Пароль для существующего пользователя ${username} заблокирован"
        fi
    fi
    
    if [ "$add_to_docker" = "true" ]; then
        add_user_to_docker_group "${username}"
    else
        log "Пользователь ${username} не добавлен в группу docker (указан флаг --no-docker)"
    fi
}

create_users() {
    log "Создание пользователей с SSH ключами..."
    
    if [ $# -lt 4 ] || [ $(($# % 4)) -ne 0 ]; then
        error "Неверное количество параметров. Использование: --user username \"ssh-key\" is_sudo add_to_docker"
        exit 1
    fi
    
    while [ $# -ge 4 ]; do
        local username=$1
        local ssh_key=$2
        local is_sudo=$3
        local add_to_docker=$4
        shift 4
        
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
        
        if [ "$add_to_docker" = "true" ]; then
            add_user_to_docker_group "$username"
        else
            log "Пользователь $username не добавлен в группу docker (указан флаг --no-docker)"
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
    
    if [ $# -eq 0 ]; then
        error "Не указаны параметры"
        echo "Использование:"
        echo "  Обычные пользователи: $0 --user username \"ssh-key\" is_sudo [--no-docker] [--user ...] [--configure-ssh]"
        echo "  Сервисные пользователи: $0 --service service1 [--no-docker] [service2 ...] [--configure-ssh]"
        echo "  Смешанный режим: $0 --user admin \"ssh-key\" true --service onedev --no-docker [--configure-ssh]"
        echo ""
        echo "Флаги:"
        echo "  --configure-ssh    Настроить SSH для аутентификации по ключам (отключить пароли)"
        echo "  --no-docker        Не добавлять пользователя в группу docker"
        exit 1
    fi
    
    local user_args=()
    local service_users_with_docker=()
    local service_users_no_docker=()
    local configure_ssh_flag=false
    local mode=""
    
    while [ $# -gt 0 ]; do
        case $1 in
            --user)
                mode="user"
                shift
                if [ $# -lt 3 ]; then
                    error "Недостаточно параметров для --user. Нужно: username ssh-key is_sudo"
                    exit 1
                fi
                local username=$1
                local ssh_key=$2
                local is_sudo=$3
                shift 3
                
                local add_to_docker="true"
                if [ $# -gt 0 ] && [ "$1" = "--no-docker" ]; then
                    add_to_docker="false"
                    shift
                fi
                
                user_args+=("$username" "$ssh_key" "$is_sudo" "$add_to_docker")
                ;; 
            --service)
                mode="service"
                shift
                local add_to_docker="true"
                if [ $# -gt 0 ] && [ "$1" = "--no-docker" ]; then
                    add_to_docker="false"
                    shift
                fi
                
                while [ $# -gt 0 ] && [[ ! "$1" =~ ^-- ]]; do
                    if [ "$add_to_docker" = "true" ]; then
                        service_users_with_docker+=("$1")
                    else
                        service_users_no_docker+=("$1")
                    fi
                    shift
                done
                ;; 
            --configure-ssh)
                configure_ssh_flag=true
                shift
                ;;
            *)
                error "Неизвестный параметр: $1"
                exit 1
                ;;
        esac
    done    
    if [ ${#service_users_with_docker[@]} -gt 0 ]; then
        log "Создание сервисных пользователей (с Docker)..."
        for service_user in "${service_users_with_docker[@]}"; do
            create_service_user "$service_user" "true"
        done
    fi
    
    
    if [ ${#service_users_no_docker[@]} -gt 0 ]; then
        log "Создание сервисных пользователей (без Docker)..."
        for service_user in "${service_users_no_docker[@]}"; do
            create_service_user "$service_user" "false"
        done
    fi
    
    if [ ${#user_args[@]} -gt 0 ]; then
        create_users "${user_args[@]}"
    fi
    
    if [ "$configure_ssh_flag" = true ]; then
        configure_ssh
    else
        log "SSH конфигурация пропущена (используйте --configure-ssh для настройки)"
    fi
    
    success "==================================================="
    success "Создание пользователей завершено!"
    success "==================================================="
    
    if [ ${#service_users_with_docker[@]} -gt 0 ]; then
        log "Созданные сервисные пользователи (с Docker):"
        for service_user in "${service_users_with_docker[@]}"; do
            success "  - $service_user (системный пользователь + docker)"
        done
    fi
    
    if [ ${#service_users_no_docker[@]} -gt 0 ]; then
        log "Созданные сервисные пользователи (без Docker):"
        for service_user in "${service_users_no_docker[@]}"; do
            success "  - $service_user (системный пользователь)"
        done
    fi
    
    if [ ${#SUDO_PASSWORDS[@]} -gt 0 ]; then
        log "Пользователи sudo и их пароли:"
        for username in "${!SUDO_PASSWORDS[@]}"; do
            warn "$username: ${SUDO_PASSWORDS[$username]}"
        done
    fi
    
    if [ "$configure_ssh_flag" = true ]; then
        warn "ВАЖНО: Убедитесь, что вы можете получить доступ к серверу с помощью SSH ключа, прежде чем закрыть эту сессию"
    fi

}

main "$@"