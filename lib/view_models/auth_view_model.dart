import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math';

class AuthViewModel extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  bool _isLoading = false;
  bool get isLoading => _isLoading;
  User? get currentUser => _auth.currentUser;

  AuthViewModel() {
    // يرصد أي تغيير في حالة المصادقة (popup / redirect / email) ويُحدّث الواجهة تلقائياً
    _auth.authStateChanges().listen((_) => notifyListeners());
  }

  // ── معرّف الجهاز (يمنع إنشاء أكثر من حساب) ─────────────────────────────
  Future<String> _getDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    var id = prefs.getString('device_id');
    if (id == null) {
      final rng = Random.secure();
      id = List.generate(24, (_) => rng.nextInt(36).toRadixString(36)).join();
      await prefs.setString('device_id', id);
    }
    return id;
  }

  Future<String?> _checkDeviceConflict() async {
    final deviceId = await _getDeviceId();
    final snap = await FirebaseFirestore.instance
        .collection('users')
        .where('deviceId', isEqualTo: deviceId)
        .limit(1)
        .get();
    if (snap.docs.isNotEmpty) {
      final existingEmail = snap.docs.first.data()['email'] ?? '';
      return 'هذا الجهاز مسجّل بالفعل بالحساب: $existingEmail\nيرجى تسجيل الدخول بدلاً من إنشاء حساب جديد.';
    }
    return null;
  }

  Future<String?> signUp(String email, String password, {String? displayName}) async {
    _setLoading(true);
    final deviceConflict = await _checkDeviceConflict();
    if (deviceConflict != null) { _setLoading(false); return deviceConflict; }

    try {
      final deviceId = await _getDeviceId();
      final result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      if (displayName != null && displayName.isNotEmpty) {
        await result.user?.updateDisplayName(displayName);
      }
      final uid = result.user?.uid;
      if (uid == null) { _setLoading(false); return 'فشل إنشاء الحساب'; }
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'email': email,
        'displayName': displayName ?? '',
        'role': 'user',
        'isActive': true,
        'points': 0,
        'ratingsGiven': 0,
        'followersCount': 0,
        'followingCount': 0,
        'lastChapterRatingsReceived': 0,
        'deviceId': deviceId,
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
    if (!kIsWeb) {
      try { await GoogleSignIn().signOut(); } catch (_) {}
    }
    await _auth.signOut();
    notifyListeners();
  }

  // ── تسجيل دخول بـ Google ────────────────────────────────────────────────────
  static const _webClientId =
      '181320126312-svfo1lv1qfb5peqqr3sjsb5v4eo8o6o0.apps.googleusercontent.com';

  Future<String?> signInWithGoogle() async {
    _setLoading(true);
    try {
      if (kIsWeb) {
        final provider = GoogleAuthProvider();
        provider.setCustomParameters({'prompt': 'select_account'});

        try {
          // Popup: نتيجة فورية، لا اعتماد على IndexedDB أو cross-origin redirect
          final result = await _auth.signInWithPopup(provider);
          final user = result.user;
          if (user != null) await _createUserIfNeeded(user);
          _setLoading(false);
          return null;
        } on FirebaseAuthException catch (e) {
          if (e.code == 'popup-closed-by-user' ||
              e.code == 'cancelled-popup-request') {
            _setLoading(false);
            return 'تم إلغاء تسجيل الدخول';
          }
          if (e.code == 'popup-blocked') {
            // احتياطي: redirect إذا منع المتصفح الـ popup (وضع PWA standalone)
            await _auth.signInWithRedirect(provider);
            _setLoading(false);
            return null;
          }
          rethrow;
        }
      }

      // جوال (تطبيق نيتف): google_sign_in المدمج
      final googleUser = await GoogleSignIn(
        clientId: _webClientId,
        scopes: ['email', 'profile'],
      ).signIn();
      if (googleUser == null) {
        _setLoading(false);
        return 'تم إلغاء تسجيل الدخول';
      }
      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      final result = await _auth.signInWithCredential(credential);
      final user = result.user;
      if (user == null) { _setLoading(false); return 'فشل تسجيل الدخول'; }
      await _createUserIfNeeded(user);
      _setLoading(false);
      return null;
    } on FirebaseAuthException catch (e) {
      _setLoading(false);
      return _handleAuthError(e);
    } catch (e) {
      _setLoading(false);
      return 'حدث خطأ: $e';
    }
  }

  // يُستدعى عند تحميل التطبيق — يعالج نتيجة redirect الاحتياطي
  Future<void> checkRedirectResult() async {
    if (!kIsWeb) return;
    try {
      final result = await _auth.getRedirectResult();
      final user = result.user;
      if (user == null) return;
      await _createUserIfNeeded(user);
      notifyListeners();
    } catch (e) {
      debugPrint('checkRedirectResult: $e');
    }
  }

  Future<void> _createUserIfNeeded(User user) async {
    final ref = FirebaseFirestore.instance.collection('users').doc(user.uid);
    final snap = await ref.get();
    if (!snap.exists) {
      final deviceId = await _getDeviceId();
      await ref.set({
        'email':                     user.email ?? '',
        'displayName':               user.displayName ?? '',
        'profilePicture':            user.photoURL ?? '',
        'role':                      'user',
        'isActive':                  true,
        'points':                    0,
        'ratingsGiven':              0,
        'followersCount':            0,
        'followingCount':            0,
        'lastChapterRatingsReceived': 0,
        'deviceId':                  deviceId,
        'createdAt':                 FieldValue.serverTimestamp(),
      });
    }
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
      case 'wrong-password':
      case 'invalid-credential': // Firebase v9+ يجمعهما في كود واحد
        return 'البريد الإلكتروني أو كلمة المرور غير صحيحة.';
      case 'too-many-requests':
        return 'محاولات كثيرة، يرجى الانتظار قليلاً ثم المحاولة.';
      case 'user-disabled':
        return 'هذا الحساب موقوف، يرجى التواصل مع الدعم.';
      case 'unauthorized-domain':
        return 'الموقع غير مرخص لتسجيل الدخول بـ Google — راسل الدعم.';
      case 'operation-not-allowed':
        return 'تسجيل الدخول بـ Google غير مفعّل حالياً.';
      case 'popup-blocked':
        return 'المتصفح يمنع النوافذ المنبثقة — جرّب فتح الموقع من متصفح آخر.';
      default:
        return 'حدث خطأ (${e.code})، يرجى المحاولة مرة أخرى.';
    }
  }
}
