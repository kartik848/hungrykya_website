import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';

import 'package:http/http.dart' as http;
import 'package:web/web.dart' as web;

class LocationException implements Exception {
  final String message;
  final bool denied;
  LocationException(this.message, {this.denied = false});
  @override
  String toString() => message;
}

class GeoAddress {
  final double lat;
  final double lng;
  final String house;
  final String area;
  final String city;
  final String district;
  final String pincode;
  const GeoAddress({required this.lat, required this.lng, this.house = '', this.area = '', this.city = '', this.district = '', this.pincode = ''});
}

/// Browser geolocation (asks the customer for location permission) plus
/// reverse geocoding through OpenStreetMap Nominatim (free, no API key).
/// One row in the address search dropdown.
class PlaceSuggestion {
  final String title;
  final String subtitle;
  final String area;
  final String city;
  final String district;
  final String pincode;
  final double? lat;
  final double? lng;
  const PlaceSuggestion({
    required this.title,
    required this.subtitle,
    this.area = '',
    this.city = '',
    this.district = '',
    this.pincode = '',
    this.lat,
    this.lng,
  });
}

/// India Post data for a pincode.
class PincodeInfo {
  final String district;
  final String state;
  final List<String> areas;
  const PincodeInfo({required this.district, required this.state, required this.areas});
}

class LocationService {
  static final _pinCache = <String, PincodeInfo?>{};

  /// Looks up an Indian pincode (India Post). Returns null for unknown pincodes.
  static Future<PincodeInfo?> lookupPincode(String pin) async {
    if (!RegExp(r'^\d{6}$').hasMatch(pin)) return null;
    if (_pinCache.containsKey(pin)) return _pinCache[pin];
    try {
      final r = await http.get(Uri.https('api.postalpincode.in', '/pincode/$pin')).timeout(const Duration(seconds: 10));
      final body = jsonDecode(r.body);
      final first = body is List && body.isNotEmpty ? body.first as Map : const {};
      final offices = (first['PostOffice'] as List?) ?? const [];
      if (first['Status'] != 'Success' || offices.isEmpty) return _pinCache[pin] = null;
      final o0 = offices.first as Map;
      final areas = <String>{
        for (final o in offices) ((o as Map)['Name'] ?? '').toString().trim(),
      }.where((e) => e.isNotEmpty).toList();
      return _pinCache[pin] = PincodeInfo(
        district: (o0['District'] ?? '').toString(),
        state: (o0['State'] ?? '').toString(),
        areas: areas,
      );
    } catch (_) {
      return null; // network problem: don't cache
    }
  }

  /// Address autocomplete (Photon / OpenStreetMap), biased towards [lat],[lng].
  static Future<List<PlaceSuggestion>> searchPlaces(String query, {double? lat, double? lng}) async {
    final q = query.trim();
    if (q.length < 3) return const [];
    try {
      final params = {'q': q, 'limit': '7', 'lang': 'en'};
      if (lat != null && lng != null) {
        params['lat'] = '$lat';
        params['lon'] = '$lng';
      }
      final r = await http.get(Uri.https('photon.komoot.io', '/api/', params)).timeout(const Duration(seconds: 8));
      final features = (jsonDecode(r.body)['features'] as List?) ?? const [];
      final out = <PlaceSuggestion>[];
      for (final f in features) {
        final p = Map<String, dynamic>.from((f as Map)['properties'] as Map);
        if ((p['countrycode'] ?? '').toString().toUpperCase() != 'IN') continue;
        final coords = ((f['geometry'] as Map?)?['coordinates'] as List?) ?? const [];
        String s(String k) => (p[k] ?? '').toString().trim();
        final name = s('name');
        final street = [s('housenumber'), s('street')].where((e) => e.isNotEmpty).join(' ');
        final locality = [s('locality'), s('district')].firstWhere((e) => e.isNotEmpty, orElse: () => '');
        final city = [s('city'), s('county'), s('state')].firstWhere((e) => e.isNotEmpty, orElse: () => '');
        final area = <String>{if (name.isNotEmpty) name, if (street.isNotEmpty) street, if (locality.isNotEmpty) locality}.join(', ');
        if (area.isEmpty) continue;
        out.add(PlaceSuggestion(
          title: name.isNotEmpty ? name : area,
          subtitle: [if (name.isNotEmpty && street.isNotEmpty) street, locality, city, s('postcode')].where((e) => e.isNotEmpty).toSet().join(', '),
          area: area,
          city: city,
          district: s('county').replaceAll(RegExp(r'\s+(Urban|Rural)?\s*Taluka$', caseSensitive: false), ''),
          pincode: s('postcode').replaceAll(' ', ''),
          lng: coords.length == 2 ? (coords[0] as num).toDouble() : null,
          lat: coords.length == 2 ? (coords[1] as num).toDouble() : null,
        ));
      }
      return out;
    } catch (_) {
      return const [];
    }
  }

