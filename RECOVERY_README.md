# GeM MCP recovery kit

This kit recovers files retained from the earlier conversation and recreates the
company profile/relevance engine from the recorded design. The exact customized
`gem_scraper.py` was not retained as a file in the conversation history.

## Restore the scraper source

On a server with Git access:
```bash
git clone https://github.com/r3tr056/gem_mcp.git
cd gem_mcp
```
The upstream repository's default branch is `master`. Preserve its `gem_scraper.py`,
`requirements.txt`, `.env.example`, and other support files. Copy the `server.py`,
`relevance_engine.py`, and `company_profile.json` from this recovery kit over the
corresponding files in the clone.

## Important customization to restore in gem_scraper.py

The earlier working scraper had these customizations:
1. `fetch_bids_api(..., bid_status="ongoing_bids")` for ongoing bids.
2. `parse_solr_doc` status mapping: `b_status == 1` -> `open`; `b_status == 0` -> `closed`; other -> `awarded`.
3. `search_bids(..., status="open")` forwards the status and uses GeM's native `ongoing_bids` filter for open bids.
4. `upsert_bids` persists `relevance_score`, `priority`, `matched_categories`, `matched_keywords`, and `match_reason` in each MongoDB document. The exact prior file was not retained, so compare against the upstream source before patching.

## Test before deployment
```bash
python3 -m py_compile server.py gem_scraper.py relevance_engine.py
python3 -m json.tool company_profile.json >/dev/null
```
The deployment script is separate (`deploy_gem_mcp.sh`). Copy/rename it to `deploy.sh`
beside the project files before running it.
