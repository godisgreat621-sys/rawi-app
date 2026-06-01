import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/novel_model.dart';
import '../models/library_item.dart'; // New import
import 'package:rxdart/rxdart.dart'; // New import for combining streams

class NovelsProvider with ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ── جلب اسم المستخدم من Firestore ──────────────────────────────────────────
  Future<String> _getDisplayName(String uid) async {
    try {
      final doc = await _db.collection('users').doc(uid).get();
      final data = doc.data();
      final name = data?['displayName'] ?? '';
      if (name.toString().trim().isNotEmpty) return name.toString().trim();
      // fallback: الجزء الأول من البريد
      final email = FirebaseAuth.instance.currentUser?.email ?? '';
      return email.split('@').first;
    } catch (_) {
      return FirebaseAuth.instance.currentUser?.email?.split('@').first ?? 'كاتب';
    }
  }

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

      // ← جلب الاسم الحقيقي أولاً
      final authorName = await _getDisplayName(user.uid);

      final novelRef = await _db.collection('novels').add({
        'title':       title,
        'description': description,
        'category':    category,
        'coverUrl':    coverUrl,
        'authorId':    user.uid,
        'authorName':  authorName,        // ← الاسم الحقيقي
        'authorEmail': user.email ?? '',
        'rating':      0.0,
        'likes':       0,
        'readers':     0,
        'chaptersCount': 1,
        'status':      'ongoing',
        'createdAt':   FieldValue.serverTimestamp(),
      });

      await novelRef.collection('chapters').add({
        'title':         chapterTitle.isEmpty ? 'الفصل الأول' : chapterTitle,
        'content':       chapterContent,
        'chapterNumber': 1,
        'isDraft':       false,
        'wordCount':     wordCount,
        'rating':        0.0,
        'ratingsCount':  0,
        'createdAt':     FieldValue.serverTimestamp(),
      });

      // ← تحديث lastPublished فقط، بدون مسح ratingsGiven
      await _db.collection('users').doc(user.uid).set({
        'lastPublished':              FieldValue.serverTimestamp(),
        'lastChapterRatingsReceived': 0,
        'lastChapterId':              novelRef.id,
      }, SetOptions(merge: true));

      // إشعار المتابعين
      _notifyFollowers(user.uid, title, authorName, isNew: true); // تم تنظيف النصوص بالداخل

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

      final novelRef     = _db.collection('novels').doc(novelId);
      final chaptersSnap = await novelRef.collection('chapters').get();
      final nextNumber   = chaptersSnap.docs.length + 1;

      final chapterRef = await novelRef.collection('chapters').add({
        'title':         chapterTitle.isEmpty ? 'الفصل $nextNumber' : chapterTitle,
        'content':       chapterContent,
        'chapterNumber': nextNumber,
        'isDraft':       false,
        'wordCount':     wordCount,
        'rating':        0.0,
        'ratingsCount':  0,
        'createdAt':     FieldValue.serverTimestamp(),
      });

      await novelRef.update({'chaptersCount': nextNumber});

      // ← تحديث lastPublished فقط، بدون مسح ratingsGiven
      await _db.collection('users').doc(user.uid).set({
        'lastPublished':              FieldValue.serverTimestamp(),
        'lastChapterRatingsReceived': 0,
        'lastChapterId':              chapterRef.id,
      }, SetOptions(merge: true));

      // إشعار المتابعين بفصل جديد
      _notifyFollowers(user.uid, '', '', novelId: novelId);

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

      final data       = draftDoc.data()!;
      final isNewNovel = data['isNewNovel'] ?? true;

      String? error;
      if (isNewNovel) {
        error = await addNovel(
          title:          data['novelTitle'] ?? '',
          description:    data['description'] ?? '',
          category:       data['category'] ?? 'عام',
          chapterTitle:   data['chapterTitle'] ?? '',
          chapterContent: data['chapterContent'] ?? '',
          wordCount:      data['wordCount'] ?? 0,
          coverUrl:       data['coverUrl'],
        );
      } else {
        error = await addChapter(
          novelId:        data['novelId'] ?? '',
          chapterTitle:   data['chapterTitle'] ?? '',
          chapterContent: data['chapterContent'] ?? '',
          wordCount:      data['wordCount'] ?? 0,
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
    final snap   = await _db
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

  // ── Stream لجلب كل الروايات والمسودات للمستخدم الحالي ────────────────────────
  Stream<List<LibraryItem>> getMyLibraryItemsStream() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return Stream.value([]);

    final novelsStream = _db
        .collection('novels')
        .where('authorId', isEqualTo: user.uid)
        .snapshots()
        .map((snap) => snap.docs.map((d) => LibraryItem.fromNovel(Novel.fromFirestore(d))).toList());

    final draftsStream = _db
        .collection('drafts')
        .where('authorId', isEqualTo: user.uid)
        .snapshots()
        .map((snap) => snap.docs.map((doc) => LibraryItem.fromDraft(doc.data() as Map<String, dynamic>, doc.id)).toList());

    return Rx.combineLatest2(novelsStream, draftsStream, (List<LibraryItem> novels, List<LibraryItem> drafts) {
      final allItems = [...novels, ...drafts];
      // Sort by creation/update time, drafts should probably appear first or by their updated time
      allItems.sort((a, b) {
        // For simplicity, sort by title for now. A more robust sorting would involve timestamps.
        // If a more precise sorting by last activity (creation/update) is needed,
        // the LibraryItem model would need to store these timestamps.
        return a.title.compareTo(b.title);
      });
      return allItems;
    });
  }

  // ── جلب مسودات المستخدم الحالي ──────────────────────────────────────────────
  Stream<List<Map<String, dynamic>>> getMyDraftsStream() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return Stream.value([]);
    return _db
        .collection('drafts')
        .where('authorId', isEqualTo: user.uid)
        .snapshots()
        .map((snap) =>
            snap.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList());
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
        'title':       title,
        'type':        type,
        'description': description,
        'authorId':    user.uid,
        'authorEmail': user.email,
        'status':      'pending',
        'createdAt':   FieldValue.serverTimestamp(),
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
        'status':          status,
        'response':        response,
        'resolvedBy':      adminId,
        'resolvedByName':  adminName,
        'resolvedAt':      FieldValue.serverTimestamp(),
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
    String novelId,
  ) async {
    try {
      await _db.collection('notifications').add({
        'userId':    authorId,
        'type':      'like',
        'message':   '$likerName أعجب برواية "$novelTitle"',
        'novelId':   novelId,
        'isRead':    false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }

  // ── إشعار المؤلف بتعليق ────────────────────────────────────────────────────
  Future<void> notifyAuthorOfComment(
    String authorId,
    String novelTitle,
    String commenterName,
    String novelId,
  ) async {
    try {
      await _db.collection('notifications').add({
        'userId':    authorId,
        'type':      'comment',
        'message':   '$commenterName علّق على "$novelTitle"',
        'novelId':   novelId,
        'isRead':    false,
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
    String novelId,
    String chapterId,
  ) async {
    try {
      await _db.collection('notifications').add({
        'userId':    authorId,
        'type':      'rating',
        'message':   '$raterName قيّم فصل "$chapterTitle" في "$novelTitle"',
        'novelId':   novelId,
        'chapterId': chapterId,
        'isRead':    false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }

  // إشعار المتابعين بنشر جديد
  Future<void> _notifyFollowers(String authorId, String title, String authorName, {bool isNew = false, String? novelId}) async {
    final followers = await _db.collection('users').doc(authorId).collection('followers').get();
    if (followers.docs.isEmpty) return;

    String message = isNew 
      ? 'نشر $authorName رواية جديدة: "$title"'
      : 'تم نشر فصل جديد في رواية تتابعها';

    for (var doc in followers.docs) {
      await _db.collection('notifications').add({
        'userId': doc.id,
        'type': 'follow_post',
        'message': message,
        'novelId': novelId,
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  }

  // إشعار بالرد على تعليق
  Future<void> notifyUserOfReply(String originalCommentId, String novelTitle, String replierName, String replyText, String novelId) async {
    try {
      final commentSnap = await _db.collectionGroup('comments').where(FieldPath.documentId, isEqualTo: originalCommentId).get();
      if (commentSnap.docs.isEmpty) return;
      
      final originalAuthorId = commentSnap.docs.first.data()['authorId'];
      if (originalAuthorId == FirebaseAuth.instance.currentUser?.uid) return;

      await _db.collection('notifications').add({
        'userId': originalAuthorId,
        'type': 'comment',
        'message': '$replierName رد على تعليقك في "$novelTitle": "${replyText.substring(0, replyText.length > 20 ? 20 : replyText.length)}..."',
        'novelId': novelId,
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }

  // ── نظام المتابعة مع التحديث التلقائي للعدادات ──────────────────────────────
  Future<void> toggleFollow(String targetAuthorId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.uid == targetAuthorId) return;

    final followingRef = _db.collection('users').doc(user.uid).collection('following').doc(targetAuthorId);
    final followersRef = _db.collection('users').doc(targetAuthorId).collection('followers').doc(user.uid);
    final myDocRef     = _db.collection('users').doc(user.uid);
    final targetDocRef = _db.collection('users').doc(targetAuthorId);

    final doc = await followingRef.get();
    final batch = _db.batch();

    if (doc.exists) {
      batch.delete(followingRef);
      batch.delete(followersRef);
      batch.update(myDocRef, {'followingCount': FieldValue.increment(-1)});
      batch.update(targetDocRef, {'followersCount': FieldValue.increment(-1)});
    } else {
      batch.set(followingRef, {'followedAt': FieldValue.serverTimestamp()});
      batch.set(followersRef, {'followedAt': FieldValue.serverTimestamp()});
      batch.update(myDocRef, {'followingCount': FieldValue.increment(1)});
      batch.update(targetDocRef, {'followersCount': FieldValue.increment(1)});
      
      // إرسال إشعار للمؤلف
      await _db.collection('notifications').add({
        'userId': targetAuthorId,
        'type': 'follow',
        'message': 'لديك متابع جديد!',
        'senderId': user.uid,
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
    notifyListeners();
  }

  // ── نظام الإشارات المرجعية (القراءة لاحقاً) ──────────────────────────────────
  Future<void> toggleBookmark(String novelId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final ref = _db.collection('users').doc(user.uid).collection('bookmarks').doc(novelId);
    final doc = await ref.get();
    if (doc.exists) {
      await ref.delete();
    } else {
      await ref.set({'bookmarkedAt': FieldValue.serverTimestamp()});
    }
    notifyListeners();
  }

  Stream<bool> isBookmarked(String novelId) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return Stream.value(false);
    return _db
        .collection('users').doc(user.uid)
        .collection('bookmarks').doc(novelId)
        .snapshots()
        .map((snap) => snap.exists);
  }

  // Stream لجلب الروايات المحفوظة فقط
  Stream<List<Novel>> getBookmarkedNovelsStream() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return Stream.value([]);

    return _db.collection('users').doc(user.uid).collection('bookmarks').snapshots().asyncMap((snap) async {
      List<Novel> bookmarked = [];
      for (var doc in snap.docs) {
        final novelDoc = await _db.collection('novels').doc(doc.id).get();
        if (novelDoc.exists) bookmarked.add(Novel.fromFirestore(novelDoc));
      }
      return bookmarked;
    });
  }
}