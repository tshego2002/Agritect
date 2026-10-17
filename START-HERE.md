# START HERE — Agritect setup for non-technical teams

You do not need to know how to code. If you can follow a cake recipe exactly,
you can build this. You will type a total of **two lines**. Everything else is
clicking.

**Do the build at home, 1–2 days before the hackathon** (venue Wi-Fi often
blocks downloads). It takes about 1 hour of your attention plus ~20 minutes of
waiting. Print this guide.

## Part 0 (optional but smart) — try it on a laptop first

You can test the whole app on a normal laptop before the Pi even arrives.
On **Windows**: open the agritect-kit folder and double-click
**test_on_laptop.bat**. On a **Mac**: open Terminal, type `cd ` (with a
space), drag the agritect-kit folder onto the window, press Enter, then
type `bash run_demo_laptop.sh` and press Enter.
The first run downloads the model and generates the voices (internet needed,
~20 min); then a browser tab opens with the app. On a laptop the camera
button becomes a "choose a file" button — feed it a leaf photo saved from
the web. Only the Wi-Fi hotspot part needs the real Pi. Bonus: the Pi install
reuses nothing from this test, so you can delete nothing and skip nothing —
Parts 1–4 are unchanged.

## What to buy / borrow

1. Raspberry Pi 5 and its official power supply
2. The Pi's "active cooler" (small fan — the Pi gets warm)
3. A microSD card, 32 GB, plus a card reader for your laptop (two cards if
   you can — the second is your backup)
4. A **micro-HDMI to HDMI cable** (the Pi's video plug is the small one —
   a normal HDMI cable will NOT fit)
5. Any monitor or TV with HDMI, a USB keyboard and a USB mouse (borrow them —
   only needed during setup)
6. A USB memory stick
7. A charged USB-C power bank (runs the kiosk at the demo)
8. An Android phone for testing

## Part 1 — Put the Pi's system on the SD card (on your laptop, ~15 min)

1. On your laptop, download and install **Raspberry Pi Imager** from
   raspberrypi.com/software (green button).
2. Put the microSD card into your laptop (use the card reader).
3. Open Raspberry Pi Imager and click:
   - CHOOSE DEVICE → **Raspberry Pi 5**
   - CHOOSE OS → **Raspberry Pi OS (64-bit)** (the first option)
   - CHOOSE STORAGE → your SD card
4. Click NEXT. When it asks "apply OS customisation settings?" click
   **EDIT SETTINGS** — this part matters:
   - Username: `pi`  · Password: pick one and **write it down**
   - Tick "Configure wireless LAN" and type your **home Wi-Fi** name and
     password exactly
   - Save, then YES, then YES again. Wait for "Write successful".
5. Copy the whole **agritect-kit** folder onto your USB memory stick.

**Checkpoint:** you have an SD card that says "Write successful", and a USB
stick with the agritect-kit folder on it.

## Part 2 — First boot (on the Pi, ~10 min)

1. Put the SD card into the slot on the underside of the Pi.
2. Connect: monitor (micro-HDMI side into the Pi), keyboard, mouse.
   Power LAST.
3. Wait 1–2 minutes. You will see a desktop with a raspberry logo —
   like a simple laptop.
4. Look at the **top-right corner**: a Wi-Fi symbol should appear, meaning it
   joined your home Wi-Fi by itself. (If not: click that corner, pick your
   Wi-Fi, type the password.)
5. Plug in the USB stick. A window pops up — click OK to open it.
6. Right-click the **agritect-kit** folder → **Copy**. Click the little
   **house/folder icon** in the top bar (File Manager, Home). Right-click in
   the empty space → **Paste**.

**Checkpoint:** the agritect-kit folder is visible in the Pi's Home folder,
and the Wi-Fi symbol is showing top-right.

## Part 3 — The two lines (on the Pi, ~30 min, mostly waiting)

