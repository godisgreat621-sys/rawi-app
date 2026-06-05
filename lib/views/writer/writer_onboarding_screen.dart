import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class WriterOnboardingScreen extends StatefulWidget {
  const WriterOnboardingScreen({super.key});

  static Future<bool> shouldShow() async {
    final prefs = await SharedPreferences.getInstance();
    return !(prefs.getBool('writer_onboarding_done') ?? false);
  }

  static Future<void> markDone() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('writer_onboarding_done', true);
  }

  @override
  State<WriterOnboardingScreen> createState() => _WriterOnboardingScreenState();
}

class _WriterOnboardingScreenState extends State<WriterOnboardingScreen> {
  static const _bg          = Color(0xFF0D0F14);
  static const _surface     = Color(0xFF161920);
  static const _accent      = Color(0xFF8BAF7C);
  static const _gold        = Color(0xFFD4A843);
  static const _textPrimary = Color(0xFFECECEC);
  static const _textSec     = Color(0xFF6B7280);

  final _pageController = PageController();
  int _page = 0;

  static const _pages = [
    _OnboardPage(
      icon: Icons.auto_stories_rounded,
      iconColor: _accent,
      title: 'أهلاً بك ككاتب! 🎉',
      body: 'نشرت أول رواية لك على منصة راوي.\n'
            'إليك بعض النصائح للانطلاق بشكل صحيح.',
    ),
    _OnboardPage(
      icon: Icons.workspace_premium_rounded,
      iconColor: _gold,
      title: 'نظام النقاط',
      body: '• كل رواية تنشرها = 15 نقطة\n'
            '• كل فصل جديد = 10 نقاط\n'
            '• كل تقييم تحصل عليه = 5 نقاط\n'
            '• الخمول 3 أيام = خصم 10 نقاط\n\n'
            'انشر بانتظام لتحافظ على مكانتك!',
    ),
    _OnboardPage(
      icon: Icons.lightbulb_outline_rounded,
      iconColor: Color(0xFF64B5F6),
      title: 'نصائح الكتابة',
      body: '• أضف وصفاً جذاباً للرواية\n'
            '• ارفع صورة غلاف مميزة\n'
            '• انشر الفصول بانتظام كل 3-7 أيام\n'
            '• تفاعل مع تعليقات القراء\n'
            '• حدد تصنيفاً دقيقاً لروايتك',
    ),
    _OnboardPage(
      icon: Icons.bar_chart_rounded,
      iconColor: Color(0xFFEF9A9A),
      title: 'تابع إحصائياتك',
      body: 'من شاشة الكتابة يمكنك:\n\n'
            '• رؤية عدد القراء لكل فصل\n'
            '• معدل إكمال الرواية\n'
            '• عدد الإعجابات والتقييمات\n\n'
            'اضغط على أيقونة 📊 بجانب روايتك.',
    ),
  ];

  Future<void> _finish() async {
    await WriterOnboardingScreen.markDone();
    // حفظ تاريخ أول نشر
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      FirebaseFirestore.instance.collection('users').doc(user.uid).set(
        {'firstPublishedAt': FieldValue.serverTimestamp()},
        SetOptions(merge: true),
      );
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Column(
          children: [
            // مؤشر الصفحات
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_pages.length, (i) => AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width:  i == _page ? 20 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: i == _page ? _accent : _surface,
                  borderRadius: BorderRadius.circular(3),
                ),
              )),
            ),
            const SizedBox(height: 8),

            // الصفحات
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (p) => setState(() => _page = p),
                itemCount: _pages.length,
                itemBuilder: (_, i) => _buildPage(_pages[i]),
              ),
            ),

            // الأزرار
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: Row(children: [
                if (_page > 0)
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _pageController.previousPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeOut),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: _accent),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: Text('السابق',
                          style: GoogleFonts.cairo(
                              color: _accent, fontWeight: FontWeight.w600)),
                    ),
                  ),
                if (_page > 0) const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: _page < _pages.length - 1
                        ? () => _pageController.nextPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeOut)
                        : _finish,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _accent,
                      foregroundColor: _bg,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: Text(
                      _page < _pages.length - 1 ? 'التالي' : 'ابدأ الكتابة',
                      style: GoogleFonts.cairo(
                          fontWeight: FontWeight.w700, fontSize: 15),
                    ),
                  ),
                ),
              ]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPage(_OnboardPage page) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              color: page.iconColor.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(page.icon, size: 44, color: page.iconColor),
          ),
          const SizedBox(height: 28),
          Text(page.title,
              style: GoogleFonts.cairo(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: _textPrimary),
              textAlign: TextAlign.center),
          const SizedBox(height: 16),
          Text(page.body,
              style: GoogleFonts.cairo(
                  fontSize: 14, color: _textSec, height: 1.8),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

class _OnboardPage {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String body;
  const _OnboardPage({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.body,
  });
}
