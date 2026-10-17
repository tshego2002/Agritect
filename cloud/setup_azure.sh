#!/usr/bin/env bash
# Agritect — Azure cloud setup (run once, from your laptop).
#
# Prerequisites:
#   brew install azure-cli        (macOS)
#   az login                      (opens browser, signs you in)
#
# Usage:
#   bash cloud/setup_azure.sh
#
# What it creates:
#   Resource group  : agritect-rg
#   Storage account : agritect<random>  (LRS, cool tier)
#   Containers      : incoming   Pi → Cloud  (labels.jsonl, photos)
#                     outgoing   Cloud → Pi  (model, treatments, media)
#   Two credential files:
#     cloud/pi-sas.env   → copy to the Pi (write incoming, read outgoing)
#     cloud/ops-sas.env  → stays on your laptop (full access for push_update.sh)

set -euo pipefail

# ── tunables ─────────────────────────────────────────────────────────────────
LOCATION="southafricanorth"
RESOURCE_GROUP="agritect-rg"
STORAGE_ACCOUNT="agritect$(openssl rand -hex 4)"   # must be globally unique
INCOMING="incoming"    # Pi  → Cloud
OUTGOING="outgoing"    # Cloud → Pi
SAS_DAYS=365           # rotate by re-running this script
# ─────────────────────────────────────────────────────────────────────────────

HERE="$(cd "$(dirname "$0")" && pwd)"

# BSD date (macOS) vs GNU date (Linux)
if date -v+1d > /dev/null 2>&1; then
  EXPIRY=$(date -u -v+${SAS_DAYS}d '+%Y-%m-%dT%H:%MZ')
else
  EXPIRY=$(date -u -d "+${SAS_DAYS} days" '+%Y-%m-%dT%H:%MZ')
fi

echo
echo "========================================================"
echo "  Agritect — Azure cloud setup"
echo "  Resource group  : $RESOURCE_GROUP"
echo "  Location        : $LOCATION"
echo "  Storage account : $STORAGE_ACCOUNT"
echo "  SAS expiry      : $EXPIRY"
echo "========================================================"
echo

# ── 1. Resource group ─────────────────────────────────────────────────────────
echo "==> [1/5] Resource group"
az group create \
  --name "$RESOURCE_GROUP" \
  --location "$LOCATION" \
  --output none
echo "    OK"

# ── 2. Storage account ────────────────────────────────────────────────────────
echo "==> [2/5] Storage account"
az storage account create \
  --name "$STORAGE_ACCOUNT" \
  --resource-group "$RESOURCE_GROUP" \
  --location "$LOCATION" \
  --sku Standard_LRS \
  --kind StorageV2 \
  --access-tier Cool \
  --allow-blob-public-access false \
  --min-tls-version TLS1_2 \
  --output none

CONN=$(az storage account show-connection-string \
  --name "$STORAGE_ACCOUNT" \
  --resource-group "$RESOURCE_GROUP" \
  --query connectionString -o tsv)

ACCOUNT_URL="https://${STORAGE_ACCOUNT}.blob.core.windows.net"
echo "    OK: $ACCOUNT_URL"

# ── 3. Blob containers ────────────────────────────────────────────────────────
echo "==> [3/5] Blob containers"
az storage container create --name "$INCOMING" --connection-string "$CONN" --output none
az storage container create --name "$OUTGOING" --connection-string "$CONN" --output none

# Seed outgoing/version.txt = 0 so the Pi has a baseline to compare against.
printf "0" | az storage blob upload \
  --container-name "$OUTGOING" \
  --name "version.txt" \
  --data @- \
  --overwrite true \
  --connection-string "$CONN" \
  --output none
echo "    OK: containers created, outgoing/version.txt seeded as 0"

# ── 4. Pi SAS token ───────────────────────────────────────────────────────────
# Minimal permissions:
#   incoming: add (a) + create (c) + write (w)
#   outgoing: read (r) + list  (l)
echo "==> [4/5] Pi SAS token  (write incoming, read outgoing)"

PI_INCOMING_SAS=$(az storage container generate-sas \
  --name "$INCOMING" \
  --permissions acw \
  --expiry "$EXPIRY" \
  --connection-string "$CONN" \
  -o tsv)

PI_OUTGOING_SAS=$(az storage container generate-sas \
  --name "$OUTGOING" \
  --permissions rl \
  --expiry "$EXPIRY" \
  --connection-string "$CONN" \
  -o tsv)

cat > "$HERE/pi-sas.env" << EOF
# Agritect — Pi sync credentials.
# Copy this file to the Pi:
#   scp cloud/pi-sas.env pi@<pi-ip>:~/agritect-kit/pi/sync/
#
# Permissions: write-only on incoming, read-only on outgoing.
# Regenerate: re-run  bash cloud/setup_azure.sh
# Expiry: ${EXPIRY}
AZURE_ACCOUNT_URL="${ACCOUNT_URL}"
AZURE_INCOMING_CONTAINER="${INCOMING}"
AZURE_OUTGOING_CONTAINER="${OUTGOING}"
AZURE_PI_INCOMING_SAS="${PI_INCOMING_SAS}"
AZURE_PI_OUTGOING_SAS="${PI_OUTGOING_SAS}"
EOF
echo "    Written: cloud/pi-sas.env"

# ── 5. Ops SAS token ──────────────────────────────────────────────────────────
# Full access for push_update.sh running on your laptop.
echo "==> [5/5] Ops SAS token  (full access, laptop only)"

OPS_SAS=$(az storage account generate-sas \
  --account-name "$STORAGE_ACCOUNT" \
  --connection-string "$CONN" \
  --services b \
  --resource-types sco \
  --permissions acdlruw \
  --expiry "$EXPIRY" \
  --https-only \
  --output tsv)

cat > "$HERE/ops-sas.env" << EOF
# Agritect — Ops credentials (YOUR LAPTOP ONLY — never copy to Pi).
# Used by: bash cloud/push_update.sh
# Expiry:  ${EXPIRY}
AZURE_ACCOUNT_URL="${ACCOUNT_URL}"
AZURE_STORAGE_ACCOUNT="${STORAGE_ACCOUNT}"
AZURE_INCOMING_CONTAINER="${INCOMING}"
AZURE_OUTGOING_CONTAINER="${OUTGOING}"
AZURE_OPS_SAS="${OPS_SAS}"
EOF
echo "    Written: cloud/ops-sas.env"

# ── Summary ───────────────────────────────────────────────────────────────────
echo
echo "========================================================"
echo "  ALL DONE"
echo "  Storage : $ACCOUNT_URL"
echo "  incoming: ${ACCOUNT_URL}/${INCOMING}  (Pi uploads here)"
echo "  outgoing: ${ACCOUNT_URL}/${OUTGOING}  (Pi pulls from here)"
echo "========================================================"
echo
echo "  Next steps:"
echo
echo "  1. Copy Pi credentials:"
echo "       scp cloud/pi-sas.env pi@<pi-ip>:~/agritect-kit/pi/sync/"
echo
echo "  2. Install sync on the Pi:"
echo "       ssh pi@<pi-ip> 'cd ~/agritect-kit && sudo bash pi/setup_sync.sh'"
echo
echo "  3. Push your first update (model / treatments / media):"
echo "       bash cloud/push_update.sh"
echo
echo "  Pi sync fires automatically when ethernet is plugged in."
echo "  View Pi sync logs:  journalctl -u agritect-sync -f"
echo