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

  /// وظيفة عامة لرفع الصور متوافقة تماماً مع الويب والموبايل
  static Future<String?> pickAndUploadImage(String folder) async {
    final user = _auth.currentUser;
    if (user == null) return null;

    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 60);
    if (image == null) return null;

    try {
      final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
      final ref = _storage.ref().child(folder).child(fileName);

      // استخدام Bytes بدلاً من File لضمان التوافق مع الويب والموبايل
      final Uint8List bytes = await image.readAsBytes();
      await ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));

      return await ref.getDownloadURL();
    } catch (e) {
      debugPrint('Error uploading image: $e');
      return null;
    }
  }

  /// يرفع صورة شخصية للمستخدم الحالي ويحدث بياناته
  static Future<String?> uploadProfilePicture() async {
    final user = _auth.currentUser;
    if (user == null) return null;
    final url = await pickAndUploadImage('user_profiles');
    if (url == null) return null;
    try {
      await _firestore.collection('users').doc(user.uid).update({
        'profilePicture': url,
      });

      return url;
    } catch (e) {
      debugPrint('Error uploading profile picture: $e');
      return null;
    }
  }

  /// تحديث اسم العرض للمستخدم
  static Future<void> updateDisplayName(String newName) async {
    final user = _auth.currentUser;
    if (user == null) return;

    // تحديث في Firebase Auth
    await user.updateDisplayName(newName);
    
    // تحديث في Firestore
    await _firestore.collection('users').doc(user.uid).update({
      'displayName': newName,
    });
  }
}