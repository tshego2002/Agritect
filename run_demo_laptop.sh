#!/usr/bin/env bash
# Agritect — laptop test / backup demo (Mac + Linux).
# Windows users: double-click test_on_laptop.bat instead.
# First run needs internet (model download + voice generation); after that
# it starts instantly and works offline.
set -euo pipefail
cd "$(dirname "$0")"

# Ignore stale certificate settings left over from earlier attempts (a path
# that no longer exists would make pip refuse every connection).
for v in SSL_CERT_FILE REQUESTS_CA_BUNDLE CURL_CA_BUNDLE PIP_CERT; do
  f="${!v:-}"
  if [ -n "$f" ] && [ ! -f "$f" ]; then
    echo "Ignoring stale $v (file not found: $f)"; unset "$v"
  fi
done

python3 -m venv pi/server/.venv 2>/dev/null || true
VPY=pi/server/.venv/bin/python

# ── Fix truststore RecursionError (Python 3.12 + macOS) ──────────────────────
# This MUST run before any pip network call, because the crash happens the
# moment pip opens an HTTPS connection. We directly overwrite the two
# _ssl_constants.py files (vendored inside pip, and the standalone package)
# to use the raw C-level descriptor instead of the broken super() chain.
apply_truststore_fix() {
  local f="$1"
  [ -f "$f" ] || return 0
  grep -q '_raw_verify_mode_descriptor' "$f" && return 0  # already patched
  python3 - "$f" << 'PYEOF'
import sys, pathlib
p = pathlib.Path(sys.argv[1])
src = p.read_text()

# 1. Add the C-level descriptor grab right after the super() line
OLD = "_original_super_SSLContext = super(_original_SSLContext, _original_SSLContext)"
NEW = OLD + """
# Recursion fix: grab verify_mode directly from the C extension
import _ssl as _ssl_c
_raw_verify_mode_descriptor = _ssl_c._SSLContext.__dict__.get("verify_mode")"""
src = src.replace(OLD, NEW, 1)

# 2. Replace the body of _set_ssl_context_verify_mode
import re
pattern = r"(def _set_ssl_context_verify_mode\([^)]*\)[^:]*:)\n([ \t]+.*\n)+"
replacement = r"""\1
    if _raw_verify_mode_descriptor is not None:
        _raw_verify_mode_descriptor.__set__(ssl_context, verify_mode)
    else:
        _original_super_SSLContext.verify_mode.__set__(ssl_context, verify_mode)
"""
src = re.sub(pattern, replacement, src)

p.write_text(src)
print("truststore fix applied:", p)
PYEOF
}

# Patch the pip-vendored copy first (needed before pip makes any network call)
apply_truststore_fix "pi/server/.venv/lib/python3.12/site-packages/pip/_vendor/truststore/_ssl_constants.py"
# Patch the standalone truststore package too (may not exist yet on first run)
apply_truststore_fix "pi/server/.venv/lib/python3.12/site-packages/truststore/_ssl_constants.py"
# ─────────────────────────────────────────────────────────────────────────────

echo "Installing the app's building blocks (first time: a few minutes)..."
"$VPY" -m pip -q install -r pi/server/requirements.txt -r laptop/requirements.txt

# Re-apply after installs in case truststore standalone was just installed
apply_truststore_fix "pi/server/.venv/lib/python3.12/site-packages/truststore/_ssl_constants.py"

"$VPY" -c "import sysconfig,pathlib;(pathlib.Path(sysconfig.get_paths()['purelib'])/'zz_truststore.pth').write_text('import truststore; truststore.inject_into_ssl()\n')" || true

if [ ! -f pi/server/model/efficientnet_v2_s_best.onnx ]; then
  echo "Downloading the AI model (~85 MB, internet needed)..."
  "$VPY" laptop/01_download_model.py
fi
echo "Checking voice clips + plan cards (first time 10–20 min; later runs only add what's missing)..."
"$VPY" laptop/02_build_content.py || echo "Some clips could not be generated — the app will use the device's built-in voice for those."

IP="$(hostname -I 2>/dev/null | awk '{print $1}' || true)"
[ -z "${IP:-}" ] && IP="$(ipconfig getifaddr en0 2>/dev/null || true)"
echo "====================================================="
echo "  Laptop:             http://localhost:8000"
[ -n "${IP:-}" ] && echo "  Phone on same Wi-Fi: http://$IP:8000"
echo "  Stop with Ctrl+C."
echo "====================================================="
( sleep 2 && { open http://localhost:8000 2>/dev/null || xdg-open http://localhost:8000 2>/dev/null || true; } ) &
exec "$VPY" -m uvicorn app:app --host 0.0.0.0 --port 8000 --app-dir pi/server
