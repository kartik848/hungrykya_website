import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import '../core/config.dart';
import '../core/fb.dart';

class PickedImage {
  final Uint8List bytes;
  final String name;
  const PickedImage(this.bytes, this.name);
}

/// Photo uploads: pick → resize in the browser → upload to imgbb → store the
/// returned https URL on the product/banner.
class MediaService {
  /// Opens the file picker. Photos are resized to [maxWidth] and re-encoded
  /// as JPEG (quality 82) by the browser before upload.
  static Future<PickedImage?> pick({double maxWidth = 1600}) async {
    final x = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: maxWidth, maxHeight: maxWidth, imageQuality: 82);
    if (x == null) return null;
    final bytes = await x.readAsBytes();
    if (bytes.length > AppConfig.maxImageBytes) {
      throw Exception('Photo is too large (${(bytes.length / 1024 / 1024).toStringAsFixed(1)} MB). Please pick one under 10 MB.');
    }
    final name = x.name.isEmpty ? 'photo.jpg' : x.name;
    return PickedImage(bytes, name);
  }

  /// Uploads to imgbb and returns the public image URL.
  static Future<String> upload(PickedImage img) async {
    final req = http.MultipartRequest('POST', Uri.parse('https://api.imgbb.com/1/upload?key=${AppConfig.imgbbApiKey}'))
      ..fields['name'] = 'hungrykya-${DateTime.now().millisecondsSinceEpoch}'
      ..files.add(http.MultipartFile.fromBytes('image', img.bytes, filename: img.name));
    final http.Response res;
    try {
      res = await http.Response.fromStream(await req.send()).timeout(const Duration(seconds: 90));
    } catch (_) {
      throw Exception('Upload failed — check your internet connection and try again.');
    }
    Map<String, dynamic> body;
    try {
      body = jsonDecode(res.body) as Map<String, dynamic>;
    } catch (_) {
      throw Exception('Upload failed (HTTP ${res.statusCode}). Please try again.');
    }
    final data = body['data'];
    if (res.statusCode != 200 || body['success'] != true || data is! Map) {
      final msg = (body['error'] is Map ? body['error']['message'] : null) ?? 'HTTP ${res.statusCode}';
      throw Exception('Upload failed: $msg');
    }
    return (data['display_url'] ?? data['url']) as String;
  }
}

/// Reads photos stored by older versions as Firestore blobs (`media:<id>`).
class MediaCache {
  static final _cache = <String, Future<Uint8List?>>{};

  static Future<Uint8List?> load(String id) => _cache.putIfAbsent(id, () async {
        try {
          final d = await Fb.db.collection('media').doc(id).get();
          final b = d.data()?['data'];
          return b is Blob ? b.bytes : null;
        } catch (_) {
          _cache.remove(id);
          return null;
        }
      });
}
