import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  static const _bg            = Color(0xFF0D0F14);
  static const _surface       = Color(0xFF161920);
  static const _surfaceHigh   = Color(0xFF1E2130);
  static const _accent        = Color(0xFF8BAF7C);
  static const _border        = Color(0xFF252836);
  static const _textPrimary   = Color(0xFFECECEC);
  static const _textSecondary = Color(0xFF6B7280);
  static const _gold          = Color(0xFFD4A843);

  Future<void> _markAllRead(String userId) async {
    final snap = await FirebaseFirestore.instance
        .collection('notifications')
        .where('userId', isEqualTo: userId)
        .where('isRead', isEqualTo: false)
        .get();
    final batch = FirebaseFirestore.instance.batch();
    for (final doc in snap.docs) {
      batch.update(doc.reference, {'isRead': true});
    }
    await batch.commit();
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
      default:
        return _NotifStyle(Icons.notifications_rounded, _textSecondary,
            'إشعار');
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
                TextButton(
                  onPressed: () => _markAllRead(user.uid),
                  child: Text('قراءة الكل',
                      style: GoogleFonts.cairo(
                          fontSize: 13,
                          color: _accent,
                          fontWeight: FontWeight.w600)),
                ),
              const SizedBox(width: 4),
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
                    .orderBy('createdAt', descending: true)
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

                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return _buildEmpty();
                  }

                  final docs = snapshot.data!.docs;
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
                                color: _accent.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                    color: _accent.withOpacity(0.3)),
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
                          final message = data['message'] ?? '';
                          final time    = _formatTime(data['createdAt']);

                          return GestureDetector(
                            onTap: () {
                              if (!isRead) {
                                doc.reference.update({'isRead': true});
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
                                      : style.color.withOpacity(0.25),
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
                                      color: style.color.withOpacity(0.12),
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
                  size: 38, color: _accent.withOpacity(0.4)),
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