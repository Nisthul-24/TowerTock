# TowerTock Android & AdMob Setup Guide

## Overview

This document explains every step required to:
1. Configure the Android export in Godot 4
2. Integrate Google AdMob rewarded video
3. Prepare for Google Play submission

---

## 1. Android Export Prerequisites

### Android SDK
- Install Android Studio: https://developer.android.com/studio
- SDK minimum API: **24** (Android 7.0) — required by Google Play at time of writing
- Target API: **35** (Android 15) — adjust to current Play Store requirement
- NDK: Install via Android Studio SDK Manager

### Java
- JDK 17 or newer required by Godot 4.3+
- Set JAVA_HOME environment variable

### Godot Android Templates
In Godot 4 editor:
1. Editor → Export → Android
2. Click **Install Android Build Templates**
3. This creates `android/` directory in your project

### Keystore (for release builds)
Generate a release keystore (do NOT commit to source control):
```bash
keytool -genkey -v -keystore towertock-release.keystore \
  -alias towertock -keyalg RSA -keysize 2048 -validity 10000
```
Store the keystore file securely outside your project directory.

---

## 2. Google AdMob Integration

### Plugin Options (choose one)

**Option A — Godot Android AdMob Plugin (Recommended)**
- Repository: https://github.com/Shin-NiL/Godot-Android-Admob-Plugin
- Supports Godot 4.x and Google Mobile Ads SDK 23+
- Provides GDScript signals matching `ad_manager.gd`

**Option B — Custom Android Plugin**
- Implement a Godot 4 Android plugin in Java/Kotlin
- Wrap Google Mobile Ads SDK
- Use `JavaClassWrapper` to call from GDScript

### Installing the Plugin (Option A)

1. Download the latest release from the plugin GitHub
2. Copy the `.aar` and `.gdap` files to `android/plugins/`
3. In Godot: Project → Export → Android → Plugins
4. Enable **GodotAdmob** in the plugin list

### AdMob App ID Configuration

Add to `android/build/AndroidManifest.xml`:
```xml
<meta-data
    android:name="com.google.android.gms.ads.APPLICATION_ID"
    android:value="ca-app-pub-REPLACE_WITH_YOUR_APP_ID"/>
```

**IMPORTANT**: Replace `ca-app-pub-REPLACE_WITH_YOUR_APP_ID` with your real AdMob App ID from:
https://apps.admob.com → Apps → [Your App] → App settings → App ID

### Ad Unit IDs

In `scripts/ad_manager.gd`:
```gdscript
const USE_TEST_ADS := false  # Set to false for production ONLY

const PRODUCTION_ADMOB_APP_ID        := "ca-app-pub-XXXXXXXXXXXXXXXX~XXXXXXXXXX"
const PRODUCTION_REWARDED_AD_UNIT_ID := "ca-app-pub-XXXXXXXXXXXXXXXX/XXXXXXXXXX"
```

Get ad unit IDs from AdMob console:
https://apps.admob.com → Apps → [Your App] → Ad units → Create ad unit → Rewarded

**During development, ALWAYS use `USE_TEST_ADS := true`.**

Google test rewarded ad unit (already configured in ad_manager.gd):
`ca-app-pub-3940256099942544/5224354917`

---

## 3. Godot Export Configuration

### Export Preset

In Godot editor: Project → Export → Add → Android

Key settings:
| Setting | Value |
|---------|-------|
| Package Name | `com.yourcompany.towertock` |
| App Name | TowerTock |
| Version Name | 1.0.0 |
| Version Code | 1 |
| Min SDK | 24 |
| Target SDK | 35 |
| Orientation | Portrait |
| Keystore (release) | Path to your `.keystore` file |
| Keystore User | Your alias |
| Keystore Password | (enter securely — never commit) |

### Required Permissions
```
INTERNET
ACCESS_NETWORK_STATE
```
These are needed for AdMob. Godot adds INTERNET automatically.

### Export to Android App Bundle (.aab)
- Export → Android → Export Project
- Check **Export AAB** (for Play Store)
- Use **Release** build type for submission
- Debug builds are for local device testing only

---

## 4. Google Play Compliance

### Privacy Policy
- Required for all apps using AdMob
- Host a privacy policy that describes:
  - What data is collected (AdMob collects device identifiers)
  - How it is used (advertising)
  - Links to Google's privacy policy
- Add URL to: Play Console → Store listing → Privacy policy

### Data Safety Form
Complete in Play Console → Policy → App content → Data safety:
- Advertising ID: Collected, shared with advertising partners
- Device info: Collected for fraud prevention

### Consent (UMP — User Messaging Platform)
For distribution in EU/UK/EEA, implement Google's UMP SDK:
https://developers.google.com/admob/android/privacy/gdpr

### Content Rating
Complete IARC questionnaire in Play Console:
- App type: Game
- Category: Arcade
- No violence, no user-generated content, no location

---

## 5. Production Checklist

Before submitting to Play Store:

- [ ] Replace all test ad unit IDs with production IDs
- [ ] Set `USE_TEST_ADS := false` in `ad_manager.gd`
- [ ] Set AdMob App ID in AndroidManifest.xml
- [ ] Build with release keystore
- [ ] Test rewarded ad flow on physical Android device
- [ ] Test ad failure path (airplane mode)
- [ ] Verify revive works exactly once per run
- [ ] Verify score persists after revival
- [ ] Add privacy policy URL to Play Console
- [ ] Complete Data Safety form
- [ ] Complete content rating questionnaire
- [ ] Test on multiple screen sizes
- [ ] Test on Android 7.0 (min SDK)
- [ ] Review Play Store listing screenshots

---

## 6. Developer-Supplied Values

The following values MUST be provided by the developer before release.
They are intentionally left as placeholders in the project.

| Placeholder | Location | Description |
|-------------|----------|-------------|
| `ca-app-pub-REPLACE_WITH_YOUR_APP_ID` | AndroidManifest.xml | Your AdMob App ID |
| `PRODUCTION_ADMOB_APP_ID` | scripts/ad_manager.gd | Same App ID in GDScript |
| `PRODUCTION_REWARDED_AD_UNIT_ID` | scripts/ad_manager.gd | Your rewarded ad unit |
| `com.yourcompany.towertock` | Export preset | Your package identifier |
| Keystore file + credentials | Export preset | Your signing credentials |
| Privacy policy URL | Play Console | Your hosted policy URL |

---

## 7. Known Limitations

- **Audio**: Procedurally generated WAV placeholder files are included.
  For production, replace with professionally composed music and SFX.
  
- **AdMob plugin**: The plugin connection uses signal names that vary by 
  plugin version. Verify signal names match your chosen plugin's documentation.

- **Icon**: A minimal placeholder icon is generated by `GenerateIcon.ps1`.
  Create a proper 512×512 PNG icon for Play Store submission.

- **Desktop testing**: Ad simulation runs in the editor.
  Rewarded ads must be tested on a physical Android device with the plugin.

- **Crash recovery**: App kill during ad display is handled by 
  state guards, but final verification requires on-device testing.
