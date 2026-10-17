# Agritect — offline crop-disease kiosk (hackathon starter kit)

Phone takes a photo → Raspberry Pi 5 hotspot → on-device model diagnoses →
a spoken, pictured **diagnosis card** (what it is, how sure, where on the leaf,
what you should see, why, what happens if you wait) → a **step-by-step
treatment wizard** (one step per screen, voice + pictogram, do-today/this-week/
next-season, what you need) → farmer saves the plan. English & Kiswahili.
**No internet, no SIM, no app install.**

> **Non-technical team?** Read **START-HERE.md** instead — it's a
> click-by-click guide, and `sudo bash install.sh` on the Pi does every step
> below in one command (the Pi just needs normal Wi-Fi during install).

```
agritect-kit/
├── START-HERE.md           plain-language guide for non-technical teams
├── install.sh              one command on the Pi = whole build (see above)
├── update_from.sh          moving to a new kit folder? copy model+voices over
├── laptop/                 run these on a CONNECTED laptop, before the event
│   ├── 01_download_model.py    model + classes (BiernyVR, MIT) → pi/server/model/
│   ├── 02_build_content.py     TTS audio + plan cards → pi/server/static/media/
│   └── 03_make_qr.py           printable QR to the kiosk (fallback entry)
├── pi/                     copy this whole folder to the Pi
│   ├── setup_pi.sh             ONE command: hotspot + captive portal + service
│   ├── server/                 FastAPI app + single-page web UI
│   └── content/treatments.json the editable treatment plans (EN + SW)
├── test_on_laptop.bat      Windows: double-click to try everything on a laptop
└── run_demo_laptop.sh      Mac/Linux: same laptop test, and the demo-day backup
```

## Shopping list
Raspberry Pi 5 (4 or 8 GB) + official PSU + **active cooler** · 32 GB microSD
with Raspberry Pi OS Bookworm 64-bit · a charged USB-C power bank (demo) ·
any Android phone for testing · printed leaf photos (see step 6).

## The recipe

**On your laptop (internet needed — the only time it ever is):**
```bash
cd agritect-kit/laptop
pip install -r requirements.txt
python 01_download_model.py        # ~85 MB; prints treatment coverage per class
python 02_build_content.py         # ~5 min of TTS; re-runs skip existing files
python 03_make_qr.py               # prints qr_kiosk.png — print it big
```
Optional but recommended: drop one clear reference JPG per disease into
`pi/server/static/media/reference/<normalized_class>.jpg`
(e.g. `tomatolateblight.jpg`) — the confirm screen shows photos instead of
placeholders. PlantVillage images work; check the dataset license for your use.

**Copy the kit to the Pi** (SD card, USB stick, or scp — your choice):
```bash
# everything under agritect-kit/pi/ → /home/pi/agritect/
```

**On the Pi (one command):**
```bash
cd /home/pi/agritect
sudo bash setup_pi.sh
```
Review the script first — it is short and commented. It creates an **open**
Wi-Fi network `Agritect` at `10.42.0.1`, wildcards DNS on it, and installs
a systemd service that serves the app on port 80 at every boot (running as
your user with only the bind-to-port-80 capability, not root).
`sudo bash setup_pi.sh --undo` reverses everything.

**Test:** join `Agritect` on a phone. The sign-in sheet should pop up with
the app. If it doesn't: open any website, or scan the printed QR, or type
`10.42.0.1`. Airplane mode + Wi-Fi on proves the offline story on stage.

## Demo-day runbook
1. Power the Pi from the power bank; wait ~40 s (service autostarts).
2. Phone: airplane mode ON, Wi-Fi ON, join `Agritect`.
3. Photograph a **printed PlantVillage leaf photo** — print 3–4 (tomato late
   blight and maize rust demo well). Printed training-style images are the
   one case where the model's lab-data bias works *for* you on stage.
4. Flow: tap start → tap Maize → shutter → the diagnosis card appears and speaks (name,
   how sure, urgency); the red heat-overlay fades in over the leaf → tap
   "What you should see" / "Why" / "If you do nothing" to hear each → "Fix it,
   step by step" → Next through the steps → Done → save picture + voice.
5. If anything dies: the laptop test script is the same app — run it and
   point phones at the laptop instead.

## Troubleshooting
- **Service status / logs:** `systemctl status agritect` ·
  `journalctl -u agritect -f`
- **Portal didn't pop:** normal on some phones — use the QR. Note: some
  captive-portal mini-browsers block file downloads; for the save-to-phone
  step, open `10.42.0.1` in the real browser (Chrome) instead.
