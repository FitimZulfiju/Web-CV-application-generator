#!/usr/bin/env bash
# WebCV Cloudflared Tunnel Setup Script

set -o nounset
set -o errexit
set -o pipefail

log() { level="$1"; shift; printf '[%s] %s\n' "$level" "$*"; }

# -------------------------
# Helpers for privilege handling.
# -------------------------
IS_ROOT=false
HAS_SUDO=false
if [ "$(id -u)" -eq 0 ]; then
  IS_ROOT=true
else
  if command -v sudo >/dev/null 2>&1; then
    HAS_SUDO=true
  fi
fi

# Use run_cmd "<cmd...>" to run with sudo if needed/available; if neither sudo nor root, runs without elevation.
run_cmd() {
  if $IS_ROOT; then
    bash -c "$*"
  elif $HAS_SUDO; then
 sudo bash -c "$*"
  else
    # No sudo and not root – run plain (may fail for privileged ops)
    bash -c "$*"
  fi
}

# Try to install a package using common package managers
install_package() {
  pkg="$1"
  if command -v apt-get >/dev/null 2>&1; then
    log "INFO" "Using apt-get to install $pkg"
 if $IS_ROOT; then
      DEBIAN_FRONTEND=noninteractive apt-get update -qq
      DEBIAN_FRONTEND=noninteractive apt-get install -y -qq "$pkg"
    elif $HAS_SUDO; then
      DEBIAN_FRONTEND=noninteractive sudo apt-get update -qq
      DEBIAN_FRONTEND=noninteractive sudo apt-get install -y -qq "$pkg"
    else
      log "ERROR" "Need sudo/root to install packages with apt-get. Please run the script with sudo or as root."
      return 1
    fi
  elif command -v dnf >/dev/null 2>&1; then
    log "INFO" "Using dnf to install $pkg"
    if $IS_ROOT; then
 dnf install -y "$pkg"
    elif $HAS_SUDO; then
   sudo dnf install -y "$pkg"
    else
      log "ERROR" "Need sudo/root to install packages with dnf. Please run the script with sudo or as root."
      return 1
    fi
  elif command -v yum >/dev/null 2>&1; then
    log "INFO" "Using yum to install $pkg"
    if $IS_ROOT; then
      yum install -y "$pkg"
    elif $HAS_SUDO; then
      sudo yum install -y "$pkg"
    else
      log "ERROR" "Need sudo/root to install packages with yum. Please run the script with sudo or as root."
      return 1
    fi
  elif command -v apk >/dev/null 2>&1; then
    log "INFO" "Using apk to install $pkg"
    if $IS_ROOT; then
      apk add --no-cache "$pkg"
    elif $HAS_SUDO; then
      sudo apk add --no-cache "$pkg"
    else
  log "ERROR" "Need sudo/root to install packages with apk. Please run the script with sudo or as root."
      return 1
    fi
  else
 log "ERROR" "No supported package manager found to install $pkg (tried apt/dnf/yum/apk)."
  return 1
  fi
  return 0
}

# Install ufw if missing
ensure_ufw() {
  if command -v ufw >/dev/null 2>&1; then
    log "INFO" "ufw already installed"
    return 0
  fi

  log "INFO" "ufw not found – attempting to install ufw"
  if install_package ufw; then
    log "INFO" "ufw installed successfully"
  else
    log "WARN" "Failed to install ufw automatically. Continuing; script will skip ufw steps."
  fi
}

# -------------------------
# Begin main script
# -------------------------
fix_env_file() {
    if [ -f .env ]; then
   log "INFO" "Converting .env to Unix format"
        if command -v dos2unix >/dev/null 2>&1; then
            dos2unix .env || true
        else
     log "WARN" "dos2unix not found; skipping conversion"
    fi
    fi
}

# Set the script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
log "DEBUG" "SCRIPT_DIR=$SCRIPT_DIR"
ls -l "$SCRIPT_DIR/.env" 2>/dev/null || true

# Load .env
if [ -f "$SCRIPT_DIR/.env" ]; then
    log "INFO" "Loading environment from $SCRIPT_DIR/.env"
    # shellcheck disable=SC1090
    source "$SCRIPT_DIR/.env"
else
    log "ERROR" ".env file not found at $SCRIPT_DIR/.env"
    exit 1
fi

