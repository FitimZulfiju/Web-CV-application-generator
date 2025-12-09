#!/usr/bin/env bash
# Simplified WebCV Cloudflare Tunnel Setup Script
# Focuses on configuration and deployment without complex tunnel recreation

set -euo pipefail

# Logging functions
log() { printf '[%s] %s\n' "$1" "$2" >&2; }

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR" || exit 1

# Load environment variables
ENV_FILE="$SCRIPT_DIR/.env"
if [ ! -f "$ENV_FILE" ]; then
  log "ERROR" ".env file not found at $ENV_FILE"
  exit 1
fi

log "INFO" "Loading environment from $ENV_FILE"
set -a
source "$ENV_FILE"
set +a

# Set defaults
DEPLOY_USER="${DEPLOY_USER:-$(whoami)}"
DEPLOY_USER_HOME="${DEPLOY_USER_HOME:-/home/$DEPLOY_USER}"
CLOUDFLARED_DIR="${CLOUDFLARED_DIR:-$DEPLOY_USER_HOME/.cloudflared}"
DOCKER_COMPOSE_DIR="$SCRIPT_DIR"

# Ensure DEPLOY_USER and DEPLOY_USER_HOME are in .env
if ! grep -q "^DEPLOY_USER=" "$ENV_FILE"; then
  echo "DEPLOY_USER=$DEPLOY_USER" >> "$ENV_FILE"
  log "INFO" "Added DEPLOY_USER to .env"
fi

if ! grep -q "^DEPLOY_USER_HOME=" "$ENV_FILE"; then
  echo "DEPLOY_USER_HOME=$DEPLOY_USER_HOME" >> "$ENV_FILE"
  log "INFO" "Added DEPLOY_USER_HOME to .env"
fi

# Check if user exists, create if needed
if ! id "$DEPLOY_USER" &>/dev/null; then
  log "WARN" "User $DEPLOY_USER does not exist"
  if [ "$EUID" -eq 0 ]; then
    log "INFO" "Creating user $DEPLOY_USER..."
    useradd -m -d "$DEPLOY_USER_HOME" -s /bin/bash "$DEPLOY_USER"
    
    # Add to docker group if it exists
    if getent group docker &>/dev/null; then
      usermod -aG docker "$DEPLOY_USER"
      log "INFO" "Added $DEPLOY_USER to docker group"
    fi
  else
    log "ERROR" "User $DEPLOY_USER doesn't exist and script not running as root"
    log "ERROR" "Please run: sudo useradd -m -d $DEPLOY_USER_HOME -s /bin/bash $DEPLOY_USER"
    exit 1
  fi
fi

log "INFO" "Using deployment user: $DEPLOY_USER ($DEPLOY_USER_HOME)"

# Create cloudflared directory
mkdir -p "$CLOUDFLARED_DIR"
chown -R "$DEPLOY_USER:$DEPLOY_USER" "$CLOUDFLARED_DIR" 2>/dev/null || true
chmod 755 "$CLOUDFLARED_DIR" 2>/dev/null || true

# Check if cloudflared is installed
if ! command -v cloudflared &>/dev/null; then
  log "ERROR" "cloudflared is not installed"
  log "INFO" "Install with: curl -L https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb -o cloudflared.deb && sudo dpkg -i cloudflared.deb"
  exit 1
fi

log "INFO" "cloudflared version: $(cloudflared version 2>/dev/null | head -1)"

# Get or create tunnel
TUNNEL_NAME="${TUNNEL_NAME:-webcv}"
log "INFO" "Checking for tunnel: $TUNNEL_NAME"

TUNNEL_ID=$(cloudflared tunnel list 2>/dev/null | grep "$TUNNEL_NAME" | awk '{print $1}' | head -1)

if [ -z "$TUNNEL_ID" ]; then
  log "INFO" "Tunnel $TUNNEL_NAME not found, creating..."
  
  # Create tunnel (runs as current user, creates in ~/.cloudflared)
  if ! cloudflared tunnel create "$TUNNEL_NAME" 2>&1 | tee /tmp/tunnel_create.log; then
    log "ERROR" "Failed to create tunnel"
    cat /tmp/tunnel_create.log
    exit 1
  fi
  
  # Get the new tunnel ID
  TUNNEL_ID=$(cloudflared tunnel list 2>/dev/null | grep "$TUNNEL_NAME" | awk '{print $1}' | head -1)
  
  if [ -z "$TUNNEL_ID" ]; then
    log "ERROR" "Failed to get tunnel ID after creation"
    exit 1
  fi
  
  log "INFO" "Created tunnel with ID: $TUNNEL_ID"
