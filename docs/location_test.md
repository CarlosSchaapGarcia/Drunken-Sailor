# Location Accuracy Outdoor Test

Test performed in Emmen city center. Steps to reproduce:

1. Start the app on the phone and accept location permission when prompted.
2. Walk to three known landmarks and record the app-reported GPS coordinates and the true coordinates (from a trusted map/GPS).
3. Keep the app active for 10 minutes and observe any drift.

Acceptance criteria:
- Reported GPS position within 15 meters of true location for each test point.
- No drift exceeding 50 meters during a 10-minute continuous run.

Placeholders:
- Screenshots and measured coordinates to be added after field test.

Notes:
- If GPS is disabled, the app will prompt to open location settings.
- The app requests foreground location only; background access is not requested.
