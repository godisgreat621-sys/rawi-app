import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthViewModel extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  User? get currentUser => _auth.currentUser;

  Future<String?> signUp(String email, String password) async {
    _setLoading(true);
    try {
      await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
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
      await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
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

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  String _handleAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'weak-password':
        return 'كلمة المرور ضعيفة جداً، يرجى كتابة 6 أحرف أو أكثر.';
      case 'email-already-in-use':
        return 'هذا البريد الإلكتروني مسجل بالفعل بحساب آخر.';
      case 'invalid-email':
        return 'صيغة البريد الإلكتروني غير صحيحة.';
      case 'user-not-found':
        return 'لا يوجد حساب مسجل بهذا البريد الإلكتروني.';
      case 'wrong-password':
        return 'كلمة المرور التي أدخلتها غير صحيحة.';
      default:
        return 'حدث خطأ ما، يرجى المحاولة مرة أخرى لاحقاً.';
    }
  }
}