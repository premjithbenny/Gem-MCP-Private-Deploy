```bash
#!/usr/bin/env bash
# GeM MCP deployment for Ubuntu, including ARM64 systems.
# Run from the project directory:
#   sudo bash deploy.sh
#
# Optional MongoDB installation:
#   sudo INSTALL_MONGODB=1 bash deploy.sh

set -Eeuo pipefail

APP_DIR="/opt/gem_mcp"
SERVICE_NAME="gem-mcp"
MCP_PORT="7000"
WEBUI_PORT="3000"
PYTHON_BIN="${PYTHON_BIN:-python3}"
INSTALL_MONGODB="${INSTALL_MONGODB:-0}"
SOURCE_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

if [[ $EUID -ne 0 ]]; then
  echo "ERROR: Run with sudo: sudo bash deploy.sh" >&2
  exit 1
fi

for f in server.py gem_scraper.py relevance_engine.py; do
  if [[ ! -f "$SOURCE_DIR/$f" ]]; then
    echo "ERROR: $SOURCE_DIR/$f not found." >&2
    exit 1
  fi
done

. /etc/os-release
if [[ "${ID:-}" != "ubuntu" && "${ID_LIKE:-}" != *ubuntu* ]]; then
  echo "WARNING: Designed for Ubuntu; detected ${PRETTY_NAME:-unknown}."
fi

echo "==> Installing system dependencies"
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y "$PYTHON_BIN" python3-venv python3-pip \
  build-essential curl ca-certificates rsync

if [[ "$INSTALL_MONGODB" == "1" ]]; then
  CODENAME="${VERSION_CODENAME:-}"
  if [[ "$CODENAME" != "jammy" && "$CODENAME" != "noble" ]]; then
    echo "ERROR: Automatic MongoDB install supports Ubuntu 22.04/24.04 only." >&2
    exit 1
  fi

  echo "==> Installing MongoDB Community Server 8.0"
  apt-get install -y gnupg
  install -d -m 0755 /usr/share/keyrings
  curl -fsSL https://pgp.mongodb.com/server-8.0.asc \
    | gpg --dearmor --yes -o /usr/share/keyrings/mongodb-server-8.0.gpg

  echo "deb [ arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/mongodb-server-8.0.gpg ] https://repo.mongodb.org/apt/ubuntu ${CODENAME}/mongodb-org/8.0 multiverse" \
    > /etc/apt/sources.list.d/mongodb-org-8.0.list

  apt-get update
  apt-get install -y mongodb-org
  systemctl enable --now mongod
fi

echo "==> Copying project to $APP_DIR"
install -d -m 0755 "$APP_DIR"

# Preserve server-side environment and runtime files.
rsync -a \
  --exclude '.git/' \
  --exclude '.venv/' \
  --exclude 'venv/' \
  --exclude '__pycache__/' \
  --exclude '*.pyc' \
  --exclude '*.log' \
  --exclude '.env' \
  --exclude 'deploy.sh' \
  "$SOURCE_DIR/" "$APP_DIR/"

# Create .env from .env.example only when .env does not already exist.
if [[ ! -f "$APP_DIR/.env" ]]; then
  if [[ -f "$SOURCE_DIR/.env.example" ]]; then
    cp "$SOURCE_DIR/.env.example" "$APP_DIR/.env"
    echo "Created $APP_DIR/.env from .env.example"
  elif [[ -f "$SOURCE_DIR/.env" ]]; then
    cp "$SOURCE_DIR/.env" "$APP_DIR/.env"
  else
    touch "$APP_DIR/.env"
    echo "WARNING: No .env.example found; created an empty .env."
  fi
fi

chmod 600 "$APP_DIR/.env"
echo "Review configuration: nano $APP_DIR/.env"

echo "==> Creating Python virtual environment"
if [[ ! -x "$APP_DIR/.venv/bin/python" ]]; then
  "$PYTHON_BIN" -m venv "$APP_DIR/.venv"
fi

"$APP_DIR/.venv/bin/python" -m pip install --upgrade pip wheel

if [[ -f "$APP_DIR/requirements.txt" ]]; then
  "$APP_DIR/.venv/bin/pip" install -r "$APP_DIR/requirements.txt"
fi

"$APP_DIR/.venv/bin/pip" install \
  'mcp<2' 'uvicorn[standard]' starlette python-dotenv \
  requests beautifulsoup4 pymongo

echo "==> Validating Python files and imports"
cd "$APP_DIR"

"$APP_DIR/.venv/bin/python" -m py_compile \
  server.py gem_scraper.py relevance_engine.py

"$APP_DIR/.venv/bin/python" - <<'PY'
from mcp.server.fastmcp import FastMCP
import uvicorn, starlette, requests, bs4, pymongo, dotenv
from relevance_engine import score_bid
print("Python dependencies and imports: OK")
PY

echo "==> Creating service account"
if ! id gemmcp >/dev/null 2>&1; then
  useradd --system --home-dir "$APP_DIR" \
    --shell /usr/sbin/nologin gemmcp
fi

chown -R gemmcp:gemmcp "$APP_DIR"
chmod 600 "$APP_DIR/.env"

echo "==> Installing systemd service"
cat > "/etc/systemd/system/${SERVICE_NAME}.service" <<EOF
[Unit]
Description=GeM MCP Server
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=gemmcp
Group=gemmcp
WorkingDirectory=${APP_DIR}
Environment=HOST=0.0.0.0
Environment=PORT=${MCP_PORT}
EnvironmentFile=-${APP_DIR}/.env
ExecStart=${APP_DIR}/.venv/bin/python ${APP_DIR}/server.py
Restart=on-failure
RestartSec=5
NoNewPrivileges=true
PrivateTmp=true

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now "$SERVICE_NAME"

echo
echo "==> Deployment finished"
echo "Service:       systemctl status ${SERVICE_NAME} --no-pager"
echo "Logs:          journalctl -u ${SERVICE_NAME} -f"
echo "Restart:       systemctl restart ${SERVICE_NAME}"
echo "Health check:  curl -i http://127.0.0.1:${MCP_PORT}/health"
echo "MCP endpoint:  http://SERVER_LAN_IP:${MCP_PORT}/mcp"
echo "Open WebUI:    http://SERVER_LAN_IP:${WEBUI_PORT}"
echo
echo "IMPORTANT: Confirm server.py reads the PORT environment variable."
echo "Configure Open WebUI separately using the Docker command in README.md."
echo "Do not expose MCP publicly without suitable access controls and TLS."
```
