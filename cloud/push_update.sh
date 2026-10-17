#!/usr/bin/env bash
# Agritect — push an update from your laptop to Azure.
#
# Run this whenever you have a new model, updated treatments.json, or new
# media files and want all Pis to receive them on their next sync.
#
# Usage:
#   bash cloud/push_update.sh                     # push everything that exists
#   bash cloud/push_update.sh --model-only        # only push the model
#   bash cloud/push_update.sh --content-only      # only push treatments.json
#   bash cloud/push_update.sh --media-only        # only push media files
#
# Prerequisites:
#   bash cloud/setup_azure.sh    (creates cloud/ops-sas.env)
#
# How it works:
#   1. Uploads changed files to outgoing/ in Azure Blob Storage.
#   2. Builds outgoing/manifest.json  {blob_name: md5}  so the Pi only
#      downloads files that actually changed (skips the 78 MB model if
#      only treatments.json changed, for example).
#   3. Bumps outgoing/version.txt by 1.
#   4. Next time a Pi plugs in ethernet, it detects the version change,
#      checks each file's MD5 against the manifest, pulls only what
#      differs, and restarts the app.

set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
KIT="$(dirname "$HERE")"
OPS_ENV="$HERE/ops-sas.env"

# ── local source paths ────────────────────────────────────────────────────────
MODEL_DIR="$KIT/pi/server/model"
CONTENT_FILE="$KIT/pi/content/treatments.json"
MEDIA_DIR="$KIT/pi/server/static/media"

# ── flags ─────────────────────────────────────────────────────────────────────
PUSH_MODEL=true
PUSH_CONTENT=true
PUSH_MEDIA=true

for arg in "$@"; do
  case "$arg" in
    --model-only)   PUSH_CONTENT=false; PUSH_MEDIA=false ;;
    --content-only) PUSH_MODEL=false;   PUSH_MEDIA=false ;;
    --media-only)   PUSH_MODEL=false;   PUSH_CONTENT=false ;;
    *) echo "Unknown flag: $arg" >&2; exit 1 ;;
  esac
done

# ── load credentials ──────────────────────────────────────────────────────────
if [[ ! -f "$OPS_ENV" ]]; then
  echo "ERROR: cloud/ops-sas.env not found. Run bash cloud/setup_azure.sh first." >&2
  exit 1
fi

# shellcheck disable=SC1090
source "$OPS_ENV"

ACCOUNT="${AZURE_ACCOUNT_URL}"
CONTAINER="${AZURE_OUTGOING_CONTAINER}"
SAS="${AZURE_OPS_SAS}"

# ── helper: upload a single file via az storage blob upload ───────────────────
upload_blob() {
  local local_path="$1"
  local blob_name="$2"
  echo "    → $blob_name"
  az storage blob upload \
    --account-name "$AZURE_STORAGE_ACCOUNT" \
    --sas-token "$SAS" \
    --container-name "$CONTAINER" \
    --name "$blob_name" \
    --file "$local_path" \
    --overwrite true \
    --output none
}

# ── helper: upload a directory recursively ────────────────────────────────────
upload_dir() {
  local src_dir="$1"
  local blob_prefix="$2"
  if [[ ! -d "$src_dir" ]]; then
    echo "    Skipping $blob_prefix (directory not found: $src_dir)"
    return
  fi
  find "$src_dir" -type f | while read -r file; do
    local rel="${file#$src_dir/}"
    upload_blob "$file" "${blob_prefix}${rel}"
  done
}

echo
echo "========================================================"
echo "  Agritect — push update to Azure"
echo "  Container: $CONTAINER"
echo "========================================================"

# ── 1. Model ─────────────────────────────────────────────────────────────────
if $PUSH_MODEL; then
  echo
  echo "==> Model  ($MODEL_DIR)"
  if [[ -d "$MODEL_DIR" ]]; then
    upload_dir "$MODEL_DIR" "model/"
  else
    echo "    Skipping (directory not found)"
  fi
fi

