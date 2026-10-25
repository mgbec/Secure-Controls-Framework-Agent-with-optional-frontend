# Recording Guide — SCF Compliance Agent

How to record the narrated slide video (screen + webcam talking-head) on
**Windows with OBS Studio**. Target: **1080p / 30fps**, ~6–7 minutes.

Repo: https://github.com/mgbec/SCF-Agent-with-A2A

---

## 1. What you'll capture

- **Screen:** `docs/presentation.html` open full-screen in a browser.
- **Webcam:** a talking-head in the **bottom-right** corner.
- **Mic:** your narration, following `docs/narration-script.md`.

The deck reserves the bottom-right corner so your webcam never covers slide
content. Press **G** in the deck to show the dashed webcam-safe zone while you
position the camera, then press **G** again to hide it before recording.

### Deck controls
| Key | Action |
|-----|--------|
| → / Space | Next slide |
| ← | Previous slide |
| **N** | Toggle on-screen presenter notes (keep OFF while recording) |
| **G** | Toggle the webcam-safe-zone guide |
| **F** | Fullscreen |
| Home / End | First / last slide |

---

## 2. One-time OBS setup

1. Install **OBS Studio** (free, obsproject.com).
2. Settings → **Video**: Base and Output resolution `1920×1080`, FPS `30`.
3. Settings → **Output**: Recording format `mp4` (or `mkv` and remux after),
   quality "Indistinguishable" / high bitrate.
4. Build the scene with two sources:
   - **Display Capture** (or **Window Capture** of the browser) — full screen.
   - **Video Capture Device** (your webcam) — scale it to roughly **320×240**
     and drag it into the **bottom-right** corner, matching the deck's reserved
     zone. Optional: right-click → Filters → add a slight crop or rounded look.
5. **Audio**: confirm your mic shows up under Audio Mixer. Do a 10-second test
   recording and check the level peaks around -12 dB to -6 dB.

---

## 3. Before you hit record

- Open `docs/presentation.html`, press **F** for fullscreen, **Home** to reset
  to slide 1, and make sure presenter notes are **off** (press **N** if needed).
- Have `docs/narration-script.md` on a second monitor or phone.
- Close notifications (Windows Focus Assist on), silence chat apps.
- Press **G**, position the webcam inside the dashed box, then **G** to hide it.

---

## 4. Recording

- Start the OBS recording, wait 2 seconds, then begin on slide 1.
- Narrate each slide from the script; press → on each `[advance]` cue.
- If you fumble a line, pause, clap once (easy to spot in the waveform), and
  re-say the sentence — you'll trim it in editing.
- End on slide 12, hold ~2 seconds, then stop the recording.

---

## 5. YouTube chapters

Paste these into the video description (timestamps are approximate — adjust to
your actual pacing). The first must be `0:00`.

```
0:00  Intro — what the SCF Compliance Agent is
0:25  The problem: manual, repetitive compliance work
1:05  What it does: eight capabilities
1:45  Architecture: data-grounded reasoning
2:35  Three ways in, three auth models
3:15  Agent-to-agent ingress (non-blocking)
4:00  Security for non-human identities
4:45  Cost engineering: pay-per-use
5:25  Self-updating SCF data
5:55  Real output: AWS implementation worksheets
6:35  Infrastructure as code & ops
7:00  Summary
```

---

## 6. Export & upload

- If you recorded `mkv`, use OBS → File → **Remux Recordings** to get `mp4`.
- Trim fumbles in any editor (Clipchamp ships with Windows).
- Upload at 1080p. Add the chapters above, the repo link, and a short
  description. Consider captions — YouTube auto-captions, but the narration
  script doubles as an accurate transcript you can upload for better
  accessibility.

---

## Scope note

This guide prepares you to record. It does **not** record or render the video
for you — that needs your camera, mic, and OBS on your machine.
