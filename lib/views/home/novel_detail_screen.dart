import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:my_first_app/providers/novels_provider.dart';
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
  // ── ألوان ─────────────────────────────────────────────────────────────────
  static const _bg           = Color(0xFF0D0F14);
  static const _surface      = Color(0xFF161920);
  static const _surfaceHigh  = Color(0xFF1E2130);
  static const _accent       = Color(0xFF8BAF7C);
  static const _border       = Color(0xFF252836);
  static const _textPrimary  = Color(0xFFECECEC);
  static const _textSecondary= Color(0xFF6B7280);
  static const _gold         = Color(0xFFD4A843);

  bool _isFollowing     = false;
  bool _isFollowLoading = false;

  // ── ألوان الغلاف بحسب التصنيف ──────────────────────────────────────────────
  static const _categoryColors = <String, Color>{
    'فانتازيا':  Color(0xFF2D1F4E),
    'رومانسية':  Color(0xFF4E1F2D),
    'رعب':       Color(0xFF1F2D20),
    'غموض':      Color(0xFF1F2A4E),
    'تاريخية':   Color(0xFF4E3A1F),
    'خيال علمي': Color(0xFF1F3A4E),
    'عام':       Color(0xFF252836),
  };

  @override
  void initState() {
    super.initState();
    _checkIfFollowing();
  }

  Future<void> _checkIfFollowing() async {
    final user     = FirebaseAuth.instance.currentUser;
    final authorId = widget.novel['authorId'];
    if (user == null || authorId == null || authorId.isEmpty) return;
    final doc = await FirebaseFirestore.instance
        .collection('users').doc(user.uid)
        .collection('following').doc(authorId).get();
    if (mounted) setState(() => _isFollowing = doc.exists);
  }

  Future<void> _toggleFollow() async {
    final user     = FirebaseAuth.instance.currentUser;
    final authorId = widget.novel['authorId'];
    if (user == null || authorId == null || authorId.isEmpty) return;
    if (user.uid == authorId) return;
    setState(() => _isFollowLoading = true);

    await context.read<NovelsProvider>().toggleFollow(authorId);
    
    if (mounted) setState(() {
      _isFollowing = !_isFollowing;
      _isFollowLoading = false;
    });
  }

  // ── تعديل الرواية ──────────────────────────────────────────────────────────
  void _showEditSheet(Map<String, dynamic> novelData) {
    final titleCtrl = TextEditingController(
        text: novelData['title'] ?? widget.novel['title']);
    final descCtrl = TextEditingController(
        text: novelData['description'] ?? widget.novel['description']);
    String selectedCat = novelData['category'] ?? widget.novel['category'] ?? 'عام';
    final titleChanged = novelData['titleChanged'] ?? false;
    final readers      = (novelData['readers'] ?? 0) as int;
    final canEditTitle = !titleChanged && readers < 10;

    const categories = [
      'عام', 'فانتازيا', 'رعب', 'رومانسية',
      'غموض', 'تاريخية', 'خيال علمي',
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Container(
          padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom),
          decoration: const BoxDecoration(
            color: Color(0xFF161920),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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
                    Text('تعديل الرواية',
                        style: GoogleFonts.cairo(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: _textPrimary)),
                    IconButton(
                      icon: const Icon(Icons.close, color: _textSecondary),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),

                // العنوان
                if (canEditTitle) ...[
                  Text('العنوان — يمكن تعديله مرة واحدة قبل 10 قراء',
                      style: GoogleFonts.cairo(
                          fontSize: 11, color: Colors.orange)),
                  const SizedBox(height: 6),
                  _sheetField(titleCtrl, 'عنوان الرواية'),
                  const SizedBox(height: 14),
                ] else ...[
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _surfaceHigh,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(children: [
                      const Icon(Icons.lock_outline,
                          size: 15, color: _textSecondary),
                      const SizedBox(width: 8),
                      Text('العنوان مقفل',
                          style: GoogleFonts.cairo(
                              fontSize: 12, color: _textSecondary)),
                    ]),
                  ),
                  const SizedBox(height: 14),
                ],

                // التصنيف
                Text('التصنيف',
                    style: GoogleFonts.cairo(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: _textPrimary)),
                const SizedBox(height: 8),
                SizedBox(
                  height: 36,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: categories.map((cat) {
                      final sel = cat == selectedCat;
                      return GestureDetector(
                        onTap: () => setS(() => selectedCat = cat),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          margin: const EdgeInsets.only(left: 8),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: sel ? _accent : _surfaceHigh,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                                color: sel ? _accent : _border),
                          ),
                          child: Text(cat,
                              style: GoogleFonts.cairo(
                                  fontSize: 12,
                                  color: sel
                                      ? const Color(0xFF0D0F14)
                                      : _textSecondary,
                                  fontWeight: sel
                                      ? FontWeight.w700
                                      : FontWeight.w400)),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 14),

                // الوصف
                Text('الوصف',
                    style: GoogleFonts.cairo(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: _textPrimary)),
                const SizedBox(height: 8),
                _sheetField(descCtrl, 'وصف الرواية...', maxLines: 3),
                const SizedBox(height: 18),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _accent,
                      foregroundColor: const Color(0xFF0D0F14),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    onPressed: () async {
                      final updates = <String, dynamic>{
                        'description': descCtrl.text.trim(),
                        'category':    selectedCat,
                      };
                      if (canEditTitle &&
                          titleCtrl.text.trim() !=
                              (novelData['title'] ?? widget.novel['title'])) {
                        updates['title']        = titleCtrl.text.trim();
                        updates['titleChanged'] = true;
                      }
                      await FirebaseFirestore.instance
                          .collection('novels')
                          .doc(widget.novel['id'])
                          .update(updates);
                      if (ctx.mounted) Navigator.pop(ctx);
                    },
                    child: Text('حفظ التعديلات',
                        style: GoogleFonts.cairo(fontWeight: FontWeight.w700)),
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

  Widget _sheetField(TextEditingController ctrl, String hint,
      {int maxLines = 1}) {
    return TextField(
      controller: ctrl,
      maxLines: maxLines,
      style: GoogleFonts.cairo(color: _textPrimary, fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.cairo(color: _textSecondary, fontSize: 13),
        filled: true,
        fillColor: _surfaceHigh,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _accent, width: 1.5),
        ),
      ),
    );
  }

  // ── إكمال الرواية ──────────────────────────────────────────────────────────
  Future<void> _confirmComplete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _surface,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('إعلان اكتمال الرواية',
            style: GoogleFonts.cairo(
                fontWeight: FontWeight.w700, color: _textPrimary)),
        content: Text(
          'بعد الإعلان لن تتمكن من إضافة فصول جديدة.',
          style: GoogleFonts.cairo(color: _textSecondary, height: 1.6),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('إلغاء',
                  style: GoogleFonts.cairo(color: _textSecondary))),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text('تأكيد',
                  style: GoogleFonts.cairo(
                      color: Colors.green, fontWeight: FontWeight.w700))),
        ],
      ),
    );
    if (confirmed == true) {
      await FirebaseFirestore.instance
          .collection('novels')
          .doc(widget.novel['id'])
          .update({
        'status':      'completed',
        'completedAt': FieldValue.serverTimestamp(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('الرواية مكتملة الآن ✅',
              style: GoogleFonts.cairo()),
          backgroundColor: Colors.green,
        ));
      }
    }
  }

  // ── حذف الرواية ────────────────────────────────────────────────────────────
  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _surface,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('حذف الرواية',
            style: GoogleFonts.cairo(
                fontWeight: FontWeight.w700, color: _textPrimary)),
        content: Text('هل أنت متأكد؟ لا يمكن التراجع.',
            style: GoogleFonts.cairo(color: _textSecondary)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('إلغاء',
                  style: GoogleFonts.cairo(color: _textSecondary))),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text('حذف',
                  style: GoogleFonts.cairo(
                      color: Colors.redAccent,
                      fontWeight: FontWeight.w700))),
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

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final authorId    = widget.novel['authorId'] ?? '';
    final isOwner     = currentUser?.uid == authorId;
    final novelId     = widget.novel['id'] ?? '';
    final category    = widget.novel['category'] ?? 'عام';
    final coverBg     = _categoryColors[category] ?? _surfaceHigh;
    final coverUrl    = widget.novel['coverUrl'] as String?;

    return Scaffold(
      backgroundColor: _bg,
      body: CustomScrollView(
        slivers: [
          // ── AppBar + غلاف ────────────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 280,
            pinned: true,
            backgroundColor: _bg,
            elevation: 0,
            leading: Padding(
              padding: const EdgeInsets.all(8),
              child: CircleAvatar(
                backgroundColor: _surface,
                child: IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new_rounded,
                      color: _textPrimary, size: 16),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),
            actions: [
              if (isOwner) ...[
                StreamBuilder<DocumentSnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('novels').doc(novelId).snapshots(),
                  builder: (_, snap) {
                    final data = snap.hasData && snap.data!.exists
                        ? snap.data!.data() as Map<String, dynamic>
                        : <String, dynamic>{};
                    return Padding(
                      padding: const EdgeInsets.all(8),
                      child: CircleAvatar(
                        backgroundColor: _surface,
                        child: IconButton(
                          icon: const Icon(Icons.edit_outlined,
                              color: _accent, size: 18),
                          onPressed: () => _showEditSheet(data),
                        ),
                      ),
                    );
                  },
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 8, top: 8, bottom: 8),
                  child: CircleAvatar(
                    backgroundColor: _surface,
                    child: IconButton(
                      icon: const Icon(Icons.delete_outline,
                          color: Colors.redAccent, size: 18),
                      onPressed: _confirmDelete,
                    ),
                  ),
                ),
              ],
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                color: _bg,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 50),
                    // الغلاف
                    Container(
                      width: 130,
                      height: 190,
                      decoration: BoxDecoration(
                        color: coverBg,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: _border),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.4),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                        image: coverUrl != null
                            ? DecorationImage(
                                image: NetworkImage(coverUrl),
                                fit: BoxFit.cover)
                            : null,
                      ),
                      child: coverUrl == null
                          ? Icon(Icons.auto_stories_rounded,
                              size: 50,
                              color: _accent.withOpacity(0.4))
                          : null,
                    ),
                  ],
                ),
              ),
            ),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(1),
              child: Container(height: 1, color: _border),
            ),
          ),

          // ── المحتوى ─────────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('novels').doc(novelId).snapshots(),
              builder: (_, novelSnap) {
                final novelData =
                    novelSnap.hasData && novelSnap.data!.exists
                        ? novelSnap.data!.data() as Map<String, dynamic>
                        : <String, dynamic>{};
                final isCompleted = novelData['status'] == 'completed';
                final title = novelData['title'] ??
                    widget.novel['title'] ?? '';
                final authorName = novelData['authorName'] ??
                    widget.novel['author'] ?? 'كاتب مجهول';
                final desc = novelData['description'] ??
                    widget.novel['description'] ?? '';
                final cat = novelData['category'] ??
                    widget.novel['category'] ?? 'عام';

                return Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // تصنيف + حالة
                      Row(children: [
                        _badge(cat, _accent.withOpacity(0.15), _accent),
                        if (isCompleted) ...[
                          const SizedBox(width: 8),
                          _badge('مكتملة ✅',
                              Colors.green.withOpacity(0.12), Colors.green),
                        ],
                      ]),
                      const SizedBox(height: 12),

                      // العنوان
                      Text(title,
                          style: GoogleFonts.cairo(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: _textPrimary)),

                      const SizedBox(height: 8),

                      // الكاتب + متابعة
                      Row(
                        mainAxisAlignment:
                            MainAxisAlignment.spaceBetween,
                        children: [
                          GestureDetector(
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => AuthorScreen(
                                  authorId:   authorId,
                                  authorName: authorName,
                                ),
                              ),
                            ),
                            child: Row(children: [
                              const Icon(Icons.person_outline_rounded,
                                  size: 15, color: _accent),
                              const SizedBox(width: 5),
                              Text(authorName,
                                  style: GoogleFonts.cairo(
                                      fontSize: 13,
                                      color: _accent,
                                      decoration:
                                          TextDecoration.underline,
                                      decorationColor: _accent)),
                            ]),
                          ),
                          if (!isOwner && authorId.isNotEmpty)
                            _isFollowLoading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                        color: _accent, strokeWidth: 2))
                                : GestureDetector(
                                    onTap: _toggleFollow,
                                    child: AnimatedContainer(
                                      duration: const Duration(
                                          milliseconds: 200),
                                      padding:
                                          const EdgeInsets.symmetric(
                                              horizontal: 14,
                                              vertical: 6),
                                      decoration: BoxDecoration(
                                        color: _isFollowing
                                            ? _surface
                                            : _accent,
                                        borderRadius:
                                            BorderRadius.circular(20),
                                        border: Border.all(
                                            color: _isFollowing
                                                ? _border
                                                : _accent),
                                      ),
                                      child: Text(
                                        _isFollowing ? 'متابَع' : 'تابع',
                                        style: GoogleFonts.cairo(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: _isFollowing
                                              ? _textSecondary
                                              : const Color(0xFF0D0F14),
                                        ),
                                      ),
                                    ),
                                  ),
                        ],
                      ),
                      const SizedBox(height: 18),

                      // الإحصائيات
                      Container(
                        padding: const EdgeInsets.symmetric(
                            vertical: 14, horizontal: 8),
                        decoration: BoxDecoration(
                          color: _surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: _border),
                        ),
                        child: Row(
                          mainAxisAlignment:
                              MainAxisAlignment.spaceAround,
                          children: [
                            _stat(Icons.star_rounded,
                                (novelData['rating'] ?? 0.0)
                                    .toStringAsFixed(1),
                                'التقييم',
                                color: _gold),
                            _vDiv(),
                            _stat(Icons.favorite_rounded,
                                (novelData['likes'] ?? 0).toString(),
                                'إعجاب',
                                color: Colors.redAccent),
                            _vDiv(),
                            _stat(Icons.remove_red_eye_rounded,
                                (novelData['readers'] ?? 0).toString(),
                                'قارئ'),
                            _vDiv(),
                            _stat(Icons.menu_book_rounded,
                                (novelData['chaptersCount'] ?? 0)
                                    .toString(),
                                'فصل'),
                          ],
                        ),
                      ),
                      const SizedBox(height: 22),

                      // الوصف
                      _sectionTitle('نبذة عن الرواية'),
                      const SizedBox(height: 8),
                      Text(
                        desc.toString().isEmpty
                            ? 'لا يوجد وصف لهذه الرواية.'
                            : desc,
                        style: GoogleFonts.cairo(
                          fontSize: 14,
                          height: 1.8,
                          color: _textSecondary,
                        ),
                      ),
                      const SizedBox(height: 24),

                      // الفصول
                      Row(
                        mainAxisAlignment:
                            MainAxisAlignment.spaceBetween,
                        children: [
                          _sectionTitle('الفصول'),
                          if (isOwner && !isCompleted)
                            GestureDetector(
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => AddNovelScreen(
                                    novelId:    novelId,
                                    novelTitle: title,
                                  ),
                                ),
                              ),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: _accent.withOpacity(0.12),
                                  borderRadius:
                                      BorderRadius.circular(8),
                                  border: Border.all(
                                      color:
                                          _accent.withOpacity(0.3)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.add,
                                        size: 14, color: _accent),
                                    const SizedBox(width: 4),
                                    Text('فصل جديد',
                                        style: GoogleFonts.cairo(
                                            fontSize: 12,
                                            color: _accent,
                                            fontWeight:
                                                FontWeight.w700)),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // قائمة الفصول
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
                                child: CircularProgressIndicator(
                                    color: _accent, strokeWidth: 2));
                          }
                          if (!chapSnap.hasData ||
                              chapSnap.data!.docs.isEmpty) {
                            return Padding(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 20),
                              child: Center(
                                  child: Text('لا توجد فصول بعد.',
                                      style: GoogleFonts.cairo(
                                          color: _textSecondary))),
                            );
                          }

                          return ListView.builder(
                            shrinkWrap: true,
                            physics:
                                const NeverScrollableScrollPhysics(),
                            itemCount: chapSnap.data!.docs.length,
                            itemBuilder: (_, i) {
                              final ch = chapSnap.data!.docs[i];
                              final chData =
                                  ch.data() as Map<String, dynamic>;
                              final chNum =
                                  chData['chapterNumber'] ?? (i + 1);
                              final wc = chData['wordCount'] ?? 0;
                              final rt = (chData['rating'] ?? 0.0)
                                  .toDouble();
                              final rtCt =
                                  chData['ratingsCount'] ?? 0;

                              return GestureDetector(
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => NovelReaderScreen(
                                      novel: {
                                        'id':           novelId,
                                        'chapterId':    ch.id,
                                        'chapterTitle': chData['title'] ?? '',
                                        'chapterNumber': chNum.toString(),
                                        'title':        title,
                                        'author':       authorName,
                                        'content':      chData['content'] ?? '',
                                        'likes':        (novelData['likes'] ?? 0).toString(),
                                        'readers':      (novelData['readers'] ?? 0).toString(),
                                        'authorId':     authorId,
                                      },
                                    ),
                                  ),
                                ),
                                child: Container(
                                  margin: const EdgeInsets.only(
                                      bottom: 10),
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: _surface,
                                    borderRadius:
                                        BorderRadius.circular(12),
                                    border:
                                        Border.all(color: _border),
                                  ),
                                  child: Row(children: [
                                    // رقم الفصل
                                    Container(
                                      width: 36,
                                      height: 36,
                                      decoration: BoxDecoration(
                                        color: _accent.withOpacity(0.12),
                                        borderRadius:
                                            BorderRadius.circular(10),
                                      ),
                                      child: Center(
                                        child: Text('$chNum',
                                            style: GoogleFonts.cairo(
                                                fontWeight:
                                                    FontWeight.w700,
                                                color: _accent,
                                                fontSize: 13)),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            chData['title'] ??
                                                'فصل $chNum',
                                            style: GoogleFonts.cairo(
                                              fontWeight:
                                                  FontWeight.w700,
                                              fontSize: 13,
                                              color: _textPrimary,
                                            ),
                                          ),
                                          const SizedBox(height: 3),
                                          Row(children: [
                                            Text(
                                              '$wc كلمة',
                                              style: GoogleFonts.cairo(
                                                  fontSize: 11,
                                                  color:
                                                      _textSecondary),
                                            ),
                                            if (rtCt > 0) ...[
                                              Text('  ·  ',
                                                  style: GoogleFonts
                                                      .cairo(
                                                          fontSize: 11,
                                                          color:
                                                              _textSecondary)),
                                              Icon(
                                                  Icons.star_rounded,
                                                  size: 11,
                                                  color: _gold),
                                              const SizedBox(width: 2),
                                              Text(
                                                '${rt.toStringAsFixed(1)} ($rtCt)',
                                                style: GoogleFonts.cairo(
                                                    fontSize: 11,
                                                    color:
                                                        _textSecondary),
                                              ),
                                            ],
                                          ]),
                                        ],
                                      ),
                                    ),
                                    const Icon(
                                        Icons.arrow_forward_ios_rounded,
                                        size: 13,
                                        color: _textSecondary),
                                  ]),
                                ),
                              );
                            },
                          );
                        },
                      ),

                      // زر الاكتمال
                      if (isOwner && !isCompleted) ...[
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: _confirmComplete,
                            icon: const Icon(
                                Icons.check_circle_outline,
                                color: Colors.green,
                                size: 18),
                            label: Text('أعلن اكتمال الرواية',
                                style: GoogleFonts.cairo(
                                    color: Colors.green,
                                    fontWeight: FontWeight.w700)),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(
                                  color: Colors.green),
                              padding: const EdgeInsets.symmetric(
                                  vertical: 14),
                              shape: RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                      ],

                      const SizedBox(height: 40),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ── مساعدات ───────────────────────────────────────────────────────────────
  Widget _badge(String text, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
          color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(text,
          style: GoogleFonts.cairo(
              fontSize: 12, fontWeight: FontWeight.w700, color: fg)),
    );
  }

  Widget _sectionTitle(String text) {
    return Row(children: [
      Container(
        width: 3,
        height: 16,
        decoration: BoxDecoration(
            color: _accent, borderRadius: BorderRadius.circular(2)),
      ),
      const SizedBox(width: 8),
      Text(text,
          style: GoogleFonts.cairo(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: _textSecondary)),
    ]);
  }

  Widget _stat(IconData icon, String val, String label, {Color? color}) {
    return Column(children: [
      Icon(icon, color: color ?? _accent, size: 20),
      const SizedBox(height: 3),
      Text(val,
          style: GoogleFonts.cairo(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: _textPrimary)),
      Text(label,
          style:
              GoogleFonts.cairo(fontSize: 10, color: _textSecondary)),
    ]);
  }

  Widget _vDiv() =>
      Container(height: 36, width: 1, color: _border);
}