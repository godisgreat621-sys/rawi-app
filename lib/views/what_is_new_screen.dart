import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

class WhatsNewScreen extends StatelessWidget {
  static const _version  = '1.3.0';
  static const _prefKey  = 'whats_new_seen_v$_version';

  static const _bg           = Color(0xFF0D0F14);
  static const _surface      = Color(0xFF161920);
  static const _accent       = Color(0xFF8BAF7C);
  static const _border       = Color(0xFF252836);
  static const _textPrimary  = Color(0xFFECECEC);
  static const _textSecondary= Color(0xFF6B7280);
  static const _gold         = Color(0xFFD4A843);

  const WhatsNewScreen({super.key});

  static Future<bool> shouldShow() async {
    final prefs = await SharedPreferences.getInstance();
    return !(prefs.getBool(_prefKey) ?? false);
  }

  static Future<void> markSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKey, true);
  }

  static const _features = [
    (Icons.palette_outlined,       _accent, 'خيار داكن/فاتح',      'غيّر سمة التطبيق من إعدادات حسابك'),
    (Icons.grid_view_rounded,      _accent, 'عرض قائمة أو شبكة',   'بدّل بين طريقتي العرض في المكتبة'),
    (Icons.filter_alt_outlined,    _gold,   'فلاتر متقدمة',         'اكتشف الروايات المكتملة، اليوم، الأعلى تقييماً'),
    (Icons.recommend_outlined,     _gold,   'موصى به لك',           'روايات من تصنيفاتك المفضلة تلقائياً'),
    (Icons.favorite_outline,       Colors.redAccent, 'إعجاب بالتعليقات', 'قيّم تعليقات القراء الآخرين'),
    (Icons.redeem_rounded,         _gold,   'هدية النقاط',           'أرسل 5 نقاط هدية لكاتبك المفضل'),
    (Icons.people_outline_rounded, _accent, 'ما يقرأه أصدقاؤك',    'اعرف ما يقرأه من تتابعهم'),
    (Icons.leaderboard_rounded,    _gold,   'المتصدرون ورتبتك',     'انظر ترتيبك الأسبوعي بين القراء'),
    (Icons.lock_outline_rounded,   _textSecondary, 'منع لقطات الشاشة', 'محتوى الروايات محمي بالكامل'),
    (Icons.workspace_premium_rounded, Colors.purpleAccent, 'شارات الإنجاز', 'شارات تكتسبها عند تحقيق أهداف النقاط'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
              child: Column(children: [
                Container(
                  width: 52, height: 52,
                  decoration: BoxDecoration(
                    color: _accent.withOpacity(0.12),
                    shape: BoxShape.circle,
                    border: Border.all(color: _accent.withOpacity(0.3)),
                  ),
                  child: const Icon(Icons.auto_awesome_rounded,
                      color: _accent, size: 26),
                ),
                const SizedBox(height: 14),
                Text('ما الجديد في راوي $_version',
                    style: GoogleFonts.cairo(
                        fontSize: 20, fontWeight: FontWeight.w700,
                        color: _textPrimary)),
                const SizedBox(height: 6),
                Text('تحديثات وميزات جديدة أضفناها لك',
                    style: GoogleFonts.cairo(
                        fontSize: 13, color: _textSecondary)),
              ]),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: _features.length,
                separatorBuilder: (_, __) => const SizedBox(height: 1),
                itemBuilder: (_, i) {
                  final f = _features[i];
                  return Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    margin: const EdgeInsets.only(bottom: 6),
                    decoration: BoxDecoration(
                      color: _surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _border),
                    ),
                    child: Row(children: [
                      Container(
                        width: 38, height: 38,
                        decoration: BoxDecoration(
                          color: f.$2.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(f.$1, color: f.$2, size: 18),
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(f.$3, style: GoogleFonts.cairo(
                              fontSize: 13, fontWeight: FontWeight.w700,
                              color: _textPrimary)),
                          Text(f.$4, style: GoogleFonts.cairo(
                              fontSize: 11, color: _textSecondary)),
                        ],
                      )),
                    ]),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    await markSeen();
                    if (context.mounted) Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _accent,
                    foregroundColor: _bg,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text('رائع! هيا نبدأ',
                      style: GoogleFonts.cairo(
                          fontWeight: FontWeight.w700, fontSize: 14)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