1. Click the **black screen icon** in the top bar (it's called Terminal).
   A window opens where you can type.
2. Type this line exactly and press Enter:

       cd ~/agritect-kit

3. Type this line exactly and press Enter:

       sudo bash install.sh

   - If it asks for a password, type the one you wrote down. **The screen
     shows nothing while you type a password — that is normal.** Press Enter.
   - Tip: to paste into this black window, use **right-click → Paste**
     (normal Ctrl+V does not work there).
4. The script announces "Step 1 of 6" … "Step 6 of 6". Steps 2 and 4 are
   slow — lots of text scrolls past. Leave it completely alone until you see:

       ALL DONE — the kiosk is live

**Checkpoint:** the "ALL DONE" message. The Pi's own internet is now OFF on
purpose — it broadcasts its own network instead. (Undo anytime with:
`sudo bash pi/setup_pi.sh --undo`)

## Part 4 — Test it with a phone (~5 min)

1. On the phone: Settings → Wi-Fi → join the network **Agritect**
   (no password).
2. A "sign in to network" page should pop up by itself showing a green leaf
   and **Agritect**. If it doesn't: open the phone's browser and type
   `10.42.0.1`, or scan your printed QR code.
3. Tap **Tap to start** → tap the crop (e.g. **Maize**) → tap the big white
   circle → photograph a leaf picture → the diagnosis appears and speaks →
   **Fix it, step by step** → Next, Next … → Done. The bottom bar always has
   Home, Back, Again, Slow.
4. Photo tip the app also speaks: **one leaf filling the screen**, not the
   whole plant. The app learnt from single-leaf photos; whole-plant photos
   confuse it.
5. Turn the monitor, keyboard and mouse off and unplug them — the Pi no
   longer needs them, ever. From now on, power = kiosk on (give it ~40
   seconds after plugging in).

## Part 5 — Prepare the demo props (anyone can do this)

- Print the QR code: on the Pi it's the file `agritect-kit/laptop/
  qr_kiosk.png` (copy it to the USB stick and print it big).
- Print 3–4 leaf photos in colour on A4: search the web for
  "PlantVillage tomato late blight leaf" and "maize common rust leaf", pick
  clear single-leaf photos. These print-outs are what you photograph on
  stage — the app recognises them very reliably.
- Charge the power bank. Pack: Pi + cooler, power bank, its cable, QR
  print, leaf prints, the test phone, the backup SD card.

## The 45-second stage demo

Phone in **airplane mode, then Wi-Fi back on** (say this out loud — it proves
there's no internet). Join Agritect → app pops up → tap Tomato → photograph
the printed late-blight leaf → the diagnosis card speaks: the disease, how sure it is, act
today → point at the red glow on the leaf ("it shows the farmer where the
problem is") → tap "If you do nothing" → tap "Fix it, step by step" → Next
through 2–3 steps → Done → Save picture → show it in the phone's gallery.

## Make it look real (optional, 20 minutes, no tech needed)
Save a few real photos from the web into the kit's picture folders and the
app shows them instead of drawings: the four crop photos, and one example
leaf for each disease you will demo. Exact folder names and filenames are
listed in `agritect-kit/pi/server/static/media/PHOTOS-WANTED.md`.

## Got a newer kit zip?
Unzip it next to the old folder, then in Terminal:
`cd ~/agritect-kit-new` and `bash update_from.sh ~/agritect-kit`
— this copies the model and voices over so nothing is downloaded twice.

## If something goes wrong

| What you see | What to do |
|---|---|
| Install stops at Step 1 "not online" | Click the Wi-Fi icon top-right, join your Wi-Fi, run the second line again |
| "certificate verify failed" (work laptops) | The kit handles this automatically now; if it still appears, use a personal (non-work) laptop for the test, or skip straight to the Pi build, which is unaffected |
| Any other error during install | Run the second line again — it safely continues where it stopped |
| Phone joined Agritect but nothing pops up | Open the browser, type `10.42.0.1` — or scan the QR |
| No sound on the phone | Turn the phone's media volume up; tap Again in the bottom bar |
| Some speaker buttons silent / robotic voice | Those clips are missing — run the laptop script or Pi install again (it only adds what's missing). Until then the phone's own voice reads the text |
| It keeps saying "take another photo" | More light, hold still, fill the screen with one leaf |
| Wrong or generic diagnosis | Tap the right crop first, and photograph ONE leaf filling the screen (not the plant). Use a printed PlantVillage-style leaf photo for the demo |
| Kiosk dead on demo day | Swap in the backup SD card (see below), or power-cycle and wait 60 s |
| Truly stuck | Hackathons have mentors. Show any developer this folder and this guide — everything they need is in README.md. 10 minutes of their time will fix it. |

**Make the backup SD card** (after everything works): repeat Part 1 with the
second card, repeat Parts 2–3 on it, confirm the phone test, label it BACKUP.
Two working cards means one dead card can't end your demo.

## Who does what (team of 3–4)

- **Builder** — follows Parts 1–4 of this guide, makes the backup card
- **Props** — Part 5: printing, charging, packing
- **Storyteller** — pitch slides: the problem, the live demo, and the
  honest "what production would need" roadmap (see README, "Make it yours")
- **Demo driver** — rehearses the 45-second flow at least five times

One more honest note: the treatment advice and Swahili voice lines in this
kit are demo placeholders, not professional agricultural advice — say so if
a judge asks; it's a strength, not a weakness, that you know the difference.