# Ensure HOME_DIR and CLOUDFLARED_DIR have sane defaults
HOME_DIR="${HOME_DIR:-$HOME}"
CURRENT_USER="${CURRENT_USER:-$(whoami)}"
CLOUDFLARED_DIR="${CLOUDFLARED_DIR:-$HOME_DIR/.cloudflared}"
DOCKER_COMPOSE_DIR="${DOCKER_COMPOSE_DIR:-$SCRIPT_DIR}"

# Build FULL_SUBDOMAIN carefully (in case SUBDOMAIN is empty)
if [ -n "${SUBDOMAIN:-}" ]; then
  FULL_SUBDOMAIN="${SUBDOMAIN}.${DOMAIN}"
else
  FULL_SUBDOMAIN="${DOMAIN}"
fi

# Build API_FULL_SUBDOMAIN (for API endpoint)
if [ -n "${API_SUBDOMAIN:-}" ]; then
  API_FULL_SUBDOMAIN="${API_SUBDOMAIN}.${DOMAIN}"
else
  API_FULL_SUBDOMAIN="api.${DOMAIN}"
fi

# Validate required env vars
if [ -z "${DOMAIN:-}" ]; then
  log "ERROR" "DOMAIN not set in .env"
  exit 1
fi

if [ -z "${TUNNEL_NAME:-}" ]; then
  log "ERROR" "TUNNEL_NAME not set in .env"
  exit 1
fi

for var in DOMAIN TUNNEL_NAME; do
  if [ -z "${!var:-}" ]; then
    log "ERROR" "Missing env var: $var"
    exit 1
  fi
done

# Cleanup previous runs (best-effort)
log "INFO" "Cleaning up previous configurations..."
{
  if $IS_ROOT || $HAS_SUDO; then
    run_cmd "systemctl stop cloudflared 2>/dev/null || true"
    run_cmd "rm -f /etc/systemd/system/cloudflared.service 2>/dev/null || true"
  else
    # no sudo/root: just try to kill processes
    pkill -f "cloudflared tunnel run" 2>/dev/null || true
  fi
} || true

# Ensure ufw is present (install if missing and sudo/root available)
ensure_ufw

# Ensure directories exist and permissions are sane
log "INFO" "Ensuring cloudflared and credential directories exist and have correct permissions..."

# Ensure HOME_DIR/.cloudflared exists and is owned/secure
mkdir -p "$HOME_DIR/.cloudflared" || { log "ERROR" "Cannot create $HOME_DIR/.cloudflared"; exit 1; }

# Try chown/chmod with elevation if available; otherwise best-effort
if $IS_ROOT || $HAS_SUDO; then
  run_cmd "chown -R '$CURRENT_USER:$CURRENT_USER' '$HOME_DIR/.cloudflared' || true"
  run_cmd "chmod 700 '$HOME_DIR/.cloudflared' || true"
else
  # non-sudo: attempt local chown (may fail on special mounts)
  if chown -R "$CURRENT_USER:$CURRENT_USER" "$HOME_DIR/.cloudflared" 2>/dev/null; then
    chmod 700 "$HOME_DIR/.cloudflared"
  else
    log "WARN" "Could not chown $HOME_DIR/.cloudflared (no sudo or mount disallows). Ensure it is writable by $CURRENT_USER."
  fi
fi

# Check network connectivity to Cloudflare
log "INFO" "Checking Cloudflare API connectivity..."
if ! curl -s -o /dev/null --connect-timeout 10 https://api.cloudflare.com/client/v4/; then
  log "ERROR" "Cannot reach Cloudflare API. Check network/DNS/firewall."
  exit 1
fi

# --- Check for updates and install latest cloudflared if needed (uses sudo if required) ---
INSTALLED_VERSION=""
if command -v cloudflared >/dev/null 2>&1; then
  INSTALLED_VERSION=$(cloudflared --version 2>/dev/null | head -n1 | awk '{print $3}')
fi
LATEST_VERSION=$(curl -s https://api.github.com/repos/cloudflare/cloudflared/releases/latest \
  | grep '"tag_name":' \
  | sed -E 's/.*"v?([^"]+)".*/\1/' || true)

log "INFO" "Installed cloudflared version: ${INSTALLED_VERSION:-<none>}"
log "INFO" "Latest cloudflared version:    ${LATEST_VERSION:-<unknown>}"

