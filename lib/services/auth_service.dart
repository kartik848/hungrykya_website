import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../core/config.dart';
import '../core/fb.dart';
import '../models/models.dart';

/// Signed-in user plus their Firestore profile, vendor record and admin flag.
class AuthService extends ChangeNotifier {
  final _auth = Fb.auth;
  final _fs = Fb.db;

  User? user;
  AppUser? profile;
  Vendor? vendor;
  bool isAdmin = false;
  bool ready = false;

  StreamSubscription? _authSub, _profileSub, _vendorSub;

  AuthService() {
    _init();
  }

  Future<void> _init() async {
    try {
      await _auth.setPersistence(Persistence.LOCAL);
    } catch (_) {}
    _authSub = _auth.authStateChanges().listen(_onUser);
  }

  bool get signedIn => user != null;
  bool get isBlocked => profile?.blocked == true;
  String get displayName {
    if (profile?.name.isNotEmpty == true) return profile!.name;
    if (user?.displayName?.isNotEmpty == true) return user!.displayName!;
    if (user?.email == AppConfig.adminEmail) return 'HungryKya Admin';
    return user?.email ?? '';
  }

  Future<void> _onUser(User? u) async {
    final old = [_profileSub, _vendorSub];
    _profileSub = null;
    _vendorSub = null;
    user = u;
    profile = null;
    vendor = null;
    isAdmin = u?.email == AppConfig.adminEmail;

    for (final s in old) {
      await s?.cancel();
    }

    if (u != null) {
      isAdmin = u.email == AppConfig.adminEmail;
      if (!isAdmin) {
        try {
          isAdmin = (await _fs.collection('admins').doc(u.uid).get()).exists;
        } catch (_) {
          isAdmin = false;
        }
      }

      // Pre-fetch initial profile and vendor docs before marking ready = true
      // so screens immediately see the loaded vendor/profile without flickering.
      try {
        final pSnap = await _fs.collection('users').doc(u.uid).get();
        if (pSnap.exists && pSnap.data() != null) {
          profile = AppUser.fromMap(pSnap.id, pSnap.data()!);
        }
      } catch (_) {}

      try {
        final vSnap = await _fs.collection('vendors').doc(u.uid).get();
        if (vSnap.exists && vSnap.data() != null) {
          vendor = Vendor.fromMap(vSnap.id, vSnap.data()!);
        }
      } catch (_) {}

      _profileSub = _fs.collection('users').doc(u.uid).snapshots().listen((d) {
        profile = d.exists ? AppUser.fromMap(d.id, d.data()!) : null;
        notifyListeners();
      }, onError: (_) {});
      _vendorSub = _fs.collection('vendors').doc(u.uid).snapshots().listen((d) {
        vendor = d.exists ? Vendor.fromMap(d.id, d.data()!) : null;
        notifyListeners();
      }, onError: (_) {});
    }

    ready = true;
    notifyListeners();
  }

  /// Re-reads `admins/{uid}` (after the doc is created in the Firebase console).
  Future<void> refreshAdmin() async {
    final u = user;
    if (u == null) return;
    try {
      isAdmin = u.email == AppConfig.adminEmail ||
          (await _fs.collection('admins').doc(u.uid).get(const GetOptions(source: Source.server))).exists;
    } catch (_) {}
    notifyListeners();
  }

