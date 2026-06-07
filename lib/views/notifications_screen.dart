import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:my_first_app/views/home/novel_detail_screen.dart';
import 'package:my_first_app/views/home/novel_reader_screen.dart';
import 'package:my_first_app/views/author_screen.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  Color _bg            = const Color(0xFF0D0F14);
  Color _surface       = const Color(0xFF161920);
  Color _surfaceHigh   = const Color(0xFF1E2130);
  static const _accent        = Color(0xFF8BAF7C);
  Color _border        = const Color(0xFF252836);
  Color _textPrimary   = const Color(0xFFECECEC);
  Color _textSecondary = const Color(0xFF6B7280);
  static const _gold          = Color(0xFFD4A843);

  Future<void> _markAllRead(String userId) async {
    final snap = await FirebaseFirestore.instance
        .collection('notifications')
        .where('userId', isEqualTo: userId)
        .where('isRead', isEqualTo: false)
        .limit(500)
        .get();
    if (snap.docs.isEmpty) return;
    // تقسيم على دفعات 400 لتجنب تجاوز حد batch (500 عملية)
    const chunkSize = 400;
    for (var i = 0; i < snap.docs.length; i += chunkSize) {
      final chunk = snap.docs.skip(i).take(chunkSize);
      final batch = FirebaseFirestore.instance.batch();
      for (final doc in chunk) {
        batch.update(doc.reference, {'isRead': true});
      }
      await batch.commit();
    }
  }

  Future<void> _confirmDeleteAll() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: _surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('حذف الإشعارات',
            style: GoogleFonts.cairo(color: _textPrimary, fontWeight: FontWeight.w700)),
        content: Text('هل تريد حذف جميع الإشعارات؟',
            style: GoogleFonts.cairo(color: _textSecondary, fontSize: 13)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('إلغاء', style: GoogleFonts.cairo(color: _textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('حذف', style: GoogleFonts.cairo(color: Colors.redAccent, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final snap = await FirebaseFirestore.instance
        .collection('notifications')
        .where('userId', isEqualTo: user.uid)
        .limit(500)
        .get();
    if (snap.docs.isEmpty) return;
    const chunkSize = 400;
    for (var i = 0; i < snap.docs.length; i += chunkSize) {
      final batch = FirebaseFirestore.instance.batch();
      for (final doc in snap.docs.skip(i).take(chunkSize)) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    }
  }

  // ── أيقونة ولون حسب النوع ────────────────────────────────────────────────
  _NotifStyle _getStyle(String type) {
    switch (type) {
      case 'like':
        return _NotifStyle(Icons.favorite_rounded, Colors.redAccent,
            'إعجاب جديد');
      case 'comment':
        return _NotifStyle(Icons.chat_bubble_rounded, Colors.blueAccent,
            'تعليق جديد');
      case 'rating':
        return _NotifStyle(Icons.star_rounded, _gold, 'تقييم جديد');
      case 'follow':
        return _NotifStyle(Icons.person_add_rounded, _accent, 'متابع جديد');
      case 'follow_post':
        return _NotifStyle(Icons.auto_stories_rounded, _accent, 'عمل جديد من متابَع');
      case 'novel_chapter':
        return _NotifStyle(Icons.bookmark_added_rounded, _accent, 'فصل جديد في رواية تتابعها');
      case 'top_rated':
        return _NotifStyle(Icons.workspace_premium_rounded, const Color(0xFFD4A843), 'دخلت قائمة الأعلى تقييماً');
      case 'gift':
        return _NotifStyle(Icons.redeem_rounded, const Color(0xFFD4A843), 'هدية نقاط');
      case 'daily_stats': // #40
        return _NotifStyle(Icons.bar_chart_rounded, Colors.blueGrey, 'إحصائياتك اليومية');
      case 'admin_message': // #45
        return _NotifStyle(Icons.admin_panel_settings_rounded, Colors.purpleAccent, 'رسالة من الإدارة');
      case 'friend_recommendation': // #23
        return _NotifStyle(Icons.recommend_rounded, const Color(0xFF8BAF7C), 'ترشيح رواية من صديق');
      case 'admin_warning':
        return _NotifStyle(Icons.warning_amber_rounded, Colors.orange, 'تحذير من الإدارة');
      case 'admin_action':
        return _NotifStyle(Icons.admin_panel_settings_rounded, Colors.redAccent, 'إجراء إداري');
      case 'report_update':
        return _NotifStyle(Icons.flag_rounded, Colors.blueGrey, 'تحديث البلاغ');
      case 'admin_points':
        return _NotifStyle(Icons.stars_rounded, const Color(0xFFD4A843), 'هدية نقاط من الإدارة');
      case 'broadcast':
        return _NotifStyle(Icons.campaign_rounded, Colors.purpleAccent, 'إعلان من الإدارة');
      case 'novel_completed':
        return _NotifStyle(Icons.auto_stories_rounded, const Color(0xFF8BAF7C), 'رواية اكتملت');
      case 'friend_reading':
        return _NotifStyle(Icons.menu_book_rounded, Colors.blueGrey, 'صديق يقرأ الآن');
      default:
        return _NotifStyle(Icons.notifications_rounded, _textSecondary, 'إشعار');
    }
  }

  // ── تنسيق الوقت ───────────────────────────────────────────────────────────
  String _formatTime(dynamic value) {
    if (value is! Timestamp) return '';
    final date = value.toDate();
    final now  = DateTime.now();
    final diff = now.difference(date);

    if (diff.inMinutes < 1)  return 'الآن';
    if (diff.inMinutes < 60) return 'منذ ${diff.inMinutes} د';
    if (diff.inHours   < 24) return 'منذ ${diff.inHours} س';
    if (diff.inDays    < 7)  return 'منذ ${diff.inDays} أيام';
    return '${date.day}/${date.month}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    _bg           = const Color(0xFF0D0F14);
    _surface      = const Color(0xFF161920);
    _surfaceHigh  = const Color(0xFF1E2130);
    _border       = const Color(0xFF252836);
    _textPrimary  = const Color(0xFFECECEC);
    _textSecondary= const Color(0xFF6B7280);
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: _bg,
      body: CustomScrollView(
        slivers: [
          // ── AppBar ──────────────────────────────────────────────────────
          SliverAppBar(
            pinned: true,
            backgroundColor: _bg,
            elevation: 0,
            title: Text('الإشعارات',
                style: GoogleFonts.cairo(
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                    color: _textPrimary)),
            actions: [
              if (user != null)
                IconButton(
                  icon: const Icon(Icons.delete_sweep_rounded,
                      color: Colors.redAccent, size: 22),
                  tooltip: 'حذف كل الإشعارات',
                  onPressed: _confirmDeleteAll,
                ),
            ],
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(1),
              child: Container(height: 1, color: _border),
            ),
          ),

          // ── المحتوى ─────────────────────────────────────────────────────
          if (user == null)
            SliverFillRemaining(
              child: Center(
                child: Text('يجب تسجيل الدخول',
                    style: GoogleFonts.cairo(color: _textSecondary)),
              ),
            )
          else
            SliverToBoxAdapter(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('notifications')
                    .where('userId', isEqualTo: user.uid)
                    .limit(100)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Padding(
                      padding: EdgeInsets.all(60),
                      child: Center(
                          child: CircularProgressIndicator(
                              color: _accent, strokeWidth: 2)),
                    );
                  }
                  
                  if (snapshot.hasError) {
                    return Center(child: Text('حدث خطأ في جلب الإشعارات', style: GoogleFonts.cairo(color: Colors.redAccent)));
                  }

                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return _buildEmpty();
                  }

                  // الترتيب يدوياً لتجنب الحاجة لـ Index في Firebase
                  final docs = snapshot.data!.docs.toList();
                  docs.sort((a, b) {
                    final aTime = (a.data() as Map)['createdAt'] as Timestamp?;
                    final bTime = (b.data() as Map)['createdAt'] as Timestamp?;
                    if (aTime == null || bTime == null) return 0;
                    return bTime.compareTo(aTime);
                  });

                  final unread =
                      docs.where((d) => (d.data() as Map)['isRead'] != true).length;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // عداد غير المقروءة
                      if (unread > 0)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
                          child: Row(children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: _accent.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                    color: _accent.withValues(alpha: 0.3)),
                              ),
                              child: Text('$unread غير مقروء',
                                  style: GoogleFonts.cairo(
                                      fontSize: 11,
                                      color: _accent,
                                      fontWeight: FontWeight.w700)),
                            ),
                          ]),
                        ),

                      const SizedBox(height: 8),

                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        itemCount: docs.length,
                        itemBuilder: (_, i) {
                          final doc  = docs[i];
                          final data = doc.data() as Map<String, dynamic>;
                          final isRead  = data['isRead'] == true;
                          final type    = data['type']    ?? '';
                          final style   = _getStyle(type);
                          final message = (data['message'] ?? data['body'] ?? '') as String;
                          final time    = _formatTime(data['createdAt']);
                          final novelId = data['novelId'];
                          final senderId= data['senderId'];

                          return GestureDetector(
                            onTap: () async {
                              if (!isRead) doc.reference.update({'isRead': true});
                              final chapterId = data['chapterId'] as String?;

                              // متابع جديد → الملف الشخصي
                              if (type == 'follow' && senderId != null) {
                                Navigator.push(context, MaterialPageRoute(
                                    builder: (_) => AuthorScreen(authorId: senderId, authorName: '')));
                                return;
                              }

                              // تعليق أو فصل جديد → الفصل مباشرة
                              if ((type == 'comment' || type == 'novel_chapter' || type == 'like') &&
                                  novelId != null && chapterId != null) {
                                final db = FirebaseFirestore.instance;
                                final nDoc = await db.collection('novels').doc(novelId).get();
                                if (!context.mounted || !nDoc.exists) return;
                                final chapDoc = await db.collection('novels').doc(novelId)
                                    .collection('chapters').doc(chapterId).get();
                                if (!context.mounted) return;
                                Navigator.push(context, MaterialPageRoute(
                                    builder: (_) => NovelReaderScreen(novel: {
                                      'id': nDoc.id, ...nDoc.data()!,
                                      'chapterId': chapterId,
                                      'chapterTitle': chapDoc.data()?['title'] ?? '',
                                      'content': chapDoc.data()?['content'] ?? '',
                                      'chapterNumber': chapDoc.data()?['chapterNumber'] ?? 1,
                                    })));
                                return;
                              }

                              // رواية / تقييم / غير ذلك → صفحة الرواية
                              if (novelId != null) {
                                final nDoc = await FirebaseFirestore.instance
                                    .collection('novels').doc(novelId).get();
                                if (!context.mounted) return;
                                if (nDoc.exists) {
                                  Navigator.push(context, MaterialPageRoute(
                                      builder: (_) => NovelDetailScreen(
                                          novel: {'id': nDoc.id, ...nDoc.data()!})));
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                    content: Text('هذه الرواية لم تعد متاحة', style: GoogleFonts.cairo()),
                                    backgroundColor: _textSecondary,
                                    behavior: SnackBarBehavior.floating,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ));
                                }
                              }
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: isRead ? _surface : _surfaceHigh,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: isRead
                                      ? _border
                                      : style.color.withValues(alpha: 0.25),
                                  width: isRead ? 1 : 1.5,
                                ),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // أيقونة النوع
                                  Container(
                                    width:  40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: style.color.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(style.icon,
                                        size: 20, color: style.color),
                                  ),
                                  const SizedBox(width: 12),

                                  // النص
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(style.label,
                                            style: GoogleFonts.cairo(
                                                fontSize: 10,
                                                color: style.color,
                                                fontWeight:
                                                    FontWeight.w700)),
                                        const SizedBox(height: 2),
                                        Text(message,
                                            style: GoogleFonts.cairo(
                                              fontSize: 13,
                                              color: isRead
                                                  ? _textSecondary
                                                  : _textPrimary,
                                              fontWeight: isRead
                                                  ? FontWeight.w400
                                                  : FontWeight.w600,
                                              height: 1.5,
                                            )),
                                      ],
                                    ),
                                  ),

                                  // الوقت + نقطة غير مقروء
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.end,
                                    children: [
                                      Text(time,
                                          style: GoogleFonts.cairo(
                                              fontSize: 10,
                                              color: _textSecondary)),
                                      if (!isRead) ...[
                                        const SizedBox(height: 6),
                                        Container(
                                          width:  8,
                                          height: 8,
                                          decoration: BoxDecoration(
                                            color:  style.color,
                                            shape:  BoxShape.circle,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 20),
                    ],
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 80),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width:  80,
              height: 80,
              decoration: BoxDecoration(
                color: _surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _border),
              ),
              child: Icon(Icons.notifications_none_rounded,
                  size: 38, color: _accent.withValues(alpha: 0.4)),
            ),
            const SizedBox(height: 20),
            Text('لا توجد إشعارات بعد',
                style: GoogleFonts.cairo(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: _textPrimary)),
            const SizedBox(height: 8),
            Text(
              'ستصلك إشعارات عندما يتفاعل القراء\nمع روايتك أو فصولك',
              textAlign: TextAlign.center,
              style: GoogleFonts.cairo(
                  fontSize: 13, color: _textSecondary, height: 1.6),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotifStyle {
  final IconData icon;
  final Color    color;
  final String   label;
  const _NotifStyle(this.icon, this.color, this.label);
}