// Firebase web config for project hungrykya-30719 (from Firebase Console →
// Project settings → Your apps → HungryKya Web). These values are public by
// design; access is controlled by firestore.rules.
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform => web;

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyAhXbpUoca2H1WqLfiM9CMgTJZiJ-7oXe4',
    appId: '1:623881049351:web:7d26d0a4a9aada783ee1a2',
    messagingSenderId: '623881049351',
    projectId: 'hungrykya-30719',
    authDomain: 'hungrykya-30719.firebaseapp.com',
    databaseURL: 'https://hungrykya-30719-default-rtdb.firebaseio.com',
    storageBucket: 'hungrykya-30719.firebasestorage.app',
    measurementId: 'G-X59N6BGJVC',
  );
}
