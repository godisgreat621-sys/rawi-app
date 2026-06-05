import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

class UserRepository {
  static final _firestore = FirebaseFirestore.instance;
  static final _auth      = FirebaseAuth.instance;

  // ── Cloudinary config ────────────────────────────────────────────────────
  static const _cloudName    = 'dkwnjmbzl';
  static const _uploadPreset = 'uy1hp02s';
  static const _uploadUrl    =
      'https://api.cloudinary.com/v1_1/$_cloudName/image/upload';

  // ── رفع bytes لـ Cloudinary ──────────────────────────────────────────────
  static Future<String> _uploadToCloudinary(
    Uint8List bytes,
    String folder,
  ) async {
    final request = http.MultipartRequest('POST', Uri.parse(_uploadUrl))
      ..fields['upload_preset'] = _uploadPreset
      ..fields['folder']        = 'rawi/$folder'
      ..files.add(
        http.MultipartFile.fromBytes(
          'file',
          bytes,
          filename: '${folder}_${DateTime.now().millisecondsSinceEpoch}.jpg',
        ),
      );

    final streamed = await request.send();
    final body     = await streamed.stream.bytesToString();

    if (streamed.statusCode != 200) {
      debugPrint('Cloudinary error [${ streamed.statusCode}]: $body');
      Map<String, dynamic>? errJson;
      try { errJson = jsonDecode(body) as Map<String, dynamic>?; } catch (_) {}
      final msg = (errJson?['error'] as Map<String, dynamic>?)?['message'] ?? body;
      throw Exception('خطأ Cloudinary ${streamed.statusCode}: $msg');
    }

    final json = jsonDecode(body) as Map<String, dynamic>;
    if (json.containsKey('error')) {
      throw Exception('خطأ Cloudinary: ${json['error']['message']}');
    }
    
    final url  = json['secure_url'] as String?;
    return url ?? '';
  }

  // ── اختر صورة فقط (بدون رفع) — استخدم قبل setState ──────────────────────
  static Future<Uint8List?> pickImageOnly() async {
    final XFile? image = await ImagePicker().pickImage(
      source:       ImageSource.gallery,
      imageQuality: kIsWeb ? null : 72,
      maxWidth:     kIsWeb ? null : 900,
      maxHeight:    kIsWeb ? null : 900,
    );
    if (image == null) return null;
    final bytes = await image.readAsBytes();
    return bytes.isEmpty ? null : bytes;
  }

  // ── واجهة عامة: اختر وارفع ──────────────────────────────────────────────
  static Future<String> pickAndUploadImage(String folder) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('يجب تسجيل الدخول لرفع الصور.');

    final bytes = await pickImageOnly();
    if (bytes == null) throw Exception('لم يتم اختيار صورة.');

    return _uploadToCloudinary(bytes, folder);
  }

  // ── رفع الصورة الشخصية (bytes جاهز) ─────────────────────────────────────
  static Future<void> uploadProfilePictureBytes(Uint8List bytes) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('يجب تسجيل الدخول.');
    final url = await _uploadToCloudinary(bytes, 'user_profiles');
    await _firestore.collection('users').doc(user.uid)
        .update({'profilePicture': url});
  }

  // ── رفع الصورة الشخصية (اختر وارفع) ─────────────────────────────────────
  static Future<String> uploadProfilePicture() async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('يجب تسجيل الدخول.');

    final url = await pickAndUploadImage('user_profiles');
    await _firestore.collection('users').doc(user.uid)
        .update({'profilePicture': url});
    return url;
  }

  // ── تحديث اسم العرض ──────────────────────────────────────────────────────
  static Future<void> updateDisplayName(String newName) async {
    final user = _auth.currentUser;
    if (user == null) return;
    await user.updateDisplayName(newName);
    await _firestore.collection('users').doc(user.uid)
        .update({'displayName': newName});
  }
}