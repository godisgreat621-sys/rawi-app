import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/novel_model.dart';

class NovelsProvider with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  List<Novel> _novels = [];
  bool _isLoading = false;

  List<Novel> get novels => _novels;
  bool get isLoading => _isLoading;

  // جلب كل الروايات من Firestore
  Stream<List<Novel>> getNovelsStream() {
    return _firestore
        .collection('novels')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Novel.fromFirestore(doc))
            .toList());
  }

  // نشر رواية جديدة في Firestore
  Future<void> addNovel(String title, String description, String content, String category) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await _firestore.collection('novels').add({
      'title': title,
      'description': description,
      'content': content,
      'category': category,
      'authorId': user.uid,
      'authorEmail': user.email,
      'rating': 0.0,
      'likes': 0,
      'readers': 0,
      'createdAt': FieldValue.serverTimestamp(),
    });
    notifyListeners();
  }
}