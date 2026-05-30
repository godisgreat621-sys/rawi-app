import 'package:cloud_firestore/cloud_firestore.dart';

class Novel {
  final String id;
  final String title;
  final String author;
  final String authorId;
  final String category;
  final String description;
  final String content;
  final double rating;
  final int likes;
  final int readers;
  final String status;

  Novel({
    required this.id,
    required this.title,
    required this.author,
    required this.authorId,
    required this.category,
    this.description = '',
    this.content = '',
    this.rating = 0.0,
    this.likes = 0,
    this.readers = 0,
    this.status = 'منشورة',
  });

  // تحويل من Firestore إلى Novel
  factory Novel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Novel(
      id: doc.id,
      title: data['title'] ?? '',
      author: data['authorEmail'] ?? 'كاتب مجهول',
      authorId: data['authorId'] ?? '',
      category: data['category'] ?? 'عام',
      description: data['description'] ?? '',
      content: data['content'] ?? '',
      rating: (data['rating'] ?? 0.0).toDouble(),
      likes: data['likes'] ?? 0,
      readers: data['readers'] ?? 0,
    );
  }
}