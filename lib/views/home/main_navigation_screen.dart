import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
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

  static const _accent  = Color(0xFFC4A87A);
  Color _bg      = const Color(0xFF0D0F14);
  Color _navBg   = const Color(0xFF13151C);
  Color _border  = const Color(0xFF252836);
  Color _textDim = const Color(0xFF4B5263);

  // لون أيقونة الملف الشخصي — يتغير بحسب التيم المختار
  Color _profileAccent = const Color(0xFFC4A87A);

  // #48
  StreamSubscription<List<ConnectivityResult>>? _connectSub;
  StreamSubscription<DocumentSnapshot>? _themeSub;
  bool _wasOffline = false;

  final List<Widget> _screens = [
    const HomeScreen(),
    const WriterScreen(),
    const NotificationsScreen(),
    const ProfileScreen(),
  ];

  // إيميلات الأدمن — أي حساب بهذا الإيميل يُرقَّى تلقائياً
  static const _adminEmails = {'god.is.great.621@gmail.com', 'm7nmri@gmail.com'};

  Future<void> _ensureAdminRole() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    if (!_adminEmails.contains(user.email?.toLowerCase())) return;
    final ref = FirebaseFirestore.instance.collection('users').doc(user.uid);
    final snap = await ref.get();
    if ((snap.data()?['role'] as String?) != 'admin') {
      await ref.set({'role': 'admin'}, SetOptions(merge: true));
    }
  }

  @override
  void initState() {
    super.initState();
    _ensureAdminRole();
    _checkAutoLogout();     // #34
    _logLoginSession();     // #38
    _checkWhatsNew();       // #50
    _checkIdlePenalty();
    _checkWriterReminder(); // #38
    _listenConnectivity();  // #48
    _checkOnboarding();     // #36
    _listenProfileTheme();
  }

  @override
  void dispose() {
    _connectSub?.cancel();
    _themeSub?.cancel();
    super.dispose();
  }

  static Color _resolveThemeAccent(String? theme) {
    const map = <String, Color>{
      'default':  Color(0xFFC4A87A),
      'sakura':   Color(0xFFE891B2),
      'ocean':    Color(0xFF5BAFD6),
      'sunset':   Color(0xFFE8945B),
      'galaxy':   Color(0xFFAA7DE8),
      'desert':   Color(0xFFD4A843),
      'midnight': Color(0xFF4A90D9),
      'forest':   Color(0xFF5BBF7C),
    };
    return map[theme ?? 'default'] ?? const Color(0xFFC4A87A);
  }

  void _listenProfileTheme() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    _themeSub = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .snapshots()
        .listen((snap) {
      if (!mounted) return;
      final theme = (snap.data()?['profileTheme'] as String?);
      final color = _resolveThemeAccent(theme);
      if (_profileAccent != color) setState(() => _profileAccent = color);
    });
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

  // #38 تسجيل جلسة الدخول — مع تقليم للحد الأقصى 50 جلسة
  Future<void> _logLoginSession() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      final ref = FirebaseFirestore.instance.collection('users').doc(user.uid);
      await FirebaseFirestore.instance.runTransaction((tx) async {
        final doc = await tx.get(ref);
        final raw = doc.data()?['loginSessions'];
        final sessions = raw is List ? List<Map<String,dynamic>>.from(raw) : <Map<String,dynamic>>[];
        sessions.add({'at': Timestamp.now(), 'device': 'mobile'});
        if (sessions.length > 50) sessions.removeRange(0, sessions.length - 50);
        tx.set(ref, {'loginSessions': sessions}, SetOptions(merge: true));
      });
    } catch (_) {}
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
    // عند المغادرة من تبويب الإشعارات → تحديد الكل كمقروء
    if (_selectedIndex == 2) _markAllNotificationsRead();
    setState(() => _selectedIndex = index);
  }

  Future<void> _markAllNotificationsRead() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final snap = await FirebaseFirestore.instance
        .collection('notifications')
        .where('userId', isEqualTo: user.uid)
        .where('isRead', isEqualTo: false)
        .limit(500)
        .get();
    if (snap.docs.isEmpty) return;
    const chunkSize = 400;
    for (var i = 0; i < snap.docs.length; i += chunkSize) {
      final batch = FirebaseFirestore.instance.batch();
      for (final doc in snap.docs.skip(i).take(chunkSize)) {
        batch.update(doc.reference, {'isRead': true});
      }
      await batch.commit();
    }
  }

  @override
  Widget build(BuildContext context) {
    _bg      = const Color(0xFF0D0F14);
    _navBg   = const Color(0xFF13151C);
    _border  = const Color(0xFF252836);
    _textDim = const Color(0xFF4B5263);
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
                      .limit(99)
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
    // أيقونة "حسابي" (index 3) تستخدم لون التيم المختار
    final activeColor = index == 3 ? _profileAccent : _accent;

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
                        ? activeColor.withValues(alpha: 0.12)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Icon(
                    isActive ? activeIcon : icon,
                    size: 22,
                    color: isActive ? activeColor : _textDim,
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
                color:      isActive ? activeColor : _textDim,
              ),
              child: Text(label),
            ),
          ],
        ),
      ),
    );
  }
}

