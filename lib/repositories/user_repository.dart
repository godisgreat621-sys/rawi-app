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
  static Future<String> pickAndUploadImage(String folder) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('يجب تسجيل الدخول لرفع الصور.');

    XFile? image;

    if (kIsWeb) {
      image = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: null, // Set to null for web to avoid Blob issues
      );
    } else {
      image = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 60,
      );
    }

    if (image == null) throw Exception('لم يتم اختيار صورة.');

    final Uint8List bytes = await image.readAsBytes();
    final String originalFileName = image.name;

    if (bytes.isEmpty) throw Exception('فشل قراءة بيانات الصورة.');

    try {
      final fileName = '${folder}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final ref = _storage.ref().child(folder).child(fileName);
      final uploadTask = await ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
      return await uploadTask.ref.getDownloadURL();
    } catch (e) {
      debugPrint('Error uploading image: $e');
      throw Exception('حدث خطأ أثناء رفع الصورة: $e');
    }
  }

  /// يرفع صورة شخصية للمستخدم الحالي ويحدث بياناته
  static Future<String> uploadProfilePicture() async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('يجب تسجيل الدخول لتحديث الصورة الشخصية.');

    try {
      final url = await pickAndUploadImage('user_profiles');
      await _firestore.collection('users').doc(user.uid).update({
        'profilePicture': url,
      });

      return url;
    } catch (e) {
      debugPrint('Error uploading profile picture: $e');
      throw Exception('حدث خطأ أثناء تحديث الصورة الشخصية: $e');
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