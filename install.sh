#!/usr/bin/env bash
# Agritect — ONE-COMMAND INSTALL (for non-technical teams).
#
# Run this ON the Raspberry Pi, while the Pi is connected to normal Wi-Fi:
#     cd ~/agritect-kit
#     sudo bash install.sh
#
# It does everything in order, then turns the Pi into the offline kiosk:
#   1. checks internet (needed once, for downloads — never again after)
#   2. installs Python pieces
#   3. downloads the AI model (~85 MB)
#   4. generates all voice clips + plan cards (10–20 min — leave it alone)
#   5. makes the printable QR code
#   6. switches the Pi to kiosk mode: Wi-Fi hotspot "Agritect" + autostart
#
# After step 6 the Pi has NO internet (it broadcasts its own network instead).
# To get internet back for a re-run:  sudo bash pi/setup_pi.sh --undo
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
RUN_USER="${SUDO_USER:-pi}"
VENV="$HERE/pi/server/.venv"

# Ignore stale certificate settings left over from earlier attempts (a path
# that no longer exists would make pip refuse every connection).
for v in SSL_CERT_FILE REQUESTS_CA_BUNDLE CURL_CA_BUNDLE PIP_CERT; do
  f="${!v:-}"
  if [ -n "$f" ] && [ ! -f "$f" ]; then
    echo "Ignoring stale $v (file not found: $f)"; unset "$v"
  fi
done

banner(){ echo; echo "===================================================="; echo "  $1"; echo "===================================================="; }

if [[ $EUID -ne 0 ]]; then
  echo; echo "Almost! Please run it with 'sudo' in front, exactly like this:"
  echo "    sudo bash install.sh"; echo; exit 1
fi

banner "Step 1 of 6 — checking internet"
if ! timeout 8 bash -c '</dev/tcp/huggingface.co/443' 2>/dev/null; then
  echo "The Pi is not online yet."
  echo "Click the Wi-Fi icon at the TOP-RIGHT of the Pi's screen, join your"
  echo "normal Wi-Fi, then run this command again:  sudo bash install.sh"
  exit 1
fi
echo "Online. Good."

banner "Step 2 of 6 — installing Python pieces (2–5 min)"
apt-get update -y
apt-get install -y python3-venv python3-pip
sudo -u "$RUN_USER" python3 -m venv "$VENV"
sudo -u "$RUN_USER" "$VENV/bin/pip" install --upgrade pip
sudo -u "$RUN_USER" "$VENV/bin/pip" install -r "$HERE/pi/server/requirements.txt" \
                                             -r "$HERE/laptop/requirements.txt"
sudo -u "$RUN_USER" "$VENV/bin/python" -c "import sysconfig,pathlib;(pathlib.Path(sysconfig.get_paths()['purelib'])/'zz_truststore.pth').write_text('import truststore; truststore.inject_into_ssl()\n')" || true

banner "Step 3 of 6 — downloading the AI model (~85 MB)"
sudo -u "$RUN_USER" "$VENV/bin/python" "$HERE/laptop/01_download_model.py"

banner "Step 4 of 6 — generating voice clips + plan cards (10–20 min)"
echo "Lots of lines will scroll past. That is normal. Do not close this window."
sudo -u "$RUN_USER" "$VENV/bin/python" "$HERE/laptop/02_build_content.py"

banner "Step 5 of 6 — making the QR code"
sudo -u "$RUN_USER" "$VENV/bin/python" "$HERE/laptop/03_make_qr.py" "http://10.42.0.1" \
  && echo "Print the file:  laptop/qr_kiosk.png  (as big as possible)"

banner "Step 6 of 6 — switching to kiosk mode"
bash "$HERE/pi/setup_pi.sh"

banner "ALL DONE — the kiosk is live"
echo "On a phone: turn Wi-Fi on, join the network called  Agritect"
echo "The app should pop up by itself. If not, scan the QR or type 10.42.0.1"
echo
echo "The Pi now starts the kiosk by itself every time it gets power."
echo "Internet on the Pi is now OFF (that is the point!)."
echo "Need internet back?   sudo bash pi/setup_pi.sh --undo"
