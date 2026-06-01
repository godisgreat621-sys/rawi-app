import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart'; // Add this import
import 'package:my_first_app/providers/novels_provider.dart'; // Add this import
import 'package:my_first_app/models/novel_model.dart';
import 'package:my_first_app/views/home/novel_detail_screen.dart';

class AuthorScreen extends StatefulWidget {
  final String authorId;
  final String authorName;

  const AuthorScreen({
    super.key,
    required this.authorId,
    required this.authorName,
  });

  @override
  State<AuthorScreen> createState() => _AuthorScreenState();
}

class _AuthorScreenState extends State<AuthorScreen> {
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

  @override
  void initState() {
    super.initState();
    _checkIfFollowing();
  }

  Future<void> _checkIfFollowing() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('following')
        .doc(widget.authorId)
        .get();
    if (mounted) setState(() => _isFollowing = doc.exists);
  }

  Future<void> _toggleFollow() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.uid == widget.authorId) return;
    
    setState(() => _isFollowLoading = true);
    await context.read<NovelsProvider>().toggleFollow(widget.authorId);
    if (mounted) {
      setState(() {
        _isFollowing = !_isFollowing;
        _isFollowLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final isMe = currentUser?.uid == widget.authorId;

    return Scaffold(
      backgroundColor: _bg,
      body: StreamBuilder<DocumentSnapshot>(
        // ── جلب بيانات الكاتب (الاسم + الصورة + النقاط) ──────────────────
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(widget.authorId)
            .snapshots(),
        builder: (_, userSnap) {
          final userData = userSnap.hasData && userSnap.data!.exists
              ? userSnap.data!.data() as Map<String, dynamic>
              : <String, dynamic>{};

          final displayName   = userData['displayName']    ?? widget.authorName;
          final profilePic    = userData['profilePicture'] as String?;
          final points        = userData['points']         ?? 0;
          final joinedAt      = (userData['createdAt'] as Timestamp?)?.toDate();
          final joinYear      = joinedAt?.year.toString() ?? '';

          return CustomScrollView(
            slivers: [
              // ── Header ──────────────────────────────────────────────────
              SliverAppBar(
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
                expandedHeight: 230,
                flexibleSpace: FlexibleSpaceBar(
                  background: Container(
                    decoration: const BoxDecoration(color: _bg),
                    child: Stack(
                      children: [
                        // خلفية ضبابية
                        Positioned.fill(
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  _accent.withOpacity(0.06),
                                  _bg,
                                ],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              ),
                            ),
                          ),
                        ),
                        // المحتوى
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const SizedBox(height: 50),
                            // الصورة الشخصية
                            Container(
                              width: 82,
                              height: 82,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: _accent, width: 2),
                              ),
                              child: CircleAvatar(
                                radius: 40,
                                backgroundColor: _surface,
                                backgroundImage: profilePic != null
                                    ? NetworkImage(profilePic)
                                    : null,
                                child: profilePic == null
                                    ? Text(
                                        displayName.isNotEmpty
                                            ? displayName[0].toUpperCase()
                                            : '؟',
                                        style: GoogleFonts.cairo(
                                          fontSize: 30,
                                          fontWeight: FontWeight.w700,
                                          color: _accent,
                                        ),
                                      )
                                    : null,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              displayName,
                              style: GoogleFonts.cairo(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: _textPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'كاتب في راوي',
                                  style: GoogleFonts.cairo(
                                    fontSize: 12,
                                    color: _textSecondary,
                                  ),
                                ),
                                if (joinYear.isNotEmpty) ...[
                                  Text('  ·  ',
                                      style: GoogleFonts.cairo(
                                          color: _textSecondary, fontSize: 12)),
                                  Text(
                                    'منذ $joinYear',
                                    style: GoogleFonts.cairo(
                                      fontSize: 12,
                                      color: _textSecondary,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
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

              // ── المحتوى ─────────────────────────────────────────────────
              SliverToBoxAdapter(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('novels')
                      .where('authorId', isEqualTo: widget.authorId)
                      .snapshots(),
                  builder: (_, novelsSnap) {
                    final novels = novelsSnap.hasData
                        ? novelsSnap.data!.docs
                            .map((d) => Novel.fromFirestore(d))
                            .toList()
                        : <Novel>[];

                    final totalLikes   = novels.fold(0, (s, n) => s + n.likes);
                    final totalReaders = novels.fold(0, (s, n) => s + n.readers);
                    final avgRating    = novels.isEmpty
                        ? 0.0
                        : novels.fold(0.0, (s, n) => s + n.rating) /
                            novels.length;

                    return Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),

                          // ── بطاقة الإحصائيات ────────────────────────────
                          Container(
                            padding: const EdgeInsets.symmetric(
                                vertical: 16, horizontal: 8),
                            decoration: BoxDecoration(
                              color: _surface,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: _border),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                _stat(novels.length.toString(), 'رواية',
                                    Icons.auto_stories_rounded, _accent),
                                _vDivider(),
                                _stat(totalReaders.toString(), 'قارئ',
                                    Icons.remove_red_eye_rounded,
                                    Colors.blueGrey),
                                _vDivider(),
                                _stat(totalLikes.toString(), 'إعجاب',
                                    Icons.favorite_rounded, Colors.redAccent),
                                _vDivider(),
                                _stat(avgRating.toStringAsFixed(1), 'تقييم',
                                    Icons.star_rounded, _gold),
                              ],
                            ),
                          ),

                          // ── نقاط + زر متابعة ────────────────────────────
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              // النقاط
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 10, horizontal: 14),
                                  decoration: BoxDecoration(
                                    color: _surface,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: _border),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.stars_rounded,
                                          color: _gold, size: 18),
                                      const SizedBox(width: 6),
                                      Text(
                                        '$points نقطة',
                                        style: GoogleFonts.cairo(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: _gold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                              // زر المتابعة (للآخرين فقط)
                              if (!isMe) ...[
                                const SizedBox(width: 10),
                                _isFollowLoading
                                    ? const SizedBox(
                                        width: 24,
                                        height: 24,
                                        child: CircularProgressIndicator(
                                            color: _accent, strokeWidth: 2),
                                      )
                                    : GestureDetector(
                                        onTap: _toggleFollow,
                                        child: AnimatedContainer(
                                          duration:
                                              const Duration(milliseconds: 200),
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 20, vertical: 10),
                                          decoration: BoxDecoration(
                                            color: _isFollowing
                                                ? _surface
                                                : _accent,
                                            borderRadius:
                                                BorderRadius.circular(10),
                                            border: Border.all(
                                              color: _isFollowing
                                                  ? _border
                                                  : _accent,
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                _isFollowing
                                                    ? Icons
                                                        .person_remove_outlined
                                                    : Icons.person_add_outlined,
                                                size: 16,
                                                color: _isFollowing
                                                    ? _textSecondary
                                                    : const Color(0xFF0D0F14),
                                              ),
                                              const SizedBox(width: 6),
                                              Text(
                                                _isFollowing
                                                    ? 'متابَع'
                                                    : 'تابع',
                                                style: GoogleFonts.cairo(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w700,
                                                  color: _isFollowing
                                                      ? _textSecondary
                                                      : const Color(0xFF0D0F14),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                              ],
                            ],
                          ),

                          const SizedBox(height: 24),

                          // ── روايات الكاتب ────────────────────────────────
                          Row(
                            children: [
                              Container(
                                width: 3,
                                height: 16,
                                decoration: BoxDecoration(
                                  color: _accent,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'روايات الكاتب',
                                style: GoogleFonts.cairo(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: _textSecondary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),

                          // ← إصلاح: استخدام القائمة الكاملة بدون فلتر status خاطئ
                          novels.isEmpty
                              ? Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 30),
                                  child: Center(
                                    child: Text(
                                      'لا توجد روايات بعد.',
                                      style: GoogleFonts.cairo(
                                          color: _textSecondary),
                                    ),
                                  ),
                                )
                              : ListView.builder(
                                  shrinkWrap: true,
                                  physics:
                                      const NeverScrollableScrollPhysics(),
                                  itemCount: novels.length,
                                  itemBuilder: (_, i) =>
                                      _buildNovelCard(context, novels[i]),
                                ),

                          const SizedBox(height: 30),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ── بطاقة رواية ───────────────────────────────────────────────────────────
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
              'author':      novel.author,
              'authorId':    novel.authorId,
              'category':    novel.category,
              'description': novel.description,
              'content':     novel.content,
              'rating':      novel.rating.toString(),
              'likes':       novel.likes.toString(),
              'readers':     novel.readers.toString(),
              'coverUrl':    novel.coverUrl,
            },
          ),
        ),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _border),
        ),
        child: Row(
          children: [
            // مصغّر الغلاف
            Container(
              width: 50,
              height: 70,
              decoration: BoxDecoration(
                color: _surfaceHigh,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _border),
                image: novel.coverUrl != null
                    ? DecorationImage(
                        image: NetworkImage(novel.coverUrl!),
                        fit: BoxFit.cover)
                    : null,
              ),
              child: novel.coverUrl == null
                  ? Icon(Icons.auto_stories_rounded,
                      color: _accent.withOpacity(0.4), size: 22)
                  : null,
            ),
            const SizedBox(width: 12),

            // المعلومات
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          novel.title,
                          style: GoogleFonts.cairo(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: _textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isCompleted)
                        Container(
                          margin: const EdgeInsets.only(right: 6),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: Text(
                            'مكتملة',
                            style: GoogleFonts.cairo(
                              fontSize: 9,
                              color: Colors.green,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  // التصنيف + الفصول
                  Text(
                    '${novel.category}  ·  ${novel.chaptersCount} فصل',
                    style: GoogleFonts.cairo(
                        fontSize: 11, color: _textSecondary),
                  ),
                  const SizedBox(height: 8),
                  // إحصائيات صغيرة
                  Row(
                    children: [
                      Icon(Icons.star_rounded, size: 12, color: _gold),
                      const SizedBox(width: 3),
                      Text(
                        novel.rating.toStringAsFixed(1),
                        style: GoogleFonts.cairo(
                            fontSize: 11, color: _textSecondary),
                      ),
                      const SizedBox(width: 12),
                      Icon(Icons.favorite_rounded,
                          size: 12, color: Colors.redAccent),
                      const SizedBox(width: 3),
                      Text(
                        novel.likes.toString(),
                        style: GoogleFonts.cairo(
                            fontSize: 11, color: _textSecondary),
                      ),
                      const SizedBox(width: 12),
                      Icon(Icons.remove_red_eye_rounded,
                          size: 12, color: Colors.blueGrey),
                      const SizedBox(width: 3),
                      Text(
                        novel.readers.toString(),
                        style: GoogleFonts.cairo(
                            fontSize: 11, color: _textSecondary),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const Icon(Icons.arrow_forward_ios_rounded,
                size: 14, color: _textSecondary),
          ],
        ),
      ),
    );
  }

  // ── مساعدات ───────────────────────────────────────────────────────────────
  Widget _stat(String value, String label, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.cairo(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: _textPrimary,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.cairo(fontSize: 10, color: _textSecondary),
        ),
      ],
    );
  }

  Widget _vDivider() =>
      Container(height: 40, width: 1, color: _border);
}