if [ -z "$INSTALLED_VERSION" ] || [ -n "$LATEST_VERSION" ] && [[ "$INSTALLED_VERSION" != "$LATEST_VERSION" ]]; then
  log "INFO" "Attempting to install/update cloudflared to $LATEST_VERSION"
  TMP_DEB="/tmp/cloudflared.deb"
  if command -v curl >/dev/null 2>&1; then
    curl -L -sS "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb" -o "$TMP_DEB" || { log "ERROR" "Failed to download cloudflared deb"; true; }
    if [ -f "$TMP_DEB" ]; then
      if $IS_ROOT || $HAS_SUDO; then
        run_cmd "dpkg -i '$TMP_DEB' || true"
    rm -f "$TMP_DEB"
      else
        log "WARN" "Downloaded cloudflared package to $TMP_DEB. Install it manually (requires sudo): sudo dpkg -i $TMP_DEB"
      fi
    else
  log "WARN" "Could not download cloudflared package (skipping auto-install)."
    fi
  else
    log "WARN" "curl not available to download cloudflared; skipping auto-install."
  fi
else
  log "INFO" "cloudflared is up to date or installation skipped"
fi

# Setup & secure directories (again)
mkdir -p "$CLOUDFLARED_DIR"
chmod 755 "$CLOUDFLARED_DIR" 2>/dev/null || true

if [ -f "$CLOUDFLARED_DIR/config.yml" ]; then
  if $IS_ROOT || $HAS_SUDO; then
    run_cmd "chmod 644 '$CLOUDFLARED_DIR/config.yml' || true"
  else
  chmod 644 "$CLOUDFLARED_DIR/config.yml" 2>/dev/null || true
  fi
fi

