# GeM MCP Server — Private Deployment

A self-hosted Model Context Protocol (MCP) server for searching tenders and bids published on India's Government e-Marketplace (GeM). Connect it to an MCP-compatible AI client such as Open WebUI to search procurement opportunities using natural-language prompts.

Designed for Linux deployments, including ARM64 systems such as Dell GB10.

## Table of Contents

- [Overview](#overview)
- [Features](#features)
- [Architecture](#architecture)
- [Repository Structure](#repository-structure)
- [Requirements](#requirements)
- [Installation](#installation)
- [Verify the Server](#verify-the-server)
- [Install Open WebUI](#install-open-webui)
- [Connect Open WebUI to MCP](#connect-open-webui-to-mcp)
- [Search GeM Bids](#search-gem-bids)
- [Configuration](#configuration)
- [Service Management](#service-management)
- [Updating the Deployment](#updating-the-deployment)
- [Troubleshooting](#troubleshooting)
- [Security](#security)

## Overview

The GeM MCP Server exposes bid-search functionality through the Model Context Protocol. An MCP-compatible AI client can discover and invoke the available tools as part of an AI conversation.

Example prompt:

> Find open GeM bids related to servers and AI infrastructure.

The AI client can call the search tool, retrieve matching bid records, and present bid numbers, titles, ministries, closing dates, and official bid links.

The application can also use project-specific relevance scoring to rank procurement opportunities against configured company capabilities.

**Important:** Always verify bid status, deadlines, eligibility, and other procurement requirements on the official GeM bid page before taking action.

## Features

- Search GeM bids by keyword.
- Support the search modes implemented by the application.
- Retrieve ongoing bids using GeM's ongoing-bids API filter.
- Parse bid numbers, titles, dates, ministries, buyer organisations, and detail URLs.
- Apply project-specific relevance scoring.
- Optionally persist search results, depending on application configuration.
- Expose functionality through MCP.
- Run as a Linux systemd service.
- Connect to Open WebUI through MCP Streamable HTTP.
- Support Linux ARM64 and x86_64 subject to dependency compatibility.

## Architecture

| Component | Purpose |
|---|---|
| `server.py` | MCP server and tool definitions |
| `gem_scraper.py` | GeM search requests and bid parsing |
| `gem_runner.py` | Supporting application execution logic |
| `relevance_engine.py` | Relevance scoring and category matching |
| `company_profile.json` | Company capabilities and matching configuration |
| `requirements.txt` | Python dependencies |
| systemd | Service management and automatic restarts |
| Open WebUI | Browser-based AI chat interface |
| LLM | Interprets user requests and invokes available tools |

### Request flow

1. The user submits a procurement-related question in Open WebUI.
2. The language model determines whether to call the GeM MCP search tool.
3. Open WebUI sends the MCP request to the server.
4. The server searches GeM and parses the returned bid records.
5. The application applies configured relevance scoring and persistence.
6. Results are returned to the AI client for presentation.

## Repository Structure

| File | Description |
|---|---|
| `server.py` | MCP server and tool definitions |
| `gem_scraper.py` | GeM API interaction and bid parsing |
| `gem_runner.py` | Supporting runner logic |
| `relevance_engine.py` | Bid relevance scoring |
| `company_profile.json` | Company-specific matching profile |
| `requirements.txt` | Python dependencies |
| `deploy_gem_mcp.sh` | Existing deployment script |
| `Dockerfile` | Container build instructions |
| `render.yaml` | Render deployment configuration |
| `test_mcp.py` | MCP-related test or diagnostic code |
| `README.md` | Project documentation |
| `RECOVERY_README.md` | Additional recovery documentation |

The exact behaviour of deployment and supporting files is determined by their implementation in this repository.

## Requirements

- Linux with systemd for the supplied service-management commands.
- Python 3, pip, and virtual environment support.
- Git and sudo access.
- Network access to GeM and Python package repositories.
- Docker Engine if Open WebUI is to be deployed using Docker.
- Any database or environment configuration required by the application.

### Default deployment settings

| Setting | Value |
|---|---|
| Application directory | `/opt/gem_mcp` |
| systemd service | `gem-mcp` |
| MCP port | `8972` |
| Health endpoint | `http://127.0.0.1:8972/health` |
| MCP endpoint | `http://SERVER_LAN_IP:8972/mcp` |
| Open WebUI host port | `2000` |

Replace `SERVER_LAN_IP` with the actual IP address or hostname reachable by the client.

## Installation

### 1. Clone the repository

```bash
git clone https://github.com/premjithbenny/Gem-MCP-Private-Deploy.git
cd Gem-MCP-Private-Deploy
```

For a private repository, authenticate using your configured GitHub credentials.

### 2. Review the deployment script

Inspect the existing script before running it with elevated privileges:

```bash
less deploy_gem_mcp.sh
```

Confirm the installation path, Python environment, systemd configuration, environment variables, and any database setup.

### 3. Deploy the MCP server

```bash
chmod +x deploy_gem_mcp.sh
sudo bash deploy_gem_mcp.sh
```

Review the script's output and follow any additional configuration instructions it provides.

**For an existing production installation:** Do not rerun the installer until you have confirmed whether it overwrites configuration, modifies persistent data, changes ownership, or restarts the service.

### 4. Configure environment variables

If the application uses a `.env` file, configure the variables required by the actual source code.

On the deployed server:

```bash
cd /opt/gem_mcp
ls -la
```

Protect the environment file:

```bash
chmod 600 /opt/gem_mcp/.env
```

Back up the existing configuration before making changes. Do not replace a working production environment file with placeholder values.

### 5. Find the server IP

```bash
hostname -I
```

Use an address reachable from Open WebUI or your MCP client.

## Verify the Server

### Check systemd status

```bash
sudo systemctl is-active gem-mcp
sudo systemctl status gem-mcp --no-pager
```

The expected service state is:

```text
active
```

### Check the health endpoint

```bash
curl -fsS http://127.0.0.1:8972/health
echo
```

A healthy response from the current deployment resembles:

```json
{
  "status": "healthy",
  "service": "gem-mcp-server",
  "database": "connected"
}
```

The exact fields depend on the implementation and configured dependencies.

### Check the listening port

```bash
sudo ss -lntp | grep 8972
```

A successful health check confirms that the health endpoint responds; test MCP tool discovery and execution separately.

## Install Open WebUI

### 1. Install Docker

Install Docker Engine and its Compose plugin using the official Docker instructions for your Linux distribution.

Verify Docker:

```bash
docker --version
docker info
```

### 2. Run Open WebUI

For a new installation:

```bash
docker volume create open-webui

docker run -d \
  --name Gem-Mcp-webui \
  --restart unless-stopped \
  -p 2000:8080 \
  -v open-webui:/app/backend/data \
  ghcr.io/open-webui/open-webui:main
```

This exposes Open WebUI on host port `2000` and stores its data in a persistent Docker volume.

If Open WebUI is already running, continue using that installation rather than creating a duplicate container.

### 3. Open the interface

Visit:

```text
http://SERVER_LAN_IP:2000
```

Complete the initial setup if necessary.

## Connect Open WebUI to MCP

Open WebUI's settings and menu labels vary by version. Use its MCP server or tool integration area.

1. Open the administration or workspace settings.
2. Find the MCP server integration section.
3. Add a server using **MCP Streamable HTTP**, if supported by your version.
4. Set the server URL to:

   `http://SERVER_LAN_IP:8972/mcp`

5. Save the configuration and test the connection if a test option is available.
6. Enable the GeM MCP tools for the chat or model if required by your version.

### Docker networking

Inside a Docker container, `127.0.0.1` refers to the container itself, not the Linux host.

When Open WebUI and GeM MCP run on the same server, use the host's reachable LAN IP, such as:

`http://192.168.1.72:8972/mcp`

Replace this example with the actual server IP.

Alternatively, on Docker for Linux, configure the container with:

```bash
--add-host=host.docker.internal:host-gateway
```

Then use:

`http://host.docker.internal:8972/mcp`

This requires the MCP service to listen on a host interface reachable from the container.

**Do not configure the MCP endpoint as an OpenAPI server.** Select the MCP/Streamable HTTP integration.

### Test the connection

In an Open WebUI chat with a suitable model and tool access enabled, try:

> Search GeM for open bids related to servers.

If the connection is successful, the model should be able to invoke the GeM search tool when appropriate.

## Search GeM Bids

The current search tool is named:

`gem-mcp_search_bids`

The observed tool inputs include:

| Parameter | Example | Description |
|---|---|---|
| `keyword` | `servers` | Search keyword |
| `search_type` | `fullText` | Search mode |
| `max_results` | `10` | Maximum number of requested results |
| `status` | `open` | Requested status filter |
| `save_to_db` | `true` | Whether to persist results according to the application |

Example input:

```json
{
  "keyword": "servers",
  "search_type": "fullText",
  "max_results": 10,
  "status": "open",
  "save_to_db": true
}
```

Use the connected MCP client's displayed schema as the authoritative list of supported arguments.

### Example prompts

**Server procurement**

> Find open GeM bids for servers.

**GPU and AI infrastructure**

> Search GeM for GPU servers and AI infrastructure tenders.

**Maintenance contracts**

> Find tenders for server and computer maintenance.

**Data-centre equipment**

> Search for data-centre equipment and infrastructure bids.

These are example queries, not guarantees that matching tenders currently exist.

### Understanding search results

Depending on the tool output, records can include:

- Bid number and title.
- Quantity and unit of measure.
- Start and closing dates.
- Ministry and buyer organisation.
- Bid type and parsed status.
- Official bid detail URL.
- Relevance score and matching categories.
- Database update information.

The application may report `raw_count`, `relevant_count`, and `count` separately. These represent different stages of the search pipeline and need not have the same value.

### Status and closing dates

The current open-search implementation uses GeM's `ongoing_bids` API filter and applies local status filtering.

Status classification depends on the parser and the values returned by GeM. Closed-bid behaviour should be verified separately before relying on it.

Always check the official bid page for the current status and deadline before acting on a result.

### Relevance scoring

The project includes `relevance_engine.py` and `company_profile.json` for company-specific matching.

The relevance score is an application-defined ranking signal, not an official GeM score or a guarantee of eligibility.

Review the profile and matching rules before adapting the deployment to another company or procurement domain.

## Configuration

### Company profile

Review the current company profile:

```bash
cd /opt/gem_mcp
cat company_profile.json
```

Back up the file before editing it. Check the schema expected by `relevance_engine.py` before changing its fields.

### Python dependencies

The project's dependencies are listed in `requirements.txt`.

To install them in the existing virtual environment:

```bash
cd /opt/gem_mcp
.venv/bin/pip install -r requirements.txt
```

Dependency upgrades can change application behaviour. Validate changes before applying them to production.

### Environment file

The variables required by `.env` depend on the current source code and deployment configuration.

Keep production credentials out of version control. Prefer a `.env.example` containing variable names and placeholder values.

## Service Management

The systemd service is named `gem-mcp`.

### Status

```bash
sudo systemctl status gem-mcp --no-pager
```

### Restart

```bash
sudo systemctl restart gem-mcp
```

### Stop and start

```bash
sudo systemctl stop gem-mcp
sudo systemctl start gem-mcp
```

### Follow logs

```bash
sudo journalctl -u gem-mcp -f
```

### View recent logs

```bash
sudo journalctl -u gem-mcp -n 100 --no-pager
```

### Inspect the service definition

```bash
sudo systemctl cat gem-mcp
```

This shows the configured user, working directory, environment, and startup command.

## Updating the Deployment

### 1. Commit and push changes

In your development clone, review the changes, run tests, and commit them to GitHub.

### 2. Pull changes on the deployment server

Enter the actual Git working-copy directory:

```bash
cd /path/to/Gem-MCP-Private-Deploy
git pull --ff-only
```

Replace the example path with the real repository location.

### 3. Apply the update

Inspect the installer before running it:

```bash
less deploy_gem_mcp.sh
```

If the script is designed to update the existing installation safely:

```bash
sudo bash deploy_gem_mcp.sh
```

Do not assume that `git pull` automatically updates `/opt/gem_mcp`; the repository clone and installed application may be in different directories.

### 4. Verify after updating

```bash
sudo systemctl is-active gem-mcp
curl -fsS http://127.0.0.1:8972/health
echo
```

Review systemd logs if the service fails to become healthy.

## Troubleshooting

### Service does not start

```bash
sudo systemctl status gem-mcp --no-pager
sudo journalctl -u gem-mcp -n 100 --no-pager
```

Inspect the error before changing configuration or reinstalling packages.

### Health endpoint is unavailable

```bash
sudo ss -lntp | grep 8972
curl -v http://127.0.0.1:8972/health
```

Confirm that the service is running and listening on the expected port.

### Open WebUI cannot reach MCP

Check the endpoint from the host:

```bash
curl -v http://SERVER_LAN_IP:8972/health
```

If Open WebUI runs in Docker, verify connectivity from the container too. Check the firewall, Docker network, and service bind address.

### MCP tools do not appear

- Confirm the URL ends in `/mcp`.
- Use the MCP Streamable HTTP integration, not OpenAPI.
- Verify the health endpoint.
- Check the installed Open WebUI version and its integration requirements.
- Confirm the tools are enabled for the chat or model.
- Inspect the server and Open WebUI logs.

### Python dependency errors

```bash
cd /opt/gem_mcp
.venv/bin/pip install -r requirements.txt
.venv/bin/python -m py_compile server.py gem_scraper.py
```

Syntax compilation alone does not verify connectivity to GeM or database availability.

### No relevant bids returned

Try a broader keyword and inspect the raw results. Check the GeM connection, search mode, requested status, and relevance configuration.

A low relevance count does not necessarily mean the API returned no bids.

## Security

- Never commit passwords, access tokens, cookies, private keys, or production credentials.
- Keep `.env` out of Git and use `.env.example` for placeholders.
- Use a private repository for confidential source code and configuration.
- Restrict ports `8972` and `2000` to trusted clients.
- Do not expose MCP directly to the public internet without appropriate authentication, TLS, and network controls.
- Review service-account permissions.
- Back up databases and configuration before deployment changes.
- Inspect scripts before executing them with `sudo`.
- Verify official bid documents and deadlines before making procurement decisions.

## Contributing

1. Create a branch for your change.
2. Make a focused modification.
3. Run the available tests and syntax checks.
4. Review the diff for secrets and generated files.
5. Submit a pull request or push to an authorised branch.

## License

Add the appropriate license before redistributing this project publicly. For private deployments, document the applicable internal usage and distribution policy.
