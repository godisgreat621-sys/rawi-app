import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/novel_model.dart';

class NovelsProvider with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const int _requiredPublishPoints = 10;

  List<Novel> _novels = [];
  bool _isLoading = false;

  List<Novel> get novels => _novels;
  bool get isLoading => _isLoading;

  // ─── جلب كل الروايات المنشورة ───────────────────────────────────────────────
  Stream<List<Novel>> getNovelsStream() {
    return _firestore
        .collection('novels')
        .where('status', isEqualTo: 'active')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Novel.fromFirestore(doc)).toList());
  }

  // ─── التحقق من تكرار العنوان (الكاتب نفسه + كل المنصة) ─────────────────────
  Future<String?> checkTitleUniqueness(String title, {String? excludeNovelId}) async {
    final normalized = _normalizeTitle(title);
    final user = FirebaseAuth.instance.currentUser;

    // 1. تحقق من عناوين الكاتب السابقة المحفوظة
    if (user != null) {
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      final usedTitles = List<String>.from(userDoc.data()?['usedTitles'] ?? []);
      if (usedTitles.any((t) => _normalizeTitle(t) == normalized)) {
        return 'استخدمت هذا العنوان من قبل، اختر عنواناً مختلفاً';
      }
    }

    // 2. تحقق من كل روايات المنصة
    final allNovels = await _firestore.collection('novels').get();
    for (final doc in allNovels.docs) {
      if (excludeNovelId != null && doc.id == excludeNovelId) continue;
      final existingTitle = doc.data()['title'] ?? '';
      if (_normalizeTitle(existingTitle) == normalized) {
        return 'يوجد رواية بهذا الاسم على المنصة، اختر عنواناً مختلفاً';
      }
    }

    return null; // لا يوجد تكرار
  }

  // ─── تطبيع العنوان للمقارنة (إزالة مسافات + توحيد الأحرف) ──────────────────
  String _normalizeTitle(String title) {
    return title
        .trim()
        .replaceAll(RegExp(r'\s+'), '')
        .replaceAll('أ', 'ا')
        .replaceAll('إ', 'ا')
        .replaceAll('آ', 'ا')
        .replaceAll('ة', 'ه')
        .replaceAll('ى', 'ي')
        .toLowerCase();
  }

  // ─── التحقق من شروط النشر ───────────────────────────────────────────────────
  Future<Map<String, dynamic>> checkPublishingRequirements({
    required bool isFirstChapter,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return {'canPublish': false, 'reason': 'يجب تسجيل الدخول أولاً'};

    final userDoc = await _firestore.collection('users').doc(user.uid).get();
    if (!userDoc.exists) return {'canPublish': true};

    final data = userDoc.data()!;
    final points = (data['points'] ?? 0) as int;
    if (points < _requiredPublishPoints) {
      return {
        'canPublish': false,
        'reason': 'يتطلب نشر فصل رصيد $_requiredPublishPoints نقاط، لديك $points فقط.'
      };
    }

    // الفصل الأول لا يخضع لشروط التقييم
    if (!isFirstChapter) {
      // شرط 1: 24 ساعة بين كل نشر
      final lastPublished = data['lastPublished'] as Timestamp?;
      if (lastPublished != null) {
        final diff = DateTime.now().difference(lastPublished.toDate());
        if (diff.inHours < 24) {
          final remaining = 24 - diff.inHours;
          return {
            'canPublish': false,
            'reason': 'يجب الانتظار $remaining ساعة قبل نشر فصل جديد ⏳'
          };
        }
      }

      // شرط 2: قيّم 3 فصول لكتّاب آخرين
      final ratingsGiven = (data['ratingsGiven'] ?? 0) as int;
      if (ratingsGiven < 3) {
        return {
          'canPublish': false,
          'reason': 'يجب تقييم ${3 - ratingsGiven} فصل لكتّاب آخرين أولاً 📖'
        };
      }

      // شرط 3: حصل على 3 تقييمات على فصله السابق
      final lastChapterRatings = (data['lastChapterRatingsReceived'] ?? 0) as int;
      if (lastChapterRatings < 3) {
        return {
          'canPublish': false,
          'reason': 'فصلك السابق يحتاج ${3 - lastChapterRatings} تقييم إضافي ⭐'
        };
      }
    }

    // التحقق: ليس لديه رواية نشطة (للروايات الجديدة فقط)
    if (isFirstChapter) {
      final activeNovel = await _firestore
          .collection('novels')
          .where('authorId', isEqualTo: user.uid)
          .where('status', isEqualTo: 'active')
          .limit(1)
          .get();
      if (activeNovel.docs.isNotEmpty) {
        return {
          'canPublish': false,
          'reason': 'يجب إكمال روايتك الحالية قبل بدء رواية جديدة 📚'
        };
      }
    }

    return {'canPublish': true};
  }

  // ─── نشر رواية جديدة (مع فصلها الأول) ──────────────────────────────────────
  Future<String?> addNovel({
    required String title,
    required String description,
    required String category,
    required String chapterTitle,
    required String chapterContent,
    required int wordCount,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return 'يجب تسجيل الدخول أولاً';

    // التحقق من تفرد العنوان
    final titleError = await checkTitleUniqueness(title);
    if (titleError != null) return titleError;

    // التحقق من شروط النشر
    final check = await checkPublishingRequirements(isFirstChapter: true);
    if (!check['canPublish']) return check['reason'];

    try {
      // جلب اسم المستخدم
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      final displayName = userDoc.exists
          ? (userDoc.data()?['displayName'] ?? user.displayName ?? user.email)
          : (user.displayName ?? user.email);

      // إنشاء الرواية
      final novelRef = await _firestore.collection('novels').add({
        'title': title,
        'description': description,
        'category': category,
        'authorId': user.uid,
        'authorEmail': user.email,
        'authorName': displayName,
        'rating': 0.0,
        'likes': 0,
        'readers': 0,
        'chaptersCount': 1,
        'titleChanged': false,
        'status': 'active', // active | completed
        'createdAt': FieldValue.serverTimestamp(),
      });

      // إنشاء الفصل الأول
      final chapterRef = await novelRef.collection('chapters').add({
        'title': chapterTitle,
        'content': chapterContent,
        'wordCount': wordCount,
        'chapterNumber': 1,
        'rating': 0.0,
        'ratingsCount': 0,
        'isDraft': false,
        'authorId': user.uid,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // حفظ العنوان في سجل الكاتب + تحديث بيانات النشر
      await _firestore.collection('users').doc(user.uid).set({
        'lastPublished': FieldValue.serverTimestamp(),
        'lastChapterId': chapterRef.id,
        'lastNovelId': novelRef.id,
        'lastChapterRatingsReceived': 0,
        'ratingsGiven': 0,
        'usedTitles': FieldValue.arrayUnion([title]),
      }, SetOptions(merge: true));

      await _notifyFollowers(user.uid, 'رواية جديدة منشورة', '$displayName نشر رواية جديدة: "$title"');
      notifyListeners();
      return null;
    } catch (e) {
      return 'حدث خطأ أثناء النشر، حاول مرة أخرى';
    }
  }

  // ─── نشر فصل جديد لرواية موجودة ─────────────────────────────────────────────
  Future<String?> addChapter({
    required String novelId,
    required String chapterTitle,
    required String chapterContent,
    required int wordCount,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return 'يجب تسجيل الدخول أولاً';

    // التحقق من شروط النشر
    final check = await checkPublishingRequirements(isFirstChapter: false);
    if (!check['canPublish']) return check['reason'];

    try {
      final novelRef = _firestore.collection('novels').doc(novelId);

      // حساب رقم الفصل
      final chaptersSnap = await novelRef.collection('chapters').get();
      final chapterNumber = chaptersSnap.docs.length + 1;

      // إضافة الفصل
      final chapterRef = await novelRef.collection('chapters').add({
        'title': chapterTitle,
        'content': chapterContent,
        'wordCount': wordCount,
        'chapterNumber': chapterNumber,
        'rating': 0.0,
        'ratingsCount': 0,
        'isDraft': false,
        'authorId': user.uid,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // تحديث عداد الفصول
      await novelRef.update({'chaptersCount': FieldValue.increment(1)});

      // تحديث بيانات المستخدم
      await _firestore.collection('users').doc(user.uid).set({
        'lastPublished': FieldValue.serverTimestamp(),
        'lastChapterId': chapterRef.id,
        'lastChapterRatingsReceived': 0,
        'ratingsGiven': 0,
      }, SetOptions(merge: true));

      final novelDoc = await novelRef.get();
      final novelTitle = (novelDoc.data()?['title'] ?? '') as String;
      final authorName = (novelDoc.data()?['authorName'] ?? '') as String;
      await _notifyFollowers(user.uid, 'فصل جديد متاح', '$authorName نشر فصلًا جديدًا في "$novelTitle"');
      notifyListeners();
      return null;
    } catch (e) {
      return 'حدث خطأ أثناء النشر، حاول مرة أخرى';
    }
  }

  // ─── إعلان اكتمال الرواية ────────────────────────────────────────────────────
  Future<void> completeNovel(String novelId) async {
    await _firestore.collection('novels').doc(novelId).update({
      'status': 'completed',
      'completedAt': FieldValue.serverTimestamp(),
    });
    notifyListeners();
  }

  Future<String?> saveDraft({
    String? draftId,
    required bool isNewNovel,
    required String novelTitle,
    String? description,
    required String category,
    required String chapterTitle,
    required String chapterContent,
    required int wordCount,
    String? novelId,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return 'يجب تسجيل الدخول أولاً';

    try {
      final draftData = {
        'authorId': user.uid,
        'authorName': user.displayName ?? user.email ?? 'مستخدم',
        'authorEmail': user.email,
        'isNewNovel': isNewNovel,
        'novelId': novelId,
        'novelTitle': novelTitle,
        'description': description ?? '',
        'category': category,
        'chapterTitle': chapterTitle,
        'chapterContent': chapterContent,
        'wordCount': wordCount,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (draftId != null) {
        await _firestore.collection('drafts').doc(draftId).set(draftData, SetOptions(merge: true));
      } else {
        await _firestore.collection('drafts').add({
          ...draftData,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      return null;
    } catch (e) {
      return 'حدث خطأ أثناء حفظ المسودة، حاول مرة أخرى';
    }
  }

  Future<String?> deleteDraft(String draftId) async {
    try {
      await _firestore.collection('drafts').doc(draftId).delete();
      return null;
    } catch (e) {
      return 'حدث خطأ أثناء حذف المسودة.';
    }
  }

  Future<String?> publishDraft(String draftId) async {
    final draftDoc = await _firestore.collection('drafts').doc(draftId).get();
    if (!draftDoc.exists) return 'المسودة غير موجودة.';

    final data = draftDoc.data() as Map<String, dynamic>;
    final isNewNovel = data['isNewNovel'] == true;

    String? error;
    if (isNewNovel) {
      error = await addNovel(
        title: data['novelTitle'] ?? '',
        description: data['description'] ?? '',
        category: data['category'] ?? 'عام',
        chapterTitle: data['chapterTitle'] ?? '',
        chapterContent: data['chapterContent'] ?? '',
        wordCount: (data['wordCount'] ?? 0) as int,
      );
    } else {
      final linkedNovelId = data['novelId'] as String?;
      if (linkedNovelId == null || linkedNovelId.isEmpty) {
        return 'مسودة الفصل لا تحتوي على رواية مرتبطة.';
      }
      error = await addChapter(
        novelId: linkedNovelId,
        chapterTitle: data['chapterTitle'] ?? '',
        chapterContent: data['chapterContent'] ?? '',
        wordCount: (data['wordCount'] ?? 0) as int,
      );
    }

    if (error != null) return error;
    await deleteDraft(draftId);
    return null;
  }

  Future<void> _createNotification(String userId, Map<String, dynamic> payload) async {
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('notifications')
        .add({
      ...payload,
      'isRead': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _notifyFollowers(String authorId, String title, String body) async {
    final followersSnapshot = await _firestore
        .collection('users')
        .doc(authorId)
        .collection('followers')
        .get();
    for (final follower in followersSnapshot.docs) {
      if (follower.id == authorId) continue;
      await _createNotification(follower.id, {'title': title, 'body': body});
    }
  }

  Future<void> notifyAuthorOfRating(String authorId, String novelTitle, String chapterTitle, String raterName) async {
    await _createNotification(authorId, {
      'title': 'حصل فصلك على تقييم جديد',
      'body': '$raterName قيّم الفصل "$chapterTitle" في "$novelTitle"',
    });
  }

  Future<void> notifyAuthorOfLike(String authorId, String novelTitle, String likerName) async {
    await _createNotification(authorId, {
      'title': 'حصلت روايتك على إعجاب',
      'body': '$likerName أعجب برواية "$novelTitle"',
    });
  }

  Future<void> notifyAuthorOfComment(String authorId, String novelTitle, String commenterName) async {
    await _createNotification(authorId, {
      'title': 'تعليق جديد على روايتك',
      'body': '$commenterName أضاف تعليقاً على رواية "$novelTitle"',
    });
  }

  Future<String?> sendSupportRequest({
    required String type,
    required String title,
    required String description,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return 'يجب تسجيل الدخول أولاً';

    try {
      await _firestore.collection('support_requests').add({
        'authorId': user.uid,
        'authorName': user.displayName ?? user.email ?? 'مستخدم',
        'authorEmail': user.email,
        'type': type,
        'title': title,
        'description': description,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });
      return null;
    } catch (e) {
      return 'حدث خطأ أثناء إرسال طلب الدعم.';
    }
  }

  Future<String?> resolveSupportRequest(
    String requestId,
    String status,
    String response,
    String adminId,
    String adminName,
  ) async {
    try {
      final requestRef = _firestore.collection('support_requests').doc(requestId);
      final requestDoc = await requestRef.get();
      if (!requestDoc.exists) return 'الطلب غير موجود.';

      final requestData = requestDoc.data() as Map<String, dynamic>;
      await requestRef.update({
        'status': status,
        'response': response,
        'adminId': adminId,
        'adminName': adminName,
        'respondedAt': FieldValue.serverTimestamp(),
      });

      final authorId = requestData['authorId'] as String?;
      if (authorId != null && authorId.isNotEmpty) {
        await _createNotification(authorId, {
          'title': 'تم تحديث طلب الدعم الخاص بك',
          'body': response,
        });
      }
      return null;
    } catch (e) {
      return 'حدث خطأ أثناء معالجة الطلب.';
    }
  }

  // ─── التحقق من التشابه في المحتوى (منع النسخ) ───────────────────────────────
  Future<bool> isContentDuplicate(String content) async {
    final first200 = content.split(RegExp(r'\s+')).take(200).join(' ');
    final allChapters = await _firestore.collectionGroup('chapters').get();

    for (final doc in allChapters.docs) {
      final existingContent = doc.data()['content'] ?? '';
      final existing200 = existingContent.split(RegExp(r'\s+')).take(200).join(' ');
      final similarity = _calculateSimilarity(first200, existing200);
      if (similarity > 0.8) return true;
    }
    return false;
  }

  double _calculateSimilarity(String a, String b) {
    if (a.isEmpty || b.isEmpty) return 0;
    final wordsA = a.split(RegExp(r'\s+')).toSet();
    final wordsB = b.split(RegExp(r'\s+')).toSet();
    final intersection = wordsA.intersection(wordsB).length;
    final union = wordsA.union(wordsB).length;
    return union == 0 ? 0 : intersection / union;
  }
}