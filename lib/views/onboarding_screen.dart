import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OnboardingScreen extends StatefulWidget {
  final VoidCallback onDone;
  const OnboardingScreen({super.key, required this.onDone});

  static Future<bool> shouldShow() async {
    final prefs = await SharedPreferences.getInstance();
    return !(prefs.getBool('onboarding_done') ?? false);
  }

  static Future<void> markDone() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_done', true);
  }

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  static const _bg           = Color(0xFF0D0F14);
  static const _surface      = Color(0xFF161920);
  static const _accent       = Color(0xFFC4A87A);
  static const _border       = Color(0xFF252836);
  static const _textPrimary  = Color(0xFFECECEC);
  static const _textSecondary= Color(0xFF6B7280);
  static const _gold         = Color(0xFFD4A843);

  final _pageController = PageController();
  int _currentPage = 0;

  final List<String> _allCategories = [
    'فانتازيا', 'دراما', 'رعب', 'غموض', 'تاريخية', 'خيال علمي', 'عام',
  ];
  final Set<String> _selectedCategories = {};
  String _readingGoal = 'متوسط'; // خفيف / متوسط / شره

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'preferredCategories': _selectedCategories.toList(),
          'readingGoal':         _readingGoal,
          'onboardingDone':      true,
        }, SetOptions(merge: true));
      }
    } catch (_) {}
    await OnboardingScreen.markDone();
    if (mounted) widget.onDone();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Column(
          children: [
            // مؤشر الصفحات
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
              child: Row(
                children: List.generate(3, (i) => Expanded(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    height: 3,
                    decoration: BoxDecoration(
                      color: i <= _currentPage ? _accent : _border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                )),
              ),
            ),

            // المحتوى
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (i) => setState(() => _currentPage = i),
                children: [
                  _buildWelcomePage(),
                  _buildCategoriesPage(),
                  _buildGoalPage(),
                ],
              ),
            ),

            // أزرار التنقل
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: Row(
                children: [
                  if (_currentPage > 0)
                    Expanded(
                      flex: 1,
                      child: OutlinedButton(
                        onPressed: () => _pageController.previousPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _textSecondary,
                          side: const BorderSide(color: _border),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text('رجوع', style: GoogleFonts.cairo()),
                      ),
                    ),
                  if (_currentPage > 0) const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: () {
                        if (_currentPage < 2) {
                          _pageController.nextPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          );
                        } else {
                          _finish();
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _accent,
                        foregroundColor: _bg,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(
                        _currentPage < 2 ? 'التالي' : 'ابدأ القراءة!',
                        style: GoogleFonts.cairo(
                            fontWeight: FontWeight.w700, fontSize: 15),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomePage() {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 90, height: 90,
            decoration: BoxDecoration(
              color: _accent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: _accent.withValues(alpha: 0.3)),
            ),
            child: const Icon(Icons.auto_stories_rounded, size: 44, color: _accent),
          ),
          const SizedBox(height: 32),
          Text('أهلاً في راوي',
              style: GoogleFonts.cairo(
                  fontSize: 28, fontWeight: FontWeight.w700, color: _textPrimary)),
          const SizedBox(height: 14),
          Text(
            'منصتك لاكتشاف وقراءة ومشاركة أفضل\nالروايات العربية',
            textAlign: TextAlign.center,
            style: GoogleFonts.cairo(fontSize: 15, color: _textSecondary, height: 1.7),
          ),
          const SizedBox(height: 32),
          _featureRow(Icons.bookmark_rounded, 'احفظ الروايات واقرأها لاحقاً'),
          const SizedBox(height: 12),
          _featureRow(Icons.star_rounded, 'قيّم الفصول واربح نقاطاً'),
          const SizedBox(height: 12),
          _featureRow(Icons.edit_note_rounded, 'انشر روايتك وابنِ جمهورك'),
        ],
      ),
    );
  }

  Widget _featureRow(IconData icon, String text) {
    return Row(
      children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: _accent),
        ),
        const SizedBox(width: 12),
        Text(text, style: GoogleFonts.cairo(fontSize: 14, color: _textPrimary)),
      ],
    );
  }

  Widget _buildCategoriesPage() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          Text('ما أنواع الروايات التي تحبها؟',
              style: GoogleFonts.cairo(
                  fontSize: 22, fontWeight: FontWeight.w700, color: _textPrimary)),
          const SizedBox(height: 8),
          Text('اختر فئة أو أكثر لنخصص لك التجربة',
              style: GoogleFonts.cairo(fontSize: 13, color: _textSecondary)),
          const SizedBox(height: 24),
          Expanded(
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: _allCategories.map((cat) {
                final sel = _selectedCategories.contains(cat);
                return GestureDetector(
                  onTap: () => setState(() {
                    if (sel) { _selectedCategories.remove(cat); }
                    else     { _selectedCategories.add(cat); }
                  }),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: sel ? _accent : _surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: sel ? _accent : _border),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      if (sel) ...[
                        const Icon(Icons.check_rounded, size: 14, color: Color(0xFF0D0F14)),
                        const SizedBox(width: 6),
                      ],
                      Text(cat,
                          style: GoogleFonts.cairo(
                              fontSize: 14,
                              fontWeight: sel ? FontWeight.w700 : FontWeight.w400,
                              color: sel ? const Color(0xFF0D0F14) : _textSecondary)),
                    ]),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGoalPage() {
    final goals = [
      ('خفيف',   'فصل أو اثنان أسبوعياً',   Icons.coffee_rounded,       _textSecondary),
      ('متوسط',  'بضعة فصول أسبوعياً',       Icons.local_fire_department, _accent),
      ('شره',    'أقرأ كل يوم!',             Icons.rocket_launch_rounded, _gold),
    ];

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          Text('ما هدفك في القراءة؟',
              style: GoogleFonts.cairo(
                  fontSize: 22, fontWeight: FontWeight.w700, color: _textPrimary)),
          const SizedBox(height: 8),
          Text('نذكّرك برفق بناءً على هدفك',
              style: GoogleFonts.cairo(fontSize: 13, color: _textSecondary)),
          const SizedBox(height: 28),
          ...goals.map((g) {
            final sel = _readingGoal == g.$1;
            return GestureDetector(
              onTap: () => setState(() => _readingGoal = g.$1),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: sel ? _accent.withValues(alpha: 0.08) : _surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: sel ? _accent : _border, width: sel ? 1.5 : 1),
                ),
                child: Row(children: [
                  Icon(g.$3, color: g.$4, size: 24),
                  const SizedBox(width: 14),
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(g.$1, style: GoogleFonts.cairo(
                          fontSize: 16, fontWeight: FontWeight.w700,
                          color: sel ? _accent : _textPrimary)),
                      Text(g.$2, style: GoogleFonts.cairo(
                          fontSize: 12, color: _textSecondary)),
                    ],
                  )),
                  if (sel) const Icon(Icons.check_circle_rounded, color: _accent, size: 20),
                ]),
              ),
            );
          }),
        ],
      ),
    );
  }
}