  static Future<({double lat, double lng})> currentPosition() async {
    try {
      return await _position(highAccuracy: true, timeoutMs: 12000);
    } on LocationException catch (e) {
      if (e.denied) rethrow;
      // GPS can be slow indoors; Wi-Fi/IP based location is usually instant.
      return _position(highAccuracy: false, timeoutMs: 15000);
    }
  }

  static Future<({double lat, double lng})> _position({required bool highAccuracy, required int timeoutMs}) {
    final c = Completer<({double lat, double lng})>();
    final web.Geolocation geo;
    try {
      geo = web.window.navigator.geolocation;
    } catch (_) {
      return Future.error(LocationException('This browser cannot share location. Open the site in Chrome, or search your area below.', denied: true));
    }
    geo.getCurrentPosition(
      ((web.GeolocationPosition p) {
        if (!c.isCompleted) c.complete((lat: p.coords.latitude, lng: p.coords.longitude));
      }).toJS,
      ((web.GeolocationPositionError e) {
        if (c.isCompleted) return;
        c.completeError(switch (e.code) {
          1 => LocationException(
              'Location is blocked. In Chrome: click the 🔒 icon next to the website address → Location → Allow, then try again. '
              '(It does not work inside the VS Code preview — open the site in Chrome.) You can also search your area below.',
              denied: true),
          3 => LocationException('Finding your location took too long. Please try again or type your address.'),
          _ => LocationException('Could not detect your location. Please type your address below.'),
        });
      }).toJS,
      web.PositionOptions(enableHighAccuracy: highAccuracy, timeout: timeoutMs, maximumAge: highAccuracy ? 0 : 300000),
    );
    return c.future;
  }

  static Future<GeoAddress> reverseGeocode(double lat, double lng) async {
    try {
      final uri = Uri.https('nominatim.openstreetmap.org', '/reverse', {
        'format': 'jsonv2',
        'lat': '$lat',
        'lon': '$lng',
        'zoom': '18',
        'addressdetails': '1',
        'accept-language': 'en',
      });
      final r = await http.get(uri).timeout(const Duration(seconds: 10));
      final a = Map<String, dynamic>.from((jsonDecode(r.body)['address'] as Map?) ?? const {});
      String pick(List<String> keys) {
        for (final k in keys) {
          final v = a[k];
          if (v is String && v.trim().isNotEmpty) return v.trim();
        }
        return '';
      }

      final road = pick(['road', 'pedestrian', 'street']);
      final locality = pick(['neighbourhood', 'suburb', 'quarter', 'residential', 'city_district', 'hamlet']);
      return GeoAddress(
        lat: lat,
        lng: lng,
        house: [pick(['house_number']), pick(['building', 'amenity'])].where((e) => e.isNotEmpty).join(', '),
        area: [road, locality].where((e) => e.isNotEmpty).join(', '),
        city: pick(['city', 'town', 'village', 'municipality', 'county', 'state_district']),
        district: pick(['state_district', 'county']).replaceAll(RegExp(r'\s+district$', caseSensitive: false), ''),
        pincode: pick(['postcode']).replaceAll(' ', ''),
      );
    } catch (_) {
      // Coordinates are still useful for delivery even if the lookup fails.
      return GeoAddress(lat: lat, lng: lng);
    }
  }

  static Future<GeoAddress> detect() async {
    final p = await currentPosition();
    var g = await reverseGeocode(p.lat, p.lng);
    if (g.pincode.isEmpty || g.city.isEmpty || g.area.isEmpty) {
      // Fill gaps from Photon's reverse geocoder.
      try {
        final r = await http
            .get(Uri.https('photon.komoot.io', '/reverse', {'lat': '${p.lat}', 'lon': '${p.lng}', 'lang': 'en'}))
            .timeout(const Duration(seconds: 8));
        final f = ((jsonDecode(r.body)['features'] as List?) ?? const []);
        if (f.isNotEmpty) {
          final pr = Map<String, dynamic>.from((f.first as Map)['properties'] as Map);
          String s(String k) => (pr[k] ?? '').toString().trim();
          g = GeoAddress(
            lat: p.lat,
            lng: p.lng,
            house: g.house,
            area: g.area.isNotEmpty ? g.area : [s('street'), s('district'), s('locality')].where((e) => e.isNotEmpty).toSet().join(', '),
            city: g.city.isNotEmpty ? g.city : s('city'),
            district: g.district,
            pincode: g.pincode.isNotEmpty ? g.pincode : s('postcode').replaceAll(' ', ''),
          );
        }
      } catch (_) {}
    }
    // Correct city/district from the official pincode directory.
    final pin = await lookupPincode(g.pincode);
    if (pin != null) {
      g = GeoAddress(
        lat: g.lat,
        lng: g.lng,
        house: g.house,
        area: g.area,
        city: g.city.isNotEmpty ? g.city : pin.district,
        district: pin.district,
        pincode: g.pincode,
      );
    }
    return g;
  }
}
