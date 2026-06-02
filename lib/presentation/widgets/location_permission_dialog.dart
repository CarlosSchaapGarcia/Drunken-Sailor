import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

Future<void> showLocationDeniedDialog(BuildContext context, String themeName) {
  final title = 'Permission needed';
  String body;
  switch (themeName) {
    case 'pirate':
      body = 'Avast! To point ye compass true we need yer location. Open settings and grant it, matey.';
      break;
    case 'nuclear':
      body = 'We need coordinates to avoid glowing hotspots. Please allow location in settings.';
      break;
    case 'submarine':
      body = 'Sonar needs a bearing. Enable location in settings to continue exploring.';
      break;
    default:
      body = 'This app needs location permission to function properly. Please enable it in settings.';
  }

  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(body),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(ctx).pop();
          },
          child: const Text('Not Now'),
        ),
        ElevatedButton(
          onPressed: () async {
            Navigator.of(ctx).pop();
            await openAppSettings();
          },
          child: const Text('Open Settings'),
        ),
      ],
    ),
  );
}
