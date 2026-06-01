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
      await UserRepository.uploadProfilePicture(); // This now throws on error
      if (mounted) {
        _showSnack('تم تحديث الصورة الشخصية ✅', Colors.green);
      }
    } catch (e) {
      if (mounted) _showSnack(e.toString().replaceFirst('Exception: ', ''), Colors.redAccent); // Display specific error
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
          final ratingsReceived = userData?['ratingsReceived'] ?? 0;
          final avgRating = (userData?['avgRating'] ?? 0.0).toDouble();
          final followersCount = userData?['followersCount'] ?? 0;
          final followingCount = userData?['followingCount'] ?? 0;

          final showPublicRating = ratingsReceived >= 10;

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
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color:  _surface,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: _border),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                GestureDetector(
                                  onTap: () => _showUserList('المتابعون', 'followers'),
                                  child: _statCard(Icons.group_outlined, followersCount.toString(), 'متابع', _accent),
                                ),
                                _vDiv(),
                                GestureDetector(
                                  onTap: () => _showUserList('أتابعهم', 'following'),
                                  child: _statCard(Icons.person_add_outlined, followingCount.toString(), 'أتابع', _accent),
                                ),
                                _vDiv(),
                                GestureDetector(
                                  onTap: _showPointsInfoDialog,
                                  child: _statCard(Icons.stars_rounded, points.toString(), 'نقطة', _gold),
                                ),
                              ],
                            ),
                            const Divider(height: 30, color: _border),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                _statCard(Icons.rate_review_rounded, ratingsGiven.toString(), 'تقييم أعطيته', _textSecondary),
                                if (showPublicRating) ...[
                                  _vDiv(),
                                  _statCard(Icons.star_half_rounded, avgRating.toStringAsFixed(1), 'تقييمي العام', _gold),
                                ],
                              ],
                            ),
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
                      _menuTile(
                        Icons.privacy_tip_outlined,
                        'الخصوصية',
                        onTap: _showPrivacySettings,
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
                        onTap: _showAboutPlatformDialog,
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

  // ── عرض قوائم المتابعين والمتابعين ────────────────────────────────────────
  void _showUserList(String title, String collectionPath) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: _bg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('users').doc(user.uid).collection(collectionPath).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final docs = snapshot.data!.docs;
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(title, style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: _accent)),
              ),
              Expanded(
                child: docs.isEmpty 
                  ? Center(child: Text('القائمة فارغة', style: GoogleFonts.cairo(color: _textSecondary)))
                  : ListView.builder(
                      itemCount: docs.length,
                      itemBuilder: (context, i) => FutureBuilder<DocumentSnapshot>(
                        future: FirebaseFirestore.instance.collection('users').doc(docs[i].id).get(),
                        builder: (context, userSnap) {
                          if (!userSnap.hasData) return const SizedBox();
                          final uData = userSnap.data!.data() as Map<String, dynamic>;
                          return ListTile(
                            leading: CircleAvatar(backgroundImage: uData['profilePicture'] != null ? NetworkImage(uData['profilePicture']) : null),
                            title: Text(uData['displayName'] ?? 'مستخدم', style: GoogleFonts.cairo(color: _textPrimary)),
                            onTap: () => Navigator.pushNamed(context, '/author', arguments: docs[i].id),
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

  void _showPrivacySettings() {
    showModalBottomSheet(
      context: context,
      backgroundColor: _surface,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('إعدادات الخصوصية', style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: _textPrimary)),
            SwitchListTile(title: Text('إظهار نقاطي للآخرين', style: GoogleFonts.cairo(color: _textSecondary)), value: true, onChanged: (v){}, activeColor: _accent),
            SwitchListTile(title: Text('إظهار تقييماتي للآخرين', style: GoogleFonts.cairo(color: _textSecondary)), value: true, onChanged: (v){}, activeColor: _accent),
          ],
        ),
      ),
    );
  }

  void _showPointsInfoDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('نظام النقاط', style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: _gold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _pointRow('3 نقاط', 'عند الانتظار 24 ساعة بين الفصول'),
            _pointRow('3 نقاط', 'عند تقييم 3 روايات لزملاء آخرين'),
            _pointRow('4 نقاط', 'عند حصول فصولك على تقييمات إيجابية'),
            const SizedBox(height: 15),
            Text('النقاط تساعدك على النشر وتبرز مكانتك ككاتب متفاعل في المجتمع.', style: GoogleFonts.cairo(fontSize: 12, color: _textSecondary)),
          ],
        ),
      ),
    );
  }

  Widget _pointRow(String pts, String desc) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        Text(pts, style: GoogleFonts.cairo(color: _accent, fontWeight: FontWeight.bold, fontSize: 13)),
        const SizedBox(width: 8),
        Expanded(child: Text(desc, style: GoogleFonts.cairo(color: _textPrimary, fontSize: 12))),
      ]),
    );
  }

  void _showAboutPlatformDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: _bg,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: _border, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 20),
            Text('عن منصة راوي', style: GoogleFonts.cairo(fontSize: 20, fontWeight: FontWeight.bold, color: _accent)),
            const SizedBox(height: 20),
            _aboutItem(Icons.history_edu_rounded, 'إبداع بشري خالص', 'نشجع الكتابة الشخصية والابتعاد عن الاعتماد الكلي على الذكاء الاصطناعي لضمان روح النص.'),
            _aboutItem(Icons.groups_rounded, 'مجتمع متفاعل', 'هدفنا أن لا يكتب أحد لنفسه فقط؛ نحن هنا لنقرأ لبعضنا، نقيم، ونطور مهاراتنا معاً.'),
            _aboutItem(Icons.timer_rounded, 'نظام النشر المنضبط', 'يسمح بنشر فصل واحد كل 24 ساعة لمنح كل عمل فرصة عادلة في القراءة والظهور.'),
            _aboutItem(Icons.auto_awesome_rounded, 'التحفيز المتبادل', 'بتقييمك للآخرين، تساهم في نمو المجتمع وتحصل على دعم مماثل لأعمالك.'),
            const SizedBox(height: 20),
            Text('الإصدار 1.0.0 - صنع بشغف لخدمة الأدب العربي', style: GoogleFonts.cairo(fontSize: 11, color: _textSecondary)),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _aboutItem(IconData icon, String title, String desc) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: _accent, size: 24),
        const SizedBox(width: 15),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: _textPrimary, fontSize: 14)),
          Text(desc, style: GoogleFonts.cairo(color: _textSecondary, fontSize: 12, height: 1.5)),
        ])),
      ]),
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