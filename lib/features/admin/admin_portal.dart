import 'dart:async';


import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../app/theme.dart';
import '../../core/config.dart';
import '../../models/models.dart';
import '../../services/auth_service.dart';
import '../../services/db.dart';
import '../../services/sound_service.dart';
import '../../widgets/common.dart';
import '../panel/orders_manager.dart';
import '../panel/panel_widgets.dart';
import '../panel/products_manager.dart';
import 'admin_sections.dart';
import 'categories_manager.dart';
import 'payouts_manager.dart';
import 'promos_manager.dart';

class AdminPortal extends StatelessWidget {
  const AdminPortal({super.key});

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: AppTheme.panel,
      child: Builder(builder: (context) {
        final auth = context.watch<AuthService>();
        if (!auth.ready) return const Scaffold(backgroundColor: PK.bg, body: Center(child: CircularProgressIndicator()));
        if (!auth.signedIn) {
          return const PanelLogin(
            title: 'Admin console',
            subtitle: 'Log in with your HungryKya admin ID and password.',
            emailLabel: 'Admin ID or email',
            showGoogle: false,
          );
        }
        if (!auth.isAdmin) return _NotAdmin(uid: auth.user!.uid, email: auth.user!.email ?? '');
        return const _AdminHome();
      }),
    );
  }
}

class _NotAdmin extends StatelessWidget {
  final String uid;
  final String email;
  const _NotAdmin({required this.uid, required this.email});

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthService>();
    return PanelMessage(
      emoji: '🔒',
      title: 'Admin access required',
      body: '$email is not an admin account.\n\n'
          'To access the Admin Console, please log in with your Admin ID (admin@123), '
          'or authorize this UID in Firebase Console under the "admins" collection:\n\n$uid',
      actions: [
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(backgroundColor: PK.amber, foregroundColor: Colors.black),
          onPressed: auth.signOut,
          icon: const Icon(Icons.login_rounded, size: 18),
          label: const Text('Log in with Admin Account'),
        ),
        OutlinedButton.icon(
          onPressed: () {
            Clipboard.setData(ClipboardData(text: uid));
            showToast(context, 'UID copied');
          },
          icon: const Icon(Icons.copy_rounded, size: 18),
          label: const Text('Copy UID'),
        ),
        TextButton(onPressed: auth.refreshAdmin, child: const Text('Check again')),
        TextButton(onPressed: auth.signOut, child: const Text('Log out')),
      ],
    );
  }
}

class _AdminHome extends StatefulWidget {
  const _AdminHome();
  @override
  State<_AdminHome> createState() => _AdminHomeState();
}

class _AdminHomeState extends State<_AdminHome> {
  final _subs = <StreamSubscription>[];
  List<OrderModel> _orders = [];
  List<Vendor> _vendors = [];
  List<AppUser> _users = [];
  int _section = 0;
  String _orderFilter = 'all';
  int _lastNewCount = -1;

  @override
  void initState() {
    super.initState();
    _subs.add(Db.allOrders().listen((o) {
      final newCount = o.where((e) => e.status == OrderStatus.placed).length;
      if (_lastNewCount >= 0 && newCount > _lastNewCount && mounted) {
        showToast(context, '🔔 New order received!');
        SoundService.playOrderAlert();
      }
      _lastNewCount = newCount;
      setState(() => _orders = o);
    }, onError: (_) {}));
    _subs.add(Db.allVendors().listen((v) => setState(() => _vendors = v), onError: (_) {}));
    _subs.add(Db.allUsers().listen((u) => setState(() => _users = u.where((x) => x.email != AppConfig.adminEmail).toList()), onError: (_) {}));
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    super.dispose();
  }

  void _go(int section, {String orderFilter = 'all'}) => setState(() {
        _section = section;
        _orderFilter = orderFilter;
      });

  @override
  Widget build(BuildContext context) {
    final newOrders = _orders.where((o) => o.status == OrderStatus.placed || o.paymentStatus == PayStatus.verification).length;
    final pendingVendors = _vendors.where((v) => v.status == VendorStatus.pending).length;
    final vendorsToPay = {for (final o in _orders.where((o) => o.awaitingPayout)) o.vendorId}.length;
    final items = [
      const PanelNavItem(Icons.space_dashboard_rounded, 'Dashboard'),
      PanelNavItem(Icons.receipt_long_rounded, 'Orders', badge: newOrders),
      const PanelNavItem(Icons.category_rounded, 'Categories'),
      const PanelNavItem(Icons.restaurant_menu_rounded, 'Menu & photos'),
      const PanelNavItem(Icons.view_carousel_rounded, 'Top banners'),
      const PanelNavItem(Icons.auto_awesome_rounded, 'Specials'),
      const PanelNavItem(Icons.local_offer_rounded, 'Offers & sales'),
      PanelNavItem(Icons.storefront_rounded, 'Vendors', badge: pendingVendors),
      PanelNavItem(Icons.account_balance_wallet_rounded, 'Payouts', badge: vendorsToPay),
      const PanelNavItem(Icons.people_alt_rounded, 'Customers'),
      const PanelNavItem(Icons.settings_rounded, 'Settings'),
    ];
    final body = switch (_section) {
      0 => AdminDashboard(orders: _orders, vendors: _vendors, users: _users, onGo: _go),
      1 => OrdersManager(key: ValueKey(_orderFilter), orders: _orders, isAdmin: true, initialFilter: _orderFilter),
      2 => const CategoriesManager(),
      3 => ProductsManager(isAdmin: true, vendors: _vendors),
      4 => const PromosManager(key: ValueKey('hero'), placement: 'hero'),
      5 => const PromosManager(key: ValueKey('bottom'), placement: 'bottom'),
      6 => const OffersManager(),
      7 => VendorsManager(vendors: _vendors, orders: _orders),
      8 => PayoutsManager(vendors: _vendors, orders: _orders),
      9 => CustomersManager(users: _users, orders: _orders),
      _ => const SettingsManager(),
    };
    return PanelShell(
      roleLabel: 'Admin',
      items: items,
      selected: _section,
      onSelect: (i) => _go(i),
      body: body,
    );
  }
}

