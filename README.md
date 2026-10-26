# GeM MCP Server — Private Deployment

A self-hosted MCP server for searching Government e-Marketplace (GeM) bids using an AI assistant such as Open WebUI. Supports Linux ARM64 and x86_64, including Dell GB10.

## Components

- **GeM MCP Server:** Searches and parses GeM bids.
- **Open WebUI:** Browser-based AI chat interface.
- **LLM:** Interprets queries and invokes MCP tools.
- **Relevance Engine:** Ranks bids against your company profile.

## Requirements

- Linux with systemd
- Python 3, pip, and venv
- Git
- Docker Engine
- Network access to GeM and Python package repositories

## Ports and URLs

| Component | Port / URL |
|---|---|
| GeM MCP Server | `7000` |
| Health endpoint | `http://127.0.0.1:7000/health` |
| MCP endpoint | `http://SERVER_LAN_IP:7000/mcp` |
| Open WebUI | `http://SERVER_LAN_IP:3000` |

Replace `SERVER_LAN_IP` with your server's IP address.

## Installation

### 1. Clone the repository

```bash
git clone https://github.com/premjithbenny/Gem-MCP-Private-Deploy.git
cd Gem-MCP-Private-Deploy
```

For a private repository, authenticate with GitHub when prompted.

### 2. Configure the environment

Copy the example environment file to `.env`:

```bash
cp .env.example .env
chmod 600 .env
nano .env
```

Review the variables and update the values required by your deployment. Keep production credentials out of Git.

### 3. Review and run the installer

Inspect the deployment script before running it:

```bash
less deploy_gem_mcp.sh
```

Confirm that the script configures the MCP server to use port `7000`.

Then run:

```bash
chmod +x deploy_gem_mcp.sh
sudo bash deploy_gem_mcp.sh
```

### 4. Verify the MCP server

```bash
sudo systemctl status gem-mcp --no-pager
curl -fsS http://127.0.0.1:7000/health
echo
sudo ss -lntp | grep ':7000'
```

The service should be active and listening on port `7000`.

### 5. Install Open WebUI

If Open WebUI is not already installed, run:

```bash
docker volume create open-webui

docker run -d \
  --name Gem-Mcp-webui \
  --restart unless-stopped \
  -p 3000:8080 \
  -v open-webui:/app/backend/data \
  ghcr.io/open-webui/open-webui:main
```

Open the interface:

```text
http://SERVER_LAN_IP:3000
```

If Open WebUI is already running, reuse the existing container and configuration rather than creating a duplicate.

## Connect Open WebUI to MCP

1. Open Open WebUI settings.
2. Find the MCP server or tool integration settings.
3. Add an **MCP Streamable HTTP** server.
4. Set the URL to:

   ```text
   http://SERVER_LAN_IP:7000/mcp
   ```

5. Save the configuration and enable the GeM MCP tools for your chat or model.

If Open WebUI runs in Docker, use a host address reachable from the container. Do not use `127.0.0.1` to refer to the host from inside the container.

## Search GeM Bids

Example prompts:

- Find open GeM bids related to servers.
- Search for GPU servers and AI infrastructure tenders.
- Find server maintenance contracts.
- Search for data-centre equipment tenders.

The search tool is named:

```text
gem-mcp_search_bids
```

Check the connected MCP client's tool schema for supported parameters.

Always verify bid status, deadlines, eligibility, and tender documents on the official GeM website before taking action.

## Service Management

Check status:

```bash
sudo systemctl status gem-mcp --no-pager
```

Restart:

```bash
sudo systemctl restart gem-mcp
```

View logs:

```bash
sudo journalctl -u gem-mcp -n 100 --no-pager
```

Follow logs:

```bash
sudo journalctl -u gem-mcp -f
```

## Troubleshooting

**MCP server is unavailable**

```bash
sudo systemctl status gem-mcp --no-pager
sudo journalctl -u gem-mcp -n 100 --no-pager
curl -v http://127.0.0.1:7000/health
```

**Open WebUI cannot connect to MCP**

- Confirm the MCP endpoint ends in `/mcp`.
- Confirm the server listens on port `7000`.
- Verify Docker networking and firewall rules.
- Use the MCP integration, not an OpenAPI integration.

**Python dependency errors**

```bash
cd /opt/gem_mcp
.venv/bin/pip install -r requirements.txt
```

## Security

- Keep `.env` out of version control.
- Commit `.env.example` with placeholders only.
- Restrict ports `7000` and `3000` to trusted clients.
- Do not expose MCP publicly without appropriate authentication, TLS, and network controls.
- Back up configuration and persistent data before making deployment changes.

## Notes

The README assumes the deployment script, Python server, and systemd service are configured consistently for port `7000`. Verify the actual implementation before deploying.