# ── 2. Treatments ─────────────────────────────────────────────────────────────
if $PUSH_CONTENT; then
  echo
  echo "==> Treatments  ($CONTENT_FILE)"
  if [[ -f "$CONTENT_FILE" ]]; then
    upload_blob "$CONTENT_FILE" "content/treatments.json"
  else
    echo "    Skipping (file not found)"
  fi
fi

# ── 3. Media ──────────────────────────────────────────────────────────────────
if $PUSH_MEDIA; then
  echo
  echo "==> Media  ($MEDIA_DIR)"
  upload_dir "$MEDIA_DIR" "media/"
fi

# ── 4. Build and upload manifest.json ────────────────────────────────────────
# The manifest lets the Pi skip files that haven't changed (no re-downloading
# the 78 MB model just because treatments.json was updated).
echo
echo "==> Building manifest.json"

MANIFEST_FILE="$(mktemp)"
printf '{' > "$MANIFEST_FILE"
FIRST=true

add_to_manifest() {
  local local_path="$1"
  local blob_name="$2"
  local md5
  md5=$(md5 -q "$local_path" 2>/dev/null || md5sum "$local_path" | cut -d' ' -f1)
  $FIRST || printf ',' >> "$MANIFEST_FILE"
  printf '"\n  "%s": "%s"' "$blob_name" "$md5" >> "$MANIFEST_FILE"
  FIRST=false
}

# Add model files
if [[ -d "$MODEL_DIR" ]]; then
  find "$MODEL_DIR" -type f | while read -r file; do
    rel="${file#$MODEL_DIR/}"
    add_to_manifest "$file" "model/$rel"
  done
fi

# Add treatments.json
if [[ -f "$CONTENT_FILE" ]]; then
  add_to_manifest "$CONTENT_FILE" "content/treatments.json"
fi

# Add media files
if [[ -d "$MEDIA_DIR" ]]; then
  find "$MEDIA_DIR" -type f | while read -r file; do
    rel="${file#$MEDIA_DIR/}"
    add_to_manifest "$file" "media/$rel"
  done
fi

printf '\n}' >> "$MANIFEST_FILE"

az storage blob upload \
  --account-name "$AZURE_STORAGE_ACCOUNT" \
  --sas-token "$SAS" \
  --container-name "$CONTAINER" \
  --name "manifest.json" \
  --file "$MANIFEST_FILE" \
  --overwrite true \
  --output none
rm -f "$MANIFEST_FILE"
echo "    manifest.json uploaded"

# ── 5. Bump version.txt ───────────────────────────────────────────────────────
echo
echo "==> Bumping version.txt"

CURRENT=$(az storage blob download \
  --account-name "$AZURE_STORAGE_ACCOUNT" \
  --sas-token "$SAS" \
  --container-name "$CONTAINER" \
  --name "version.txt" \
  --file /dev/stdout \
  --output none 2>/dev/null || echo "0")

NEW_VERSION=$(( ${CURRENT//[^0-9]/} + 1 ))
printf "%s" "$NEW_VERSION" | az storage blob upload \
  --account-name "$AZURE_STORAGE_ACCOUNT" \
  --sas-token "$SAS" \
  --container-name "$CONTAINER" \
  --name "version.txt" \
  --data @- \
  --overwrite true \
  --output none

echo "    version.txt: $CURRENT → $NEW_VERSION"

# ── Done ──────────────────────────────────────────────────────────────────────
echo
echo "========================================================"
echo "  Update pushed.  Version is now: $NEW_VERSION"
echo "========================================================"
echo
echo "  All Pis will pull this update the next time ethernet"
echo "  is plugged in (end of day sync)."
echo
echo "  To check what is in outgoing/:"
echo "    az storage blob list \\"
echo "      --account-name $AZURE_STORAGE_ACCOUNT \\"
echo "      --sas-token \"\$AZURE_OPS_SAS\" \\"
echo "      --container-name $CONTAINER \\"
echo "      --output table"
echo
