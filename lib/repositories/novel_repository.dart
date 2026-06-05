import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class NovelRepository {
  static Future<void> saveReadingProgress({
    required String novelId,
    required String chapterId,
    required int secondsRead,
    double? pagePercent,
    double? fontSize,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || novelId.isEmpty) return;

    final ref = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('readingProgress')
        .doc(novelId);

    final data = <String, dynamic>{
      'chapterId': chapterId,
      'secondsRead': secondsRead,
      'pagePercent': pagePercent ?? FieldValue.delete(),
      'fontSize': fontSize ?? FieldValue.delete(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    await ref.set(data, SetOptions(merge: true));
  }

  static Future<String?> saveDraft({
    String? draftId,
    required bool isNewNovel,
    String? novelId,
    required String novelTitle,
    String? description,
    required String chapterTitle,
    required String chapterContent,
    required int wordCount,
    required String category,
    String? coverUrl,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;

    final data = <String, dynamic>{
      'authorId': user.uid,
      'isNewNovel': isNewNovel,
      'novelId': novelId,
      'novelTitle': novelTitle,
      'description': description ?? '',
      'chapterTitle': chapterTitle,
      'chapterContent': chapterContent,
      'wordCount': wordCount,
      'category': category,
      'coverUrl': coverUrl,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    final coll = FirebaseFirestore.instance.collection('drafts');
    if (draftId != null) {
      await coll.doc(draftId).set(data, SetOptions(merge: true));
      return draftId;
    } else {
      final doc = await coll.add(data);
      return doc.id;
    }
  }

  static Future<void> deleteDraft(String draftId) async {
    if (draftId.isEmpty) return;
    await FirebaseFirestore.instance.collection('drafts').doc(draftId).delete();
  }

  static Future<Map<String, dynamic>?> loadDraft(String draftId) async {
    if (draftId.isEmpty) return null;
    final doc = await FirebaseFirestore.instance
        .collection('drafts')
        .doc(draftId)
        .get();
    return doc.exists ? doc.data() as Map<String, dynamic> : null;
  }

  static Future<Map<String, dynamic>?> getReadingProgress(
    String novelId,
  ) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || novelId.isEmpty) return null;
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('readingProgress')
        .doc(novelId)
        .get();
    return doc.exists ? doc.data() as Map<String, dynamic> : null;
  }
}