import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show kIsWeb;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    throw UnsupportedError('هذا التطبيق يدعم Web فقط حالياً');
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyC8bX7BV6xepbMHDH_Qz1-m3e-ENNUxI3E',
    authDomain: 'rawi-app-da746.firebaseapp.com',
    projectId: 'rawi-app-da746',
    storageBucket: 'rawi-app-da746.firebasestorage.app',
    messagingSenderId: '181320126312',
    appId: '1:181320126312:web:164c9094f394c2372650dd',
  );
}
