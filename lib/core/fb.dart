import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

/// The three parts of the site. Each gets its own Firebase app instance, so
/// the admin, a vendor and a customer can stay logged in separately (even in
/// the same browser) without logging each other out.
enum Area { store, vendor, admin }

Area areaFor(String path) {
  if (path.startsWith('/admin')) return Area.admin;
  if (path.startsWith('/vendor') || path.startsWith('/partner')) return Area.vendor;
  return Area.store;
}

class Fb {
  static late final Area area;
  static late final FirebaseApp app;

  static FirebaseAuth get auth => FirebaseAuth.instanceFor(app: app);
  static FirebaseFirestore get db => FirebaseFirestore.instanceFor(app: app);

  static Future<void> init(FirebaseOptions options, String path, {bool emulator = false}) async {
    area = areaFor(path);
    app = area == Area.store
        ? await Firebase.initializeApp(options: options)
        : await Firebase.initializeApp(name: 'hk-${area.name}', options: options);
    if (emulator) {
      await auth.useAuthEmulator('127.0.0.1', 9099);
      db.useFirestoreEmulator('127.0.0.1', 8081);
    }
  }
}
