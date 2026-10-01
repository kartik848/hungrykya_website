import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:web/web.dart' as web;

import '../core/fb.dart';

import '../features/admin/admin_portal.dart';
import '../features/store/address_widgets.dart';
import '../features/store/auth_page.dart';
import '../features/store/checkout_page.dart';
import '../features/store/home_page.dart';
import '../features/store/orders_pages.dart';
import '../features/store/partner_page.dart';
import '../features/store/payment_page.dart';
import '../features/vendor/vendor_portal.dart';
import 'theme.dart';

final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(path: '/', builder: (c, s) => HomePage(section: s.uri.queryParameters['s'])),
    GoRoute(path: '/login', builder: (c, s) => CustomerAuthPage(next: s.uri.queryParameters['next'])),
    GoRoute(path: '/welcome', builder: (c, s) => LocationOnboardingPage(next: s.uri.queryParameters['next'] ?? '/')),
    GoRoute(path: '/checkout', builder: (c, s) => const CheckoutPage()),
    GoRoute(path: '/pay/:id', builder: (c, s) => PaymentPage(orderId: s.pathParameters['id']!)),
    GoRoute(path: '/orders', builder: (c, s) => const MyOrdersPage()),
    GoRoute(
      path: '/orders/:id',
      builder: (c, s) => OrderTrackingPage(orderId: s.pathParameters['id']!, justPlaced: s.uri.queryParameters['placed'] == '1'),
    ),
    GoRoute(path: '/partner', builder: (c, s) => const VendorRegisterPage()),
    GoRoute(path: '/vendor', builder: (c, s) => const VendorPortal()),
    GoRoute(path: '/admin', builder: (c, s) => const AdminPortal()),
  ],
  errorBuilder: (c, s) => Scaffold(
    body: Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Text('🍽️', style: TextStyle(fontSize: 64)),
        const SizedBox(height: 12),
        Text('Page not found', style: AppTheme.display(30)),
        const SizedBox(height: 20),
        ElevatedButton(onPressed: () => c.go('/'), child: const Text('Back to menu')),
      ]),
    ),
  ),
);
