import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) throw UnsupportedError('Web not configured');
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      default:
        throw UnsupportedError('Unsupported platform: $defaultTargetPlatform');
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBa6Q51c6V-fe19-eUETlFKrMFQ9wi8S3U',
    appId: '1:986771803771:android:8557b391a1c5f024795cde',
    messagingSenderId: '986771803771',
    projectId: 'drunken-sailor-e61a6',
    storageBucket: 'drunken-sailor-e61a6.firebasestorage.app',
  );
}
