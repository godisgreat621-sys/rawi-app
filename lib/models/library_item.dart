import 'novel_model.dart';

class LibraryItem {
  final String id;
  final String title;
  final String author;
  final String authorId;
  final String category;
  final String? description;
  final String? coverUrl;
  final double? rating;
  final int? likes;
  final int? readers;
  final int? chaptersCount;
  final String? status; // 'active' | 'completed' | 'draft'
  final bool isDraft;
  final String? chapterTitle; // For drafts that are chapters
  final String? novelIdForChapterDraft; // For drafts that are chapters

  LibraryItem({
    required this.id,
    required this.title,
    required this.author,
    required this.authorId,
    required this.category,
    this.description,
    this.coverUrl,
    this.rating,
    this.likes,
    this.readers,
    this.chaptersCount,
    this.status,
    required this.isDraft,
    this.chapterTitle,
    this.novelIdForChapterDraft,
  });

  factory LibraryItem.fromNovel(Novel novel) {
    return LibraryItem(
      id: novel.id,
      title: novel.title,
      author: novel.author,
      authorId: novel.authorId,
      category: novel.category,
      description: novel.description,
      coverUrl: novel.coverUrl,
      rating: novel.rating,
      likes: novel.likes,
      readers: novel.readers,
      chaptersCount: novel.chaptersCount,
      status: novel.status,
      isDraft: false,
    );
  }

  factory LibraryItem.fromDraft(Map<String, dynamic> draftData, String draftId) {
    final bool isNewNovel = draftData['isNewNovel'] ?? true;
    return LibraryItem(
      id: draftId,
      title: isNewNovel ? (draftData['novelTitle'] ?? 'مسودة رواية') : (draftData['chapterTitle'] ?? 'مسودة فصل'),
      author: draftData['authorName'] ?? 'أنت', // Assuming current user is the author
      authorId: draftData['authorId'] ?? '',
      category: draftData['category'] ?? 'عام',
      description: draftData['description'],
      coverUrl: draftData['coverUrl'],
      status: 'draft',
      isDraft: true,
      chapterTitle: isNewNovel ? null : (draftData['chapterTitle'] ?? 'مسودة فصل'),
      novelIdForChapterDraft: isNewNovel ? null : draftData['novelId'],
    );
  }
}