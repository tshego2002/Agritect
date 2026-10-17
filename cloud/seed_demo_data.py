"""Seed Azure incoming/ with realistic multi-Pi demo data.

Run from the repo root:
    python3 cloud/seed_demo_data.py

Requires cloud/ops-sas.env to exist (run setup_azure.sh first).
Creates labels.jsonl under incoming/<pi-serial>/ for each demo Pi,
so the admin dashboard shows multiple kiosks with group-leader names.
"""

import json
import os
import random
import ssl
import sys
import time
from pathlib import Path
from urllib.parse import urlencode
from urllib.request import Request, urlopen

try:
    import certifi
    _CTX = ssl.create_default_context(cafile=certifi.where())
except ImportError:
    _CTX = ssl.create_default_context()

HERE = Path(__file__).resolve().parent
OPS_ENV = HERE / "ops-sas.env"

# ── Demo Pi identifiers (must match group_leaders.json) ──────────────────────
DEMO_PIS = {
    "pi-katanga-001": {
        "crops": ["tomato", "maize"],
        "scans": 18,
    },
    "pi-mwanza-002": {
        "crops": ["potato", "maize", "tomato"],
        "scans": 12,
    },
    "pi-arusha-003": {
        "crops": ["pepper", "tomato", "maize"],
        "scans": 9,
    },
}

# Disease pools per crop
DISEASES = {
    "tomato": [
        ("Tomato___Early_blight",             "tomatoearlyblight",           0.91),
        ("Tomato___Late_blight",              "tomatolateblight",            0.87),
        ("Tomato___Bacterial_spot",           "tomatobacterialspot",         0.83),
        ("Tomato___Leaf_Mold",                "tomatoleafmold",              0.79),
        ("Tomato___Septoria_leaf_spot",       "tomatoseptorialeafspot",      0.76),
        ("Tomato___healthy",                  "tomatohealthy",               0.95),
    ],
    "maize": [
        ("Corn_(maize)___Common_rust_",                     "corncommonrust",                    0.88),
        ("Corn_(maize)___Cercospora_leaf_spot Gray_leaf_spot", "corncercosporaleafspotgrayleafspot", 0.82),
        ("Corn_(maize)___Northern_Leaf_Blight",             "cornnorthernleafblight",            0.85),
        ("Corn_(maize)___healthy",                          "cornhealthy",                       0.93),
    ],
    "potato": [
        ("Potato___Early_blight", "potatoearlyblight", 0.86),
        ("Potato___Late_blight",  "potatolateblight",  0.90),
        ("Potato___healthy",      "potatohealthy",     0.94),
    ],
    "pepper": [
        ("Pepper,_bell___Bacterial_spot", "pepperbellbacterialspot", 0.81),
        ("Pepper,_bell___healthy",        "pepperbellhealthy",       0.92),
    ],
}

BANDS = {0.80: "sure", 0.50: "likely", 0.0: "unsure"}
MODES = ["auto", "auto", "auto", "human"]  # 75% auto


def band_of(conf):
    for thresh, b in sorted(BANDS.items(), reverse=True):
        if conf >= thresh:
            return b
    return "unsure"


def generate_labels(pi_id: str, cfg: dict) -> str:
    """Generate a labels.jsonl string for one Pi."""
    lines = []
    now = time.time()
    for i in range(cfg["scans"]):
        crop = random.choice(cfg["crops"])
        disease = random.choice(DISEASES[crop])
        cls_name, norm, base_conf = disease
        # Add some variance
        conf = round(min(0.99, max(0.40, base_conf + random.uniform(-0.12, 0.06))), 4)
        ts = now - random.randint(3600, 14 * 86400)  # last 2 weeks
        ood = random.random() < 0.08  # 8% OOD
        row = {
            "ts": round(ts, 2),
            "session": f"{pi_id[:6]}{i:04d}",
            "label": norm,
            "mode": random.choice(MODES),
            "band": band_of(conf),
            "crop": crop,
            "ood": ood,
            "top": [[cls_name, norm, conf]],
        }
        lines.append(json.dumps(row))
    return "\n".join(lines) + "\n"


def load_env(path: Path) -> dict:
    env = {}
    for line in path.read_text().splitlines():
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        eq = line.find("=")
        if eq < 0:
            continue
        k = line[:eq].strip()
        v = line[eq + 1:].strip().strip('"').strip("'")
        env[k] = v
    return env


def blob_upload(account_url, container, sas, blob_name, data, content_type="application/octet-stream"):
    url = f"{account_url.rstrip('/')}/{container}/{blob_name}?{sas}"
    req = Request(url, data=data, method="PUT", headers={
        "x-ms-blob-type": "BlockBlob",
        "Content-Type": content_type,
        "Content-Length": str(len(data)),
        "x-ms-version": "2020-04-08",
    })
    with urlopen(req, timeout=60, context=_CTX) as resp:
        if resp.status not in (200, 201):
            raise RuntimeError(f"Upload failed: HTTP {resp.status}")


def main():
    if not OPS_ENV.exists():
        print(f"ERROR: {OPS_ENV} not found. Run: bash cloud/setup_azure.sh")
        return 1

    cfg = load_env(OPS_ENV)
    account_url = cfg["AZURE_ACCOUNT_URL"]
    container = cfg["AZURE_INCOMING_CONTAINER"]
    sas = cfg["AZURE_OPS_SAS"]

    print(f"Seeding demo data into {account_url}/{container}/\n")

    # Upload group_leaders.json to outgoing/ so the admin dashboard picks it up
    leaders_file = Path(__file__).resolve().parent.parent / "pi" / "server" / "group_leaders.json"
    if leaders_file.exists():
        blob_upload(account_url, cfg["AZURE_OUTGOING_CONTAINER"], sas,
                    "group_leaders.json", leaders_file.read_bytes(), "application/json")
        print(f"  ✓ Uploaded group_leaders.json → outgoing/group_leaders.json")

    for pi_id, pi_cfg in DEMO_PIS.items():
        labels = generate_labels(pi_id, pi_cfg)
        blob_name = f"{pi_id}/labels.jsonl"
        blob_upload(account_url, container, sas, blob_name,
                    labels.encode("utf-8"), "application/x-ndjson")
        print(f"  ✓ {pi_id}: {pi_cfg['scans']} scans → incoming/{blob_name}")

    print(f"\nDone. Open the admin dashboard and the 3 Pis will appear with their group leader names.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
