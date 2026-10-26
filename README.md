# GeM MCP Server — Private Deployment

A self-hosted Model Context Protocol (MCP) server for searching tenders and bids published on India's Government e-Marketplace (GeM). Connect it to Open WebUI to search procurement opportunities using natural-language prompts.

Supports Linux ARM64 and x86_64, including Dell GB10.

## Components

- **GeM MCP Server:** Searches and parses GeM bids.
- **Open WebUI:** Browser-based AI chat interface.
- **LLM:** Interprets user queries and invokes MCP tools.
- **Relevance Engine:** Ranks bids against your company profile.

## Requirements

- Linux with systemd
- Python 3, pip, and virtual environment support
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

Replace `SERVER_LAN_IP` with your server's actual IP address.

## Installation

### 1. Clone the repository

```bash
git clone https://github.com/premjithbenny/Gem-MCP-Private-Deploy.git
cd Gem-MCP-Private-Deploy
```

For a private repository, authenticate with GitHub when prompted.

### 2. Configure the environment

Create `.env` from the example file:

```bash
cp .env.example .env
chmod 600 .env
nano .env
```

Review the configuration and replace any placeholders with the required values. Keep real credentials out of Git.

### 3. Review and run the deployment script

Inspect the script before running it:

```bash
less deploy.sh
```

Confirm that the script configures the MCP server to listen on port `7000`.

Deploy:

```bash
chmod +x deploy.sh
sudo bash deploy.sh
```

The script installs dependencies, copies the application into `/opt/gem_mcp`, configures the `gem-mcp` systemd service, and starts it.

**Note:** The deployment script preserves an existing `/opt/gem_mcp/.env`. If that file already exists, the newly created `.env` in the Git checkout will not overwrite it.

### 4. Verify the MCP server

```bash
sudo systemctl status gem-mcp --no-pager
curl -fsS http://127.0.0.1:8002/health
echo
sudo ss -lntp | grep ':8002'
```

The service should be active and listening on port `8002`.

### 5. Install Open WebUI

If Open WebUI is not already running, create a persistent volume and start the container:

```bash
docker volume create open-webui

docker run -d \
  --name Gem-Mcp-webui \
  --restart unless-stopped \
  -p 3000:8080 \
  -v open-webui:/app/backend/data \
  ghcr.io/open-webui/open-webui:main
```

Open WebUI in your browser:

```text
http://SERVER_LAN_IP:3000
```

If Open WebUI is already installed, reuse the existing container rather than creating a duplicate.

## Configure MCP in Open WebUI

Open WebUI's interface may vary by version. Use the MCP integration settings available in your installed version.

### 1. Open the settings

1. Open `http://SERVER_LAN_IP:3000` in your browser.
2. Sign in to Open WebUI.
3. Open the user menu or administration settings.
4. Locate the **Tools**, **External Tools**, or **MCP Servers** configuration area, depending on your version.

### 2. Add the GeM MCP server

Create a new MCP server connection with these settings:

| Setting | Value |
|---|---|
| Name | `GeM MCP` |
| Connection type | `MCP Streamable HTTP` |
| Server URL | `http://SERVER_LAN_IP:8002/mcp` |

Replace `SERVER_LAN_IP` with your server's actual LAN IP address.

Save the connection. If your version provides a connection test, run it and confirm that the server connects successfully.

**Important:** Use the MCP integration, not an OpenAPI connection.

### 3. Verify that the tools are available

After saving the connection:

1. Open the MCP server configuration.
2. Confirm that the GeM server is connected.
3. Open its available tools, if your version displays a tool list.
4. Confirm that the GeM bid-search tool is available.

The search tool used by this project is:

```text
gem-mcp_search_bids
```

If the tool is missing, check the MCP server logs and confirm that the URL ends with `/mcp`.

### 4. Select the MCP tools in a chat

1. Start a **new chat** in Open WebUI.
2. Select a model that supports tool calling.
3. Open the chat's **Tools** selector, tool menu, or equivalent control for your Open WebUI version.
4. Enable the GeM MCP search tool or the tools exposed by the `GeM MCP` connection.
5. Enter a procurement-related query and send it.

If your version automatically makes connected MCP tools available, you may not need to enable them manually. Tool selection and naming vary by version.

The model must support tool calling to invoke the search tool. If it only responds with general advice and does not search GeM, check that the tool is enabled and that the selected model can use tools.

### Docker networking

When Open WebUI runs in Docker, `127.0.0.1` refers to the container itself, not the Linux host.

Use the host's reachable LAN IP for the MCP URL:

```text
http://SERVER_LAN_IP:8002/mcp
```