- **No sound:** phone media volume; audio unlocks on the first tap
  (by design — browsers block autoplay before a user gesture).
- **Robotic voice on some lines:** the pre-recorded clip is missing, so the
  app fell back to the device's built-in speech. Rerun `02_build_content.py`
  (or the launcher) online — it generates only the missing clips.
- **Everything classified as "retake":** your photo may genuinely be blurry,
  or thresholds need tuning for your phone — adjust `BLUR_MIN` / `BRIGHT_*`
  env vars in the systemd unit.
- **`certificate verify failed` on a corporate laptop:** SSL-inspecting
  proxies (e.g. Zscaler) re-sign HTTPS; the laptop scripts now trust the OS
  certificate store via `truststore`, which handles it. Note Python 3.13+ also enforces strict
  X.509 rules many corporate CAs fail; the OS-truststore approach (installed
  as a `.pth` into the venv by the scripts) sidesteps that too. Last resort:
  a personal laptop, or go straight to the Pi — the proxy lives on the work
  laptop, not your network, so the Pi is unaffected.
- **First inference is slow:** ONNX warms up on first call (~1–3 s), then
  settles well under a second on the Pi 5.

## Why it asks for the crop first (and why photos matter)
The model was trained on PlantVillage: single leaves on a plain gray
background. Whole-plant field photos are outside what it knows, and it will
answer *confidently and wrongly* (e.g. "Grape black rot" for a maize field).
Two mitigations are built in:
- **Crop first.** The farmer taps Maize / Tomato / Potato / Pepper and the
  model is restricted to that crop's classes (`CROP_PREFIX` in `app.py`). If
  the unrestricted model actually preferred a different crop, the app lowers
  its confidence one notch and says "this photo looks different from what I
  know" — honesty beats bluffing.
- **Photo coaching.** The capture screen shows a good-vs-bad photo pair and
  the voice says: one leaf, filling the screen, plain background if possible.
The real fix is fine-tuning on field imagery (PlantDoc, the Nuru/PlantVillage
maize field sets, in-region collection) — that is the production roadmap.

## Add real photos (optional, high impact)
Every illustration in the app is replaced by a real photo if a JPG with the
right name exists under `pi/server/static/media/` — crops, example leaves,
symptom close-ups, treatment actions. The full list of filenames is in
`pi/server/static/media/PHOTOS-WANTED.md`. No code changes needed.

## Make it yours
- **Treatments & languages:** edit `pi/content/treatments.json`, rerun
  `02_build_content.py`. Add a language = add its text keys + a gTTS code.
- **Confidence bands:** `SURE_AT` (default 0.80) and `LIKELY_AT` (0.50) in the
  systemd unit. At or above `LIKELY_AT` the app goes straight to the diagnosis
  card; below it, the farmer is shown the top-3 pictures to choose from. The
  "Not matching? Other options" button on the card always offers the top-3.
- **Heatmap ("where I see the problem"):** occlusion sensitivity — 25 extra
  inferences by default (`HEATMAP_GRID=5`). Instant on a laptop; on the Pi it
  fades in after ~8–12 s while the voice is still explaining. `HEATMAP_GRID=0`
  disables it. (True Grad-CAM would need PyTorch; this needs nothing extra.)
- **Photo logging for retraining:** set `SAVE_PHOTOS=1` in the unit — but
  only with user consent; photos may incidentally capture people. Confirmed
  labels are always logged (text only) to `server/sessions/labels.jsonl`.
- **Production path (your roadmap slide):** fine-tune on field imagery
  (e.g. the Makerere cassava set), human-recorded voice in local languages,
  extension-service-vetted treatments, WPA2 on the hotspot, solar + enclosure,
  quarterly SD-card "sneakernet" updates that also harvest consented photos.

## Read this before you demo
- **AI-generated starter code.** Review and test everything before relying on
  it or committing it — verify logic, check defaults, confirm it meets your
  project's security standards.
- **Placeholder agronomy.** Treatment text and Swahili translations are demo
  content written for a hackathon. They are NOT professional agricultural
  advice and must be vetted by a qualified agronomist / extension service and
  a native speaker before any real-world use.
- **Deliberately open by design, demo only:** open Wi-Fi, no auth, no TLS,
  unauthenticated API. Fine for an offline kiosk demo; not for anything else.
- **Third-party components:** model = BiernyVR/crop-disease-classifier (MIT,
  trained on PlantVillage — accuracy on real field photos will be far lower
  than its 99.9 % lab benchmark); gTTS calls Google's TTS service at build
  time — check its terms for your context; reference photos you add carry
  the PlantVillage dataset license.
