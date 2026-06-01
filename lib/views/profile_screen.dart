import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:my_first_app/view_models/auth_view_model.dart';
import 'package:my_first_app/repositories/user_repository.dart';
import 'admin_screen.dart';
import 'package:my_first_app/providers/novels_provider.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  // ── ألوان ─────────────────────────────────────────────────────────────────
  static const _bg            = Color(0xFF0D0F14);
  static const _surface       = Color(0xFF161920);
  static const _surfaceHigh   = Color(0xFF1E2130);
  static const _accent        = Color(0xFF8BAF7C);
  static const _border        = Color(0xFF252836);
  static const _textPrimary   = Color(0xFFECECEC);
  static const _textSecondary = Color(0xFF6B7280);
  static const _gold          = Color(0xFFD4A843);

  bool _isUploading = false;

  Future<void> _pickAndUploadImage() async {
    setState(() => _isUploading = true);
    try {
      final url = await UserRepository.uploadProfilePicture();
      if (url != null && mounted) {
        _showSnack('تم تحديث الصورة الشخصية ✅', Colors.green);
      }
    } catch (_) {
      if (mounted) _showSnack('حدث خطأ أثناء الرفع ❌', Colors.redAccent);
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  // ── نظام تغيير الاسم: مرة كل 30 يوماً ────────────────────────────────────
  void _showEditNameDialog(String currentName, Map<String, dynamic>? userData) {
    final controller = TextEditingController(text: currentName);
    final lastChanged =
        (userData?['nameLastChangedAt'] as Timestamp?)?.toDate();
    final now         = DateTime.now();
    final canChange   = lastChanged == null ||
        now.difference(lastChanged).inDays >= 30;
    final daysLeft    = canChange
        ? 0
        : 30 - now.difference(lastChanged!).inDays;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _surface,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: Text('تعديل الاسم',
            style: GoogleFonts.cairo(
                fontWeight: FontWeight.w700, color: _textPrimary)),
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
                  border: Border.all(
                      color: Colors.orange.withOpacity(0.3)),
                ),
                child: Text(
                  'يمكنك تغيير اسمك مرة كل 30 يوماً.\nباقي $daysLeft يوم للتغيير القادم.',
                  style: GoogleFonts.cairo(
                      fontSize: 12, color: Colors.orange),
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
                  style: GoogleFonts.cairo(
                      fontSize: 12, color: _accent),
                ),
              ),
            TextField(
              controller:  controller,
              enabled:     canChange,
              style: GoogleFonts.cairo(
                  color: _textPrimary, fontSize: 14),
              decoration: InputDecoration(
                hintText:  'اسمك بين القراء',
                hintStyle: GoogleFonts.cairo(color: _textSecondary),
                filled:    true,
                fillColor: _surfaceHigh,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: _border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: _border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide:
                      const BorderSide(color: _accent, width: 1.5),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('إلغاء',
                  style: GoogleFonts.cairo(color: _textSecondary))),
          if (canChange)
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _accent,
                foregroundColor: const Color(0xFF0D0F14),
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
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
                  'displayName':        newName,
                  'nameLastChangedAt':  FieldValue.serverTimestamp(),
                });
                await user.updateDisplayName(newName);
                if (mounted) {
                  Navigator.pop(ctx);
                  _showSnack('تم تحديث اسمك ✅', Colors.green);
                }
              },
              child: Text('حفظ',
                  style: GoogleFonts.cairo(fontWeight: FontWeight.w700)),
            ),
        ],
      ),
    );
  }

  // ── نافذة الدعم الفني ─────────────────────────────────────────────────────
  void _showSupportDialog() {
    final titleCtrl = TextEditingController();
    final descCtrl  = TextEditingController();
    String selectedType = 'مشكلة تقنية';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Container(
          padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom),
          decoration: const BoxDecoration(
            color: Color(0xFF161920),
            borderRadius:
                BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('الدعم الفني',
                    style: GoogleFonts.cairo(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: _textPrimary)),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: selectedType,
                  dropdownColor: _surfaceHigh,
                  style: GoogleFonts.cairo(
                      color: _textPrimary, fontSize: 13),
                  items: ['مشكلة تقنية', 'اقتراح',
                          'استفسار عن النقاط', 'أخرى']
                      .map((e) => DropdownMenuItem(
                          value: e,
                          child: Text(e,
                              style: GoogleFonts.cairo(
                                  color: _textPrimary))))
                      .toList(),
                  onChanged: (v) => setS(() => selectedType = v!),
                  decoration: InputDecoration(
                    filled:    true,
                    fillColor: _surfaceHigh,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide:
                            const BorderSide(color: _border)),
                    enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide:
                            const BorderSide(color: _border)),
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
                      padding:
                          const EdgeInsets.symmetric(vertical: 14),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () async {
                      await context.read<NovelsProvider>()
                          .sendSupportRequest(
                        title:       titleCtrl.text,
                        type:        selectedType,
                        description: descCtrl.text,
                      );
                      if (mounted) {
                        Navigator.pop(ctx);
                        _showSnack('تم إرسال طلبك ✅', Colors.green);
                      }
                    },
                    child: Text('إرسال الطلب',
                        style: GoogleFonts.cairo(
                            fontWeight: FontWeight.w700)),
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

  Widget _supportField(TextEditingController ctrl, String hint,
      {int maxLines = 1}) {
    return TextField(
      controller: ctrl,
      maxLines:   maxLines,
      style: GoogleFonts.cairo(color: _textPrimary, fontSize: 13),
      decoration: InputDecoration(
        hintText:  hint,
        hintStyle: GoogleFonts.cairo(
            color: _textSecondary, fontSize: 13),
        filled:    true,
        fillColor: _surfaceHigh,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: _border)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: _border)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide:
                const BorderSide(color: _accent, width: 1.5)),
      ),
    );
  }

  void _showSnack(String msg, Color bg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: GoogleFonts.cairo()),
      backgroundColor: bg,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10)),
    ));
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return Scaffold(
        backgroundColor: _bg,
        body: Center(
            child: Text('يرجى تسجيل الدخول',
                style: GoogleFonts.cairo(color: _textSecondary))),
      );
    }

    return Scaffold(
      backgroundColor: _bg,
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users').doc(user.uid).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(
                    color: _accent, strokeWidth: 2));
          }

          final userData =
              snapshot.data?.data() as Map<String, dynamic>?;
          final name       = userData?['displayName'] ?? 'مستخدم';
          final email      = userData?['email']       ?? user.email ?? '';
          final profilePic = userData?['profilePicture'] as String?;
          final points     = userData?['points']      ?? 0;
          final role       = userData?['role']        ?? 'user';
          final ratingsGiven = userData?['ratingsGiven'] ?? 0;

          return CustomScrollView(
            slivers: [
              // ── Header ───────────────────────────────────────────────
              SliverAppBar(
                pinned: true,
                backgroundColor: _bg,
                elevation: 0,
                expandedHeight: 200,
                flexibleSpace: FlexibleSpaceBar(
                  background: Container(
                    color: _bg,
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  _accent.withOpacity(0.05),
                                  _bg,
                                ],
                                begin: Alignment.topCenter,
                                end:   Alignment.bottomCenter,
                              ),
                            ),
                          ),
                        ),
                        Center(
                          child: Column(
                            mainAxisAlignment:
                                MainAxisAlignment.center,
                            children: [
                              const SizedBox(height: 30),
                              // الصورة الشخصية
                              Stack(
                                children: [
                                  Container(
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                          color: _accent, width: 2),
                                    ),
                                    child: CircleAvatar(
                                      radius: 48,
                                      backgroundColor: _surface,
                                      backgroundImage: profilePic != null
                                          ? NetworkImage(profilePic)
                                          : null,
                                      child: profilePic == null
                                          ? Text(
                                              name.isNotEmpty
                                                  ? name[0].toUpperCase()
                                                  : '؟',
                                              style: GoogleFonts.cairo(
                                                  fontSize: 34,
                                                  fontWeight:
                                                      FontWeight.w700,
                                                  color: _accent))
                                          : null,
                                    ),
                                  ),
                                  if (_isUploading)
                                    Positioned.fill(
                                      child: Container(
                                        decoration: const BoxDecoration(
                                          color:  Colors.black38,
                                          shape:  BoxShape.circle,
                                        ),
                                        child: const Center(
                                          child:
                                              CircularProgressIndicator(
                                            color:      _accent,
                                            strokeWidth: 2,
                                          ),
                                        ),
                                      ),
                                    ),
                                  Positioned(
                                    bottom: 0,
                                    right:  0,
                                    child: GestureDetector(
                                      onTap: _isUploading
                                          ? null
                                          : _pickAndUploadImage,
                                      child: Container(
                                        width:  30,
                                        height: 30,
                                        decoration: BoxDecoration(
                                          color:  _accent,
                                          shape:  BoxShape.circle,
                                          border: Border.all(
                                              color: _bg, width: 2),
                                        ),
                                        child: const Icon(
                                            Icons.camera_alt_rounded,
                                            color: Color(0xFF0D0F14),
                                            size: 15),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Text(name,
                                  style: GoogleFonts.cairo(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                      color: _textPrimary)),
                              Text(email,
                                  style: GoogleFonts.cairo(
                                      fontSize: 11,
                                      color: _textSecondary)),
                            ],
                          ),
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

              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      // ── بطاقة الإحصائيات ──────────────────────────
                      Container(
                        padding: const EdgeInsets.symmetric(
                            vertical: 14, horizontal: 8),
                        decoration: BoxDecoration(
                          color:  _surface,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: _border),
                        ),
                        child: Row(
                          mainAxisAlignment:
                              MainAxisAlignment.spaceAround,
                          children: [
                            _statCard(
                                Icons.stars_rounded,
                                points.toString(),
                                'نقطة',
                                _gold),
                            _vDiv(),
                            _statCard(
                                Icons.rate_review_rounded,
                                ratingsGiven.toString(),
                                'تقييم أعطيته',
                                _accent),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // ── قائمة الإعدادات ────────────────────────────
                      _menuTile(
                        Icons.person_outline_rounded,
                        'تعديل الاسم',
                        subtitle: 'مرة كل 30 يوماً',
                        onTap: () =>
                            _showEditNameDialog(name, userData),
                      ),
                      if (role == 'admin')
                        _menuTile(
                          Icons.admin_panel_settings_outlined,
                          'لوحة الإدارة',
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const AdminScreen()),
                          ),
                        ),
                      _menuTile(
                        Icons.help_outline_rounded,
                        'الدعم الفني',
                        onTap: _showSupportDialog,
                      ),
                      _menuTile(
                        Icons.info_outline_rounded,
                        'عن منصة راوي',
                        onTap: () => showAboutDialog(
                          context: context,
                          applicationName:    'منصة راوي',
                          applicationVersion: '1.0.0',
                        ),
                      ),

                      const SizedBox(height: 30),

                      // ── تسجيل الخروج ──────────────────────────────
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () =>
                              context.read<AuthViewModel>().logout(),
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                Colors.redAccent.withOpacity(0.08),
                            foregroundColor: Colors.redAccent,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(
                                vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(
                                  color: Colors.redAccent
                                      .withOpacity(0.2)),
                            ),
                          ),
                          child: Text('تسجيل الخروج',
                              style: GoogleFonts.cairo(
                                  fontWeight: FontWeight.w700)),
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

  // ── مساعدات ───────────────────────────────────────────────────────────────
  Widget _statCard(
      IconData icon, String val, String label, Color color) {
    return Column(children: [
      Icon(icon, color: color, size: 22),
      const SizedBox(height: 4),
      Text(val,
          style: GoogleFonts.cairo(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: _textPrimary)),
      Text(label,
          style:
              GoogleFonts.cairo(fontSize: 11, color: _textSecondary)),
    ]);
  }

  Widget _vDiv() =>
      Container(height: 40, width: 1, color: _border);

  Widget _menuTile(IconData icon, String title,
      {String? subtitle, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(
            horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color:  _surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _border),
        ),
        child: Row(children: [
          Container(
            width:  36,
            height: 36,
            decoration: BoxDecoration(
              color:  _surfaceHigh,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: _accent, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: GoogleFonts.cairo(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: _textPrimary)),
                if (subtitle != null)
                  Text(subtitle,
                      style: GoogleFonts.cairo(
                          fontSize: 11, color: _textSecondary)),
              ],
            ),
          ),
          const Icon(Icons.arrow_forward_ios_rounded,
              size: 13, color: _textSecondary),
        ]),
      ),
    );
  }
}