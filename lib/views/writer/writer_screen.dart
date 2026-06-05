import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:my_first_app/providers/novels_provider.dart';
import 'package:my_first_app/providers/theme_provider.dart';
import 'package:my_first_app/models/library_item.dart';
import 'add_novel_screen.dart';
import '../home/novel_detail_screen.dart';

class WriterScreen extends StatefulWidget {
  const WriterScreen({super.key});

  @override
  State<WriterScreen> createState() => _WriterScreenState();
}

class _WriterScreenState extends State<WriterScreen> {

  Color _bg          = const Color(0xFF0D0F14);
  Color _surface     = const Color(0xFF161920);
  Color _surfaceHigh = const Color(0xFF1E2130);
  static const _accent      = Color(0xFF8BAF7C);
  Color _border      = const Color(0xFF252836);
  Color _textPrimary = const Color(0xFFECECEC);
  Color _textSecondary = const Color(0xFF6B7280);
  static const _gold        = Color(0xFFD4A843);

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDarkMode;
    _bg           = isDark ? const Color(0xFF0D0F14) : const Color(0xFFF5F5F7);
    _surface      = isDark ? const Color(0xFF161920) : const Color(0xFFFFFFFF);
    _surfaceHigh  = isDark ? const Color(0xFF1E2130) : const Color(0xFFEEEEF0);
    _border       = isDark ? const Color(0xFF252836) : const Color(0xFFE0E0E4);
    _textPrimary  = isDark ? const Color(0xFFECECEC) : const Color(0xFF111827);
    _textSecondary= isDark ? const Color(0xFF6B7280) : const Color(0xFF555F6E);

    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ────────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              decoration: BoxDecoration(
                color: _bg,
                border: Border(bottom: BorderSide(color: _border)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'مؤلفاتي',
                    style: GoogleFonts.cairo(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: _textPrimary,
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const AddNovelScreen()),
                    ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: _accent,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.add, size: 16, color: Color(0xFF0D0F14)),
                          const SizedBox(width: 6),
                          Text(
                            'رواية جديدة',
                            style: GoogleFonts.cairo(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF0D0F14),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: StreamBuilder<List<LibraryItem>>(
                stream: context.read<NovelsProvider>().getMyLibraryItemsStream(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: _accent));
                  if (!snapshot.hasData || snapshot.data!.isEmpty) return _buildEmptyState(context);
                  
                  final items = snapshot.data!;
                  return ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: items.length,
                    itemBuilder: (context, index) => _buildLibraryItemCard(context, items[index]),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── بطاقة عنصر المكتبة (رواية أو مسودة) ──────────────────────────────────
  Widget _buildLibraryItemCard(BuildContext context, LibraryItem item) {
    final isCompleted = item.status == 'completed';
    final isDraft     = item.isDraft;

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => isDraft
              ? AddNovelScreen(
                  draftId:    item.id,
                  novelId:    item.novelIdForChapterDraft, // Pass novelId for chapter drafts
                  novelTitle: null, // Let AddNovelScreen fetch the novel title
                )
              : NovelDetailScreen(
                  novel: {
                    'id':          item.id,
                    'title':       item.title,
                    'description': item.description,
                    'category':    item.category,
                    'author':      item.author,
                    'authorId':    item.authorId,
                    'coverUrl':    item.coverUrl,
                    'rating':      item.rating ?? 0.0,
                    'likes':       item.likes ?? 0,
                    'readers':     item.readers ?? 0,
                    'chaptersCount': item.chaptersCount ?? 0,
                  },
                ),
          ),
        ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _border),
        ),
        child: Column(
          children: [
            // ── الجزء العلوي: الغلاف + المعلومات الأساسية ─────────────────
            Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // مصغّر الغلاف
                  Container(
                    width: 56,
                    height: 78,
                    decoration: BoxDecoration(
                      color: isDraft ? _accent.withOpacity(0.1) : _surfaceHigh,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: _border),
                      image: item.coverUrl != null
                          ? DecorationImage(
                              image: NetworkImage(item.coverUrl!),
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                    child: item.coverUrl == null
                        ? Icon(
                            Icons.auto_stories_rounded,
                            color: _accent.withOpacity(0.4),
                            size: 24,
                          )
                        : null,
                  ),
                  const SizedBox(width: 12),

                  // المعلومات
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // العنوان + الحالة
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                item.title,
                                style: GoogleFonts.cairo(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: _textPrimary,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: isDraft ? _gold.withOpacity(0.12) : isCompleted
                                    ? Colors.green.withOpacity(0.12)
                                    : _accent.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                isDraft ? 'مسودة' : (isCompleted ? 'مكتملة' : 'منشور'),
                                style: GoogleFonts.cairo(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: isDraft ? _gold : (isCompleted ? Colors.green : _accent),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        // التصنيف
                        Text(
                          item.category,
                          style: GoogleFonts.cairo(
                            fontSize: 11,
                            color: _textSecondary,
                          ),
                        ),
                        const SizedBox(height: 10),
                        // الإحصائيات الأساسية
                        Row(
                          children: [
                            if (!isDraft) _miniStat(Icons.menu_book_rounded,
                                '${item.chaptersCount ?? 0} فصل', _accent),
                            const SizedBox(width: 16),
                            if (!isDraft) _miniStat(Icons.remove_red_eye_rounded,
                                '${item.readers ?? 0}', Colors.blueGrey),
                            const SizedBox(width: 16),
                            if (!isDraft) _miniStat(Icons.favorite_rounded,
                                '${item.likes ?? 0}', Colors.redAccent),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ── الجزء السفلي: شريط الإحصائيات التفصيلية ─────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: _surfaceHigh,
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(14),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // التقييم
                  if (!isDraft)
                    Row(children: [
                      Icon(Icons.star_rounded, size: 14, color: _gold),
                      const SizedBox(width: 4),
                      Text(item.rating?.toStringAsFixed(1) ?? '0.0', style: GoogleFonts.cairo(fontSize: 12, fontWeight: FontWeight.w700, color: _gold)),
                    ]),

                  // زر إضافة فصل (للروايات الجارية فقط)
                  if (!isCompleted)
                    GestureDetector(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AddNovelScreen(
                            novelId:    item.id,
                            novelTitle: item.title,
                          ),
                        ),
                      ),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: _accent.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: _accent.withOpacity(0.3),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.add, size: 13, color: _accent),
                            const SizedBox(width: 4),
                            Text(
                              'فصل جديد',
                              style: GoogleFonts.cairo(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: _accent,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // زر تصدير الرواية (#49)
                  if (!isDraft)
                    GestureDetector(
                      onTap: () => _exportNovel(context, item),
                      child: Padding(
                        padding: const EdgeInsets.only(left: 10),
                        child: Icon(Icons.ios_share_rounded, size: 18, color: _textSecondary),
                      ),
                    ),

                  // زر حذف
                  GestureDetector(
                    onTap: () => _confirmDelete(context, item),
                    child: Icon(
                      Icons.delete_outline_rounded,
                      size: 18,
                      color: _textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _miniStat(IconData icon, String value, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 3),
        Text(
          value,
          style: GoogleFonts.cairo(
            fontSize: 11,
            color: _textSecondary,
          ),
        ),
      ],
    );
  }

  // ── حالة فارغة ────────────────────────────────────────────────────────────
  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: _surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _border),
              ),
              child: Icon(
                Icons.edit_note_rounded,
                size: 38,
                color: _accent.withOpacity(0.5),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'لم تكتب أي رواية بعد',
              style: GoogleFonts.cairo(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: _textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'ابدأ روايتك الأولى\nوشارك قصتك مع القراء',
              textAlign: TextAlign.center,
              style: GoogleFonts.cairo(
                fontSize: 13,
                color: _textSecondary,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 28),
            GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AddNovelScreen()),
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: _accent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'ابدأ الآن',
                  style: GoogleFonts.cairo(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF0D0F14),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── تصدير الرواية نصياً (#49) ─────────────────────────────────────────────
  Future<void> _exportNovel(BuildContext context, LibraryItem item) async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('جاري تجميع الفصول...', style: GoogleFonts.cairo(fontSize: 13)),
        backgroundColor: const Color(0xFF161920),
        duration: const Duration(seconds: 2),
      ));

      final chaptersSnap = await FirebaseFirestore.instance
          .collection('novels').doc(item.id)
          .collection('chapters')
          .orderBy('chapterNumber')
          .get();

      final buf = StringBuffer();
      buf.writeln('══════════════════════════════');
      buf.writeln('رواية: ${item.title}');
      buf.writeln('تأليف: ${item.author}');
      buf.writeln('التصنيف: ${item.category ?? ''}');
      buf.writeln('══════════════════════════════\n');

      for (final doc in chaptersSnap.docs) {
        final data = doc.data();
        buf.writeln('── ${data['title'] ?? 'فصل'} ──');
        buf.writeln();
        buf.writeln(data['content'] ?? '');
        buf.writeln('\n');
      }

      await Clipboard.setData(ClipboardData(text: buf.toString()));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('تم نسخ الرواية كاملةً للحافظة ✅ (${chaptersSnap.docs.length} فصول)',
              style: GoogleFonts.cairo(fontSize: 13)),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('فشل التصدير: $e', style: GoogleFonts.cairo(fontSize: 13)),
          backgroundColor: Colors.redAccent,
        ));
      }
    }
  }

  // ── حذف رواية ─────────────────────────────────────────────────────────────
  Future<void> _confirmDelete(BuildContext context, LibraryItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF161920),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'حذف الرواية',
          style: GoogleFonts.cairo(
            fontWeight: FontWeight.w700,
            color: _textPrimary,
          ),
        ),
        content: Text(
          'هل أنت متأكد من حذف "${item.title}"؟\nلا يمكن التراجع عن هذا الإجراء.',
          style: GoogleFonts.cairo(color: _textSecondary, height: 1.6),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('إلغاء', style: GoogleFonts.cairo(color: _textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'حذف',
              style: GoogleFonts.cairo(
                color: Colors.redAccent,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      final error = item.isDraft
          ? await context.read<NovelsProvider>().deleteDraft(item.id)
          : await context.read<NovelsProvider>().deleteNovel(item.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              error == null ? 'تم حذف الرواية.' : error,
              style: GoogleFonts.cairo(),
            ),
            backgroundColor: error == null ? Colors.green : Colors.redAccent,
          ),
        );
      }
    }
  }
}