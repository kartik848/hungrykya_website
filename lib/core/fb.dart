import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

enum Area { store, vendor, admin }

Area areaFor(String path) {
  if (path.startsWith('/admin')) return Area.admin;
  if (path.startsWith('/vendor') || path.startsWith('/partner')) return Area.vendor;
  return Area.store;
}

class Fb {
  static Area get area => Area.store;
  static late final FirebaseApp app;

  static FirebaseAuth get auth => FirebaseAuth.instanceFor(app: app);
  static FirebaseFirestore get db => FirebaseFirestore.instanceFor(app: app);

  static Future<void> init(FirebaseOptions options, String path, {bool emulator = false}) async {
    app = Firebase.apps.isEmpty
        ? await Firebase.initializeApp(options: options)
        : Firebase.app();

    try {
      await auth.setPersistence(Persistence.LOCAL);
    } catch (_) {}

    if (emulator) {
      await auth.useAuthEmulator('127.0.0.1', 9099);
      db.useFirestoreEmulator('127.0.0.1', 8081);
    }
  }
}
