#!/bin/bash

# Health check script for Docker Registry
# Usage: ./health-check.sh [registry|ui|trivy|all]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Load environment
ENV=${ENV:-dev}
ENV_FILE=".env.$ENV"

if [[ -f "$ENV_FILE" ]]; then
    source "$ENV_FILE"
else
    echo "Environment file $ENV_FILE not found, using defaults"
    REGISTRY_PORT=5000
    REGISTRY_UI_PORT=8080
    TRIVY_PORT=8081
fi

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

check_service() {
    local service=$1
    local url=$2
    local name=$3
    
    echo -n "Checking $name... "
    
    if curl -s -f "$url" > /dev/null 2>&1; then
        echo -e "${GREEN}✓ OK${NC}"
        return 0
    else
        echo -e "${RED}✗ FAILED${NC}"
        return 1
    fi
}

check_registry() {
    check_service "registry" "http://localhost:$REGISTRY_PORT/v2/" "Docker Registry"
}

check_ui() {
    check_service "registry-ui" "http://localhost:$REGISTRY_UI_PORT/" "Registry UI"
}

check_trivy() {
    check_service "trivy" "http://localhost:$TRIVY_PORT/healthz" "Trivy Scanner"
}

check_all() {
    echo "Health Check for Docker Registry Services"
    echo "========================================"
    
    local failed=0
    
    check_registry || failed=$((failed + 1))
    check_ui || failed=$((failed + 1))
    check_trivy || failed=$((failed + 1))
    
    echo ""
    if [[ $failed -eq 0 ]]; then
        echo -e "${GREEN}All services are healthy!${NC}"
        exit 0
    else
        echo -e "${RED}$failed service(s) failed health check${NC}"
        exit 1
    fi
}

case "${1:-all}" in
    registry)
        check_registry
        ;;
    ui)
        check_ui
        ;;
    trivy)
        check_trivy
        ;;
    all)
        check_all
        ;;
    *)
        echo "Usage: $0 [registry|ui|trivy|all]"
        exit 1
        ;;
esac
