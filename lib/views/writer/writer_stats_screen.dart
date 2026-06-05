import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:my_first_app/providers/theme_provider.dart';

class WriterStatsScreen extends StatelessWidget {
  final String novelId;
  final String novelTitle;
  const WriterStatsScreen({
    super.key,
    required this.novelId,
    required this.novelTitle,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDarkMode;
    final bg          = isDark ? const Color(0xFF0D0F14) : const Color(0xFFF5F5F7);
    final surface     = isDark ? const Color(0xFF161920) : const Color(0xFFFFFFFF);
    final surfaceHigh = isDark ? const Color(0xFF1E2130) : const Color(0xFFEEEEF0);
    final border      = isDark ? const Color(0xFF252836) : const Color(0xFFE0E0E4);
    final textPri     = isDark ? const Color(0xFFECECEC) : const Color(0xFF111827);
    final textSec     = isDark ? const Color(0xFF6B7280) : const Color(0xFF555F6E);
    const accent      = Color(0xFF8BAF7C);
    const gold        = Color(0xFFD4A843);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        title: Text(novelTitle,
            style: GoogleFonts.cairo(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: textPri),
            overflow: TextOverflow.ellipsis),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: border),
        ),
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _loadStats(novelId),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(
                    color: accent, strokeWidth: 2));
          }
          if (snap.hasError || !snap.hasData) {
            return Center(
                child: Text('تعذّر تحميل الإحصائيات',
                    style: GoogleFonts.cairo(color: textSec)));
          }
          final s = snap.data!;
          final chapters = s['chapters'] as List<Map<String, dynamic>>;
          final totalReaders  = s['readers']    as int;
          final totalLikes    = s['likes']      as int;
          final avgRating     = s['avgRating']  as double;
          final totalWords    = s['totalWords'] as int;
          final completedReaders = s['completedReaders'] as int;
          final completionRate = totalReaders == 0
              ? 0.0
              : completedReaders / totalReaders;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // ── بطاقات الملخص ──────────────────────────────────────────
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 1.6,
                children: [
                  _statCard(Icons.remove_red_eye_rounded, '$totalReaders', 'قارئ', Colors.blueAccent, surface, border, textPri, textSec),
                  _statCard(Icons.favorite_rounded, '$totalLikes', 'إعجاب', Colors.redAccent, surface, border, textPri, textSec),
                  _statCard(Icons.star_rounded, avgRating.toStringAsFixed(1), 'تقييم', gold, surface, border, textPri, textSec),
                  _statCard(Icons.text_fields_rounded, _formatNum(totalWords), 'كلمة', accent, surface, border, textPri, textSec),
                ],
              ),
              const SizedBox(height: 16),

              // ── معدل الإكمال ────────────────────────────────────────────
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                    color: surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: border)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('معدل الإكمال',
                        style: GoogleFonts.cairo(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: textPri)),
                    const SizedBox(height: 8),
                    Row(children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: completionRate,
                            backgroundColor: surfaceHigh,
                            color: accent,
                            minHeight: 8,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text('${(completionRate * 100).toStringAsFixed(0)}%',
                          style: GoogleFonts.cairo(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: accent)),
                    ]),
                    const SizedBox(height: 4),
                    Text('$completedReaders من $totalReaders قارئ أكملوا الرواية',
                        style: GoogleFonts.cairo(
                            fontSize: 11, color: textSec)),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // ── الفصول ─────────────────────────────────────────────────
              if (chapters.isNotEmpty) ...[
                Text('إحصائيات الفصول',
                    style: GoogleFonts.cairo(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: textPri)),
                const SizedBox(height: 10),
                ...chapters.asMap().entries.map((e) {
                  final idx = e.key + 1;
                  final ch  = e.value;
                  final reads   = (ch['readCount']   as num?)?.toInt() ?? 0;
                  final likes   = (ch['likes']       as num?)?.toInt() ?? 0;
                  final words   = (ch['wordCount']   as num?)?.toInt() ?? 0;
                  final title   = ch['title'] as String? ?? 'فصل $idx';
                  final pct     = totalReaders == 0
                      ? 0.0
                      : (reads / totalReaders).clamp(0.0, 1.0);
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                        color: surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: border)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: accent.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Center(
                              child: Text('$idx',
                                  style: GoogleFonts.cairo(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: accent)),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(title,
                                style: GoogleFonts.cairo(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: textPri),
                                overflow: TextOverflow.ellipsis),
                          ),
                          Text('$words كلمة',
                              style: GoogleFonts.cairo(
                                  fontSize: 10, color: textSec)),
                        ]),
                        const SizedBox(height: 8),
                        Row(children: [
                          Icon(Icons.remove_red_eye_rounded,
                              size: 12, color: textSec),
                          const SizedBox(width: 4),
                          Text('$reads قراءة',
                              style: GoogleFonts.cairo(
                                  fontSize: 11, color: textSec)),
                          const SizedBox(width: 12),
                          Icon(Icons.favorite_rounded,
                              size: 12, color: Colors.redAccent),
                          const SizedBox(width: 4),
                          Text('$likes',
                              style: GoogleFonts.cairo(
                                  fontSize: 11, color: textSec)),
                          const Spacer(),
                          Text('${(pct * 100).toStringAsFixed(0)}% وصل',
                              style: GoogleFonts.cairo(
                                  fontSize: 10, color: accent)),
                        ]),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: pct,
                            backgroundColor: surfaceHigh,
                            color: accent,
                            minHeight: 4,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ],
          );
        },
      ),
    );
  }

  static Future<Map<String, dynamic>> _loadStats(String novelId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return {};

    final novelDoc = await FirebaseFirestore.instance
        .collection('novels')
        .doc(novelId)
        .get();
    final novelData = novelDoc.data() ?? {};

    final chapSnap = await FirebaseFirestore.instance
        .collection('novels')
        .doc(novelId)
        .collection('chapters')
        .orderBy('createdAt')
        .get();

    int totalWords = 0;
    int completedReaders = 0;
    final chapters = <Map<String, dynamic>>[];
    final chapIds = chapSnap.docs.map((d) => d.id).toList();

    for (final doc in chapSnap.docs) {
      final d = doc.data();
      final content = d['content'] as String? ?? '';
      final wc = d['wordCount'] as int? ?? content.split(' ').length;
      totalWords += wc;
      chapters.add({
        'title':     d['title'] ?? '',
        'wordCount': wc,
        'readCount': d['readCount'] ?? 0,
        'likes':     d['likes'] ?? 0,
      });
    }

    // حساب القراء الذين أكملوا كل الفصول
    if (chapIds.isNotEmpty) {
      try {
        final progressSnap = await FirebaseFirestore.instance
            .collectionGroup('readingProgress')
            .where('novelId', isEqualTo: novelId)
            .get();
        for (final pd in progressSnap.docs) {
          final readIds = List<String>.from(
              (pd.data() as Map)['readChapterIds'] ?? []);
          if (chapIds.every((id) => readIds.contains(id))) {
            completedReaders++;
          }
        }
      } catch (_) {}
    }

    return {
      'readers':          (novelData['readers']  as num?)?.toInt() ?? 0,
      'likes':            (novelData['likes']    as num?)?.toInt() ?? 0,
      'avgRating':        (novelData['rating']   as num?)?.toDouble() ?? 0.0,
      'totalWords':       totalWords,
      'completedReaders': completedReaders,
      'chapters':         chapters,
    };
  }

  String _formatNum(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}م';
    if (n >= 1000)    return '${(n / 1000).toStringAsFixed(1)}ك';
    return '$n';
  }

  Widget _statCard(IconData icon, String value, String label, Color color,
      Color surface, Color border, Color textPri, Color textSec) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(height: 6),
          Text(value,
              style: GoogleFonts.cairo(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: textPri)),
          Text(label,
              style: GoogleFonts.cairo(fontSize: 10, color: textSec)),
        ],
      ),
    );
  }
}
