import 'package:cloud_firestore/cloud_firestore.dart';

class Novel {
  final String id;
  final String title;
  final String author;
  final String authorId;
  final String category;
  final String description;
  final String content;
  final String? coverUrl;
  final double rating;
  final int likes;
  final int readers;
  final int chaptersCount;
  final bool titleChanged;
  final String status; // 'active' | 'completed'

  Novel({
    required this.id,
    required this.title,
    required this.author,
    required this.authorId,
    required this.category,
    this.description = '',
    this.coverUrl,
    this.content = '',
    this.rating = 0.0,
    this.likes = 0,
    this.readers = 0,
    this.chaptersCount = 0,
    this.titleChanged = false,
    this.status = 'active',
  });

  factory Novel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Novel(
      id: doc.id,
      title: data['title'] ?? '',
      author: data['authorName'] ?? data['authorEmail'] ?? 'كاتب مجهول',
      authorId: data['authorId'] ?? '',
      category: data['category'] ?? 'عام',
      description: data['description'] ?? '',
      coverUrl: data['coverUrl'],
      content: data['content'] ?? '',
      rating: (data['rating'] ?? 0.0).toDouble(),
      likes: (data['likes'] ?? 0).toInt(),
      readers: (data['readers'] ?? 0).toInt(),
      chaptersCount: (data['chaptersCount'] ?? 0).toInt(),
      titleChanged: data['titleChanged'] ?? false,
      status: data['status'] ?? 'active',
    );
  }
}

// ─── موديل الفصل ─────────────────────────────────────────────────────────────
class Chapter {
  final String id;
  final String novelId;
  final String title;
  final String content;
  final int wordCount;
  final int chapterNumber;
  final double rating;
  final int ratingsCount;
  final bool isDraft;
  final DateTime? createdAt;

  Chapter({
    required this.id,
    required this.novelId,
    required this.title,
    required this.content,
    required this.wordCount,
    required this.chapterNumber,
    this.rating = 0.0,
    this.ratingsCount = 0,
    this.isDraft = false,
    this.createdAt,
  });

  factory Chapter.fromFirestore(DocumentSnapshot doc, String novelId) {
    final data = doc.data() as Map<String, dynamic>;
    return Chapter(
      id: doc.id,
      novelId: novelId,
      title: data['title'] ?? '',
      content: data['content'] ?? '',
      wordCount: (data['wordCount'] ?? 0) as int,
      chapterNumber: (data['chapterNumber'] ?? 0) as int,
      rating: (data['rating'] ?? 0.0).toDouble(),
      ratingsCount: (data['ratingsCount'] ?? 0) as int,
      isDraft: data['isDraft'] ?? false,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}