for f in "$CLOUDFLARED_DIR"/*.json; do
  [ -f "$f" ] && { if $IS_ROOT || $HAS_SUDO; then run_cmd "chmod 644 '$f' || true"; else chmod 644 "$f" 2>/dev/null || true; fi; }
done

# Attempt to open outbound HTTPS in ufw if available (and installed)
if command -v ufw >/dev/null 2>&1; then
  if $IS_ROOT || $HAS_SUDO; then
    run_cmd "ufw allow out 443/tcp || true"
  else
    # no sudo/root: try direct command (will fail if user can't run)
    if command -v ufw >/dev/null 2>&1; then
      ufw allow out 443/tcp 2>/dev/null || log "WARN" "Could not modify ufw rules without root"
    fi
  fi
else
  log "WARN" "ufw not present – it was attempted to be installed earlier. If firewall rules needed, install ufw or configure firewall manually."
fi

# Cloudflare authentication login
CERT_PATH="$CLOUDFLARED_DIR/cert.pem"
if [ ! -f "$CERT_PATH" ]; then
  log "INFO" "Authenticating with Cloudflare (this will open a browser/print a URL)..."
  # cloudflared tunnel login writes to $HOME/.cloudflared
  if ! cloudflared tunnel login; then
    log "ERROR" "cloudflared login failed. Ensure you have a browser or follow printed URL and try again."
    exit 1
  fi
fi

# Remove any existing broken config before tunnel operations
if [ -f "$HOME_DIR/.cloudflared/config.yml" ]; then
log "INFO" "Removing existing config.yml to avoid conflicts..."
  rm -f "$HOME_DIR/.cloudflared/config.yml"
fi

# Tunnel management
log "INFO" "Managing WebCV tunnel '$TUNNEL_NAME'..."
TUNNEL_ALREADY_EXISTS=false
if cloudflared tunnel list | grep -q "$TUNNEL_NAME"; then
  log "INFO" "Tunnel '$TUNNEL_NAME' already exists"
  TUNNEL_ALREADY_EXISTS=true
else
  log "INFO" "Creating new WebCV tunnel..."

  # Store the current HOME and set it explicitly for cloudflared
  ORIGINAL_HOME="$HOME"
  export HOME="$HOME_DIR"

  # Run cloudflared tunnel create as the current user
  if ! cloudflared tunnel create "$TUNNEL_NAME"; then
    log "ERROR" "Tunnel creation failed. Check permissions on $HOME_DIR/.cloudflared"
    export HOME="$ORIGINAL_HOME"
    exit 1
  fi

  # Restore original HOME
  export HOME="$ORIGINAL_HOME"

  log "INFO" "Tunnel created successfully. Waiting for credentials file..."
  # Give it a moment to write the credentials
  sleep 2

  # Fix permissions on newly created credentials file
  log "INFO" "Fixing permissions on new credentials file..."
  for f in "$CLOUDFLARED_DIR"/*.json; do
    if [ -f "$f" ]; then
      if $IS_ROOT || $HAS_SUDO; then
        run_cmd "chmod 644 '$f' || true"
      else
        chmod 644 "$f" 2>/dev/null || true
      fi
    fi
  done
fi

# Get tunnel ID
TUNNEL_ID=$(cloudflared tunnel list | awk -v name="$TUNNEL_NAME" '$0 ~ name {print $1}')
if [ -z "$TUNNEL_ID" ]; then
  log "ERROR" "Could not obtain tunnel ID for $TUNNEL_NAME"
  exit 1
fi

log "INFO" "Found tunnel ID: $TUNNEL_ID"

# Credential paths - check multiple locations
CRED_PATH="$CLOUDFLARED_DIR/$TUNNEL_ID.json"
HOME_CRED="$HOME_DIR/.cloudflared/$TUNNEL_ID.json"
ROOT_CRED="/root/.cloudflared/$TUNNEL_ID.json"

# Find where credentials actually are
if [ -f "$CRED_PATH" ]; then
  log "INFO" "Found credentials at $CRED_PATH"
elif [ -f "$HOME_CRED" ]; then
  log "INFO" "Found credentials at $HOME_CRED"
  CRED_PATH="$HOME_CRED"
elif [ -f "$ROOT_CRED" ]; then
  log "WARN" "Found credentials at $ROOT_CRED (cloudflared was run as root)"
  log "INFO" "Copying credentials from root directory..."
  if $IS_ROOT || $HAS_SUDO; then
    run_cmd "cp '$ROOT_CRED' '$HOME_DIR/.cloudflared/'"
    run_cmd "chown '$CURRENT_USER:$CURRENT_USER' '$HOME_DIR/.cloudflared/$TUNNEL_ID.json'"
    run_cmd "chmod 600 '$HOME_DIR/.cloudflared/$TUNNEL_ID.json'"
    CRED_PATH="$HOME_DIR/.cloudflared/$TUNNEL_ID.json"
  else
    log "ERROR" "Cannot copy credentials from root directory without sudo"
    exit 1
  fi
else
  # Credentials file not found - this might be because the tunnel already existed
  log "WARN" "Credentials file not found in expected locations"

  if $TUNNEL_ALREADY_EXISTS; then
  log "INFO" "Tunnel already existed. Credentials may be missing. Recreating tunnel..."

    # Delete and recreate the tunnel
    if ! cloudflared tunnel delete "$TUNNEL_NAME"; then
      log "ERROR" "Failed to delete existing tunnel. Please manually delete it with: cloudflared tunnel delete $TUNNEL_NAME"
      exit 1
    fi

    log "INFO" "Recreating tunnel..."
    ORIGINAL_HOME="$HOME"
    export HOME="$HOME_DIR"

    if ! cloudflared tunnel create "$TUNNEL_NAME"; then
      log "ERROR" "Failed to recreate tunnel"
      export HOME="$ORIGINAL_HOME"
      exit 1
    fi

    export HOME="$ORIGINAL_HOME"
    sleep 3

  # Get the new tunnel ID
    TUNNEL_ID=$(cloudflared tunnel list | awk -v name="$TUNNEL_NAME" '$0 ~ name {print $1}')
    if [ -z "$TUNNEL_ID" ]; then
      log "ERROR" "Could not obtain tunnel ID after recreation"
  exit 1
    fi

    log "INFO" "New tunnel ID: $TUNNEL_ID"
    HOME_CRED="$HOME_DIR/.cloudflared/$TUNNEL_ID.json"

    if [ -f "$HOME_CRED" ]; then
      log "INFO" "Found credentials at $HOME_CRED after recreation"
      CRED_PATH="$HOME_CRED"
    else
      log "ERROR" "Still cannot find credentials file after recreation"
      log "ERROR" "Available files in ~/.cloudflared:"
      ls -la "$HOME_DIR/.cloudflared" 2>&1 | head -20
 exit 1
    fi
  else
    log "ERROR" "Credentials file not found in any location:"
    log "ERROR" "  - $CRED_PATH"
  log "ERROR" "  - $HOME_CRED"
    log "ERROR" "  - $ROOT_CRED"
    log "ERROR" "Available files in ~/.cloudflared:"
    ls -la "$HOME_DIR/.cloudflared" 2>&1 | head -20
    log "DEBUG" "Current user: $(whoami)"
    log "DEBUG" "HOME_DIR: $HOME_DIR"
    log "DEBUG" "HOME env var: $HOME"
    exit 1
  fi
fi

log "INFO" "Using credentials: $CRED_PATH"

# Verify credentials file is readable
if [ ! -r "$CRED_PATH" ]; then
  log "ERROR" "Credentials file exists but is not readable: $CRED_PATH"
  ls -la "$CRED_PATH"
  exit 1
fi

# Create config.yml in CLOUDFLARED_DIR
CONFIG_PATH="$CLOUDFLARED_DIR/config.yml"

# If config path is unexpectedly a directory, remove it (with care)
if [ -d "$CONFIG_PATH" ]; then
  log "WARN" "$CONFIG_PATH is a directory. Removing..."
  if $IS_ROOT || $HAS_SUDO; then
 run_cmd "rm -rf '$CONFIG_PATH'"
  else
    rm -rf "$CONFIG_PATH"
  fi
fi

log "INFO" "Writing WebCV tunnel configuration to $CONFIG_PATH"
log "INFO" "Using Docker Compose service names (web, api, grafana) for webcv_network"
CRED_BASENAME=$(basename "$CRED_PATH")
cat << EOF > "$CONFIG_PATH"
tunnel: $TUNNEL_ID
credentials-file: /home/nonroot/.cloudflared/$CRED_BASENAME


ingress:
  - hostname: $FULL_SUBDOMAIN
    service: http://webcv-app:80
    originRequest:
      noTLSVerify: true
  - service: http_status:404

EOF
if $IS_ROOT || $HAS_SUDO; then
  run_cmd "chown '$CURRENT_USER:$CURRENT_USER' '$CONFIG_PATH' || true"
  run_cmd "chmod 644 '$CONFIG_PATH' || true"
else
  chmod 644 "$CONFIG_PATH" 2>/dev/null || true
fi

log "INFO" "✅ Config file created successfully"

# Update .env in DOCKER_COMPOSE_DIR with TUNNEL_ID
log "INFO" "Updating $DOCKER_COMPOSE_DIR/.env with TUNNEL_ID=$TUNNEL_ID"
if [ -f "$DOCKER_COMPOSE_DIR/.env" ]; then
  if grep -q "^TUNNEL_ID=" "$DOCKER_COMPOSE_DIR/.env"; then
    sed -i "s/^TUNNEL_ID=.*/TUNNEL_ID=$TUNNEL_ID/" "$DOCKER_COMPOSE_DIR/.env"
    log "INFO" "✅ Updated existing TUNNEL_ID in .env"
  else
    echo "TUNNEL_ID=$TUNNEL_ID" >> "$DOCKER_COMPOSE_DIR/.env"
    log "INFO" "✅ Added TUNNEL_ID to .env"
  fi
