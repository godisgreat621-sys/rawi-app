import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:my_first_app/providers/theme_provider.dart';
import 'package:my_first_app/core/image_utils.dart';
import 'author_screen.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;

  Color _bg           = const Color(0xFF0D0F14);
  Color _surface      = const Color(0xFF161920);
  Color _surfaceHigh  = const Color(0xFF1E2130);
  Color _border       = const Color(0xFF252836);
  Color _textPrimary  = const Color(0xFFECECEC);
  Color _textSecondary= const Color(0xFF6B7280);
  static const _accent = Color(0xFF8BAF7C);
  static const _gold   = Color(0xFFD4A843);

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

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
      body: NestedScrollView(
        headerSliverBuilder: (_, innerBoxIsScrolled) => [
          SliverAppBar(
            pinned: true,
            backgroundColor: _bg,
            elevation: 0,
            title: Text('المتصدرون',
                style: GoogleFonts.cairo(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: _textPrimary)),
            bottom: TabBar(
              controller: _tab,
              indicatorColor: _accent,
              labelColor: _accent,
              unselectedLabelColor: _textSecondary,
              labelStyle: GoogleFonts.cairo(fontSize: 13, fontWeight: FontWeight.w700),
              unselectedLabelStyle: GoogleFonts.cairo(fontSize: 13),
              tabs: const [
                Tab(text: 'الكتّاب'),
                Tab(text: 'القرّاء'),
              ],
            ),
          ),
        ],
        body: TabBarView(
          controller: _tab,
          children: [
            _buildRanking('points', 'نقاط الكتابة'),
            _buildRanking('readingPoints', 'نقاط القراءة'),
          ],
        ),
      ),
    );
  }

  Widget _buildRanking(String field, String label) {
    final me = FirebaseAuth.instance.currentUser;
    return FutureBuilder<QuerySnapshot>(
      future: FirebaseFirestore.instance
          .collection('users')
          .orderBy(field, descending: true)
          .limit(50)
          .get(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(color: _accent, strokeWidth: 2));
        }
        if (!snap.hasData || snap.data!.docs.isEmpty) {
          return Center(
            child: Text('لا توجد بيانات بعد',
                style: GoogleFonts.cairo(color: _textSecondary)),
          );
        }
        final docs = snap.data!.docs;
        return ListView.builder(
          padding: const EdgeInsets.only(top: 8, bottom: 24),
          itemCount: docs.length,
          itemBuilder: (_, i) {
            final data = docs[i].data() as Map<String, dynamic>;
            final uid  = docs[i].id;
            final name = data['displayName'] ?? 'مجهول';
            final pic  = data['profilePicture'] as String?;
            final pts  = (data[field] as num?)?.toInt() ?? 0;
            final isMe = uid == me?.uid;
            final rank = i + 1;

            Color rankColor = _textSecondary;
            Widget? badge;
            if (rank == 1) {
              rankColor = const Color(0xFFFFD700);
              badge = const Icon(Icons.emoji_events_rounded,
                  color: Color(0xFFFFD700), size: 22);
            } else if (rank == 2) {
              rankColor = const Color(0xFFB0BEC5);
              badge = const Icon(Icons.emoji_events_rounded,
                  color: Color(0xFFB0BEC5), size: 20);
            } else if (rank == 3) {
              rankColor = const Color(0xFFCD7F32);
              badge = const Icon(Icons.emoji_events_rounded,
                  color: Color(0xFFCD7F32), size: 20);
            }

            return GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) =>
                        AuthorScreen(authorId: uid, authorName: name)),
              ),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: isMe
                      ? _accent.withValues(alpha: 0.08)
                      : _surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isMe
                        ? _accent.withValues(alpha: 0.35)
                        : _border,
                    width: isMe ? 1.5 : 1,
                  ),
                ),
                child: Row(children: [
                  // رتبة / كأس
                  SizedBox(
                    width: 36,
                    child: badge ??
                        Text('#$rank',
                            style: GoogleFonts.cairo(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: rankColor),
                            textAlign: TextAlign.center),
                  ),
                  const SizedBox(width: 10),
                  // صورة
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: _surfaceHigh,
                    backgroundImage: pic != null
                        ? NetworkImage(optimizeImageUrl(pic, width: 80))
                        : null,
                    child: pic == null
                        ? Text(
                            name.isNotEmpty ? name[0].toUpperCase() : '؟',
                            style: GoogleFonts.cairo(
                                color: _accent,
                                fontWeight: FontWeight.w700))
                        : null,
                  ),
                  const SizedBox(width: 12),
                  // الاسم
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Flexible(
                            child: Text(name,
                                style: GoogleFonts.cairo(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: _textPrimary),
                                overflow: TextOverflow.ellipsis),
                          ),
                          if (isMe) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: _accent.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text('أنت',
                                  style: GoogleFonts.cairo(
                                      fontSize: 9,
                                      color: _accent,
                                      fontWeight: FontWeight.w700)),
                            ),
                          ],
                        ]),
                        Text(label,
                            style: GoogleFonts.cairo(
                                fontSize: 10, color: _textSecondary)),
                      ],
                    ),
                  ),
                  // النقاط
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('$pts',
                          style: GoogleFonts.cairo(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: rank <= 3 ? rankColor : _gold)),
                      Text('نقطة',
                          style: GoogleFonts.cairo(
                              fontSize: 10, color: _textSecondary)),
                    ],
                  ),
                ]),
              ),
            );
          },
        );
      },
    );
  }
}
