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
  static const _cloudName    = 'dkwnjmbz1';
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
      debugPrint('Cloudinary error: $body');
      throw Exception('فشل رفع الصورة: تأكد من أن الـ Preset في Cloudinary هو Unsigned');
    }

    final json = jsonDecode(body) as Map<String, dynamic>;
    final url  = json['secure_url'] as String?;
    if (url == null || url.isEmpty) {
      throw Exception('لم يتم الحصول على رابط الصورة.');
    }
    return url;
  }

  // ── واجهة عامة: اختر وارفع ──────────────────────────────────────────────
  // يجب استدعاء هذه الدالة مباشرة من onTap/onPressed بدون await مسبق
  static Future<String> pickAndUploadImage(String folder) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('يجب تسجيل الدخول لرفع الصور.');

    // استدعاء مباشر بدون أي await قبله
    final XFile? image = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: kIsWeb ? null : 70,
    );

    if (image == null) throw Exception('لم يتم اختيار صورة.');

    final Uint8List bytes = await image.readAsBytes();
    if (bytes.isEmpty) throw Exception('فشل قراءة بيانات الصورة.');

    return _uploadToCloudinary(bytes, folder);
  }

  // ── رفع الصورة الشخصية ───────────────────────────────────────────────────
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