else
  echo "TUNNEL_ID=$TUNNEL_ID" > "$DOCKER_COMPOSE_DIR/.env"
  log "INFO" "✅ Created .env with TUNNEL_ID"
fi

# Systemd service setup (only if we have sudo/root)
if $IS_ROOT || $HAS_SUDO; then
  log "INFO" "Configuring systemd service for WebCV cloudflared tunnel (requires sudo/root)"
  run_cmd "tee /etc/systemd/system/cloudflared.service > /dev/null <<EOF
[Unit]
Description=Cloudflare Tunnel for WebCV
After=network.target

[Service]
TimeoutStartSec=0
ExecStart=$(which cloudflared) tunnel run $TUNNEL_NAME
Restart=always
RestartSec=5
User=$CURRENT_USER

[Install]
WantedBy=multi-user.target
EOF"
  run_cmd "systemctl daemon-reload"
  run_cmd "systemctl enable --now cloudflared" || log "WARN" "Could not enable/start systemd service. Check systemctl output."
else
  log "WARN" "Not running as root and sudo not available – skipping systemd unit creation. You can run the tunnel manually:"
  echo
  printf "  cloudflared tunnel --config %s run %s\n" "$CONFIG_PATH" "$TUNNEL_NAME"
  echo
fi

log "SUCCESS" "WebCV Cloudflare Tunnel setup complete!"
log "INFO" "Tunnel configuration:"
log "INFO" "  - $DOMAIN -> web:8080 (WebCV Blazor Server Web App)"
log "INFO" "  - $API_FULL_SUBDOMAIN -> api:8080 (WebCV API + WASM Client)"
log "INFO" "  - $FULL_SUBDOMAIN -> grafana:3000 (Grafana Dashboard)"
log "INFO" "Check status (if systemd enabled): sudo systemctl status cloudflared"
log "INFO" "View logs: journalctl -u cloudflared -f"
log "INFO" "IMPORTANT: cloudflared container MUST be on the 'webcv_network' to reach these services!"
