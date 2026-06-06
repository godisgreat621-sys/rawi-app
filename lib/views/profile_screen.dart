import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:my_first_app/view_models/auth_view_model.dart';
import 'package:my_first_app/repositories/user_repository.dart';
import 'admin_screen.dart';
import 'package:my_first_app/views/author_screen.dart'; // Add this import
import 'package:my_first_app/providers/novels_provider.dart';
import 'package:my_first_app/models/novel_model.dart';
import 'package:my_first_app/views/home/novel_detail_screen.dart';
import 'package:my_first_app/providers/theme_provider.dart';
import 'package:my_first_app/views/privacy_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  static const _accent = Color(0xFF8BAF7C);
  static const _gold   = Color(0xFFD4A843);
  Color _bg          = const Color(0xFF0D0F14);
  Color _surface     = const Color(0xFF161920);
  Color _surfaceHigh = const Color(0xFF1E2130);
  Color _border      = const Color(0xFF252836);
  Color _textPrimary = const Color(0xFFECECEC);
  Color _textSecondary = const Color(0xFF6B7280);

  // دور المستخدم — لإظهار زر الأدمن بدون الكشف للآخرين
  String _myRole = 'user';

  bool _isUploading = false;

  Future<void> _pickAndUploadImage() async {
    if (_isUploading) return;
    try {
      // اختر الصورة أولاً قبل أي setState حتى لا تتعطل نافذة الاختيار
      final bytes = await UserRepository.pickImageOnly();
      if (bytes == null) return; // المستخدم ألغى
      if (!mounted) return;
      setState(() => _isUploading = true);
      await UserRepository.uploadProfilePictureBytes(bytes);
      if (mounted) {
        setState(() => _isUploading = false);
        _showSnack('تم تحديث الصورة الشخصية ✅', Colors.green);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploading = false);
        _showSnack(e.toString().replaceFirst('Exception: ', ''), Colors.redAccent);
      }
    }
  }

  // ── نظام تغيير الاسم: مرة كل 30 يوماً ────────────────────────────────────
  void _showEditNameDialog(String currentName, Map<String, dynamic>? userData) {
    final controller = TextEditingController(text: currentName);
    final lastChanged = (userData?['nameLastChangedAt'] as Timestamp?)
        ?.toDate();
    final now = DateTime.now();
    final canChange =
        lastChanged == null || now.difference(lastChanged).inDays >= 30;
    final daysLeft = canChange ? 0 : 30 - now.difference(lastChanged!).inDays;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'تعديل الاسم',
          style: GoogleFonts.cairo(
            fontWeight: FontWeight.w700,
            color: _textPrimary,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!canChange)
              Container(
                padding: const EdgeInsets.all(10),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.orange.withOpacity(0.3)),
                ),
                child: Text(
                  'يمكنك تغيير اسمك مرة كل 30 يوماً.\nباقي $daysLeft يوم للتغيير القادم.',
                  style: GoogleFonts.cairo(fontSize: 12, color: Colors.orange),
                ),
              ),
            if (canChange)
              Container(
                padding: const EdgeInsets.all(10),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: _accent.withOpacity(0.07),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _accent.withOpacity(0.2)),
                ),
                child: Text(
                  'تنبيه: يرى القراء اسمك على تعليقاتك وتقييماتك.\nاختر اسماً ثابتاً حتى لا يضيع القراء.',
                  style: GoogleFonts.cairo(fontSize: 12, color: _accent),
                ),
              ),
            TextField(
              controller: controller,
              enabled: canChange,
              style: GoogleFonts.cairo(color: _textPrimary, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'اسمك بين القراء',
                hintStyle: GoogleFonts.cairo(color: _textSecondary),
                filled: true,
                fillColor: _surfaceHigh,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: _border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: _border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: _accent, width: 1.5),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'إلغاء',
              style: GoogleFonts.cairo(color: _textSecondary),
            ),
          ),
          if (canChange)
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _accent,
                foregroundColor: const Color(0xFF0D0F14),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () async {
                final newName = controller.text.trim();
                if (newName.isEmpty) return;
                final user = FirebaseAuth.instance.currentUser;
                if (user == null) return;
                // تحديث الاسم + تسجيل وقت التغيير
                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(user.uid)
                    .update({
                      'displayName': newName,
                      'nameLastChangedAt': FieldValue.serverTimestamp(),
                    });
                await user.updateDisplayName(newName);
                if (mounted) {
                  Navigator.pop(ctx);
                  _showSnack('تم تحديث اسمك ✅', Colors.green);
                }
              },
              child: Text(
                'حفظ',
                style: GoogleFonts.cairo(fontWeight: FontWeight.w700),
              ),
            ),
        ],
      ),
    );
  }

  // ── نافذة الدعم الفني ─────────────────────────────────────────────────────
  void _showSupportDialog() {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    String selectedType = 'مشكلة تقنية';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          decoration: const BoxDecoration(
            color: Color(0xFF161920),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'الدعم الفني',
                  style: GoogleFonts.cairo(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: _textPrimary,
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: selectedType,
                  dropdownColor: _surfaceHigh,
                  style: GoogleFonts.cairo(color: _textPrimary, fontSize: 13),
                  items: ['مشكلة تقنية', 'اقتراح', 'استفسار عن النقاط', 'أخرى']
                      .map(
                        (e) => DropdownMenuItem(
                          value: e,
                          child: Text(
                            e,
                            style: GoogleFonts.cairo(color: _textPrimary),
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setS(() => selectedType = v!),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: _surfaceHigh,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: _border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: _border),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                _supportField(titleCtrl, 'عنوان المشكلة'),
                const SizedBox(height: 10),
                _supportField(descCtrl, 'اشرح لنا بالتفصيل...', maxLines: 3),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _accent,
                      foregroundColor: const Color(0xFF0D0F14),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () async {
                      await context.read<NovelsProvider>().sendSupportRequest(
                        title: titleCtrl.text,
                        type: selectedType,
                        description: descCtrl.text,
                      );
                      if (mounted) {
                        Navigator.pop(ctx);
                        _showSnack('تم إرسال طلبك ✅', Colors.green);
                      }
                    },
                    child: Text(
                      'إرسال الطلب',
                      style: GoogleFonts.cairo(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _supportField(
    TextEditingController ctrl,
    String hint, {
    int maxLines = 1,
  }) {
    return TextField(
      controller: ctrl,
      maxLines: maxLines,
      style: GoogleFonts.cairo(color: _textPrimary, fontSize: 13),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.cairo(color: _textSecondary, fontSize: 13),
        filled: true,
        fillColor: _surfaceHigh,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: _border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: _border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _accent, width: 1.5),
        ),
      ),
    );
  }

  void _showSnack(String msg, Color bg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: GoogleFonts.cairo()),
        backgroundColor: bg,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDarkMode;
    _bg          = isDark ? const Color(0xFF0D0F14) : const Color(0xFFF5F5F7);
    _surface     = isDark ? const Color(0xFF161920) : const Color(0xFFFFFFFF);
    _surfaceHigh = isDark ? const Color(0xFF1E2130) : const Color(0xFFEEEEF0);
    _textPrimary = isDark ? const Color(0xFFECECEC) : const Color(0xFF111827);
    _textSecondary = isDark ? const Color(0xFF6B7280) : const Color(0xFF555F6E);
    _border      = isDark ? const Color(0xFF252836) : const Color(0xFFE0E0E4);
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return Scaffold(
        backgroundColor: _bg,
        body: Center(
          child: Text(
            'يرجى تسجيل الدخول',
            style: GoogleFonts.cairo(color: _textSecondary),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: _bg,
      floatingActionButton: _myRole == 'admin'
          ? FloatingActionButton(
              backgroundColor: const Color(0xFF1E2130),
              elevation: 2,
              tooltip: 'لوحة التحكم',
              onPressed: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const AdminScreen())),
              child: const Icon(Icons.shield_rounded, color: _accent, size: 22),
            )
          : null,
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: _accent, strokeWidth: 2),
            );
          }

          final userData = snapshot.data?.data() as Map<String, dynamic>?;
          final name = userData?['displayName'] ?? 'مستخدم';
          final email = userData?['email'] ?? user.email ?? '';
          final profilePic = userData?['profilePicture'] as String?;
          final points = userData?['points'] ?? 0;
          final role = userData?['role'] ?? 'user';
          // تحديث الدور الداخلي بصمت (لزر الأدمن العائم)
          if (_myRole != role) {
            WidgetsBinding.instance.addPostFrameCallback(
                (_) => setState(() => _myRole = role));
          }
          final ratingsGiven    = userData?['ratingsGiven']    ?? 0;
          final followersCount  = userData?['followersCount']  ?? 0;
          final followingCount  = userData?['followingCount']  ?? 0;

          return CustomScrollView(
            slivers: [
              // ── Header (تصميم محسَّن) ──────────────────────────────
              SliverAppBar(
                pinned: true,
                backgroundColor: _bg,
                elevation: 0,
                expandedHeight: 120,
                toolbarHeight: 0,
                flexibleSpace: FlexibleSpaceBar(
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      // #2 خلفية ضبابية من صورة البروفايل
                      if (profilePic != null) ...[
                        Image.network(profilePic, fit: BoxFit.cover),
                        BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
                          child: Container(color: _bg.withOpacity(0.82)),
                        ),
                      ] else
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [_accent.withOpacity(0.08), _bg],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                          ),
                        ),
                      // #1 تخطيط مضغوط: صورة يساراً + معلومات يميناً
                      Positioned(
                        bottom: 16, left: 16, right: 16,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Stack(clipBehavior: Clip.none, children: [
                              Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(color: _accent, width: 2.5),
                                  boxShadow: [BoxShadow(color: Colors.black38, blurRadius: 12)],
                                ),
                                child: CircleAvatar(
                                  radius: 38,
                                  backgroundColor: _surface,
                                  backgroundImage: profilePic != null ? NetworkImage(profilePic) : null,
                                  child: profilePic == null
                                      ? Text(name.isNotEmpty ? name[0].toUpperCase() : '؟',
                                          style: GoogleFonts.cairo(fontSize: 26, fontWeight: FontWeight.w700, color: _accent))
                                      : null,
                                ),
                              ),
                              if (_isUploading)
                                Positioned.fill(
                                  child: Container(
                                    decoration: const BoxDecoration(color: Colors.black38, shape: BoxShape.circle),
                                    child: const Center(child: CircularProgressIndicator(color: _accent, strokeWidth: 2)),
                                  ),
                                ),
                              Positioned(
                                bottom: 0, right: 0,
                                child: GestureDetector(
                                  onTap: _isUploading ? null : _pickAndUploadImage,
                                  child: Container(
                                    width: 26, height: 26,
                                    decoration: BoxDecoration(
                                      color: _accent, shape: BoxShape.circle,
                                      border: Border.all(color: _bg, width: 2),
                                    ),
                                    child: const Icon(Icons.camera_alt_rounded, color: Color(0xFF0D0F14), size: 13),
                                  ),
                                ),
                              ),
                            ]),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(children: [
                                    Flexible(
                                      child: Text(name,
                                          style: GoogleFonts.cairo(fontSize: 17, fontWeight: FontWeight.w700, color: _textPrimary),
                                          maxLines: 1, overflow: TextOverflow.ellipsis),
                                    ),
                                    const SizedBox(width: 6),
                                    _roleChip(role), // #3
                                  ]),
                                  const SizedBox(height: 2),
                                  // #7 تاريخ الانضمام
                                  Builder(builder: (_) {
                                    final createdAt = (userData?['createdAt'] as Timestamp?)?.toDate();
                                    if (createdAt == null) return const SizedBox.shrink();
                                    final months = DateTime.now().difference(createdAt).inDays ~/ 30;
                                    final label = months == 0 ? 'عضو هذا الشهر'
                                        : months < 12 ? 'عضو منذ $months شهراً'
                                        : 'عضو منذ ${months ~/ 12} سنة';
                                    return Text(label,
                                        style: GoogleFonts.cairo(fontSize: 9, color: _textSecondary));
                                  }),
                                  Text(email,
                                      style: GoogleFonts.cairo(fontSize: 10, color: _textSecondary),
                                      maxLines: 1, overflow: TextOverflow.ellipsis),
                                ],
                              ),
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

              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      // #5 أربع بطاقات إحصائية في صف واحد
                      Row(children: [
                        Expanded(child: _statBox(Icons.group_outlined, followersCount.toString(), 'متابع', _accent,
                            onTap: () => _showUserList('المتابعون', 'followers'))),
                        const SizedBox(width: 6),
                        Expanded(child: _statBox(Icons.person_add_outlined, followingCount.toString(), 'أتابع', _accent,
                            onTap: () => _showUserList('أتابعهم', 'following'))),
                        const SizedBox(width: 6),
                        Expanded(child: _statBox(Icons.stars_rounded, points.toString(), 'نقطة', _gold,
                            onTap: _showPointsInfoDialog)),
                        const SizedBox(width: 6),
                        Expanded(child: _statBox(Icons.rate_review_rounded, ratingsGiven.toString(), 'تقييم', _textSecondary,
                            onTap: _showRatedNovels)),
                      ]),
                      const SizedBox(height: 16),

                      // #6 شارات الإنجاز — Grid 3 أعمدة
                      Builder(builder: (_) {
                        final badges = List<String>.from(userData?['badges'] ?? []);
                        if (badges.isEmpty) return const SizedBox.shrink();
                        const badgeData = <String, (IconData, Color)>{
                          'مبتدئ':           (Icons.emoji_events_outlined, Color(0xFF6B7280)),
                          'قارئ نشيط':       (Icons.menu_book_rounded,    Color(0xFF8BAF7C)),
                          'محب للأدب':       (Icons.favorite_rounded,     Color(0xFFE06B6B)),
                          'راوي محترف':      (Icons.workspace_premium_rounded, Color(0xFFD4A843)),
                          'أسطورة الروايات': (Icons.star_rounded,         Color(0xFF9B59B6)),
                        };
                        return Container(
                          margin: const EdgeInsets.only(bottom: 14),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text('الإنجازات',
                                style: GoogleFonts.cairo(fontSize: 11, color: _textSecondary, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 8),
                            GridView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 3, crossAxisSpacing: 8,
                                mainAxisSpacing: 8, childAspectRatio: 2.2,
                              ),
                              itemCount: badges.length,
                              itemBuilder: (_, i) {
                                final b     = badges[i];
                                final bd    = badgeData[b] ?? (Icons.star, _accent);
                                final color = bd.$2;
                                return Container(
                                  decoration: BoxDecoration(
                                    color: color.withOpacity(0.08),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: color.withOpacity(0.3)),
                                  ),
                                  child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                                    Icon(bd.$1, size: 14, color: color),
                                    const SizedBox(width: 4),
                                    Flexible(child: Text(b,
                                        style: GoogleFonts.cairo(fontSize: 10, color: color, fontWeight: FontWeight.w700),
                                        maxLines: 1, overflow: TextOverflow.ellipsis)),
                                  ]),
                                );
                              },
                            ),
                          ]),
                        );
                      }),

                      // #40 السيرة الذاتية
                      Builder(builder: (_) {
                        final bio = (userData?['bio'] as String?) ?? '';
                        return Container(
                          margin: const EdgeInsets.only(bottom: 14),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: _surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: _border),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  bio.isEmpty ? 'أضف سيرة ذاتية قصيرة...' : bio,
                                  style: GoogleFonts.cairo(
                                      fontSize: 13,
                                      color: bio.isEmpty ? _textSecondary : _textPrimary,
                                      height: 1.6),
                                ),
                              ),
                              GestureDetector(
                                onTap: () => _showEditBioDialog(bio),
                                child: Icon(Icons.edit_outlined, size: 16, color: _textSecondary),
                              ),
                            ],
                          ),
                        );
                      }),

                      // #17 إحصائيات أسبوعية
                      Builder(builder: (_) {
                        final secs = (userData?['weeklyReadingSeconds'] as num?)?.toInt() ?? 0;
                        final mins = secs ~/ 60;
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: _accent.withOpacity(0.07),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: _accent.withOpacity(0.18)),
                          ),
                          child: Row(children: [
                            const Icon(Icons.auto_stories_outlined, size: 18, color: _accent),
                            const SizedBox(width: 10),
                            Text('هذا الأسبوع:',
                                style: GoogleFonts.cairo(fontSize: 13, color: _textSecondary)),
                            const SizedBox(width: 6),
                            Text('$mins دقيقة قراءة',
                                style: GoogleFonts.cairo(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: _accent)),
                          ]),
                        );
                      }),
                      const SizedBox(height: 8),
                      _decoratedDivider(), // #10

                      // ── الإعدادات الرئيسية ────────────────────────
                      _menuTile(Icons.person_outline_rounded, 'تعديل الاسم',
                          subtitle: 'مرة كل 30 يوماً',
                          onTap: () => _showEditNameDialog(name, userData)),
                      _menuTile(Icons.bookmark_outline_rounded, 'المكتبة الخاصة',
                          onTap: _showBookmarksSheet),
                      // مفتاح الثيم
                      Builder(builder: (_) {
                        final tp = context.watch<ThemeProvider>();
                        return Container(
                          margin: const EdgeInsets.only(bottom: 2),
                          decoration: BoxDecoration(color: _surface,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: _border)),
                          child: SwitchListTile(
                            secondary: Icon(
                              tp.isDarkMode ? Icons.dark_mode_outlined : Icons.light_mode_outlined,
                              color: _accent, size: 20),
                            title: Text(tp.isDarkMode ? 'وضع داكن' : 'وضع فاتح',
                                style: GoogleFonts.cairo(fontSize: 13, color: _textPrimary)),
                            value: tp.isDarkMode,
                            activeThumbColor: _accent,
                            onChanged: (val) async {
                              tp.setDarkMode(val);
                              final u = FirebaseAuth.instance.currentUser;
                              if (u != null) {
                                await FirebaseFirestore.instance
                                    .collection('users').doc(u.uid)
                                    .set({'isDarkMode': val}, SetOptions(merge: true));
                              }
                            },
                          ),
                        );
                      }),
                      const SizedBox(height: 12),

                      // ── شبكة الإجراءات السريعة ─────────────────────
                      GridView.count(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisCount: 4,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                        childAspectRatio: 0.9,
                        children: [
                          _gridAction(Icons.history_rounded,       'النقاط',      _gold,         _showPointsHistory),
                          _gridAction(Icons.leaderboard_rounded,   'المتصدرون',   _gold,         _showLeaderboard),
                          _gridAction(Icons.emoji_events_outlined, 'التحدي',      _accent,       _showWeeklyChallenge),
                          _gridAction(Icons.notifications_outlined,'الإشعارات',   _accent,       _showNotificationSettings),
                          _gridAction(Icons.privacy_tip_outlined,  'الخصوصية',   _textSecondary, () => _showPrivacySettings(userData)),
                          _gridAction(Icons.security_rounded,      'الأمان',      _textSecondary, _showSecuritySessions),
                          _gridAction(Icons.help_outline_rounded,  'الدعم',       _textSecondary, _showSupportDialog),
                          _gridAction(Icons.info_outline_rounded,  'عن راوي',    _textSecondary, _showAboutPlatformDialog),
                        ],
                      ),
                      const SizedBox(height: 8),
                      _menuTile(Icons.policy_outlined, 'سياسة الخصوصية',
                          onTap: () => Navigator.push(context,
                              MaterialPageRoute(builder: (_) => const PrivacyScreen()))),

                      const SizedBox(height: 30),

                      // ── تسجيل الخروج ──────────────────────────────
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () =>
                              context.read<AuthViewModel>().logout(),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.redAccent.withOpacity(0.08),
                            foregroundColor: Colors.redAccent,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(
                                color: Colors.redAccent.withOpacity(0.2),
                              ),
                            ),
                          ),
                          child: Text(
                            'تسجيل الخروج',
                            style: GoogleFonts.cairo(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 30),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ── عرض الروايات التي قيمها المستخدم ─────────────────────────────────────
  void _showRatedNovels() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: _bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'روايات قيمتها',
              style: GoogleFonts.cairo(
                fontWeight: FontWeight.bold,
                color: _accent,
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collectionGroup('ratings')
                  .where('authorId', isEqualTo: user.uid)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData)
                  return const Center(child: CircularProgressIndicator());
                final docs = snapshot.data!.docs;
                if (docs.isEmpty)
                  return Center(
                    child: Text(
                      'لم تقم بتقييم أي رواية بعد',
                      style: GoogleFonts.cairo(color: _textSecondary),
                    ),
                  );

                return ListView.builder(
                  itemCount: docs.length,
                  itemBuilder: (context, i) {
                    final doc  = docs[i];
                    final data = doc.data() as Map<String, dynamic>;
                    // novelId من مسار الوثيقة: novels/{novelId}/ratings/...
                    final novelId = doc.reference.parent.parent?.id ?? '';
                    return ListTile(
                      leading: const Icon(Icons.auto_stories_rounded, color: _accent, size: 18),
                      title: Text(
                        data['novelTitle'] ?? data['comment'] ?? 'رواية',
                        style: GoogleFonts.cairo(color: _textPrimary, fontSize: 13),
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: data['comment'] != null && data['comment'].toString().isNotEmpty
                          ? Text(data['comment'], style: GoogleFonts.cairo(color: _textSecondary, fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis)
                          : null,
                      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                        Text(data['rating'].toString(), style: GoogleFonts.cairo(color: _gold, fontWeight: FontWeight.w700)),
                        const Icon(Icons.star_rounded, color: _gold, size: 14),
                      ]),
                      onTap: novelId.isEmpty ? null : () async {
                        final nd = await FirebaseFirestore.instance.collection('novels').doc(novelId).get();
                        if (!nd.exists || !context.mounted) return;
                        Navigator.push(context, MaterialPageRoute(
                          builder: (_) => NovelDetailScreen(novel: {'id': nd.id, ...nd.data()!}),
                        ));
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ── ميزة مبتكرة: نظام الرتب بناءً على النقاط ────────────────────────────────
  String _getWriterRank(int points) {
    if (points >= 2000) return 'عميد الرواة';
    if (points >= 1000) return 'أديب متألق';
    if (points >= 500) return 'حكواتي متمكن';
    if (points >= 100) return 'كاتب واعد';
    return 'راوي ناشئ';
  }

  Color _getRankColor(int points) {
    if (points >= 2000) return _gold;
    if (points >= 500) return _accent;
    return _textSecondary;
  }

  // ── عرض الروايات المحفوظة (المحفوظات) ──────────────────────────────────
  void _showBookmarksSheet() {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: _bg,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Container(
        height: MediaQuery.of(ctx).size.height * 0.7,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'المحفوظات (للقراءة لاحقاً)',
                style: GoogleFonts.cairo(
                  fontWeight: FontWeight.bold,
                  color: _accent,
                ),
              ),
            ),
            Expanded(
              child: StreamBuilder<List<Novel>>(
                stream: context
                    .read<NovelsProvider>()
                    .getBookmarkedNovelsStream(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData)
                    return const Center(child: CircularProgressIndicator());
                  final items = snapshot.data!;
                  if (items.isEmpty)
                    return Center(
                      child: Text(
                        'لا توجد روايات محفوظة',
                        style: GoogleFonts.cairo(color: _textSecondary),
                      ),
                    );
                  return ListView.builder(
                    itemCount: items.length,
                    itemBuilder: (context, index) =>
                        _buildNovelListTile(items[index]),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNovelListTile(Novel novel) {
    return ListTile(
      leading: Container(
        width: 40,
        height: 60,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(4),
          color: _surfaceHigh,
          image: novel.coverUrl != null
              ? DecorationImage(
                  image: NetworkImage(novel.coverUrl!),
                  fit: BoxFit.cover,
                )
              : null,
        ),
      ),
      title: Text(
        novel.title,
        style: GoogleFonts.cairo(color: _textPrimary, fontSize: 13),
      ),
      subtitle: Text(
        novel.author,
        style: GoogleFonts.cairo(color: _textSecondary, fontSize: 11),
      ),
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
              'coverUrl':     novel.coverUrl,
              'rating':       novel.rating,
              'likes':        novel.likes,
              'readers':      novel.readers,
              'chaptersCount': novel.chaptersCount,
            },
          ),
        ),
      ),
    );
  }

  // ── عرض قوائم المتابعين والمتابعين ────────────────────────────────────────
  void _showUserList(String title, String collectionPath) {
    HapticFeedback.selectionClick();
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: _bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection(collectionPath)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData)
            return const Center(child: CircularProgressIndicator());
          final docs = snapshot.data!.docs;
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  title,
                  style: GoogleFonts.cairo(
                    fontWeight: FontWeight.bold,
                    color: _accent,
                  ),
                ),
              ),
              Expanded(
                child: docs.isEmpty
                    ? Center(
                        child: Text(
                          'القائمة فارغة',
                          style: GoogleFonts.cairo(color: _textSecondary),
                        ),
                      )
                    : ListView.builder(
                        itemCount: docs.length,
                        itemBuilder: (context, i) =>
                            FutureBuilder<DocumentSnapshot>(
                              future: FirebaseFirestore.instance
                                  .collection('users')
                                  .doc(docs[i].id)
                                  .get(),
                              builder: (context, userSnap) {
                                if (!userSnap.hasData) return const SizedBox();
                                final uData =
                                    userSnap.data!.data()
                                        as Map<String, dynamic>;
                                return ListTile(
                                  leading: CircleAvatar(
                                    backgroundImage:
                                        uData['profilePicture'] != null
                                        ? NetworkImage(uData['profilePicture'])
                                        : null,
                                  ),
                                  title: Text(
                                    uData['displayName'] ?? 'مستخدم',
                                    style: GoogleFonts.cairo(
                                      color: _textPrimary,
                                    ),
                                  ),
                                  trailing: collectionPath == 'following'
                                      ? TextButton(
                                          onPressed: () => context
                                              .read<NovelsProvider>()
                                              .toggleFollow(docs[i].id),
                                          child: Text(
                                            'إلغاء المتابعة',
                                            style: GoogleFonts.cairo(
                                              color: Colors.redAccent,
                                              fontSize: 11,
                                            ),
                                          ),
                                        )
                                      : null,
                                  onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => AuthorScreen(
                                        authorId: docs[i].id,
                                        authorName:
                                            uData['displayName'] ?? 'مؤلف',
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showPrivacySettings(Map<String, dynamic>? userData) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    bool showPoints = userData?['showPublicPoints'] ?? true;
    bool showRatings = userData?['showPublicRatings'] ?? true;

    showModalBottomSheet(
      context: context,
      backgroundColor: _surface,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'إعدادات الخصوصية',
                style: GoogleFonts.cairo(
                  fontWeight: FontWeight.bold,
                  color: _textPrimary,
                ),
              ),
              const SizedBox(height: 10),
              SwitchListTile(
                title: Text(
                  'إظهار نقاطي للآخرين',
                  style: GoogleFonts.cairo(color: _textSecondary, fontSize: 14),
                ),
                value: showPoints,
                activeColor: _accent,
                onChanged: (v) async {
                  setS(() => showPoints = v);
                  await FirebaseFirestore.instance
                      .collection('users')
                      .doc(user.uid)
                      .update({'showPublicPoints': v});
                },
              ),
              SwitchListTile(
                title: Text(
                  'إظهار تقييمي العام للآخرين',
                  style: GoogleFonts.cairo(color: _textSecondary, fontSize: 14),
                ),
                value: showRatings,
                activeColor: _accent,
                onChanged: (v) async {
                  setS(() => showRatings = v);
                  await FirebaseFirestore.instance
                      .collection('users')
                      .doc(user.uid)
                      .update({'showPublicRatings': v});
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  // #18 سجل النقاط
  void _showPointsHistory() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: _surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.55,
        maxChildSize: 0.85,
        builder: (_, sc) => Column(
          children: [
            const SizedBox(height: 12),
            Container(
                width: 36, height: 4,
                decoration: BoxDecoration(
                    color: _border, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(children: [
                const Icon(Icons.history_rounded, color: _gold, size: 18),
                const SizedBox(width: 8),
                Text('سجل النقاط',
                    style: GoogleFonts.cairo(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: _textPrimary)),
              ]),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('users').doc(user.uid)
                    .collection('pointsHistory')
                    .orderBy('createdAt', descending: true)
                    .limit(50)
                    .snapshots(),
                builder: (_, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(
                        child: CircularProgressIndicator(color: _accent, strokeWidth: 2));
                  }
                  final docs = snap.data?.docs ?? [];
                  if (docs.isEmpty) {
                    return Center(
                        child: Text('لا يوجد سجل بعد',
                            style: GoogleFonts.cairo(color: _textSecondary)));
                  }
                  return ListView.builder(
                    controller: sc,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: docs.length,
                    itemBuilder: (_, i) {
                      final d      = docs[i].data() as Map<String, dynamic>;
                      final delta  = (d['delta'] as num?)?.toInt() ?? 0;
                      final reason = (d['reason'] as String?) ?? '';
                      final ts     = (d['createdAt'] as Timestamp?)?.toDate();
                      final color  = delta >= 0 ? _accent : Colors.redAccent;
                      final sign   = delta >= 0 ? '+' : '';
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 5),
                        child: Row(children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text('$sign$delta',
                                style: GoogleFonts.cairo(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: color)),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(reason,
                                    style: GoogleFonts.cairo(
                                        fontSize: 13, color: _textPrimary)),
                                if (ts != null)
                                  Text(
                                    '${ts.day}/${ts.month}/${ts.year}',
                                    style: GoogleFonts.cairo(
                                        fontSize: 10, color: _textSecondary),
                                  ),
                              ],
                            ),
                          ),
                        ]),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // #38 سجل الجلسات الأمنية
  void _showSecuritySessions() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: _surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Icon(Icons.security_rounded, color: _accent, size: 18),
              const SizedBox(width: 8),
              Text('أمان الحساب',
                  style: GoogleFonts.cairo(
                      fontSize: 16, fontWeight: FontWeight.w700,
                      color: _textPrimary)),
            ]),
            const SizedBox(height: 14),
            FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance
                  .collection('users').doc(user.uid).get(),
              builder: (_, snap) {
                final d = snap.data?.data() as Map<String, dynamic>?;
                final sessions = List<dynamic>.from(d?['loginSessions'] ?? []);
                if (sessions.isEmpty) {
                  return Text('لا توجد بيانات جلسات محفوظة',
                      style: GoogleFonts.cairo(color: _textSecondary));
                }
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: sessions.reversed.take(5).map((s) {
                    final ts = (s['at'] as Timestamp?)?.toDate();
                    final device = (s['device'] as String?) ?? 'جهاز غير معروف';
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.phone_android_rounded,
                          color: _textSecondary, size: 18),
                      title: Text(device,
                          style: GoogleFonts.cairo(
                              fontSize: 13, color: _textPrimary)),
                      subtitle: ts != null
                          ? Text(
                              '${ts.day}/${ts.month}/${ts.year}  ${ts.hour}:${ts.minute.toString().padLeft(2,'0')}',
                              style: GoogleFonts.cairo(
                                  fontSize: 10, color: _textSecondary))
                          : null,
                    );
                  }).toList(),
                );
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // #40 تعديل السيرة الذاتية
  void _showEditBioDialog(String current) {
    final ctrl = TextEditingController(text: current);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('السيرة الذاتية',
            style: GoogleFonts.cairo(fontWeight: FontWeight.w700, color: _textPrimary)),
        content: TextField(
          controller: ctrl,
          maxLines: 4,
          maxLength: 200,
          style: GoogleFonts.cairo(fontSize: 13, color: _textPrimary),
          decoration: InputDecoration(
            hintText: 'اكتب نبذة قصيرة عن نفسك...',
            hintStyle: GoogleFonts.cairo(color: _textSecondary, fontSize: 12),
            filled: true,
            fillColor: _surfaceHigh,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx),
              child: Text('إلغاء', style: GoogleFonts.cairo(color: _textSecondary))),
          TextButton(
            onPressed: () async {
              final user = FirebaseAuth.instance.currentUser;
              if (user != null) {
                await FirebaseFirestore.instance.collection('users').doc(user.uid)
                    .set({'bio': ctrl.text.trim()}, SetOptions(merge: true));
              }
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: Text('حفظ', style: GoogleFonts.cairo(color: _accent, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  // #29 لوحة المتصدرين
  void _showLeaderboard() {
    showModalBottomSheet(
      context: context,
      backgroundColor: _surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.55,
        maxChildSize: 0.85,
        builder: (_, sc) => Column(
          children: [
            const SizedBox(height: 12),
            Container(width: 36, height: 4,
                decoration: BoxDecoration(color: _border, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(children: [
                const Icon(Icons.leaderboard_rounded, color: _gold, size: 18),
                const SizedBox(width: 8),
                Text('أعلى المتصدرين', style: GoogleFonts.cairo(fontSize: 16, fontWeight: FontWeight.w700, color: _textPrimary)),
              ]),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: FutureBuilder<QuerySnapshot>(
                future: FirebaseFirestore.instance.collection('users')
                    .orderBy('points', descending: true).limit(50).get(),
                builder: (_, snap) {
                  if (!snap.hasData) return const Center(child: CircularProgressIndicator(color: _accent, strokeWidth: 2));
                  final docs    = snap.data!.docs;
                  final myUid   = FirebaseAuth.instance.currentUser?.uid ?? '';
                  // #46 ابحث عن رتبة المستخدم الحالي
                  final myRank  = docs.indexWhere((d) => d.id == myUid) + 1;
                  final show20  = docs.take(20).toList();
                  return Column(children: [
                    // #46 شريط رتبتي
                    if (myRank > 0)
                      Container(
                        margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: _accent.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: _accent.withOpacity(0.25)),
                        ),
                        child: Row(children: [
                          const Icon(Icons.person_rounded, color: _accent, size: 16),
                          const SizedBox(width: 8),
                          Text('رتبتك: #$myRank من أصل ${docs.length}',
                              style: GoogleFonts.cairo(fontSize: 13, color: _accent, fontWeight: FontWeight.w700)),
                        ]),
                      ),
                    Expanded(
                      child: ListView.builder(
                        controller: sc,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        itemCount: show20.length,
                        itemBuilder: (_, i) {
                          final d   = show20[i].data() as Map<String, dynamic>;
                          final n   = (d['displayName'] as String?) ?? 'مجهول';
                          final pts = (d['points'] as num?)?.toInt() ?? 0;
                          final pic = d['profilePicture'] as String?;
                          final isMe = show20[i].id == myUid;
                          const medals = ['🥇','🥈','🥉'];
                          return Container(
                            margin: const EdgeInsets.only(bottom: 6),
                            decoration: BoxDecoration(
                              color: isMe ? _accent.withOpacity(0.07) : Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                              border: isMe ? Border.all(color: _accent.withOpacity(0.3)) : null,
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                              leading: CircleAvatar(
                                radius: 20,
                                backgroundImage: pic != null ? NetworkImage(pic) : null,
                                backgroundColor: _surfaceHigh,
                                child: pic == null ? Text(n.isNotEmpty ? n[0] : '؟',
                                    style: GoogleFonts.cairo(color: _accent, fontWeight: FontWeight.w700)) : null,
                              ),
                              title: Row(children: [
                                if (i < 3) Text('${medals[i]} ', style: const TextStyle(fontSize: 16)),
                                Text(n, style: GoogleFonts.cairo(fontSize: 13,
                                    color: isMe ? _accent : _textPrimary,
                                    fontWeight: isMe ? FontWeight.w700 : FontWeight.normal)),
                                if (isMe) ...[const SizedBox(width: 6),
                                  Text('(أنت)', style: GoogleFonts.cairo(fontSize: 10, color: _accent))],
                              ]),
                              trailing: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(color: _gold.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
                                child: Text('$pts نقطة', style: GoogleFonts.cairo(fontSize: 12, color: _gold, fontWeight: FontWeight.w700)),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ]);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // #30 تحدي القراءة الأسبوعي
  void _showWeeklyChallenge() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    const target = 5;
    showModalBottomSheet(
      context: context,
      backgroundColor: _surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: FutureBuilder<QuerySnapshot>(
          future: FirebaseFirestore.instance
              .collection('users').doc(user.uid)
              .collection('readingProgress')
              .where('updatedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(
                  DateTime.now().subtract(const Duration(days: 7))))
              .get(),
          builder: (_, snap) {
            final done = snap.hasData ? snap.data!.docs.length : 0;
            final pct  = (done / target).clamp(0.0, 1.0);
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  const Icon(Icons.emoji_events_rounded, color: _gold, size: 20),
                  const SizedBox(width: 8),
                  Text('تحدي هذا الأسبوع',
                      style: GoogleFonts.cairo(fontSize: 16, fontWeight: FontWeight.w700, color: _textPrimary)),
                ]),
                const SizedBox(height: 16),
                Text('اقرأ $target فصول أسبوعياً لتحصل على 20 نقطة إضافية',
                    style: GoogleFonts.cairo(fontSize: 13, color: _textSecondary)),
                const SizedBox(height: 16),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: pct, minHeight: 10,
                    backgroundColor: _border,
                    valueColor: AlwaysStoppedAnimation<Color>(_gold),
                  ),
                ),
                const SizedBox(height: 10),
                Text('$done / $target فصول مقروءة هذا الأسبوع',
                    style: GoogleFonts.cairo(fontSize: 13, color: _textPrimary, fontWeight: FontWeight.w600)),
                if (done >= target) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: _gold.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: _gold.withOpacity(0.3))),
                    child: Row(children: [
                      const Icon(Icons.check_circle, color: _gold, size: 18),
                      const SizedBox(width: 8),
                      Text('أتممت التحدي! حصلت على 20 نقطة إضافية 🎉',
                          style: GoogleFonts.cairo(fontSize: 12, color: _gold, fontWeight: FontWeight.w700)),
                    ]),
                  ),
                ],
                const SizedBox(height: 8),
              ],
            );
          },
        ),
      ),
    );
  }

  // #36 إعدادات الإشعارات
  void _showNotificationSettings() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: _surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(),
        builder: (_, snap) {
          final d = (snap.data?.data() as Map<String, dynamic>?) ?? {};
          final prefs = (d['notifPrefs'] as Map<String, dynamic>?) ?? {};

          Future<void> toggle(String key) async {
            final current = (prefs[key] as bool?) ?? true;
            await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
              'notifPrefs': {key: !current}
            }, SetOptions(merge: true));
          }

          final items = [
            ('likes',       'إعجابات',            Icons.favorite_outline),
            ('comments',    'تعليقات',            Icons.chat_bubble_outline),
            ('ratings',     'تقييمات',            Icons.star_outline),
            ('follows',     'متابعون جدد',        Icons.person_add_outlined),
            ('novel_chapter','فصول من روايات تتابعها', Icons.auto_stories_outlined),
          ];

          return Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('إعدادات الإشعارات',
                    style: GoogleFonts.cairo(fontSize: 16, fontWeight: FontWeight.w700, color: _textPrimary)),
                const SizedBox(height: 14),
                ...items.map((item) {
                  final enabled = (prefs[item.$1] as bool?) ?? true;
                  return SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    secondary: Icon(item.$3, color: enabled ? _accent : _textSecondary, size: 20),
                    title: Text(item.$2, style: GoogleFonts.cairo(fontSize: 13, color: _textPrimary)),
                    value: enabled,
                    activeThumbColor: _accent,
                    onChanged: (_) => toggle(item.$1),
                  );
                }),
                const SizedBox(height: 8),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showPointsInfoDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'نظام النقاط',
          style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: _gold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _pointRow('15 نقطة', 'عند نشر فصل جديد (مرة واحدة كل 24 ساعة)'),
            _pointRow('5 نقاط',  'عند تقييم فصل لكاتب آخر'),
            _pointRow('−10 نقاط', 'كل 3 أيام خمول بدون نشر أو تقييم، حتى الصفر'),
            const SizedBox(height: 15),
            Text(
              'النقاط تعكس تفاعلك ومساهمتك في المجتمع — انشر وقيّم لتبقى نشطاً.',
              style: GoogleFonts.cairo(fontSize: 12, color: _textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pointRow(String pts, String desc) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(
            pts,
            style: GoogleFonts.cairo(
              color: _accent,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              desc,
              style: GoogleFonts.cairo(color: _textPrimary, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  void _showAboutPlatformDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: _bg,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: _border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'عن منصة راوي',
              style: GoogleFonts.cairo(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: _accent,
              ),
            ),
            const SizedBox(height: 20),
            _aboutItem(
              Icons.history_edu_rounded,
              'إبداع بشري خالص',
              'نشجع الكتابة الشخصية والابتعاد عن الاعتماد الكلي على الذكاء الاصطناعي لضمان روح النص.',
            ),
            _aboutItem(
              Icons.groups_rounded,
              'مجتمع متفاعل',
              'هدفنا أن لا يكتب أحد لنفسه فقط؛ نحن هنا لنقرأ لبعضنا، نقيم، ونطور مهاراتنا معاً.',
            ),
            _aboutItem(
              Icons.timer_rounded,
              'نظام النشر المنضبط',
              'يسمح بنشر فصل واحد كل 24 ساعة لمنح كل عمل فرصة عادلة في القراءة والظهور.',
            ),
            _aboutItem(
              Icons.auto_awesome_rounded,
              'التحفيز المتبادل',
              'بتقييمك للآخرين، تساهم في نمو المجتمع وتحصل على دعم مماثل لأعمالك.',
            ),
            const SizedBox(height: 20),
            Text(
              'الإصدار 1.0.0 - صنع بشغف لخدمة الأدب العربي',
              style: GoogleFonts.cairo(fontSize: 11, color: _textSecondary),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _aboutItem(IconData icon, String title, String desc) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: _accent, size: 24),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.cairo(
                    fontWeight: FontWeight.bold,
                    color: _textPrimary,
                    fontSize: 14,
                  ),
                ),
                Text(
                  desc,
                  style: GoogleFonts.cairo(
                    color: _textSecondary,
                    fontSize: 12,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── مساعدات ───────────────────────────────────────────────────────────────
  // #3 شارة الدور
  Widget _roleChip(String role) {
    // أدمن لا يظهر للآخرين — يُعرض كقارئ/كاتب حسب نشاطه
    final map = {
      'writer': ('كاتب',   _accent),
      'user':   ('قارئ',   _textSecondary),
    };
    final r = map[role == 'admin' ? 'user' : role] ?? ('قارئ', _textSecondary);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: r.$2.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: r.$2.withOpacity(0.35)),
      ),
      child: Text(r.$1,
          style: GoogleFonts.cairo(fontSize: 9, color: r.$2, fontWeight: FontWeight.w700)),
    );
  }

  // أيقونة شبكة الإجراءات السريعة
  Widget _gridAction(IconData icon, String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _border),
        ),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 5),
          Text(label,
              style: GoogleFonts.cairo(fontSize: 10, color: _textPrimary,
                  fontWeight: FontWeight.w600),
              textAlign: TextAlign.center, maxLines: 1,
              overflow: TextOverflow.ellipsis),
        ]),
      ),
    );
  }

  // #10 فاصل مزخرف
  Widget _decoratedDivider() => Row(children: [
    Expanded(child: Container(height: 1, color: _border)),
    Container(
      margin: const EdgeInsets.symmetric(horizontal: 10),
      width: 6, height: 6,
      decoration: BoxDecoration(color: _accent.withOpacity(0.45), shape: BoxShape.circle),
    ),
    Expanded(child: Container(height: 1, color: _border)),
  ]);

  // #5 بطاقة إحصائية مستقلة
  Widget _statBox(IconData icon, String val, String label, Color color, {VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 5),
          Text(val, style: GoogleFonts.cairo(fontSize: 15, fontWeight: FontWeight.w700, color: _textPrimary)),
          Text(label, style: GoogleFonts.cairo(fontSize: 9, color: _textSecondary)),
        ]),
      ),
    );
  }

  Widget _menuTile(
    IconData icon,
    String title, {
    String? subtitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _border),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: _surfaceHigh,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: _accent, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.cairo(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: _textPrimary,
                    ),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle,
                      style: GoogleFonts.cairo(
                        fontSize: 11,
                        color: _textSecondary,
                      ),
                    ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 13,
              color: _textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}
