import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:my_first_app/providers/theme_provider.dart';
import 'package:my_first_app/core/image_utils.dart';
import 'home/novel_detail_screen.dart';

class ReadingListsScreen extends StatelessWidget {
  const ReadingListsScreen({super.key});

  static const _lists = [
    ('أريد القراءة', Icons.bookmark_outline_rounded,   Color(0xFF8BAF7C)),
    ('أقرأ الآن',    Icons.menu_book_rounded,           Color(0xFF64B5F6)),
    ('المفضلة',      Icons.favorite_outline_rounded,    Color(0xFFEF9A9A)),
    ('مكتملة',       Icons.check_circle_outline_rounded, Color(0xFFD4A843)),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDarkMode;
    final bg      = isDark ? const Color(0xFF0D0F14) : const Color(0xFFF5F5F7);
    final surface = isDark ? const Color(0xFF161920) : const Color(0xFFFFFFFF);
    final border  = isDark ? const Color(0xFF252836) : const Color(0xFFE0E0E4);
    final textPri = isDark ? const Color(0xFFECECEC) : const Color(0xFF111827);
    final textSec = isDark ? const Color(0xFF6B7280) : const Color(0xFF555F6E);

    final user = FirebaseAuth.instance.currentUser;

    return DefaultTabController(
      length: _lists.length,
      child: Scaffold(
        backgroundColor: bg,
        appBar: AppBar(
          backgroundColor: bg,
          elevation: 0,
          title: Text('قوائم القراءة',
              style: GoogleFonts.cairo(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: textPri)),
          bottom: TabBar(
            isScrollable: true,
            indicatorColor: const Color(0xFF8BAF7C),
            labelColor: const Color(0xFF8BAF7C),
            unselectedLabelColor: textSec,
            labelStyle:
                GoogleFonts.cairo(fontSize: 13, fontWeight: FontWeight.w700),
            unselectedLabelStyle: GoogleFonts.cairo(fontSize: 13),
            tabs: _lists
                .map((l) => Tab(
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(l.$2, size: 15, color: l.$3),
                        const SizedBox(width: 6),
                        Text(l.$1),
                      ]),
                    ))
                .toList(),
          ),
        ),
        body: user == null
            ? Center(
                child: Text('يجب تسجيل الدخول',
                    style: GoogleFonts.cairo(color: textSec)))
            : TabBarView(
                children: _lists
                    .map((l) => _ListTab(
                          userId: user.uid,
                          listName: l.$1,
                          accent: l.$3,
                          surface: surface,
                          border: border,
                          bg: bg,
                          textPri: textPri,
                          textSec: textSec,
                        ))
                    .toList(),
              ),
      ),
    );
  }
}

class _ListTab extends StatelessWidget {
  final String userId;
  final String listName;
  final Color  accent;
  final Color  surface;
  final Color  border;
  final Color  bg;
  final Color  textPri;
  final Color  textSec;

  const _ListTab({
    required this.userId,
    required this.listName,
    required this.accent,
    required this.surface,
    required this.border,
    required this.bg,
    required this.textPri,
    required this.textSec,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('readingLists')
          .doc(listName)
          .snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return Center(
              child: CircularProgressIndicator(
                  color: accent, strokeWidth: 2));
        }
        final novelIds = snap.hasData && snap.data!.exists
            ? List<String>.from(
                ((snap.data!.data() as Map?)?['novelIds']) ?? [])
            : <String>[];

        if (novelIds.isEmpty) {
          return Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.inbox_outlined, size: 48,
                  color: accent.withValues(alpha: 0.4)),
              const SizedBox(height: 12),
              Text('القائمة فارغة',
                  style: GoogleFonts.cairo(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: textPri)),
              const SizedBox(height: 6),
              Text('أضف روايات من صفحة التفاصيل',
                  style: GoogleFonts.cairo(fontSize: 12, color: textSec)),
            ]),
          );
        }

        return FutureBuilder<List<Map<String, dynamic>>>(
          future: _loadNovels(novelIds),
          builder: (context, novSnap) {
            if (!novSnap.hasData) {
              return Center(
                  child: CircularProgressIndicator(
                      color: accent, strokeWidth: 2));
            }
            final novels = novSnap.data!;
            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: novels.length,
              itemBuilder: (_, i) {
                final n       = novels[i];
                final nId     = n['id'] as String;
                final title   = n['title'] as String? ?? '';
                final author  = n['author'] as String? ?? '';
                final cover   = n['coverUrl'] as String?;
                final rating  = (n['rating'] as num?)?.toDouble() ?? 0.0;
                final cat     = n['category'] as String? ?? '';

                return GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => NovelDetailScreen(novel: n)),
                  ),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                        color: surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: border)),
                    child: Row(children: [
                      // غلاف
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: cover != null
                            ? Image.network(
                                optimizeImageUrl(cover, width: 120),
                                width: 50,
                                height: 68,
                                fit: BoxFit.cover)
                            : Container(
                                width: 50,
                                height: 68,
                                color: bg,
                                child: Icon(Icons.auto_stories_rounded,
                                    color: accent, size: 22)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(title,
                                style: GoogleFonts.cairo(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: textPri),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                            const SizedBox(height: 3),
                            Text(author,
                                style: GoogleFonts.cairo(
                                    fontSize: 11, color: textSec)),
                            const SizedBox(height: 4),
                            Row(children: [
                              const Icon(Icons.star_rounded,
                                  size: 12, color: Color(0xFFD4A843)),
                              const SizedBox(width: 3),
                              Text(rating.toStringAsFixed(1),
                                  style: GoogleFonts.cairo(
                                      fontSize: 11, color: textSec)),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                    color: accent.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(5)),
                                child: Text(cat,
                                    style: GoogleFonts.cairo(
                                        fontSize: 9, color: accent)),
                              ),
                            ]),
                          ],
                        ),
                      ),
                      // زر إزالة
                      IconButton(
                        icon: Icon(Icons.remove_circle_outline_rounded,
                            size: 18, color: textSec),
                        tooltip: 'إزالة من القائمة',
                        onPressed: () => _removeFromList(userId, listName, nId),
                      ),
                    ]),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  static Future<List<Map<String, dynamic>>> _loadNovels(
      List<String> ids) async {
    if (ids.isEmpty) return [];
    final results = <Map<String, dynamic>>[];
    // Firestore whereIn يقبل 10 عناصر فقط — نقسّم
    for (var i = 0; i < ids.length; i += 10) {
      final chunk = ids.sublist(i, i + 10 > ids.length ? ids.length : i + 10);
      final snap  = await FirebaseFirestore.instance
          .collection('novels')
          .where(FieldPath.documentId, whereIn: chunk)
          .get();
      for (final d in snap.docs) {
        results.add({'id': d.id, ...d.data()});
      }
    }
    return results;
  }

  static Future<void> _removeFromList(
      String userId, String listName, String novelId) async {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('readingLists')
        .doc(listName)
        .update({'novelIds': FieldValue.arrayRemove([novelId])});
  }
}
