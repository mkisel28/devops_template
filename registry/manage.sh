#!/bin/bash

# Registry Docker Compose Management Script
# Usage: ./manage.sh [start|stop|restart|logs|build|clean] [dev|prod]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Default environment
ENV=${2:-dev}
ENV_FILE=".env.$ENV"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

check_env_file() {
    if [[ ! -f "$ENV_FILE" ]]; then
        log_error "Environment file $ENV_FILE not found!"
        exit 1
    fi
    log_info "Using environment file: $ENV_FILE"
}

setup_auth() {
    if [[ ! -f "auth/htpasswd" ]]; then
        log_info "Setting up authentication..."
        
        # Load environment variables
        source "$ENV_FILE"
        
        if ! command -v htpasswd &> /dev/null; then
            log_warning "htpasswd not found, installing apache2-utils..."
            sudo apt-get update && sudo apt-get install -y apache2-utils
        fi
        
        mkdir -p auth
        htpasswd -Bbn "$REGISTRY_USERNAME" "$REGISTRY_PASSWORD" > auth/htpasswd
        log_success "Authentication file created"
    fi
}

setup_certs() {
    if [[ ! -f "certs/domain.crt" ]] || [[ ! -f "certs/domain.key" ]]; then
        log_info "Setting up SSL certificates..."
        
        # Load environment variables
        source "$ENV_FILE"
        
        mkdir -p certs
        
        # Create self-signed certificate for development
        if [[ "$ENV" == "dev" ]]; then
            openssl req -new -newkey rsa:4096 -days 365 -nodes -x509 \
                -subj "/C=US/ST=State/L=City/O=Organization/CN=$REGISTRY_DOMAIN" \
                -keyout certs/domain.key \
                -out certs/domain.crt
            log_success "Self-signed certificate created for development"
        else
            log_warning "For production, please place your SSL certificates in certs/domain.crt and certs/domain.key"
        fi
    fi
}

start_services() {
    log_info "Starting Docker Registry services in $ENV environment..."
    
    check_env_file
    setup_auth
    setup_certs
    
    if [[ "$ENV" == "prod" ]]; then
        docker compose --env-file "$ENV_FILE" --profile production up -d
    else
        docker compose --env-file "$ENV_FILE" up -d registry registry-ui trivy
    fi
    
    log_success "Services started successfully!"
    
    # Load environment variables to show URLs
    source "$ENV_FILE"
    
    echo ""
    log_info "Services are available at:"
    echo "  Registry API: http://localhost:$REGISTRY_PORT"
    echo "  Registry UI:  http://localhost:$REGISTRY_UI_PORT"
    echo "  Trivy:        http://localhost:$TRIVY_PORT"
    
    if [[ "$ENV" == "prod" ]]; then
        echo "  Nginx Proxy:  http://localhost:$NGINX_HTTP_PORT"
    fi
}

stop_services() {
    log_info "Stopping Docker Registry services..."
    docker compose --env-file "$ENV_FILE" down
    log_success "Services stopped successfully!"
}

restart_services() {
    stop_services
    start_services
}

show_logs() {
    docker compose --env-file "$ENV_FILE" logs -f
}

build_services() {
    log_info "Building Docker Registry services..."
    docker compose --env-file "$ENV_FILE" build
    log_success "Services built successfully!"
}

clean_services() {
    log_warning "This will remove all containers, volumes, and networks!"
    read -p "Are you sure? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        docker compose --env-file "$ENV_FILE" down -v --remove-orphans
        docker system prune -f
        log_success "Cleanup completed!"
    else
        log_info "Cleanup cancelled."
    fi
}

show_status() {
    log_info "Docker Registry services status:"
    docker compose --env-file "$ENV_FILE" ps
}

push_test_image() {
    # Load environment variables
    source "$ENV_FILE"
    
    log_info "Testing registry with a sample image..."
    
    # Pull a small test image
    docker pull hello-world
    
    # Tag it for our registry
    docker tag hello-world localhost:$REGISTRY_PORT/hello-world:latest
    
    # Push to registry
    docker push localhost:$REGISTRY_PORT/hello-world:latest
    
    log_success "Test image pushed successfully!"
    log_info "You can now see it in the Registry UI at http://localhost:$REGISTRY_UI_PORT"
}

show_help() {
    echo "Docker Registry Management Script"
    echo ""
    echo "Usage: $0 [COMMAND] [ENVIRONMENT]"
    echo ""
    echo "Commands:"
    echo "  start     Start all services"
    echo "  stop      Stop all services"
    echo "  restart   Restart all services"
    echo "  logs      Show service logs"
    echo "  build     Build services"
    echo "  clean     Remove all containers, volumes, and networks"
    echo "  status    Show service status"
    echo "  test      Push a test image to registry"
    echo "  help      Show this help message"
    echo ""
    echo "Environments:"
    echo "  dev       Development environment (default)"
    echo "  prod      Production environment"
    echo ""
    echo "Examples:"
    echo "  $0 start dev"
    echo "  $0 stop prod"
    echo "  $0 logs"
}

# Main script logic
case "${1:-help}" in
    start)
        start_services
        ;;
    stop)
        stop_services
        ;;
    restart)
        restart_services
        ;;
    logs)
        show_logs
        ;;
    build)
        build_services
        ;;
    clean)
        clean_services
        ;;
    status)
        show_status
        ;;
    test)
        push_test_image
        ;;
    help|*)
        show_help
        ;;
esac
