import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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

  static const _bg      = Color(0xFF0D0F14);
  static const _navBg   = Color(0xFF13151C);
  static const _accent  = Color(0xFF8BAF7C);
  static const _border  = Color(0xFF252836);
  static const _textDim = Color(0xFF4B5263);

  final List<Widget> _screens = [
    const HomeScreen(),
    const WriterScreen(),
    const NotificationsScreen(),
    const ProfileScreen(),
  ];

  void _onItemTapped(int index) {
    if (_selectedIndex == index) return;
    HapticFeedback.selectionClick();
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
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
                        ? _accent.withOpacity(0.12)
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