"""Company-specific GeM tender relevance scoring engine."""
import json
import re
from pathlib import Path

PROFILE_PATH = Path(__file__).with_name("company_profile.json")

CATEGORY_WEIGHTS = {
    "nvidia": 30,
    "gpu": 30,
    "ai_ml": 25,
    "networking": 25,
    "dci": 20,
    "storage": 15,
    "cloud": 15,
    "infrastructure": 15,
    "devops": 12,
    "workstations": 12,
    "services": 5,
}

GENERIC_TERMS = {
    "AI", "ML", "GPU", "Cloud", "Storage", "Networking",
    "Infrastructure", "Automation", "Monitoring", "Deployment",
    "Implementation", "Installation", "Configuration", "Support",
    "Server", "Backup", "Router",
}


def _load_profile():
    try:
        with PROFILE_PATH.open("r", encoding="utf-8") as handle:
            return json.load(handle)
    except (OSError, json.JSONDecodeError):
        return {}


def _normalize(text):
    return re.sub(r"[^a-z0-9]+", " ", str(text or "").lower()).strip()


def score_bid(bid: dict) -> dict:
    """Score a bid from title and supporting metadata against company capabilities."""
    profile = _load_profile()
    title = str(bid.get("title", "") or "")
    metadata = " ".join(str(bid.get(k, "") or "") for k in (
        "ministry", "buyer_org", "description", "category", "bid_type"
    ))
    title_norm = _normalize(title)
    metadata_norm = _normalize(metadata)

    categories = profile.get("capabilities", profile.get("categories", {}))
    if not categories:
        # Also support a flat profile where categories are top-level keys.
        categories = {k: v for k, v in profile.items()
                      if isinstance(v, (list, dict)) and k not in {"company_name"}}

    matched_categories = []
    matched_keywords = []
    score = 0

    for category, entries in categories.items():
        if category not in CATEGORY_WEIGHTS:
            continue
        if isinstance(entries, dict):
            keywords = entries.get("keywords", [])
        elif isinstance(entries, list):
            keywords = entries
        else:
            continue

        category_matched = False
        for keyword in keywords:
            if not isinstance(keyword, str) or not keyword.strip():
                continue
            kw_norm = _normalize(keyword)
            if not kw_norm:
                continue
            if kw_norm in title_norm:
                category_matched = True
                matched_keywords.append(keyword)
            elif kw_norm in metadata_norm:
                # Metadata matches count at half weight, but category counted once.
                category_matched = True
                matched_keywords.append(keyword)

        if category_matched:
            matched_categories.append(category)

    # Title matches drive the main score; metadata matches are weaker.
    for category in matched_categories:
        entries = categories.get(category, [])
        keywords = entries.get("keywords", []) if isinstance(entries, dict) else entries
        title_hit = any(
            isinstance(k, str) and _normalize(k) and _normalize(k) in title_norm
            for k in keywords
        )
        score += CATEGORY_WEIGHTS[category] if title_hit else max(3, CATEGORY_WEIGHTS[category] // 2)

    title_n = title_norm
    if "nvidia" in title_n and any(x in title_n for x in ("gpu", "h100", "h200", "a100", "dgx", "hgx")):
        score += 15
    if any(x in title_n for x in ("gpu", "h100", "h200", "a100", "dgx", "hgx")) and any(x in title_n for x in ("ai", "machine learning", "deep learning")):
        score += 10
    if any(x in title_n for x in ("network", "switch", "infiniband", "ethernet")) and any(x in title_n for x in ("data center", "datacenter", "rack", "server")):
        score += 5

    score = min(100, score)
    if score >= 70:
        priority = "HIGH"
    elif score >= 45:
        priority = "MEDIUM"
    elif score >= 20:
        priority = "LOW"
    else:
        priority = "IGNORE"

    return {
        "relevance_score": score,
        "priority": priority,
        "matched_categories": sorted(set(matched_categories)),
        "matched_keywords": sorted(set(matched_keywords)),
        "match_reason": (
            f"Matched {len(set(matched_categories))} company capability categories. "
            f"Key matches: {', '.join(sorted(set(matched_keywords))[:8]) or 'none'}."
        ),
    }
