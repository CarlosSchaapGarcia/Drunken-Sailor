# Drunken Sailor

Flutter app that points you to the nearest open bar. Three themed interfaces: Pirate Compass, Submarine Radar, Nuclear Geiger Counter.

## Dependencies

Install these on your machine before anything else:

| Tool | Purpose | Install |
|------|---------|---------|
| [Docker Desktop](https://www.docker.com/products/docker-desktop/) | Builds the APK | Required |
| [ADB (Android SDK Platform Tools)](https://developer.android.com/tools/releases/platform-tools) | Installs APK on phone | Required |
| [Firebase CLI](https://firebase.google.com/docs/cli) | Deploy Firestore rules/indexes | `npm install -g firebase-tools` |
| [Node.js](https://nodejs.org/) | Run the seed script | Required for seeding |

Docker Desktop: set **Settings → Resources → CPU** to at least 6, **Memory** to 8 GB.

---

## First-time setup

### 1. Clone and enter the repo

```powershell
git clone <repo-url>
cd Drunken-Sailor
```

### 2. Firebase config

`lib/firebase_options.dart` and `android/app/google-services.json` are committed — no action needed. The app is pre-configured for the `drunken-sailor-e61a6` Firebase project.

### 3. Build the Docker image (once)

```powershell
docker build -t drunken-sailor-builder .
```

This takes 10–15 minutes the first time. Only needed again if `Dockerfile` changes.

---

## Building and running on your phone

### Flutter version

This project was built and tested with **Flutter 3.44.0** on the stable channel, using **Dart 3.12.0**.

### Run directly with Flutter

If you have Flutter installed locally, you can also run the application directly on a connected device.

1. Check that Flutter can see your device:
   ```powershell
   flutter devices
   ```
2. Run the app:
   ```powershell
   flutter run
   ```

### Build the APK

```powershell
docker run --rm `
  -v "${PWD}:/app" `
  -v "drunken-sailor-gradle:/root/.gradle" `
  -v "drunken-sailor-pub:/root/.pub-cache" `
  -w /app `
  drunken-sailor-builder `
  sh -c "rm -rf .dart_tool && flutter pub get && flutter build apk --release"
```

First run: ~10 minutes (downloads Flutter artifacts and Gradle dependencies into named volumes).
Subsequent runs: ~2–4 minutes (volumes are cached).

### Install on phone

1. Enable **USB debugging** on your phone (Developer Options)
2. Plug in via USB
3. Verify ADB sees it:
   ```powershell
   adb devices
   ```
4. Install:
   ```powershell
   adb install -r build\app\outputs\flutter-apk\app-release.apk
   ```

If you get `INSTALL_FAILED_UPDATE_INCOMPATIBLE` (signature mismatch from a previous install):
```powershell
adb uninstall com.example.drunken_sailor
adb install build\app\outputs\flutter-apk\app-release.apk
```

### Rebuilding after code changes

Just re-run the build command above. The named volumes keep Gradle and pub caches warm so it stays fast.

### Checking Firebase connectivity

```powershell
adb logcat -s flutter
```

Open the app — you should see:
```
[Firebase] Connected — 10 bars loaded
```

---

## Firestore setup

### Deploy rules and indexes

```powershell
firebase login
firebase deploy --only firestore --project drunken-sailor-e61a6
```

This deploys `firestore.rules` (read-only public access) and `firestore.indexes.json` (composite index for gay-friendly + geohash queries).

### Seeding bar data

The seed script lives in `scripts/`. It deletes all existing bars and re-inserts from `scripts/emmen_bars.js`.

**Prerequisites:**
- Get `scripts/serviceAccountKey.json` from a teammate (never committed — see `.gitignore`)
- `package-lock.json` is committed so you get the exact same dependency versions as everyone else

**Run:**

```powershell
docker run --rm `
  -v "${PWD}/scripts:/scripts" `
  -w /scripts `
  node:18-alpine `
  sh -c "npm ci && node seed_bars.js"
```

(`npm ci` uses `package-lock.json` for reproducible installs — faster and more reliable than `npm install`)

**Adding or editing bars:** edit `scripts/emmen_bars.js`, then re-run the seed command above. Hours use `"HH:MM"` strings. Set `hours: null` for temporarily closed venues. Verify coordinates in Google Maps before committing.

---

## Project structure

```
├── lib/
│   ├── main.dart                      # App entry point, Firebase init
│   ├── app.dart                       # Root widget, navigation, distance indicator
│   ├── models/
│   │   ├── bar.dart                   # Bar data model + distance/hours logic
│   │   └── firebase_service.dart      # Firestore geo queries
│   ├── services/
│   │   └── location_service.dart      # GPS polling (foreground only)
│   ├── utils/
│   │   └── geohash_util.dart          # Geohash encode + neighbor computation
│   ├── views/
│   │   ├── compass_view.dart          # Pirate compass
│   │   ├── radar_view.dart            # Submarine radar
│   │   └── geiger_view.dart           # Nuclear counter
│   └── widgets/
│       ├── location_permission_dialog.dart  # Themed permission denied dialog
│       └── location_debug_overlay.dart      # GPS debug overlay
├── android/
│   └── app/
│       └── google-services.json       # Firebase Android config (committed)
├── scripts/
│   ├── emmen_bars.js                  # Bar data source — edit this to add bars
│   ├── seed_bars.js                   # Seed runner
│   ├── package-lock.json              # Committed — pins Node dependency versions
│   └── serviceAccountKey.json        # NOT committed — get from a teammate
├── firestore.rules                    # Firestore security rules
├── firestore.indexes.json             # Composite indexes definition
├── firebase.json                      # Firebase CLI project config
└── Dockerfile                         # Build environment
```

---

## Database schema

Each document in the `bars` Firestore collection:

```json
{
  "name": "Café De Beurs",
  "latitude": 52.7897,
  "longitude": 6.8942,
  "geohash": "u1hke2vyk",
  "location": "<GeoPoint>",
  "gay_friendly": false,
  "hours": {
    "monday":    { "opens": 960, "closes": 120 },
    "friday":    { "opens": 960, "closes": 180 },
    "saturday":  { "opens": 840, "closes": 180 }
  }
}
```

Hours are minutes since midnight (e.g. `960` = 16:00, `180` = 03:00). Days not present in `hours` are treated as closed.

---

## Debug features

**GPS overlay** — hold the hamburger menu (top-left) for 5 seconds. Shows live lat/lng/accuracy in the bottom-right corner. Hold again to dismiss.

---

## Features

### Done
- Pirate Compass, Submarine Radar, Nuclear Geiger Counter views
- Live GPS with foreground location service (updates every 5s, ≤20m accuracy)
- Distance indicator: green when a bar is open, red with negative distance when all are closed
- Firestore geo queries via geohash tiling (9-tile search, 5km radius)
- Gay-friendly filter field on all bar documents
- Themed location permission denied dialog (pirate/submarine/nuclear copy)
- Composite Firestore index for gay-friendly + geohash queries

### Planned
- Map view
- Bar blacklist
- Gay bars filter button
- Sea shanty error messages
- Vibration on arrival

---

## Troubleshooting

**Build fails with `Matrix4 isn't a type`** — stale `.dart_tool` from Windows. The build command already runs `rm -rf .dart_tool` to prevent this.

**Build fails with Gradle error** — clear the named volumes and retry:
```powershell
docker volume rm drunken-sailor-pub drunken-sailor-gradle
```

**`INSTALL_FAILED_UPDATE_INCOMPATIBLE`** — uninstall the old APK first:
```powershell
adb uninstall com.example.drunken_sailor
```

**Distance shows "Locating..."** — GPS hasn't got a fix yet, or location permission was denied. Check the GPS debug overlay.

**Distance shows 0 bars / Firebase not loading** — the seed hasn't been run yet, or the `geohash` field is missing from bar documents. Re-run the seed.
