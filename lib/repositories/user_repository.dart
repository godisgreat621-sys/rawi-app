import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart';

class UserRepository {
  static final _storage = FirebaseStorage.instance;
  static final _firestore = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;

  /// يرفع صورة شخصية للمستخدم الحالي ويحدث بياناته في Firestore و Auth
  static Future<String?> uploadProfilePicture() async {
    final user = _auth.currentUser;
    if (user == null) return null;

    final picker = ImagePicker();
    // اختيار صورة من المعرض
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 50, // تقليل الجودة لتقليل حجم الملف وسرعة الرفع
      maxWidth: 500,    // تحديد العرض الأقصى للصورة
    );

    if (image == null) return null;

    try {
      // 1. إنشاء مرجع في Firebase Storage (باسم UID المستخدم)
      final ref = _storage.ref().child('user_profiles').child('${user.uid}.jpg');

      // 2. رفع الملف (مع مراعاة طريقة القراءة لبيئة الويب)
      if (kIsWeb) {
        await ref.putData(await image.readAsBytes(), SettableMetadata(contentType: 'image/jpeg'));
      } else {
        await ref.putFile(File(image.path));
      }

      // 3. الحصول على رابط التحميل (URL)
      final url = await ref.getDownloadURL();

      // 4. تحديث مستند المستخدم في Firestore
      await _firestore.collection('users').doc(user.uid).update({
        'profilePicture': url,
      });

      return url;
    } catch (e) {
      debugPrint('Error uploading profile picture: $e');
      return null;
    }
  }
}