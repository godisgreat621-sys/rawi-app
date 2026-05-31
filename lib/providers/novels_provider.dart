import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/novel_model.dart';

class NovelsProvider with ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ── إنشاء رواية جديدة مع فصلها الأول ──────────────────────────────────────
  Future<String?> addNovel({
    required String title,
    required String description,
    required String category,
    required String chapterTitle,
    required String chapterContent,
    String? coverUrl,
    required int wordCount,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return 'يجب تسجيل الدخول أولاً';

      final novelRef = await _db.collection('novels').add({
        'title': title,
        'description': description,
        'category': category,
        'coverUrl': coverUrl,
        'authorId': user.uid,
        'authorEmail': user.email ?? '',
        'rating': 0.0,
        'likes': 0,
        'readers': 0,
        'chaptersCount': 1,
        'status': 'ongoing',
        'createdAt': FieldValue.serverTimestamp(),
      });

      await novelRef.collection('chapters').add({
        'title': chapterTitle.isEmpty ? 'الفصل الأول' : chapterTitle,
        'content': chapterContent,
        'chapterNumber': 1,
        'isDraft': false,
        'wordCount': wordCount,
        'rating': 0.0,
        'ratingsCount': 0,
        'createdAt': FieldValue.serverTimestamp(),
      });

      await _db.collection('users').doc(user.uid).set({
        'lastPublished': FieldValue.serverTimestamp(),
        'ratingsGiven': 0,
        'lastChapterRatingsReceived': 0,
      }, SetOptions(merge: true));

      notifyListeners();
      return null;
    } catch (e) {
      return 'حدث خطأ: $e';
    }
  }

  // ── إضافة فصل لرواية موجودة ────────────────────────────────────────────────
  Future<String?> addChapter({
    required String novelId,
    required String chapterTitle,
    required String chapterContent,
    required int wordCount,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return 'يجب تسجيل الدخول أولاً';

      final novelRef = _db.collection('novels').doc(novelId);
      final chaptersSnap = await novelRef.collection('chapters').get();
      final nextNumber = chaptersSnap.docs.length + 1;

      await novelRef.collection('chapters').add({
        'title': chapterTitle.isEmpty ? 'الفصل $nextNumber' : chapterTitle,
        'content': chapterContent,
        'chapterNumber': nextNumber,
        'isDraft': false,
        'wordCount': wordCount,
        'rating': 0.0,
        'ratingsCount': 0,
        'createdAt': FieldValue.serverTimestamp(),
      });

      await novelRef.update({'chaptersCount': nextNumber});

      await _db.collection('users').doc(user.uid).set({
        'lastPublished': FieldValue.serverTimestamp(),
        'ratingsGiven': 0,
        'lastChapterRatingsReceived': 0,
      }, SetOptions(merge: true));

      notifyListeners();
      return null;
    } catch (e) {
      return 'حدث خطأ: $e';
    }
  }

  // ── نشر مسودة محفوظة ───────────────────────────────────────────────────────
  Future<String?> publishDraft(String draftId) async {
    try {
      final draftDoc = await _db.collection('drafts').doc(draftId).get();
      if (!draftDoc.exists) return 'المسودة غير موجودة';

      final data = draftDoc.data()!;
      final isNewNovel = data['isNewNovel'] ?? true;

      String? error;
      if (isNewNovel) {
        error = await addNovel(
          title: data['novelTitle'] ?? '',
          description: data['description'] ?? '',
          category: data['category'] ?? 'عام',
          chapterTitle: data['chapterTitle'] ?? '',
          chapterContent: data['chapterContent'] ?? '',
          wordCount: data['wordCount'] ?? 0,
          coverUrl: data['coverUrl'],
        );
      } else {
        error = await addChapter(
          novelId: data['novelId'] ?? '',
          chapterTitle: data['chapterTitle'] ?? '',
          chapterContent: data['chapterContent'] ?? '',
          wordCount: data['wordCount'] ?? 0,
        );
      }

      if (error == null) {
        await _db.collection('drafts').doc(draftId).delete();
      }

      return error;
    } catch (e) {
      return 'حدث خطأ: $e';
    }
  }

  // ── التحقق من تكرار المحتوى ────────────────────────────────────────────────
  Future<bool> isContentDuplicate(String content) async {
    if (content.length < 50) return false;
    final sample = content.substring(0, 100);
    final snap = await _db
        .collection('novels')
        .where('contentSample', isEqualTo: sample)
        .limit(1)
        .get();
    return snap.docs.isNotEmpty;
  }

  // ── Stream لجلب كل الروايات ─────────────────────────────────────────────────
  Stream<List<Novel>> getNovelsStream() {
    return _db
        .collection('novels')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) => Novel.fromFirestore(d)).toList());
  }

  // ── جلب مسودات المستخدم الحالي ──────────────────────────────────────────────
  Stream<List<Map<String, dynamic>>> getMyDraftsStream() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return Stream.value([]);
    return _db
        .collection('drafts')
        .where('authorId', isEqualTo: user.uid)
        .snapshots()
        .map((snap) => snap.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList());
  }

  // ── حذف رواية ──────────────────────────────────────────────────────────────
  Future<String?> deleteNovel(String novelId) async {
    try {
      await _db.collection('novels').doc(novelId).delete();
      notifyListeners();
      return null;
    } catch (e) {
      return 'حدث خطأ أثناء الحذف: $e';
    }
  }

  // ── تغيير حالة رواية ───────────────────────────────────────────────────────
  Future<String?> setNovelStatus(String novelId, String status) async {
    try {
      await _db.collection('novels').doc(novelId).update({'status': status});
      return null;
    } catch (e) {
      return 'حدث خطأ: $e';
    }
  }

  // ── تغيير دور مستخدم ───────────────────────────────────────────────────────
  Future<String?> setUserRole(String userId, String role) async {
    try {
      await _db.collection('users').doc(userId).update({'role': role});
      return null;
    } catch (e) {
      return 'حدث خطأ: $e';
    }
  }

  // ── تفعيل/تعطيل حساب مستخدم ────────────────────────────────────────────────
  Future<String?> setUserActive(String userId, bool isActive) async {
    try {
      await _db.collection('users').doc(userId).update({'isActive': isActive});
      return null;
    } catch (e) {
      return 'حدث خطأ: $e';
    }
  }

  // ── حذف مسودة ──────────────────────────────────────────────────────────────
  Future<String?> deleteDraft(String draftId) async {
    try {
      await _db.collection('drafts').doc(draftId).delete();
      return null;
    } catch (e) {
      return 'حدث خطأ: $e';
    }
  }

  // ── إرسال طلب دعم ──────────────────────────────────────────────────────────
  Future<String?> sendSupportRequest({
    required String title,
    required String type,
    required String description,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return 'يجب تسجيل الدخول أولاً';
      await _db.collection('support_requests').add({
        'title': title,
        'type': type,
        'description': description,
        'authorId': user.uid,
        'authorEmail': user.email,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });
      return null;
    } catch (e) {
      return 'حدث خطأ: $e';
    }
  }

  // ── معالجة طلب دعم (أدمن) ──────────────────────────────────────────────────
  Future<String?> resolveSupportRequest(
    String requestId,
    String status,
    String response,
    String adminId,
    String adminName,
  ) async {
    try {
      await _db.collection('support_requests').doc(requestId).update({
        'status': status,
        'response': response,
        'resolvedBy': adminId,
        'resolvedByName': adminName,
        'resolvedAt': FieldValue.serverTimestamp(),
      });
      return null;
    } catch (e) {
      return 'حدث خطأ: $e';
    }
  }

  // ── إشعار المؤلف بإعجاب ────────────────────────────────────────────────────
  Future<void> notifyAuthorOfLike(
    String authorId,
    String novelTitle,
    String likerName,
  ) async {
    try {
      await _db.collection('notifications').add({
        'userId': authorId,
        'type': 'like',
        'message': '$likerName أعجب برواية "$novelTitle" ❤️',
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }

  // ── إشعار المؤلف بتعليق ────────────────────────────────────────────────────
  Future<void> notifyAuthorOfComment(
    String authorId,
    String novelTitle,
    String commenterName,
  ) async {
    try {
      await _db.collection('notifications').add({
        'userId': authorId,
        'type': 'comment',
        'message': '$commenterName علّق على "$novelTitle" 💬',
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }

  // ── إشعار المؤلف بتقييم ────────────────────────────────────────────────────
  Future<void> notifyAuthorOfRating(
    String authorId,
    String novelTitle,
    String chapterTitle,
    String raterName,
  ) async {
    try {
      await _db.collection('notifications').add({
        'userId': authorId,
        'type': 'rating',
        'message': '$raterName قيّم فصل "$chapterTitle" في "$novelTitle" ⭐',
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }
}