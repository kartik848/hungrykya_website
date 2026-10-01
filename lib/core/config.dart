/// App-wide constants. Values an admin can change at runtime (UPI id, delivery
/// fee, contact details...) live in Firestore `settings/store`; these are the
/// fallbacks used until that document exists.
class AppConfig {
  static const brandName = 'HungryKya';
  static const tagline = 'Ghar jaisa khana, restaurant wala swaad.';

  static const defaultUpiId = '903177188@axl';
  static const defaultPayeeName = 'HungryKya';

  /// HungryKya's own kitchen. Products with this vendorId pay no commission.
  static const houseVendorId = 'house';
  static const houseVendorName = 'HungryKya Kitchen';

  /// Commission charged to partner vendors on every order (2%).
  static const vendorCommissionRate = 0.02;
  static const commissionTermsVersion = 'v1-2026-10';
  static const commissionConsentText =
      'I agree that HungryKya will charge a commission of 2% on the food value '
      '(after discounts, excluding delivery fee) of every order my kitchen receives '
      'through the HungryKya platform. Payouts to my kitchen will be settled after '
      'deducting this commission. HungryKya may suspend my listing if I break the '
      'platform rules or food-safety norms.';

  /// The admin logs in with the short id "admin@123". Firebase needs a dotted
  /// domain, so ids without one get [loginDomainSuffix] appended.
  static const adminEmail = 'admin@123.hungrykya.app';
  static const loginDomainSuffix = '.hungrykya.app';

  static String normalizeLoginId(String id) {
    final v = id.trim().toLowerCase();
    final at = v.indexOf('@');
    if (at > 0 && !v.substring(at + 1).contains('.')) return '$v$loginDomainSuffix';
    return v;
  }

  /// imgbb.com API key used to host uploaded photos (menu items, banners).
  /// It ships in the web app, so anyone could use it to upload to this
  /// imgbb account — rotate it from imgbb settings if it is ever abused.
  static const imgbbApiKey = '9996fcaf2d3ccf2cd3d8f5ece57583f8';

  /// Largest photo accepted after in-browser resizing.
  static const maxImageBytes = 10 * 1024 * 1024;
}
