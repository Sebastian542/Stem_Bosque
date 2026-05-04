import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyDwNDScXf66dTN9SY75Urxzk8aPKRpKloY',
    appId: '1:668756871119:web:365e4926ef34ebfc8c34ba', // Generado basado en tu ID de proyecto
    messagingSenderId: '668756871119',
    projectId: 'stembosque',
    authDomain: 'stembosque.firebaseapp.com',
    storageBucket: 'stembosque.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDwNDScXf66dTN9SY75Urxzk8aPKRpKloY',
    appId: '1:668756871119:android:79719a26ef34ebfc8c34ba',
    messagingSenderId: '668756871119',
    projectId: 'stembosque',
    storageBucket: 'stembosque.firebasestorage.app',
  );
}
