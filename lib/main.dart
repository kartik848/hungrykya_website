import 'package:flutter/material.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:provider/provider.dart';

import 'app/router.dart';
import 'app/theme.dart';
import 'core/fb.dart';
import 'firebase_options.dart';
import 'services/auth_service.dart';
import 'services/cart.dart';
import 'services/store_data.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  usePathUrlStrategy();

  final options = DefaultFirebaseOptions.currentPlatform;
  if (options.apiKey.startsWith('REPLACE')) {
    runApp(const _NotConfigured());
    return;
  }
  // Separate Firebase app (and login) for the website, vendor portal and admin.
  // `--dart-define=USE_EMULATOR=true` talks to local emulators (for testing).
  await Fb.init(options, Uri.base.path, emulator: const bool.fromEnvironment('USE_EMULATOR'));

  final cart = Cart();
  await cart.restore();

  runApp(MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => AuthService()),
      ChangeNotifierProvider.value(value: cart),
      ChangeNotifierProvider(create: (_) => StoreData(cart)),
    ],
    child: const HungryKyaApp(),
  ));
}

class HungryKyaApp extends StatelessWidget {
  const HungryKyaApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp.router(
        title: 'HungryKya — Bhook lagi? Order now',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.store,
        routerConfig: appRouter,
      );
}

/// Shown until `flutterfire configure` has generated real Firebase options.
class _NotConfigured extends StatelessWidget {
  const _NotConfigured();

  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.store,
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Text('🔥', style: TextStyle(fontSize: 56)),
                const SizedBox(height: 16),
                Text('Firebase is not configured yet', style: AppTheme.display(28), textAlign: TextAlign.center),
                const SizedBox(height: 12),
                Text(
                  'Run:  flutterfire configure --project=hungrykya-30719 --platforms=web\nthen restart the app.',
                  textAlign: TextAlign.center,
                  style: AppTheme.body(15, color: HK.muted, height: 1.6),
                ),
              ]),
            ),
          ),
        ),
      );
}
