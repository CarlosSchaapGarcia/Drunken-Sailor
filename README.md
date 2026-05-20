# Drunken Sailor - Flutter App

This is the Flutter/Dart implementation of the Drunken Sailor bar finder app. The app helps you find the nearest open bar with three interactive interfaces: Pirate Compass, Submarine Radar, and Nuclear Geiger Counter.

## Project Structure

```
flutter_app/
├── lib/
│   ├── main.dart                 # App entry point
│   ├── app.dart                  # Main app logic and navigation
│   ├── models/
│   │   ├── bar.dart             # Bar data model
│   │   └── firebase_service.dart # Firebase database service
│   └── views/
│       ├── compass_view.dart    # Pirate compass interface
│       ├── geiger_view.dart     # Nuclear counter interface
│       └── radar_view.dart      # Submarine radar interface
├── pubspec.yaml                  # Flutter dependencies
└── README.md                      # This file
```

## Features

### MUST HAVE ✅
- [x] Find closest open bar
- [x] **Compass View** - Pirate themed compass pointing to nearest bar
- [x] **Geiger Counter** - Nuclear themed radiation detector showing proximity
- [x] **Sonar/Radar** - Submarine themed radar scanning for bars
- [x] Firebase Realtime Database integration
- [x] Flutter and Dart implementation

### NICE TO HAVE 📋
- [ ] Map view
- [ ] Bar blacklist functionality
- [ ] Error handling with sea shanties
- [ ] Gay bars filter button
- [ ] Vibration feedback on arrival

## Setup Instructions

### Prerequisites
- Flutter SDK (3.0+)
- Firebase project set up
- Dart 3.0+

### Installation

1. **Navigate to the Flutter app directory:**
   ```bash
   cd flutter_app
   ```

2. **Install dependencies:**
   ```bash
   flutter pub get
   ```

3. **Set up Firebase:**
   - Follow the [Firebase setup guide](https://firebase.flutter.dev/docs/overview/) for your platform
   - Download your `google-services.json` (Android) or `GoogleService-Info.plist` (iOS)
   - Place in the appropriate platform-specific directory

4. **Create Firebase Realtime Database Structure:**
   
   Your Firebase database should have this structure:
   ```
   bars/
   ├── bar_001/
   │   ├── id: "bar_001"
   │   ├── name: "The Pirate Ship"
   │   ├── latitude: 52.6857
   │   ├── longitude: 7.2633
   │   ├── category: "regular"
   │   ├── isBlacklisted: false
   │   └── hours/
   │       ├── Monday: {opens: 840, closes: 180}      # 14:00 - 03:00
   │       ├── Tuesday: {opens: 840, closes: 180}
   │       └── ...
   ├── bar_002/
   │   └── ...
   └── ...
   ```
   
   Times are in minutes since midnight (e.g., 840 = 14:00, 1260 = 21:00)

5. **Run the app:**
   ```bash
   flutter run
   ```

## View Navigation

Users can navigate between the three views by:
- **Swiping left/right** on the screen
- **Tapping navigation dots** at the bottom
- **Using the side menu** to jump directly to a view

## Database Schema

### Bar Model
```dart
{
  "id": "bar_001",
  "name": "Bar Name",
  "latitude": 52.6857,
  "longitude": 7.2633,
  "category": "regular" | "gay" | null,
  "isBlacklisted": false,
  "hours": {
    "Monday": {"opens": 840, "closes": 180},
    "Tuesday": {"opens": 840, "closes": 180},
    // ... etc
  }
}
```

## Usage

### Compass View
- Shows the bearing to the nearest open bar
- Red needle points to the destination
- Pirate themed decorations (skull, anchor)

### Geiger Counter
- Displays proximity as radiation levels
- Colors change based on distance:
  - Green (Safe) - Far away
  - Yellow (Elevated) - Getting closer
  - Red (Danger) - Very close
- Clicking sound effect speeds up as you get closer

### Radar View
- Submarine themed sonar display
- Sweep line rotates continuously
- Target blips show bar locations
- Periscope and wave decorations

## Vibration & Sound

When the user reaches their destination (within 50m), the app will:
- Trigger vibration feedback
- Optional: Play a sea shanty (if audio module is added)

## Future Enhancements

1. **Location Services** - Integrate GPS for real location tracking
2. **Map View** - Show bars on an interactive map
3. **Blacklist Management** - Persistent user blacklist
4. **Gay Bar Filter** - Dedicated button to filter for gay-friendly venues
5. **Sea Shanties** - Error messages with pirate themed audio
6. **Push Notifications** - Alert when nearby bar opens

## Architecture

The app uses:
- **Provider** for state management
- **Firebase Realtime Database** for bar data
- **Geolocator** for user location
- **Custom Paint** for complex UI visualizations
- **PageView** for smooth view transitions

## Troubleshooting

### Firebase Connection Issues
- Ensure your `google-services.json` or `GoogleService-Info.plist` is properly placed
- Check Firebase project settings and rules
- Verify internet connectivity

### View Rendering Issues
- Clear build cache: `flutter clean`
- Rebuild: `flutter pub get && flutter run`

### Location Permission
- Ensure app has location permissions enabled in device settings

## Performance Notes

- Custom Paint widgets are optimized for smooth 60 FPS animations
- Firebase queries are cached where possible
- Compass needle updates at 30ms intervals
- Radar sweep rotates at 60 FPS

## License

All code converted from Figma AI export. See ATTRIBUTIONS.md for original design credits.