else
  log "INFO" "Using existing tunnel ID: $TUNNEL_ID"
fi

# Find credential file
CRED_FILE="$CLOUDFLARED_DIR/${TUNNEL_ID}.json"

if [ ! -f "$CRED_FILE" ]; then
  log "WARN" "Credential file not found at $CRED_FILE, searching..."
  
  # Search for any credential file matching the tunnel ID
  FOUND_CRED=$(find "$CLOUDFLARED_DIR" /root/.cloudflared -name "${TUNNEL_ID}.json" -type f 2>/dev/null | head -1)
  
  if [ -n "$FOUND_CRED" ]; then
    log "INFO" "Found credential at: $FOUND_CRED"
    cp "$FOUND_CRED" "$CRED_FILE"
  else
    # Try to find any .json file and use the most recent
    FOUND_CRED=$(find "$CLOUDFLARED_DIR" /root/.cloudflared -name "*.json" -type f 2>/dev/null | sort -r | head -1)
    if [ -n "$FOUND_CRED" ]; then
      log "WARN" "Using most recent credential file: $FOUND_CRED"
      cp "$FOUND_CRED" "$CRED_FILE"
      # Update tunnel ID based on filename
      TUNNEL_ID=$(basename "$FOUND_CRED" .json)
      log "INFO" "Updated TUNNEL_ID to: $TUNNEL_ID"
    else
      log "ERROR" "No credential files found"
      exit 1
    fi
  fi
fi

# Fix ownership and permissions
chown "$DEPLOY_USER:$DEPLOY_USER" "$CRED_FILE" 2>/dev/null || true
chmod 644 "$CRED_FILE"

log "INFO" "Using credentials: $CRED_FILE"

# Update TUNNEL_ID in .env
if grep -q "^TUNNEL_ID=" "$ENV_FILE"; then
  sed -i "s/^TUNNEL_ID=.*/TUNNEL_ID=$TUNNEL_ID/" "$ENV_FILE"
  log "INFO" "Updated TUNNEL_ID in .env"
else
  echo "TUNNEL_ID=$TUNNEL_ID" >> "$ENV_FILE"
  log "INFO" "Added TUNNEL_ID to .env"
fi

# Create cloudflared-mount directory
MOUNT_DIR="$DOCKER_COMPOSE_DIR/cloudflared-mount"
mkdir -p "$MOUNT_DIR"

log "INFO" "Creating tunnel configuration..."

# Create webcv-config.yml
cat > "$MOUNT_DIR/webcv-config.yml" << EOF
tunnel: $TUNNEL_ID
credentials-file: /etc/cloudflared/${TUNNEL_ID}.json

ingress:
  - hostname: ${SUBDOMAIN}.${DOMAIN}
    service: http://webcv-app:8090
    originRequest:
      noTLSVerify: true
  - hostname: ${DOMAIN}
    service: http://webcv-app:8090
    originRequest:
      noTLSVerify: true
  - service: http_status:404
EOF

log "INFO" "Created config: $MOUNT_DIR/webcv-config.yml"

# Copy credentials to both locations
cp "$CRED_FILE" "$MOUNT_DIR/"
cp "$CRED_FILE" "$CLOUDFLARED_DIR/" 2>/dev/null || true

# Set permissions
chmod 644 "$MOUNT_DIR/webcv-config.yml"
chmod 644 "$MOUNT_DIR"/*.json

log "SUCCESS" "Cloudflared configuration complete!"
log "INFO" "Mount directory contents:"
ls -lah "$MOUNT_DIR/"

# Restart cloudflared container if Docker is available
if command -v docker &>/dev/null; then
  log "INFO" "Restarting cloudflared container..."
  
  if docker ps -a 2>/dev/null | grep -q webcv-cloudflared; then
    docker restart webcv-cloudflared 2>/dev/null || log "WARN" "Failed to restart container"
    sleep 3
    
    if docker ps 2>/dev/null | grep -q webcv-cloudflared; then
      log "SUCCESS" "Container restarted successfully"
      log "INFO" "Recent logs:"
      docker logs webcv-cloudflared --tail 10 2>/dev/null || true
    else
      log "WARN" "Container may not be running. Check with: docker logs webcv-cloudflared"
    fi
  else
    log "WARN" "Container webcv-cloudflared not found"
    log "INFO" "Start it with: docker-compose up -d cloudflared"
  fi
fi

log "SUCCESS" "Setup complete!"
log "INFO" "Tunnel ID: $TUNNEL_ID"
log "INFO" "Domain: ${DOMAIN:-fitim.it.com}"
