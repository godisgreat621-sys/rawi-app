import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:my_first_app/views/home/novel_reader_screen.dart';
import 'package:my_first_app/views/writer/add_novel_screen.dart';
import 'package:my_first_app/views/author_screen.dart';

class NovelDetailScreen extends StatefulWidget {
  final Map<String, dynamic> novel;
  const NovelDetailScreen({super.key, required this.novel});

  @override
  State<NovelDetailScreen> createState() => _NovelDetailScreenState();
}

class _NovelDetailScreenState extends State<NovelDetailScreen> {
  bool _isFollowing = false;
  bool _isFollowLoading = false;
  int _userRating = 0;
  bool _isRatingLoading = false;

  @override
  void initState() {
    super.initState();
    _checkIfFollowing();
    _loadUserRating();
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // متابعة
  // ─────────────────────────────────────────────────────────────────────────────
  Future<void> _checkIfFollowing() async {
    final user = FirebaseAuth.instance.currentUser;
    final authorId = widget.novel['authorId'];
    if (user == null || authorId == null || authorId.isEmpty) return;
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('following')
        .doc(authorId)
        .get();
    if (mounted) setState(() => _isFollowing = doc.exists);
  }

  Future<void> _toggleFollow() async {
    final user = FirebaseAuth.instance.currentUser;
    final authorId = widget.novel['authorId'];
    if (user == null || authorId == null || authorId.isEmpty) return;
    if (user.uid == authorId) return;
    setState(() => _isFollowLoading = true);

    final followingRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('following')
        .doc(authorId);
    final followersRef = FirebaseFirestore.instance
        .collection('users')
        .doc(authorId)
        .collection('followers')
        .doc(user.uid);

    if (_isFollowing) {
      await followingRef.delete();
      await followersRef.delete();
    } else {
      await followingRef.set({'followedAt': FieldValue.serverTimestamp()});
      await followersRef.set({'followedAt': FieldValue.serverTimestamp()});
    }
    if (mounted)
      setState(() {
        _isFollowing = !_isFollowing;
        _isFollowLoading = false;
      });
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // تقييم
  // ─────────────────────────────────────────────────────────────────────────────
  Future<void> _loadUserRating() async {
    final user = FirebaseAuth.instance.currentUser;
    final novelId = widget.novel['id'];
    if (user == null || novelId == null) return;
    final doc = await FirebaseFirestore.instance
        .collection('novels')
        .doc(novelId)
        .collection('ratings')
        .doc(user.uid)
        .get();
    if (mounted && doc.exists)
      setState(() => _userRating = (doc.data()?['rating'] ?? 0) as int);
  }

  Future<void> _submitRating(int rating) async {
    final user = FirebaseAuth.instance.currentUser;
    final novelId = widget.novel['id'];
    if (user == null || novelId == null) return;
    setState(() => _isRatingLoading = true);

    final ratingsRef = FirebaseFirestore.instance
        .collection('novels')
        .doc(novelId)
        .collection('ratings');
    await ratingsRef.doc(user.uid).set({
      'rating': rating,
      'ratedAt': FieldValue.serverTimestamp(),
    });

    final all = await ratingsRef.get();
    final total = all.docs.fold<int>(
      0,
      (s, d) => s + ((d.data()['rating'] ?? 0) as int),
    );
    final avg = total / all.docs.length;
    await FirebaseFirestore.instance.collection('novels').doc(novelId).update({
      'rating': double.parse(avg.toStringAsFixed(1)),
    });

    if (mounted) {
      setState(() {
        _userRating = rating;
        _isRatingLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Expanded(
                child: Text(
                  'تم تقييمك بـ $rating نجوم',
                  style: GoogleFonts.cairo(),
                ),
              ),
              const SizedBox(width: 6),
              const Icon(Icons.star, size: 16, color: Colors.amber),
            ],
          ),
          backgroundColor: Colors.amber,
        ),
      );
    }
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // تعديل معلومات الرواية
  // ─────────────────────────────────────────────────────────────────────────────
  void _showEditSheet(Map<String, dynamic> novelData) {
    final theme = Theme.of(context);
    final titleCtrl = TextEditingController(text: widget.novel['title']);
    final descCtrl = TextEditingController(text: widget.novel['description']);
    String selectedCat = widget.novel['category'] ?? 'عام';
    final titleChanged = novelData['titleChanged'] ?? false;
    final readers = (novelData['readers'] ?? 0) as int;
    final canEditTitle = !titleChanged && readers < 10;

    final categories = [
      'عام',
      'فانتازيا',
      'رعب',
      'رومانسية',
      'غموض',
      'تاريخية',
      'خيال علمي',
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          decoration: BoxDecoration(
            color: theme.scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'تعديل الرواية ✏️',
                      style: GoogleFonts.cairo(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),

                // العنوان
                if (canEditTitle) ...[
                  Text(
                    'العنوان (مرة واحدة فقط قبل 10 قراء)',
                    style: GoogleFonts.cairo(
                      fontSize: 12,
                      color: Colors.orange,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: titleCtrl,
                    style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
                    decoration: InputDecoration(
                      hintText: 'عنوان الرواية',
                      hintStyle: GoogleFonts.cairo(color: Colors.grey),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                ] else ...[
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.grey.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.lock_outline,
                          size: 16,
                          color: Colors.grey,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'العنوان مقفل (تم تعديله أو تجاوز 10 قراء)',
                          style: GoogleFonts.cairo(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                ],

                // التصنيف
                Text(
                  'التصنيف',
                  style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 36,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: categories.length,
                    itemBuilder: (_, i) {
                      final cat = categories[i];
                      final sel = cat == selectedCat;
                      return GestureDetector(
                        onTap: () => setS(() => selectedCat = cat),
                        child: Container(
                          margin: const EdgeInsets.only(left: 8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: sel
                                ? theme.colorScheme.primary
                                : Colors.grey.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            cat,
                            style: GoogleFonts.cairo(
                              fontSize: 12,
                              color: sel ? Colors.black : Colors.grey,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 14),

                // الوصف
                Text(
                  'الوصف',
                  style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: descCtrl,
                  maxLines: 3,
                  style: GoogleFonts.cairo(fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'وصف الرواية...',
                    hintStyle: GoogleFonts.cairo(color: Colors.grey),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    contentPadding: const EdgeInsets.all(12),
                  ),
                ),
                const SizedBox(height: 16),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () async {
                      final updates = <String, dynamic>{
                        'description': descCtrl.text.trim(),
                        'category': selectedCat,
                      };
                      if (canEditTitle &&
                          titleCtrl.text.trim() != widget.novel['title']) {
                        updates['title'] = titleCtrl.text.trim();
                        updates['titleChanged'] = true;
                      }
                      await FirebaseFirestore.instance
                          .collection('novels')
                          .doc(widget.novel['id'])
                          .update(updates);
                      if (ctx.mounted) Navigator.pop(ctx);
                    },
                    child: Text(
                      'حفظ التعديلات',
                      style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // تأكيد إكمال الرواية
  // ─────────────────────────────────────────────────────────────────────────────
  Future<void> _confirmComplete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'إعلان اكتمال الرواية ✅',
          style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
        ),
        content: Text(
          'بعد الإعلان لن تتمكن من إضافة فصول جديدة لهذه الرواية، '
          'وستتمكن من نشر رواية جديدة.',
          style: GoogleFonts.cairo(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('إلغاء', style: GoogleFonts.cairo()),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'تأكيد الاكتمال',
              style: GoogleFonts.cairo(
                color: Colors.green,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await FirebaseFirestore.instance
          .collection('novels')
          .doc(widget.novel['id'])
          .update({
            'status': 'completed',
            'completedAt': FieldValue.serverTimestamp(),
          });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'رواية "محتواها مكتملة" الآن ✅',
              style: GoogleFonts.cairo(),
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // حذف الرواية
  // ─────────────────────────────────────────────────────────────────────────────
  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'حذف الرواية',
          style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
        ),
        content: Text(
          'هل أنت متأكد؟ لا يمكن التراجع.',
          style: GoogleFonts.cairo(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('إلغاء', style: GoogleFonts.cairo()),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'حذف',
              style: GoogleFonts.cairo(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await FirebaseFirestore.instance
          .collection('novels')
          .doc(widget.novel['id'])
          .delete();
      if (mounted) Navigator.pop(context);
    }
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Build
  // ─────────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final currentUser = FirebaseAuth.instance.currentUser;
    final authorId = widget.novel['authorId'] ?? '';
    final isOwner = currentUser?.uid == authorId;
    final novelId = widget.novel['id'] ?? '';

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // ── AppBar ──────────────────────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 300,
            pinned: true,
            backgroundColor: theme.scaffoldBackgroundColor,
            leading: CircleAvatar(
              backgroundColor: isDark ? Colors.black54 : Colors.white70,
              child: IconButton(
                icon: Icon(
                  Icons.arrow_back,
                  color: isDark ? Colors.white : Colors.black87,
                ),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            actions: [
              if (isOwner) ...[
                // تعديل
                StreamBuilder<DocumentSnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('novels')
                      .doc(novelId)
                      .snapshots(),
                  builder: (_, snap) {
                    final data = snap.hasData && snap.data!.exists
                        ? snap.data!.data() as Map<String, dynamic>
                        : <String, dynamic>{};
                    return CircleAvatar(
                      backgroundColor: isDark ? Colors.black54 : Colors.white70,
                      child: IconButton(
                        icon: Icon(
                          Icons.edit_outlined,
                          color: theme.colorScheme.primary,
                        ),
                        onPressed: () => _showEditSheet(data),
                      ),
                    );
                  },
                ),
                const SizedBox(width: 8),
                // حذف
                CircleAvatar(
                  backgroundColor: isDark ? Colors.black54 : Colors.white70,
                  child: IconButton(
                    icon: const Icon(
                      Icons.delete_outline,
                      color: Colors.redAccent,
                    ),
                    onPressed: _confirmDelete,
                  ),
                ),
              ],
              const SizedBox(width: 12),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      theme.colorScheme.primary.withOpacity(0.15),
                      theme.scaffoldBackgroundColor,
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: Center(
                  child: Container(
                    width: 140,
                    height: 210,
                    margin: const EdgeInsets.only(top: 40),
                    decoration: BoxDecoration(
                      color: isDark
                          ? theme.colorScheme.surface
                          : Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: isDark ? Colors.black54 : Colors.black12,
                          blurRadius: 15,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Icon(
                        Icons.book_rounded,
                        size: 64,
                        color: theme.colorScheme.primary.withOpacity(0.8),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // ── المحتوى ─────────────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: StreamBuilder<DocumentSnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('novels')
                    .doc(novelId)
                    .snapshots(),
                builder: (_, novelSnap) {
                  final novelData = novelSnap.hasData && novelSnap.data!.exists
                      ? novelSnap.data!.data() as Map<String, dynamic>
                      : <String, dynamic>{};
                  final isCompleted = novelData['status'] == 'completed';

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // تصنيف
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary.withOpacity(
                                0.15,
                              ),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              novelData['category'] ??
                                  widget.novel['category'] ??
                                  'عام',
                              style: GoogleFonts.cairo(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          ),
                          if (isCompleted) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.green.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                'مكتملة ✅',
                                style: GoogleFonts.cairo(
                                  fontSize: 12,
                                  color: Colors.green,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 12),

                      // العنوان
                      Text(
                        novelData['title'] ?? widget.novel['title'] ?? '',
                        style: GoogleFonts.cairo(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),

                      // الكاتب + متابعة
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          GestureDetector(
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => AuthorScreen(
                                  authorId: authorId,
                                  authorName:
                                      widget.novel['author'] ?? 'كاتب مجهول',
                                ),
                              ),
                            ),
                            child: Text(
                              'بقلم: ${widget.novel['author'] ?? 'كاتب مجهول'}',
                              style: GoogleFonts.cairo(
                                fontSize: 14,
                                color: theme.colorScheme.primary,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                          if (!isOwner && authorId.isNotEmpty)
                            _isFollowLoading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : OutlinedButton.icon(
                                    onPressed: _toggleFollow,
                                    icon: Icon(
                                      _isFollowing
                                          ? Icons.person_remove_outlined
                                          : Icons.person_add_outlined,
                                      size: 15,
                                      color: _isFollowing
                                          ? Colors.grey
                                          : theme.colorScheme.primary,
                                    ),
                                    label: Text(
                                      _isFollowing ? 'متابَع' : 'تابع',
                                      style: GoogleFonts.cairo(
                                        fontSize: 12,
                                        color: _isFollowing
                                            ? Colors.grey
                                            : theme.colorScheme.primary,
                                      ),
                                    ),
                                    style: OutlinedButton.styleFrom(
                                      side: BorderSide(
                                        color: _isFollowing
                                            ? Colors.grey
                                            : theme.colorScheme.primary,
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 4,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                    ),
                                  ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // إحصائيات
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isDark
                              ? theme.colorScheme.surface
                              : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _stat(
                              Icons.star_rounded,
                              (novelData['rating'] ?? 0.0).toStringAsFixed(1),
                              'التقييم',
                              theme,
                              color: Colors.amber,
                            ),
                            _divider(),
                            _stat(
                              Icons.favorite_rounded,
                              (novelData['likes'] ?? 0).toString(),
                              'إعجاب',
                              theme,
                              color: Colors.redAccent,
                            ),
                            _divider(),
                            _stat(
                              Icons.remove_red_eye_rounded,
                              (novelData['readers'] ?? 0).toString(),
                              'قارئ',
                              theme,
                            ),
                            _divider(),
                            _stat(
                              Icons.menu_book_rounded,
                              (novelData['chaptersCount'] ?? 0).toString(),
                              'فصل',
                              theme,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // تقييم بالنجوم (للقراء)
                      if (!isOwner) ...[
                        _ratingWidget(theme),
                        const SizedBox(height: 20),
                      ],

                      // وصف
                      Text(
                        'نبذة عن الرواية',
                        style: GoogleFonts.cairo(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        (novelData['description'] ??
                                    widget.novel['description'] ??
                                    '')
                                .toString()
                                .isEmpty
                            ? 'لا يوجد وصف لهذه الرواية.'
                            : (novelData['description'] ??
                                  widget.novel['description'] ??
                                  ''),
                        style: GoogleFonts.cairo(
                          fontSize: 14,
                          height: 1.7,
                          color: isDark ? Colors.white70 : Colors.black54,
                        ),
                      ),
                      const SizedBox(height: 24),

                      // ── قائمة الفصول ──────────────────────────────────────
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'الفصول',
                            style: GoogleFonts.cairo(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                          if (isOwner && !isCompleted)
                            TextButton.icon(
                              onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => AddNovelScreen(
                                    novelId: novelId,
                                    novelTitle:
                                        novelData['title'] ??
                                        widget.novel['title'],
                                  ),
                                ),
                              ),
                              icon: const Icon(Icons.add, size: 18),
                              label: Text(
                                'فصل جديد',
                                style: GoogleFonts.cairo(fontSize: 13),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // فصول stream
                      StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('novels')
                            .doc(novelId)
                            .collection('chapters')
                            .orderBy('chapterNumber')
                            .snapshots(),
                        builder: (_, chapSnap) {
                          if (chapSnap.connectionState ==
                              ConnectionState.waiting) {
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          }
                          if (chapSnap.hasError) {
                            return Center(
                              child: Text('حدث خطأ في تحميل الفصول: ${chapSnap.error}'),
                            );
                          }
                          if (!chapSnap.hasData ||
                              chapSnap.data!.docs.isEmpty) {
                            return Center(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 20,
                                ),
                                child: Text(
                                  'لا توجد فصول بعد.',
                                  style: GoogleFonts.cairo(color: Colors.grey),
                                ),
                              ),
                            );
                          }

                          final chapters = chapSnap.data!.docs;
                          return ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: chapters.length,
                            itemBuilder: (_, i) {
                              final ch =
                                  chapters[i].data() as Map<String, dynamic>;
                              final chapterId = chapters[i].id;
                              final chNum = ch['chapterNumber'] ?? (i + 1);
                              final wc = ch['wordCount'] ?? 0;
                              final rt = (ch['rating'] ?? 0.0).toDouble();
                              final rtCt = ch['ratingsCount'] ?? 0;

                              return Card(
                                margin: const EdgeInsets.only(bottom: 10),
                                elevation: 1,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: ListTile(
                                  onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => NovelReaderScreen(
                                        novel: {
                                          'id': novelId,
                                          'chapterId': chapterId,
                                          'chapterTitle': ch['title'] ?? '',
                                          'chapterNumber': chNum.toString(),
                                          'title':
                                              novelData['title'] ??
                                              widget.novel['title'] ??
                                              '',
                                          'author':
                                              widget.novel['author'] ?? '',
                                          'content': ch['content'] ?? '',
                                          'likes': (novelData['likes'] ?? 0)
                                              .toString(),
                                          'readers': (novelData['readers'] ?? 0)
                                              .toString(),
                                          'authorId': authorId,
                                        },
                                      ),
                                    ),
                                  ),
                                  leading: CircleAvatar(
                                    backgroundColor: theme.colorScheme.primary
                                        .withOpacity(0.1),
                                    child: Text(
                                      '$chNum',
                                      style: GoogleFonts.cairo(
                                        fontWeight: FontWeight.bold,
                                        color: theme.colorScheme.primary,
                                      ),
                                    ),
                                  ),
                                  title: Text(
                                    ch['title'] ?? 'فصل $chNum',
                                    style: GoogleFonts.cairo(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                  subtitle: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          '$wc كلمة  •  ${rt.toStringAsFixed(1)} ($rtCt تقييم)',
                                          style: GoogleFonts.cairo(
                                            fontSize: 11,
                                            color: Colors.grey,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      const Icon(
                                        Icons.star,
                                        size: 12,
                                        color: Colors.amber,
                                      ),
                                    ],
                                  ),
                                  trailing: const Icon(
                                    Icons.arrow_forward_ios,
                                    size: 14,
                                    color: Colors.grey,
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),

                      // زر إكمال الرواية
                      if (isOwner && !isCompleted) ...[
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: _confirmComplete,
                            icon: const Icon(
                              Icons.check_circle_outline,
                              color: Colors.green,
                            ),
                            label: Text(
                              'أعلن اكتمال الرواية',
                              style: GoogleFonts.cairo(color: Colors.green),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Colors.green),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ],

                      const SizedBox(height: 30),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  Widget _ratingWidget(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.amber.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _userRating == 0
                      ? 'قيّم هذه الرواية'
                      : 'تقييمك: $_userRating نجوم',
                  style: GoogleFonts.cairo(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.amber.shade700,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              const Icon(Icons.star, size: 14, color: Colors.amber),
            ],
          ),
          const SizedBox(height: 10),
          _isRatingLoading
              ? const Center(
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.amber,
                    ),
                  ),
                )
              : Row(
                  children: List.generate(5, (i) {
                    final star = i + 1;
                    return GestureDetector(
                      onTap: () => _submitRating(star),
                      child: Padding(
                        padding: const EdgeInsets.only(left: 4),
                        child: Icon(
                          star <= _userRating
                              ? Icons.star_rounded
                              : Icons.star_outline_rounded,
                          color: Colors.amber,
                          size: 34,
                        ),
                      ),
                    );
                  }),
                ),
        ],
      ),
    );
  }

  Widget _stat(
    IconData icon,
    String val,
    String label,
    ThemeData theme, {
    Color? color,
  }) {
    return Column(
      children: [
        Icon(icon, color: color ?? theme.colorScheme.primary, size: 22),
        const SizedBox(height: 3),
        Text(
          val,
          style: GoogleFonts.cairo(fontSize: 14, fontWeight: FontWeight.bold),
        ),
        Text(label, style: GoogleFonts.cairo(fontSize: 10, color: Colors.grey)),
      ],
    );
  }

  Widget _divider() =>
      Container(height: 36, width: 1, color: Colors.grey.withOpacity(0.25));
}
