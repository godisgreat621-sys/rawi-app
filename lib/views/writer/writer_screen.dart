import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:my_first_app/providers/novels_provider.dart';
import '../../models/novel_model.dart';
import 'add_novel_screen.dart';
import '../home/novel_detail_screen.dart';

class WriterScreen extends StatelessWidget {
  const WriterScreen({super.key});

  static const _bg          = Color(0xFF0D0F14);
  static const _surface     = Color(0xFF161920);
  static const _surfaceHigh = Color(0xFF1E2130);
  static const _accent      = Color(0xFF8BAF7C);
  static const _border      = Color(0xFF252836);
  static const _textPrimary = Color(0xFFECECEC);
  static const _textSecondary = Color(0xFF6B7280);
  static const _gold        = Color(0xFFD4A843);

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

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

            // ── القائمة ───────────────────────────────────────────────────
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('novels')
                    .where('authorId', isEqualTo: currentUser?.uid)
                    .orderBy('createdAt', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(
                        color: _accent,
                        strokeWidth: 2,
                      ),
                    );
                  }

                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return _buildEmptyState(context);
                  }

                  final novels = snapshot.data!.docs
                      .map((doc) => Novel.fromFirestore(doc))
                      .toList();

                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 30),
                    itemCount: novels.length,
                    itemBuilder: (context, index) =>
                        _buildNovelCard(context, novels[index]),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── بطاقة الرواية ─────────────────────────────────────────────────────────
  Widget _buildNovelCard(BuildContext context, Novel novel) {
    final isCompleted = novel.status == 'completed';

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => NovelDetailScreen(
            novel: {
              'id':          novel.id,
              'title':       novel.title,
              'description': novel.description,
              'category':    novel.category,
              'author':      novel.author,
              'authorId':    novel.authorId,
              'coverUrl':    novel.coverUrl,
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
                      color: _surfaceHigh,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: _border),
                      image: novel.coverUrl != null
                          ? DecorationImage(
                              image: NetworkImage(novel.coverUrl!),
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                    child: novel.coverUrl == null
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
                                novel.title,
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
                                color: isCompleted
                                    ? Colors.green.withOpacity(0.12)
                                    : _accent.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                isCompleted ? 'مكتملة' : 'جارية',
                                style: GoogleFonts.cairo(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: isCompleted ? Colors.green : _accent,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        // التصنيف
                        Text(
                          novel.category,
                          style: GoogleFonts.cairo(
                            fontSize: 11,
                            color: _textSecondary,
                          ),
                        ),
                        const SizedBox(height: 10),
                        // الإحصائيات الأساسية
                        Row(
                          children: [
                            _miniStat(Icons.menu_book_rounded,
                                '${novel.chaptersCount} فصل', _accent),
                            const SizedBox(width: 16),
                            _miniStat(Icons.remove_red_eye_rounded,
                                '${novel.readers}', Colors.blueGrey),
                            const SizedBox(width: 16),
                            _miniStat(Icons.favorite_rounded,
                                '${novel.likes}', Colors.redAccent),
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
                  Row(
                    children: [
                      Icon(Icons.star_rounded, size: 14, color: _gold),
                      const SizedBox(width: 4),
                      Text(
                        novel.rating.toStringAsFixed(1),
                        style: GoogleFonts.cairo(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: _gold,
                        ),
                      ),
                    ],
                  ),

                  // زر إضافة فصل (للروايات الجارية فقط)
                  if (!isCompleted)
                    GestureDetector(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AddNovelScreen(
                            novelId:    novel.id,
                            novelTitle: novel.title,
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

                  // زر حذف
                  GestureDetector(
                    onTap: () => _confirmDelete(context, novel),
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
              'ابدأ روايتك الأولى\nوشارك قصتك مع القراء ✍️',
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

  // ── حذف رواية ─────────────────────────────────────────────────────────────
  Future<void> _confirmDelete(BuildContext context, Novel novel) async {
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
          'هل أنت متأكد من حذف "${novel.title}"؟\nلا يمكن التراجع عن هذا الإجراء.',
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
      final error = await context.read<NovelsProvider>().deleteNovel(novel.id);
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