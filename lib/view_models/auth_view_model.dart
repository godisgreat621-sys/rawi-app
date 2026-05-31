import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthViewModel extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  bool _isLoading = false;
  bool get isLoading => _isLoading;
  User? get currentUser => _auth.currentUser;

  Future<String?> signUp(String email, String password, {String? displayName}) async {
    _setLoading(true);
    try {
      final result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      if (displayName != null && displayName.isNotEmpty) {
        await result.user?.updateDisplayName(displayName);
      }
      await FirebaseFirestore.instance
          .collection('users')
          .doc(result.user!.uid)
          .set({
        'email': email,
        'displayName': displayName ?? '',
        'role': 'user',
        'isActive': true,
        'points': 0,
        'ratingsGiven': 0,
        'lastChapterRatingsReceived': 0,
        'createdAt': FieldValue.serverTimestamp(),
      });
      _setLoading(false);
      return null;
    } on FirebaseAuthException catch (e) {
      _setLoading(false);
      return _handleAuthError(e);
    }
  }

  Future<String?> login(String email, String password) async {
    _setLoading(true);
    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);
      _setLoading(false);
      return null;
    } on FirebaseAuthException catch (e) {
      _setLoading(false);
      return _handleAuthError(e);
    }
  }

  Future<void> logout() async {
    await _auth.signOut();
    notifyListeners();
  }

  Future<String?> updateDisplayName(String newName) async {
    try {
      await _auth.currentUser?.updateDisplayName(newName);
      final uid = _auth.currentUser?.uid;
      if (uid != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .update({'displayName': newName});
      }
      notifyListeners();
      return null;
    } catch (e) {
      return 'حدث خطأ أثناء تحديث الاسم.';
    }
  }

  Future<String?> updatePassword(String newPassword) async {
    try {
      await _auth.currentUser?.updatePassword(newPassword);
      return null;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        return 'يرجى تسجيل الخروج والدخول مجدداً ثم المحاولة.';
      }
      return 'حدث خطأ أثناء تغيير كلمة المرور.';
    }
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  String _handleAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'weak-password':
        return 'كلمة المرور ضعيفة جداً، يرجى كتابة 6 أحرف أو أكثر.';
      case 'email-already-in-use':
        return 'هذا البريد الإلكتروني مسجل بالفعل.';
      case 'invalid-email':
        return 'صيغة البريد الإلكتروني غير صحيحة.';
      case 'user-not-found':
        return 'لا يوجد حساب بهذا البريد الإلكتروني.';
      case 'wrong-password':
        return 'كلمة المرور غير صحيحة.';
      default:
        return 'حدث خطأ، يرجى المحاولة مرة أخرى.';
    }
  }
}