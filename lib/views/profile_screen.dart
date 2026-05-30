import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:my_first_app/view_models/auth_view_model.dart';
import 'package:my_first_app/models/novel_model.dart';
import 'package:my_first_app/views/home/novel_detail_screen.dart';
import 'package:my_first_app/views/notifications_screen.dart';
import 'package:my_first_app/views/admin_screen.dart';
import 'package:my_first_app/views/writer/add_novel_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme         = Theme.of(context);
    final authViewModel = Provider.of<AuthViewModel>(context);
    final user          = authViewModel.currentUser;
    final isDark        = theme.brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              const SizedBox(height: 20),

              // ── الهيدر: صورة + اسم + جرس ──────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const SizedBox(width: 44),  // توازن
                    Column(
                      children: [
                        CircleAvatar(
                          radius: 46,
                          backgroundColor:
                              theme.colorScheme.primary.withOpacity(0.2),
                          child: Icon(Icons.person,
                              size: 46, color: theme.colorScheme.primary),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          user?.displayName ?? user?.email ?? 'زائر',
                          style: GoogleFonts.cairo(
                              fontSize: 17, fontWeight: FontWeight.bold),
                        ),
                        Text('عضو في منصة راوي ✍️',
                            style: GoogleFonts.cairo(
                                color: Colors.grey, fontSize: 12)),
                      ],
                    ),
                    // جرس الإشعارات
                    StreamBuilder<QuerySnapshot>(
                      stream: user == null
                          ? null
                          : FirebaseFirestore.instance
                                .collection('users').doc(user.uid)
                                .collection('notifications')
                                .where('isRead', isEqualTo: false)
                                .snapshots(),
                      builder: (_, snap) {
                        final unread =
                            snap.hasData ? snap.data!.docs.length : 0;
                        return Stack(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.notifications_outlined),
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const NotificationsScreen(),
                                  ),
                                );
                              },
                            ),
                            if (unread > 0)
                              Positioned(
                                right: 6, top: 6,
                                child: Container(
                                  width: 16, height: 16,
                                  decoration: const BoxDecoration(
                                      color: Colors.redAccent,
                                      shape: BoxShape.circle),
                                  child: Center(
                                    child: Text('$unread',
                                        style: const TextStyle(
                                            fontSize: 9,
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold)),
                                  ),
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // ── إحصائيات ───────────────────────────────────────────────────
              StreamBuilder<QuerySnapshot>(
                stream: user == null
                    ? null
                    : FirebaseFirestore.instance
                          .collection('novels')
                          .where('authorId', isEqualTo: user.uid)
                          .snapshots(),
                builder: (_, snap) {
                  final novels = snap.hasData
                      ? snap.data!.docs
                            .map((d) => Novel.fromFirestore(d))
                            .toList()
                      : <Novel>[];
                  final totalLikes   = novels.fold(0, (s, n) => s + n.likes);
                  final totalReaders = novels.fold(0, (s, n) => s + n.readers);

                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 20),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark
                          ? theme.colorScheme.surface
                          : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _stat(novels.length.toString(), 'رواية', theme),
                        _divider(),
                        _stat(totalLikes.toString(), 'إعجاب', theme),
                        _divider(),
                        _stat(totalReaders.toString(), 'قارئ', theme),
                        _divider(),
                        StreamBuilder<QuerySnapshot>(
                          stream: user == null
                              ? null
                              : FirebaseFirestore.instance
                                    .collection('users').doc(user.uid)
                                    .collection('followers').snapshots(),
                          builder: (_, fs) {
                            final cnt =
                                fs.hasData ? fs.data!.docs.length : 0;
                            return _stat(cnt.toString(), 'متابع', theme);
                          },
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
              StreamBuilder<DocumentSnapshot>(
                stream: user == null
                    ? null
                    : FirebaseFirestore.instance
                          .collection('users').doc(user.uid).snapshots(),
                builder: (_, adminSnap) {
                  final isAdmin = adminSnap.hasData &&
                      (adminSnap.data?.data() as Map<String, dynamic>?)?['role'] == 'admin';
                  if (!isAdmin) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const AdminScreen()),
                          );
                        },
                        icon: const Icon(Icons.admin_panel_settings),
                        label: Text('لوحة الأدمن', style: GoogleFonts.cairo()),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(height: 16),

              // ── نقاطي ──────────────────────────────────────────────────────
              StreamBuilder<DocumentSnapshot>(
                stream: user == null
                    ? null
                    : FirebaseFirestore.instance
                          .collection('users').doc(user.uid).snapshots(),
                builder: (_, snap) {
                  final pts = snap.hasData && snap.data!.exists
                      ? (snap.data!.data() as Map<String, dynamic>)['points'] ?? 0
                      : 0;
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 20),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: theme.colorScheme.primary.withOpacity(0.2)),
                    ),
                    child: Row(children: [
                      Icon(Icons.workspace_premium_rounded,
                          color: Colors.amber, size: 22),
                      const SizedBox(width: 10),
                      Text('نقاطي: $pts نقطة',
                          style: GoogleFonts.cairo(
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.primary)),
                    ]),
                  );
                },
              ),
              const SizedBox(height: 24),

              // ── رواياتي ────────────────────────────────────────────────────
              _sectionTitle('رواياتي 📖', theme, padding: 20),
              const SizedBox(height: 10),

              StreamBuilder<QuerySnapshot>(
                stream: user == null
                    ? null
                    : FirebaseFirestore.instance
                          .collection('novels')
                          .where('authorId', isEqualTo: user.uid)
                          .orderBy('createdAt', descending: true)
                          .snapshots(),
                builder: (_, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Padding(
                        padding: EdgeInsets.all(20),
                        child: CircularProgressIndicator());
                  }
                  if (!snap.hasData || snap.data!.docs.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.all(30),
                      child: Column(children: [
                        Icon(Icons.edit_note,
                            size: 56,
                            color: theme.colorScheme.primary.withOpacity(0.3)),
                        const SizedBox(height: 10),
                        Text('لم تنشر أي رواية بعد',
                            style: GoogleFonts.cairo(color: Colors.grey)),
                      ]),
                    );
                  }

                  final novels = snap.data!.docs
                      .map((d) => Novel.fromFirestore(d))
                      .toList();
                  return ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: novels.length,
                    itemBuilder: (_, i) {
                      final n = novels[i];
                      final isCompleted = n.status == 'completed';
                      return Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        elevation: 1.5,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        child: ListTile(
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => NovelDetailScreen(novel: {
                                'id':          n.id,
                                'title':       n.title,
                                'author':      n.author,
                                'authorId':    n.authorId,
                                'category':    n.category,
                                'description': n.description,
                                'content':     n.content,
                                'rating':      n.rating.toString(),
                                'likes':       n.likes.toString(),
                                'readers':     n.readers.toString(),
                              }),
                            ),
                          ),
                          leading: CircleAvatar(
                            backgroundColor:
                                theme.colorScheme.primary.withOpacity(0.1),
                            child: Icon(Icons.auto_stories,
                                color: theme.colorScheme.primary),
                          ),
                          title: Row(children: [
                            Expanded(
                              child: Text(n.title,
                                  style: GoogleFonts.cairo(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14),
                                  overflow: TextOverflow.ellipsis),
                            ),
                            if (isCompleted)
                              Container(
                                margin: const EdgeInsets.only(right: 6),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.green.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text('مكتملة',
                                    style: GoogleFonts.cairo(
                                        fontSize: 10,
                                        color: Colors.green,
                                        fontWeight: FontWeight.bold)),
                              ),
                          ]),
                          subtitle: Text(
                            '${n.category}  •  ${n.chaptersCount} فصل',
                            style: GoogleFonts.cairo(
                                fontSize: 11, color: Colors.grey),
                          ),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Row(mainAxisSize: MainAxisSize.min, children: [
                                const Icon(Icons.favorite,
                                    size: 11, color: Colors.redAccent),
                                const SizedBox(width: 3),
                                Text(n.likes.toString(),
                                    style: GoogleFonts.cairo(
                                        fontSize: 10, color: Colors.grey)),
                              ]),
                              Row(mainAxisSize: MainAxisSize.min, children: [
                                const Icon(Icons.remove_red_eye,
                                    size: 11, color: Colors.blueGrey),
                                const SizedBox(width: 3),
                                Text(n.readers.toString(),
                                    style: GoogleFonts.cairo(
                                        fontSize: 10, color: Colors.grey)),
                              ]),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),

              // ── المسودات ───────────────────────────────────────────────────
              const SizedBox(height: 24),
              _sectionTitle('مسوداتي 📝', theme, padding: 20),
              const SizedBox(height: 10),

              StreamBuilder<QuerySnapshot>(
                stream: user == null
                    ? null
                    : FirebaseFirestore.instance
                          .collection('drafts')
                          .where('authorId', isEqualTo: user.uid)
                          .snapshots(),
                builder: (_, snap) {
                  if (!snap.hasData || snap.data!.docs.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                      child: Text('لا توجد مسودات.',
                          style: GoogleFonts.cairo(
                              color: Colors.grey, fontSize: 13)),
                    );
                  }
                  final drafts = snap.data!.docs;
                  return ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: drafts.length,
                    itemBuilder: (_, i) {
                      final d = drafts[i].data() as Map<String, dynamic>;
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        elevation: 1,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                        child: ListTile(
                          leading: Icon(Icons.edit_note,
                              color: theme.colorScheme.primary),
                          title: Text(
                        d['isNewNovel'] == true
                            ? 'مسودة رواية: ${d['novelTitle'] ?? 'بدون عنوان'}'
                            : 'مسودة فصل: ${d['chapterTitle'] ?? 'بدون عنوان'}',
                        style: GoogleFonts.cairo(
                            fontWeight: FontWeight.bold,
                            fontSize: 13)),
                      subtitle: Text(
                        'تصنيف: ${d['category'] ?? 'عام'} • ${d['wordCount'] ?? 0} كلمة',
                        style: GoogleFonts.cairo(
                            fontSize: 11, color: Colors.grey),
                      ),
                          trailing: TextButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => AddNovelScreen(
                                    draftId: drafts[i].id,
                                    novelId: d['novelId'] as String?,
                                    novelTitle: d['novelTitle'] as String?,
                                  ),
                                ),
                              );
                            },
                            child: Text('فتح',
                                style: GoogleFonts.cairo(
                                    color: theme.colorScheme.primary,
                                    fontWeight: FontWeight.bold)),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),

              const SizedBox(height: 24),

              // ── تسجيل خروج ─────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => authViewModel.logout(),
                    icon: const Icon(Icons.logout, color: Colors.redAccent),
                    label: Text('تسجيل الخروج',
                        style: GoogleFonts.cairo(color: Colors.redAccent)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.redAccent),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  Widget _stat(String value, String label, ThemeData theme) {
    return Column(
      children: [
        Text(value,
            style: GoogleFonts.cairo(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary)),
        Text(label,
            style: GoogleFonts.cairo(fontSize: 11, color: Colors.grey)),
      ],
    );
  }

  Widget _divider() =>
      Container(height: 36, width: 1, color: Colors.grey.withOpacity(0.3));

  Widget _sectionTitle(String title, ThemeData theme, {double padding = 0}) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: padding),
      child: Align(
        alignment: Alignment.centerRight,
        child: Text(title,
            style: GoogleFonts.cairo(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary)),
      ),
    );
  }
}