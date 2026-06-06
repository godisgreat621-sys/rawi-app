import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'dart:math';

class AuthViewModel extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  bool _isLoading = false;
  bool get isLoading => _isLoading;
  User? get currentUser => _auth.currentUser;

  // ── معرّف الجهاز (#8) ───────────────────────────────────────────────────
  // يستخدم device_info_plus للحصول على معرّف حقيقي حيثما أمكن
  Future<String> _getDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    // إذا كان مُخزَّناً مسبقاً نعيده مباشرة
    final cached = prefs.getString('device_id');
    if (cached != null && cached.isNotEmpty) return cached;

    String id;
    try {
      final info = DeviceInfoPlugin();
      if (kIsWeb) {
        final web = await info.webBrowserInfo;
        id = '${web.platform}_${web.userAgent?.hashCode ?? 0}';
      } else if (defaultTargetPlatform == TargetPlatform.android) {
        final android = await info.androidInfo;
        id = android.id;
      } else if (defaultTargetPlatform == TargetPlatform.iOS) {
        final ios = await info.iosInfo;
        id = ios.identifierForVendor ?? '';
      } else {
        id = '';
      }
    } catch (_) {
      id = '';
    }

    // fallback: معرّف عشوائي إذا لم نحصل على معرّف حقيقي
    if (id.isEmpty) {
      final rng = Random.secure();
      id = List.generate(24, (_) => rng.nextInt(36).toRadixString(36)).join();
    }
    await prefs.setString('device_id', id);
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
    // فحص تكرار الجهاز
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
    await GoogleSignIn(clientId: _webClientId).signOut();
    await _auth.signOut();
    notifyListeners();
  }

  // ── تسجيل دخول بحساب Google (#41) ──────────────────────────────────────────
  // ← ضع Web Client ID هنا بعد تفعيل Google في Firebase Console
  static const _webClientId = '181320126312-svfo1lv1qfb5peqqr3sjsb5v4eo8o6o0.apps.googleusercontent.com';

  Future<String?> signInWithGoogle() async {
    _setLoading(true);
    try {
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
        idToken:     googleAuth.idToken,
      );
      final result = await _auth.signInWithCredential(credential);
      final user = result.user;
      if (user == null) { _setLoading(false); return 'فشل تسجيل الدخول'; }

      // إنشاء وثيقة المستخدم إن لم تكن موجودة
      final ref = FirebaseFirestore.instance.collection('users').doc(user.uid);
      final snap = await ref.get();
      if (!snap.exists) {
        await ref.set({
          'email':        user.email ?? '',
          'displayName':  user.displayName ?? googleUser.displayName ?? '',
          'profilePicture': user.photoURL ?? '',
          'role':         'user',
          'isActive':     true,
          'points':       0,
          'ratingsGiven': 0,
          'followersCount': 0,
          'followingCount': 0,
          'lastChapterRatingsReceived': 0,
          'createdAt':    FieldValue.serverTimestamp(),
        });
      }
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