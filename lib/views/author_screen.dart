import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:my_first_app/providers/novels_provider.dart';
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
  Color _bg           = const Color(0xFF0D0F14);
  Color _surface      = const Color(0xFF161920);
  Color _surfaceHigh  = const Color(0xFF1E2130);
  static const _accent       = Color(0xFF8BAF7C);
  Color _border       = const Color(0xFF252836);
  Color _textPrimary  = const Color(0xFFECECEC);
  Color _textSecondary= const Color(0xFF6B7280);
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

  String _getWriterRank(int points) {
    if (points >= 2000) return 'عميد الرواة';
    if (points >= 1000) return 'أديب متألق';
    if (points >= 500)  return 'حكواتي متمكن';
    if (points >= 100)  return 'كاتب واعد';
    return 'راوي ناشئ';
  }

  Color _getRankColor(int points) {
    if (points >= 2000) return _gold;
    if (points >= 500)  return _accent;
    return _textSecondary;
  }

  // التيمات المتاحة لصفحة الكاتب
  static const Map<String, Map<String, dynamic>> profileThemes = {
    'default':  {'label': 'راوي الليل',   'accent': Color(0xFF8BAF7C), 'grad1': Color(0xFF1A2E1A), 'icon': '🌿'},
    'sakura':   {'label': 'ساكورا',        'accent': Color(0xFFE891B2), 'grad1': Color(0xFF2D1A22), 'icon': '🌸'},
    'ocean':    {'label': 'المحيط',        'accent': Color(0xFF5BAFD6), 'grad1': Color(0xFF0E1E2E), 'icon': '🌊'},
    'sunset':   {'label': 'الغروب',        'accent': Color(0xFFE8945B), 'grad1': Color(0xFF2A1A0E), 'icon': '🌅'},
    'galaxy':   {'label': 'المجرة',        'accent': Color(0xFFAA7DE8), 'grad1': Color(0xFF1A0E2A), 'icon': '🔮'},
    'desert':   {'label': 'الصحراء',       'accent': Color(0xFFD4A843), 'grad1': Color(0xFF2A1E0A), 'icon': '🏜️'},
    'midnight': {'label': 'منتصف الليل',   'accent': Color(0xFF4A90D9), 'grad1': Color(0xFF0A0E1A), 'icon': '🌙'},
    'forest':   {'label': 'الغابة',        'accent': Color(0xFF5BBF7C), 'grad1': Color(0xFF0E2215), 'icon': '🌲'},
  };

  Color _themeAccent(String? theme) =>
      (profileThemes[theme ?? 'default']?['accent'] as Color?) ?? const Color(0xFF8BAF7C);
  Color _themeGrad(String? theme) =>
      (profileThemes[theme ?? 'default']?['grad1'] as Color?) ?? const Color(0xFF1A2E1A);

  static List<Color> _ringColors(String? theme) {
    switch (theme) {
      case 'sakura':   return [Color(0xFFE891B2), Color(0xFFFFD6EC), Color(0xFFE26BA0)];
      case 'ocean':    return [Color(0xFF5BAFD6), Color(0xFF38D9C8), Color(0xFF2C7EA8)];
      case 'sunset':   return [Color(0xFFE8945B), Color(0xFFFFD166), Color(0xFFE06030)];
      case 'galaxy':   return [Color(0xFFAA7DE8), Color(0xFFD4A8FF), Color(0xFF6A3FB0)];
      case 'desert':   return [Color(0xFFD4A843), Color(0xFFFFE082), Color(0xFFAD7E1A)];
      case 'midnight': return [Color(0xFF4A90D9), Color(0xFF7AB8F5), Color(0xFF1A4A80)];
      case 'forest':   return [Color(0xFF5BBF7C), Color(0xFF9BE8AA), Color(0xFF2A7A45)];
      default:         return [Color(0xFF8BAF7C), Color(0xFFBEE0A8), Color(0xFF4A7A35)];
    }
  }

  static double _ringGlow(String? theme) {
    switch (theme) {
      case 'galaxy': return 0.55;
      case 'sunset': case 'desert': return 0.45;
      case 'sakura': return 0.42;
      default: return 0.35;
    }
  }

  @override
  Widget build(BuildContext context) {
    _bg           = const Color(0xFF0D0F14);
    _surface      = const Color(0xFF161920);
    _surfaceHigh  = const Color(0xFF1E2130);
    _border       = const Color(0xFF252836);
    _textPrimary  = const Color(0xFFECECEC);
    _textSecondary= const Color(0xFF6B7280);
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
          if (!userSnap.hasData) {
            return const Center(child: CircularProgressIndicator(color: _accent));
          }
          final userData = userSnap.data!.exists
              ? userSnap.data!.data() as Map<String, dynamic>
              : <String, dynamic>{};

          final displayName   = userData['displayName']    ?? widget.authorName;
          final profilePic    = userData['profilePicture'] as String?;
          final points        = userData['points']         ?? 0;
          final showPoints    = userData['showPublicPoints']   ?? true;
          final showRatings   = userData['showPublicRatings']  ?? true;
          final showFollowers = userData['showFollowers']       ?? true;
          final showFollowing = userData['showFollowing']       ?? true;
          final profileVisibility = (userData['profileVisibility'] as String?) ?? 'public';
          final profileTheme  = userData['profileTheme']       as String?;
          final tAccent = _themeAccent(profileTheme);
          final tGrad   = _themeGrad(profileTheme);
          final joinedAt      = (userData['createdAt'] as Timestamp?)?.toDate();
          final joinYear      = joinedAt?.year.toString() ?? '';

          // إذا كان الملف خاصاً وليس صاحبه
          if (!isMe && profileVisibility == 'private') {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.lock_rounded, size: 48, color: _textSecondary),
                  const SizedBox(height: 12),
                  Text('هذا الحساب خاص', style: GoogleFonts.cairo(color: _textSecondary, fontSize: 15)),
                ],
              ),
            );
          }

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
                      icon: Icon(Icons.arrow_back_ios_new_rounded,
                          color: _textPrimary, size: 16),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                ),
                // #44 زر مشاركة ملف الكاتب + زر الإبلاغ
                actions: [
                  IconButton(
                    icon: Icon(Icons.share_outlined, color: _textSecondary, size: 20),
                    tooltip: 'مشاركة',
                    onPressed: () {
                      Clipboard.setData(ClipboardData(
                          text: 'تابع الكاتب "${widget.authorName}" على منصة راوي!\nرمز الكاتب: ${widget.authorId}'));
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text('تم نسخ رابط الكاتب ✓',
                            style: GoogleFonts.cairo()),
                        backgroundColor: _accent,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ));
                    },
                  ),
                  if (!isMe)
                    IconButton(
                      icon: const Icon(Icons.flag_outlined, color: Colors.redAccent, size: 20),
                      tooltip: 'إبلاغ',
                      onPressed: () => _showProfileReportDialog(widget.authorId),
                    ),
                ],
                expandedHeight: 200,
                flexibleSpace: FlexibleSpaceBar(
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      // صورة الكاتب في الخلفية — ظهور خفيف بدون ضبابية
                      if (profilePic != null)
                        Opacity(
                          opacity: 0.28,
                          child: Image.network(
                            profilePic,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const SizedBox(),
                          ),
                        )
                      else
                        Container(color: _bg),
                      // طبقة لون التيم فوق الصورة
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              tGrad.withValues(alpha: 0.92),
                              tAccent.withValues(alpha: 0.50),
                              _bg.withValues(alpha: 0.95),
                            ],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                      ),
                      // المحتوى
                      Padding(
                        padding: const EdgeInsets.only(top: 56, bottom: 16),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // الصورة الشخصية — إطار مزخرف متدرج بحسب الثيم
                            Builder(builder: (_) {
                              final rc = _ringColors(profileTheme);
                              final glow = _ringGlow(profileTheme);
                              final isAccent = profileTheme == 'galaxy' || profileTheme == 'desert';
                              final innerFrame = Container(
                                padding: const EdgeInsets.all(2.5),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: LinearGradient(
                                    colors: rc,
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  boxShadow: [BoxShadow(color: tAccent.withValues(alpha: glow), blurRadius: 18, spreadRadius: isAccent ? 2 : 0)],
                                ),
                                child: Container(
                                  padding: const EdgeInsets.all(2),
                                  decoration: BoxDecoration(shape: BoxShape.circle, color: _bg),
                                  child: CircleAvatar(
                                    radius: 38,
                                    backgroundColor: _surface,
                                    backgroundImage: profilePic != null ? NetworkImage(profilePic) : null,
                                    child: profilePic == null
                                        ? Text(
                                            displayName.isNotEmpty ? displayName[0].toUpperCase() : '؟',
                                            style: GoogleFonts.cairo(fontSize: 28, fontWeight: FontWeight.w700, color: tAccent),
                                          )
                                        : null,
                                  ),
                                ),
                              );
                              return Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: tAccent.withValues(alpha: isAccent ? 0.45 : 0.25),
                                    width: 1,
                                  ),
                                ),
                                child: innerFrame,
                              );
                            }),
                            const SizedBox(height: 12),
                            // #35 اسم الكاتب + شارة التوثيق
                            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                              Text(
                                displayName,
                                style: GoogleFonts.cairo(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: _textPrimary,
                                ),
                              ),
                              if (userData['isVerified'] == true) ...[
                                const SizedBox(width: 6),
                                const Icon(Icons.verified_rounded,
                                    color: Colors.blueAccent, size: 18),
                              ],
                            ]),
                            const SizedBox(height: 4),
                            // عرض رتبة الكاتب للآخرين
                            Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: showPoints ? _gold.withValues(alpha: 0.1) : _border,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              showPoints ? _getWriterRank(points) : 'راوي',
                              style: GoogleFonts.cairo(fontSize: 10, fontWeight: FontWeight.bold, color: showPoints ? _gold : _textSecondary),
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
                      ),
                    ],
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
                      .orderBy('createdAt', descending: true)
                      .limit(20)
                      .snapshots(),
                  builder: (_, novelsSnap) {
                    final novels = novelsSnap.hasData
                        ? novelsSnap.data!.docs
                            .map((d) => Novel.fromFirestore(d))
                            .toList()
                        : <Novel>[];

                    final avgRating    = novels.isEmpty
                        ? 0.0
                        : novels.fold(0.0, (s, n) => s + n.rating) /
                            novels.length;
                    final followersCount = (userData['followersCount'] as num?)?.toInt() ?? 0;
                    final followingCount = (userData['followingCount'] as num?)?.toInt() ?? 0;

                    return Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ── النبذة الشخصية — أول ما يراه الزائر ──────────
                          Builder(builder: (_) {
                            final bio = (userData['bio'] as String?)?.trim() ?? '';
                            if (bio.isEmpty) return const SizedBox.shrink();
                            return Container(
                              width: double.infinity,
                              margin: const EdgeInsets.only(bottom: 16),
                              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
                              decoration: BoxDecoration(
                                color: _surface,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: tAccent.withValues(alpha: 0.22)),
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.format_quote_rounded, color: tAccent, size: 20),
                                  const SizedBox(height: 8),
                                  Text(bio,
                                      textAlign: TextAlign.center,
                                      style: GoogleFonts.cairo(
                                          fontSize: 13, color: _textPrimary, height: 1.7)),
                                ],
                              ),
                            );
                          }),

                          // ── بطاقة الإحصائيات الموحّدة ────────────────────
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                            decoration: BoxDecoration(
                              color: _surface,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: tAccent.withValues(alpha: 0.15)),
                            ),
                            child: Wrap(
                              alignment: WrapAlignment.center,
                              spacing: 20,
                              runSpacing: 10,
                              children: [
                                _statCompact(novels.length.toString(), 'رواية',
                                    Icons.auto_stories_rounded, tAccent),
                                _statCompact(
                                  showRatings ? avgRating.toStringAsFixed(1) : '—',
                                  'تقييم',
                                  Icons.star_rounded,
                                  showRatings ? tAccent : _textSecondary,
                                ),
                                if (showFollowers)
                                  _statCompact(followersCount.toString(), 'متابع',
                                      Icons.group_rounded, tAccent),
                                if (showFollowing)
                                  _statCompact(followingCount.toString(), 'يتابع',
                                      Icons.person_rounded, tAccent),
                              ],
                            ),
                          ),

                          // ── زر المتابعة ───────────────────────────────────
                          if (!isMe) ...[
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: _isFollowLoading
                                  ? const Center(child: SizedBox(width: 24, height: 24,
                                      child: CircularProgressIndicator(color: _accent, strokeWidth: 2)))
                                  : GestureDetector(
                                      onTap: _toggleFollow,
                                      child: AnimatedContainer(
                                        duration: const Duration(milliseconds: 200),
                                        padding: const EdgeInsets.symmetric(vertical: 12),
                                        decoration: BoxDecoration(
                                          color: _isFollowing ? _surface : tAccent,
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(
                                              color: _isFollowing ? _border : tAccent),
                                        ),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              _isFollowing
                                                  ? Icons.person_remove_outlined
                                                  : Icons.person_add_outlined,
                                              size: 16,
                                              color: _isFollowing
                                                  ? _textSecondary
                                                  : const Color(0xFF0D0F14),
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              _isFollowing ? 'متابَع' : 'تابع',
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
                            ),
                          ],

                          const SizedBox(height: 20),

                          // ── روايات الكاتب ────────────────────────────────
                          Row(
                            children: [
                              Container(
                                width: 3,
                                height: 16,
                                decoration: BoxDecoration(
                                  color: tAccent,
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
              'id':           novel.id,
              'title':        novel.title,
              'author':       novel.author,
              'authorName':   novel.author,
              'authorId':     novel.authorId,
              'category':     novel.category,
              'description':  novel.description,
              'content':      novel.content,
              'rating':       novel.rating,
              'likes':        novel.likes,
              'readers':      novel.readers,
              'coverUrl':     novel.coverUrl,
              'chaptersCount': novel.chaptersCount,
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
                      color: _accent.withValues(alpha: 0.4), size: 22)
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
                            color: Colors.green.withValues(alpha: 0.12),
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

            Icon(Icons.arrow_forward_ios_rounded,
                size: 14, color: _textSecondary),
          ],
        ),
      ),
    );
  }

  // ── مساعدات ───────────────────────────────────────────────────────────────
  Widget _statCompact(String value, String label, IconData icon, Color color) {
    return SizedBox(
      width: 64,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.cairo(fontSize: 14, fontWeight: FontWeight.w700, color: _textPrimary),
          ),
          Text(
            label,
            style: GoogleFonts.cairo(fontSize: 10, color: _textSecondary),
          ),
        ],
      ),
    );
  }

  // ── إبلاغ عن ملف المستخدم (اسم / صورة) ──────────────────────────────────
  void _showProfileReportDialog(String targetUid) {
    String? selected;
    final reasons = ['اسم مستخدم مسيء', 'صورة غير لائقة', 'انتحال شخصية', 'محتوى مخالف', 'أخرى'];
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(builder: (ctx, setSt) => AlertDialog(
        backgroundColor: _surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('إبلاغ عن الملف الشخصي', style: GoogleFonts.cairo(fontWeight: FontWeight.w700, color: _textPrimary)),
        content: SizedBox(width: 340, child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('سبب البلاغ', style: GoogleFonts.cairo(fontSize: 12, color: _textSecondary)),
          const SizedBox(height: 8),
          Wrap(spacing: 6, runSpacing: 6, children: reasons.map((r) => GestureDetector(
            onTap: () => setSt(() => selected = r),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: selected == r ? _accent.withValues(alpha: 0.15) : _surfaceHigh,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: selected == r ? _accent : _border),
              ),
              child: Text(r, style: GoogleFonts.cairo(fontSize: 12, color: selected == r ? _accent : _textSecondary)),
            ),
          )).toList()),
          const SizedBox(height: 12),
          TextField(
            controller: ctrl,
            style: GoogleFonts.cairo(fontSize: 12, color: _textPrimary),
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'تفاصيل إضافية (اختياري)',
              hintStyle: GoogleFonts.cairo(fontSize: 12, color: _textSecondary),
              filled: true, fillColor: _surfaceHigh,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: _border)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: _border)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: _accent)),
              contentPadding: const EdgeInsets.all(10),
            ),
          ),
        ])),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('إلغاء', style: GoogleFonts.cairo(color: _textSecondary))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            onPressed: () async {
              if (selected == null) return;
              final uid = FirebaseAuth.instance.currentUser?.uid;
              if (uid == null) return;
              await FirebaseFirestore.instance.collection('reports').add({
                'type': 'profile',
                'reason': selected,
                'details': ctrl.text.trim(),
                'reportedBy': uid,
                'reportedUser': targetUid,
                'status': 'pending',
                'createdAt': FieldValue.serverTimestamp(),
              });
              if (ctx.mounted) { Navigator.pop(ctx); }
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text('تم إرسال البلاغ ✅', style: GoogleFonts.cairo()),
                  backgroundColor: Colors.green, behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ));
              }
            },
            child: Text('إرسال', style: GoogleFonts.cairo(color: Colors.white)),
          ),
        ],
      )),
    );
  }
}