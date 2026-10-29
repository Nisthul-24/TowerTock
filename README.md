# TowerTock — Complete Project README

## Overview
TowerTock is a complete, original Android casual arcade game built in **Godot 4**.
Stack building sections dropped from a moving crane to build the tallest tower possible.

## Tech Stack
- **Engine**: Godot 4.3+ 
- **Language**: GDScript
- **Platform**: Android (portrait)
- **Monetization**: Google AdMob rewarded video (revive)

---

## Project Structure

```
towertock/
├── project.godot              — Godot project configuration
├── audio_bus_layout.tres      — Music / SFX / Master bus layout
├── GenerateAudio.ps1          — PowerShell: generates WAV SFX
├── GenerateIcon.ps1           — PowerShell: generates icon
├── generate_audio.py          — Python equivalent (requires Python)
│
├── scenes/
│   ├── main_menu.tscn         — Main menu scene
│   └── game.tscn              — Full gameplay scene
│
├── scripts/
│   ├── game_state_manager.gd  — Finite state machine (autoload)
│   ├── scoring_system.gd      — Score, combo, quality (autoload)
│   ├── save_manager.gd        — Persistent data (autoload)
│   ├── audio_manager.gd       — SFX + music (autoload)
│   ├── settings_manager.gd    — Settings bridge (autoload)
│   ├── ad_manager.gd          — AdMob integration (autoload)
│   ├── game_controller.gd     — Main gameplay orchestrator
│   ├── crane_controller.gd    — Crane, pendulum, cable
│   ├── stacking_controller.gd — Falling building, overlap math
│   ├── stability_controller.gd — Tower sway animation
│   ├── difficulty_manager.gd  — Progressive difficulty
│   ├── camera_controller.gd   — Smooth vertical tracking
│   ├── city_background.gd     — Procedural city skyline
│   ├── hud.gd                 — In-game overlay
│   ├── game_over_screen.gd    — Game over / revive UI
│   ├── pause_menu.gd          — Pause overlay
│   └── main_menu.gd           — Main menu controller
│
├── assets/
│   ├── audio/                 — WAV sound effects (generated)
│   └── interface/             — Icon and UI assets
│
└── android/
    └── ADMOB_ANDROID_SETUP.md — Full Android/AdMob setup guide
```

---

## Quick Start

### 1. Open in Godot 4
1. Install Godot 4.3+ from https://godotengine.org
2. Open Godot → **Import** → select `towertock/project.godot`
3. Let Godot import assets

### 2. Generate Audio Assets
Run from the project root (PowerShell):
```powershell
powershell -ExecutionPolicy Bypass -File GenerateAudio.ps1
```
This creates `assets/audio/*.wav` — Godot will auto-import them.

**Then update `scripts/audio_manager.gd`** — change file extensions from `.ogg` to `.wav`:
```gdscript
const SFX_PATHS := {
    "button_click": "res://assets/audio/sfx_button_click.wav",
    ...
}
const MUSIC_PATH := "res://assets/audio/music_main.wav"
```

### 3. Generate Icon
```powershell
powershell -ExecutionPolicy Bypass -File GenerateIcon.ps1
```
Creates `assets/interface/icon.png`.

### 4. Run in Editor
- Press **F5** or click the play button
- Click/tap to drop buildings
- Escape or Android Back to pause

---

## Android Export

See `android/ADMOB_ANDROID_SETUP.md` for full instructions.

### Quick Summary
1. Install Android Studio + SDK (API 24 minimum, API 35 target)
2. In Godot: Editor → Export → Install Android Build Templates
3. Install the AdMob Godot plugin (see setup guide for link)
4. Configure your package name, keystore, and AdMob IDs
5. Export → Android → Export AAB

---

## AdMob Configuration

**Development (safe to run now):**
```gdscript
# scripts/ad_manager.gd
const USE_TEST_ADS := true  # Uses Google's official test ad
```

**Production (replace before release):**
```gdscript
const USE_TEST_ADS := false
const PRODUCTION_ADMOB_APP_ID        := "ca-app-pub-YOUR_APP_ID"
const PRODUCTION_REWARDED_AD_UNIT_ID := "ca-app-pub-YOUR_UNIT_ID"
```

Also add your App ID to `android/build/AndroidManifest.xml`.

---

## Gameplay

| Action | Input |
|--------|-------|
| Release building | Tap screen / Left click / Space |
| Pause | Tap pause button / Escape / Android Back |
| Resume | Tap Resume button |

**Lives**: 3 per run. A complete miss costs 1 life.  
**Revive**: Watch a rewarded ad once per run to continue.  
**Score**: Points × combo multiplier. Better placement = more points.

---

## Developer-Required Values

Before Play Store release, provide these values:

| Value | Location |
|-------|----------|
| AdMob App ID | `android/build/AndroidManifest.xml` + `ad_manager.gd` |
| Rewarded Ad Unit ID | `scripts/ad_manager.gd` |
| Package name | Export preset (`com.yourcompany.towertock`) |
| Release keystore | Export preset |
| Privacy policy URL | Play Console |

---

## Test Plan Summary

### Core Gameplay
- [ ] Crane moves smoothly and reverses at boundaries
- [ ] Cable remains connected during pendulum swing
- [ ] Tap releases building exactly once
- [ ] Building falls independently after release
- [ ] Perfect placement awards highest points
- [ ] Partial overlap trims building correctly
- [ ] Complete miss deducts exactly one life
- [ ] Three misses trigger game over
- [ ] Camera follows tower upward
- [ ] Pause freezes all movement
- [ ] Restart creates clean new run

### Revive / AdMob
- [ ] Game over shows revive button when eligible
- [ ] Revive button is absent after 1st use
- [ ] Watching ad to completion grants 1 life
- [ ] Closing ad without watching = no revive
- [ ] Ad failure shows final game over (no crash)
- [ ] Tower and score preserved after revive
- [ ] New run resets revive eligibility

### Android (on-device)
- [ ] Touch input works
- [ ] Portrait orientation locks
- [ ] Audio pauses when app backgrounds
- [ ] High score persists across sessions
- [ ] Back button pauses game

---

## Known Limitations / TODO for Production

1. **Audio**: Placeholder synthesized SFX included. Replace with professional audio.
2. **Music**: Simple procedural loop. Replace with original composed music.
3. **Icon**: Minimal placeholder. Create 512×512 professional icon for Play Store.
4. **AdMob plugin**: Requires manual plugin installation — see setup guide.
5. **Consent (UMP)**: EU/EEA consent flow not yet implemented. Required before EU distribution.
6. **Building art**: Procedurally generated. Consider adding hand-crafted sprites.
7. **Particles**: Visual effects are minimal. Particle emitters can be added per the spec.
8. **App bundle signing**: Requires developer's own keystore (never included in project).

---

## License

This project's source code and generated assets are original works created for TowerTock.
Do not include, use, or reference any copyrighted assets from City Bloxx, Tower Bloxx, or other games.
