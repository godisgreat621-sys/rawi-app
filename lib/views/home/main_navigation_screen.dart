import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:my_first_app/providers/theme_provider.dart';
import 'package:my_first_app/views/what_is_new_screen.dart';
import 'package:my_first_app/views/onboarding_screen.dart';
import '../home/home_screen.dart';
import '../writer/writer_screen.dart';
import '../profile_screen.dart';
import '../notifications_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen>
    with SingleTickerProviderStateMixin {
  int _selectedIndex = 0;

  static const _accent  = Color(0xFF8BAF7C);
  Color _bg      = const Color(0xFF0D0F14);
  Color _navBg   = const Color(0xFF13151C);
  Color _border  = const Color(0xFF252836);
  Color _textDim = const Color(0xFF4B5263);

  // #48
  StreamSubscription<List<ConnectivityResult>>? _connectSub;
  bool _wasOffline = false;

  final List<Widget> _screens = [
    const HomeScreen(),
    const WriterScreen(),
    const NotificationsScreen(),
    const ProfileScreen(),
  ];

  // يقرأ قائمة الأدمن من Firestore (system_settings/admin_config)
  // لإضافة أدمن: أضف إيميله في Firestore > system_settings > admin_config > adminEmails (array)
  Future<void> _ensureAdminRole() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      final configDoc = await FirebaseFirestore.instance
          .collection('system_settings')
          .doc('admin_config')
          .get();
      final adminEmails = List<String>.from(
          (configDoc.data()?['adminEmails'] as List<dynamic>?) ?? []);
      final userEmail = user.email?.toLowerCase() ?? '';
      if (!adminEmails.contains(userEmail)) return;
      final ref = FirebaseFirestore.instance.collection('users').doc(user.uid);
      final snap = await ref.get();
      if ((snap.data()?['role'] as String?) != 'admin') {
        await ref.set({'role': 'admin'}, SetOptions(merge: true));
      }
    } catch (e) { debugPrint('[Nav] $e'); }
  }

  @override
  void initState() {
    super.initState();
    _ensureAdminRole();
    _checkAutoLogout();     // #34
    _logLoginSession();     // #38
    _checkWhatsNew();       // #50
    _checkIdlePenalty();
    _loadThemePreference();
    _checkWriterReminder(); // #38
    _listenConnectivity();  // #48
    _checkOnboarding();     // #36
  }

  @override
  void dispose() {
    _connectSub?.cancel();
    super.dispose();
  }

  // #36 عرض Onboarding للمستخدمين الجدد
  Future<void> _checkOnboarding() async {
    final should = await OnboardingScreen.shouldShow();
    if (!should || !mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Navigator.push(
        context,
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => OnboardingScreen(onDone: () => Navigator.pop(context)),
        ),
      );
    });
  }

  // #48 إعادة التحميل عند عودة الاتصال
  void _listenConnectivity() {
    _connectSub = Connectivity().onConnectivityChanged.listen((results) {
      final isOffline = results.every((r) => r == ConnectivityResult.none);
      if (_wasOffline && !isOffline && mounted) {
        setState(() {}); // يُعيد بناء الشاشة الحالية
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('عاد الاتصال بالإنترنت ✅',
              style: GoogleFonts.cairo(fontSize: 13)),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ));
      }
      _wasOffline = isOffline;
    });
  }

  // #50 شاشة "ما الجديد" تظهر مرة واحدة بعد كل إصدار
  Future<void> _checkWhatsNew() async {
    final should = await WhatsNewScreen.shouldShow();
    if (!should || !mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const WhatsNewScreen()),
      );
    });
  }

  // #38 تسجيل جلسة الدخول
  Future<void> _logLoginSession() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      await FirebaseFirestore.instance.collection('users').doc(user.uid)
          .set({
        'loginSessions': FieldValue.arrayUnion([{
          'at': Timestamp.now(),
          'device': 'Android / iOS',
        }]),
      }, SetOptions(merge: true));
    } catch (e) { debugPrint('[Nav] $e'); }
  }

  // #34 خروج تلقائي بعد 30 يوماً عدم نشاط
  Future<void> _checkAutoLogout() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    final lastActive = (doc.data()?['lastActivity'] as Timestamp?)?.toDate();
    if (lastActive == null) return;
    if (DateTime.now().difference(lastActive).inDays > 30) {
      await FirebaseAuth.instance.signOut();
    }
  }

  // #38 تذكير الكاتب بالنشر إذا مر 5 أيام
  Future<void> _checkWriterReminder() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    if (!doc.exists) return;
    final data = doc.data()!;
    final lastPublished = (data['lastPublished'] as Timestamp?)?.toDate();
    if (lastPublished == null) return;
    final daysSince = DateTime.now().difference(lastPublished).inDays;
    if (daysSince >= 5 && mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
            'لم تنشر منذ $daysSince أيام — نقاطك تُخصم كل 3 أيام خمول ⚠️',
            style: GoogleFonts.cairo(fontSize: 12),
          ),
          backgroundColor: const Color(0xFFD4A843),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ));
      });
    }
  }

  Future<void> _loadThemePreference() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final doc = await FirebaseFirestore.instance
        .collection('users').doc(user.uid).get();
    final isDark = (doc.data()?['isDarkMode'] as bool?) ?? true;
    if (mounted) {
      context.read<ThemeProvider>().setDarkMode(isDark);
    }
  }

  Future<void> _checkIdlePenalty() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final doc = await FirebaseFirestore.instance
        .collection('users').doc(user.uid).get();
    if (!doc.exists) return;

    final data         = doc.data()!;
    final lastActivity = (data['lastActivity'] as Timestamp?)?.toDate();
    if (lastActivity == null) return;

    final daysSince    = DateTime.now().difference(lastActivity).inDays;
    final missedPeriods = daysSince ~/ 3;
    if (missedPeriods == 0) return;

    final appliedPeriods = (data['appliedIdlePeriods'] as int?) ?? 0;
    final toApply        = missedPeriods - appliedPeriods;
    if (toApply <= 0) return;

    final currentPoints = (data['points'] as int?) ?? 0;
    final newPoints     = (currentPoints - toApply * 10).clamp(0, 999999);

    final batch = FirebaseFirestore.instance.batch();
    final userRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
    batch.update(userRef, {
      'points':             newPoints,
      'appliedIdlePeriods': missedPeriods,
    });
    // سجل النقاط #18
    final historyRef = userRef.collection('pointsHistory').doc();
    batch.set(historyRef, {
      'delta':     -(toApply * 10),
      'reason':    'خصم خمول ($toApply فترة × 10 نقاط)',
      'createdAt': FieldValue.serverTimestamp(),
    });
    await batch.commit();
  }

  void _onItemTapped(int index) {
    if (_selectedIndex == index) return;
    HapticFeedback.selectionClick();
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDarkMode;
    _bg      = isDark ? const Color(0xFF0D0F14) : const Color(0xFFF5F5F7);
    _navBg   = isDark ? const Color(0xFF13151C) : const Color(0xFFFFFFFF);
    _border  = isDark ? const Color(0xFF252836) : const Color(0xFFE0E0E4);
    _textDim = isDark ? const Color(0xFF4B5263) : const Color(0xFF9CA3AF);
    return Scaffold(
      backgroundColor: _bg,
      body: IndexedStack(
        index: _selectedIndex,
        children: _screens,
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildBottomNav() {
    final user = FirebaseAuth.instance.currentUser;

    return Container(
      decoration: BoxDecoration(
        color: _navBg,
        border: Border(top: BorderSide(color: _border, width: 1)),
      ),
      child: SafeArea(
        child: SizedBox(
          height: 64,
          child: Row(
            children: [
              _buildNavItem(
                index:      0,
                icon:       Icons.auto_stories_outlined,
                activeIcon: Icons.auto_stories_rounded,
                label:      'المكتبة',
              ),
              _buildNavItem(
                index:      1,
                icon:       Icons.edit_note_outlined,
                activeIcon: Icons.edit_note_rounded,
                label:      'اكتب',
              ),
              // ── الإشعارات مع العداد ──────────────────────────────────
              if (user != null)
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('notifications')
                      .where('userId', isEqualTo: user.uid)
                      .where('isRead',  isEqualTo: false)
                      .snapshots(),
                  builder: (_, snap) {
                    final count = snap.hasData ? snap.data!.docs.length : 0;
                    return _buildNavItem(
                      index:      2,
                      icon:       Icons.notifications_none_rounded,
                      activeIcon: Icons.notifications_rounded,
                      label:      'الإشعارات',
                      badgeCount: count,
                    );
                  },
                )
              else
                _buildNavItem(
                  index:      2,
                  icon:       Icons.notifications_none_rounded,
                  activeIcon: Icons.notifications_rounded,
                  label:      'الإشعارات',
                ),
              _buildNavItem(
                index:      3,
                icon:       Icons.person_outline_rounded,
                activeIcon: Icons.person_rounded,
                label:      'حسابي',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required int      index,
    required IconData icon,
    required IconData activeIcon,
    required String   label,
    int badgeCount = 0,
  }) {
    final isActive = _selectedIndex == index;

    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _onItemTapped(index),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOut,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    color: isActive
                        ? _accent.withValues(alpha: 0.12)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Icon(
                    isActive ? activeIcon : icon,
                    size: 22,
                    color: isActive ? _accent : _textDim,
                  ),
                ),
                // عداد الإشعارات
                if (badgeCount > 0)
                  Positioned(
                    top:   -2,
                    left:  -2,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: const BoxDecoration(
                        color: Colors.redAccent,
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(
                          minWidth: 16, minHeight: 16),
                      child: Text(
                        badgeCount > 99 ? '99+' : '$badgeCount',
                        style: GoogleFonts.cairo(
                            fontSize: 9,
                            color:    Colors.white,
                            fontWeight: FontWeight.w700),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 2),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: GoogleFonts.cairo(
                fontSize:   11,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
                color:      isActive ? _accent : _textDim,
              ),
              child: Text(label),
            ),
          ],
        ),
      ),
    );
  }
}