  Future<void> _ensureProfile(User u, {String? name, String? phone, String role = 'customer'}) async {
    final ref = _fs.collection('users').doc(u.uid);
    final snap = await ref.get();
    if (snap.exists) return;
    await ref.set({
      'name': name ?? u.displayName ?? (u.email == AppConfig.adminEmail ? 'HungryKya Admin' : ''),
      'email': u.email ?? '',
      'phone': phone ?? u.phoneNumber ?? '',
      'role': role,
      'blocked': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> signIn(String email, String password) async {
    try {
      await _auth.setPersistence(Persistence.LOCAL);
    } catch (_) {}
    final c = await _auth.signInWithEmailAndPassword(email: AppConfig.normalizeLoginId(email), password: password);
    await _ensureProfile(c.user!);
  }

  Future<void> signUp({required String name, required String email, required String phone, required String password}) async {
    try {
      await _auth.setPersistence(Persistence.LOCAL);
    } catch (_) {}
    final c = await _auth.createUserWithEmailAndPassword(email: email.trim(), password: password);
    await c.user!.updateDisplayName(name.trim());
    await _ensureProfile(c.user!, name: name.trim(), phone: phone.trim());
  }

  Future<void> signInWithGoogle() async {
    try {
      await _auth.setPersistence(Persistence.LOCAL);
    } catch (_) {}
    final c = await _auth.signInWithPopup(GoogleAuthProvider());
    await _ensureProfile(c.user!);
  }

  Future<void> resetPassword(String email) => _auth.sendPasswordResetEmail(email: email.trim());

  Future<void> signOut() => _auth.signOut();

  Future<void> saveLastAddress(Map<String, dynamic> address, {String? name, String? phone}) async {
    if (user == null) return;
    await _fs.collection('users').doc(user!.uid).set({
      'lastAddress': address,
      if (name != null && name.isNotEmpty) 'name': name,
      if (phone != null && phone.isNotEmpty) 'phone': phone,
    }, SetOptions(merge: true));
  }

  List<Address> get addresses => profile?.addresses ?? const [];
  Address? get currentAddress => profile?.currentAddress;

  /// Adds or replaces [a] in the saved address book and makes it the delivery address.
  Future<void> saveAddress(Address a) async {
    if (user == null) return;
    final list = [...addresses.where((e) => e.id != a.id), a];
    await _fs.collection('users').doc(user!.uid).set({
      'addresses': list.map((e) => e.toMap()).toList(),
      'defaultAddressId': a.id,
    }, SetOptions(merge: true));
  }

  Future<void> deleteAddress(String id) async {
    if (user == null) return;
    final list = addresses.where((e) => e.id != id).toList();
    await _fs.collection('users').doc(user!.uid).set({
      'addresses': list.map((e) => e.toMap()).toList(),
      if (profile?.defaultAddressId == id) 'defaultAddressId': list.isEmpty ? '' : list.first.id,
    }, SetOptions(merge: true));
  }

  Future<void> selectAddress(String id) async {
    if (user == null) return;
    await _fs.collection('users').doc(user!.uid).set({'defaultAddressId': id}, SetOptions(merge: true));
  }

  /// Creates (or reuses) the login account and files a pending vendor application,
  /// recording the vendor's consent to the platform commission.
  Future<void> registerVendor({
    required String businessName,
    required String ownerName,
    required String email,
    required String phone,
    String? password,
    required String address,
    required String city,
    required String pincode,
    required String cuisine,
    required String fssai,
    required PayoutAccount payout,
  }) async {
    final mail = email.trim().toLowerCase();
    if (mail == AppConfig.adminEmail) throw Exception('This email is reserved. Please use your own email.');
    var u = _auth.currentUser;
    if (u != null && (u.email ?? '').toLowerCase() == mail) {
      // Existing customer turning into a vendor: same account, confirm the password.
      await _auth.signInWithEmailAndPassword(email: mail, password: password!);
      u = _auth.currentUser!;
      await _ensureProfile(u, name: ownerName.trim(), phone: phone.trim(), role: 'vendor');
      await _fs.collection('users').doc(u.uid).set({'role': 'vendor'}, SetOptions(merge: true));
    } else {
      // Someone else (e.g. the admin) may be logged in on this browser — the vendor gets their own account.
      if (u != null) await _auth.signOut();
      final c = await _auth.createUserWithEmailAndPassword(email: mail, password: password!);
      await c.user!.updateDisplayName(ownerName.trim());
      u = c.user!;
      await _ensureProfile(u, name: ownerName.trim(), phone: phone.trim(), role: 'vendor');
    }
    await _fs.collection('vendors').doc(u.uid).set({
      'businessName': businessName.trim(),
      'ownerName': ownerName.trim(),
      'email': (u.email ?? email).trim(),
      'phone': phone.trim(),
      'address': address.trim(),
      'city': city.trim(),
      'pincode': pincode.trim(),
      'cuisine': cuisine.trim(),
      'fssai': fssai.trim(),
      'payout': payout.toMap(),
      'status': VendorStatus.pending,
      'commissionRate': AppConfig.vendorCommissionRate,
      'commissionConsent': {
        'accepted': true,
        'rate': AppConfig.vendorCommissionRate,
        'version': AppConfig.commissionTermsVersion,
        'text': AppConfig.commissionConsentText,
        'acceptedAt': FieldValue.serverTimestamp(),
      },
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _profileSub?.cancel();
    _vendorSub?.cancel();
    super.dispose();
  }
}

String authErrorText(Object e) {
  if (e is FirebaseAuthException) {
    switch (e.code) {
      case 'invalid-email':
        return 'That email address looks wrong.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Email or password is incorrect.';
      case 'email-already-in-use':
        return 'An account already exists with this email. Please log in instead.';
      case 'weak-password':
        return 'Password should be at least 6 characters.';
      case 'popup-closed-by-user':
      case 'cancelled-popup-request':
        return 'Sign-in was cancelled.';
      case 'operation-not-allowed':
        return 'This sign-in method is not enabled in Firebase yet.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait a minute and try again.';
      case 'network-request-failed':
        return 'Network error. Check your internet connection.';
    }
    return e.message ?? 'Something went wrong (${e.code}).';
  }
  if (e is FirebaseException) {
    if (e.code == 'permission-denied') return 'You do not have permission to do that.';
    return e.message ?? 'Something went wrong (${e.code}).';
  }
  return e.toString().replaceFirst('Exception: ', '');
}