Alternatively, on Docker for Linux, you can configure the container with:

```bash
--add-host=host.docker.internal:host-gateway
```

Then use:

```text
http://host.docker.internal:8002/mcp
```

The MCP server must listen on a host interface reachable from the container, and the host firewall must allow the connection.

## Search GeM Bids

Once the MCP connection is configured and the search tool is enabled, ask questions directly in Open WebUI.

### Example 1: Search open server bids

Enter:

```text
Find open GeM bids related to servers.
Show bid number, title, buyer organisation, closing date,
relevance score, and official bid link where available.
```

### Example 2: Search GPU and AI infrastructure tenders

```text
Search GeM for GPU servers, NVIDIA GPUs, AI infrastructure,
and high-performance computing tenders.
Prioritise open bids and explain why each result is relevant.
```

### Example 3: Search networking tenders

```text
Find open GeM bids for data-centre networking,
Ethernet switches, InfiniBand, and network infrastructure.
```

### Example 4: Search maintenance contracts

```text
Find open GeM tenders for server maintenance,
data-centre support, and IT infrastructure services.
```

### Example 5: Refine a search

```text
Search for open server bids and show up to 10 relevant results.
Exclude closed bids and include the closing date for each result.
```

Results depend on GeM's available data, the search implementation, and the arguments supported by the MCP tool. Always verify deadlines, eligibility, and tender documents on the official GeM website.

### Search tool details

The tool is named:

```text
gem-mcp_search_bids
```

The implementation may expose parameters such as:

| Parameter | Example | Purpose |
|---|---|---|
| `keyword` | `servers` | Search term |
| `search_type` | `fullText` | Search mode |
| `max_results` | `10` | Maximum requested results |
| `status` | `open` | Requested bid status |
| `save_to_db` | `true` | Whether to save results, if supported |

Use the schema shown by the connected MCP client as the authoritative list of parameters.

### How to confirm a search worked

A successful search should cause the model to invoke the GeM MCP search tool and then present the returned results.

If the model only generates a generic answer without invoking the tool:

1. Confirm that the GeM MCP connection is active.
2. Confirm that the search tool is enabled in the chat.
3. Confirm that the selected model supports tool calling.
4. Ask a specific query, such as `Search GeM for open server bids`.
5. Inspect the MCP service logs for errors.

## Service Management

Check status:

```bash
sudo systemctl status gem-mcp --no-pager
```

Restart:

```bash
sudo systemctl restart gem-mcp
```

View recent logs:

```bash
sudo journalctl -u gem-mcp -n 100 --no-pager
```

Follow logs:

```bash
sudo journalctl -u gem-mcp -f
```

Check the health endpoint:

```bash
curl -v http://127.0.0.1:8002/health
```

## Troubleshooting

### MCP server is unavailable

```bash
sudo systemctl status gem-mcp --no-pager
sudo journalctl -u gem-mcp -n 100 --no-pager
sudo ss -lntp | grep ':8002'
curl -v http://127.0.0.1:8002/health
```

Check the service configuration and confirm that `server.py` reads the `PORT` environment variable.

### Open WebUI cannot connect to MCP

- Confirm the server URL ends in `/mcp`.
- Confirm that the service listens on port `8002`.
- Use the host's reachable IP address rather than `127.0.0.1` from inside Docker.
- Check firewall rules and Docker networking.
- Confirm that the connection type is MCP Streamable HTTP.
- Check the Open WebUI and MCP server logs.

### MCP tools do not appear

- Verify that the MCP connection is saved and connected.
- Confirm that the server exposes its tools successfully.
- Refresh or reopen the chat.
- Check the installed Open WebUI version and its MCP integration requirements.
- Ensure that the selected model supports tool calling.

### Python dependency errors

```bash
cd /opt/gem_mcp
.venv/bin/pip install -r requirements.txt
```

Check service logs before changing configuration or reinstalling dependencies.

### No relevant bids returned

Try a broader keyword, inspect the tool output, and verify the requested status and search mode. A low relevance count does not necessarily mean GeM returned no bids.

## Security

- Keep `.env` out of version control.
- Commit `.env.example` with placeholder values only.
- Restrict ports `8002` and `3000` to trusted clients.
- Do not expose MCP directly to the public internet without appropriate authentication, TLS, and network controls.
- Back up configuration and persistent data before making deployment changes.
- Verify bid details and deadlines on the official GeM website.

## Notes

The deployment script, Python server, and systemd service must all be configured consistently for port `8002`. Open WebUI is exposed on host port `3000`, mapped to container port `8080`.

Check the actual repository filenames and application configuration before deployment.
