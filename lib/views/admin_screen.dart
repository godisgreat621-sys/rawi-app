import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:my_first_app/providers/novels_provider.dart';
import 'package:my_first_app/providers/theme_provider.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});
  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen>
    with SingleTickerProviderStateMixin {
  static const _accent = Color(0xFF8BAF7C);
  static const _gold   = Color(0xFFD4A843);
  Color _bg            = const Color(0xFF0D0F14);
  Color _surface       = const Color(0xFF161920);
  Color _surfaceHigh   = const Color(0xFF1E2130);
  Color _border        = const Color(0xFF252836);
  Color _textPrimary   = const Color(0xFFECECEC);
  Color _textSecondary = const Color(0xFF6B7280);

  String _userSearch   = '';
  String _novelSearch  = '';
  String _novelFilter  = 'all';
  String _broadcastTarget = 'all';
  late TabController _tab;

  final _bannerCtrl     = TextEditingController();
  final _broadcastCtrl  = TextEditingController();
  final _msgUserCtrl    = TextEditingController();
  final _msgTextCtrl    = TextEditingController();
  final _minWordsCtrl   = TextEditingController(text: '500');
  final _maxWordsCtrl   = TextEditingController(text: '5000');
  final _newCatCtrl     = TextEditingController();
  final _bannedWordCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 8, vsync: this);
    _loadSettings();
  }

  @override
  void dispose() {
    _tab.dispose();
    for (final c in [_bannerCtrl,_broadcastCtrl,_msgUserCtrl,_msgTextCtrl,_minWordsCtrl,_maxWordsCtrl,_newCatCtrl,_bannedWordCtrl]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final doc = await FirebaseFirestore.instance.collection('system_settings').doc('app_config').get();
    if (!mounted) return;
    final data = doc.data() ?? {};
    setState(() {
      _minWordsCtrl.text = '${data['minWords'] ?? 500}';
      _maxWordsCtrl.text = '${data['maxWords'] ?? 5000}';
    });
  }

  Future<void> _log(String action, {Map<String,dynamic>? extra}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    await FirebaseFirestore.instance.collection('admin_logs').add({
      'adminUid': user.uid, 'adminEmail': user.email ?? '',
      'action': action, 'at': FieldValue.serverTimestamp(),
      ...?extra,
    });
  }

  Future<bool> _confirm(String msg) async =>
      await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: _surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          title: Text('تأكيد', style: GoogleFonts.cairo(color: _textPrimary, fontWeight: FontWeight.w700)),
          content: Text(msg, style: GoogleFonts.cairo(color: _textSecondary, height: 1.6)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('إلغاء', style: GoogleFonts.cairo(color: _textSecondary))),
            TextButton(onPressed: () => Navigator.pop(ctx, true),  child: Text('تأكيد', style: GoogleFonts.cairo(color: Colors.redAccent, fontWeight: FontWeight.w700))),
          ],
        ),
      ) ?? false;

  void _snack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: GoogleFonts.cairo()),
      backgroundColor: color, behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  // ══════════════════════════════════════════════════════════════════════════
  // ① إحصائيات
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildStatsTab() => SingleChildScrollView(
    padding: const EdgeInsets.all(16),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      FutureBuilder<List<int>>(
        future: Future.wait([
          FirebaseFirestore.instance.collection('novels').count().get().then((s) => s.count ?? 0),
          FirebaseFirestore.instance.collection('users').count().get().then((s) => s.count ?? 0),
          FirebaseFirestore.instance.collectionGroup('chapters').count().get().then((s) => s.count ?? 0),
          FirebaseFirestore.instance.collection('reports').count().get().then((s) => s.count ?? 0),
        ]),
        builder: (_, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator(color: _accent));
          final c = snap.data!;
          return GridView.count(
            shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2, crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 1.7,
            children: [
              _statCard('${c[0]}', 'رواية',    Icons.auto_stories_rounded, _accent),
              _statCard('${c[1]}', 'مستخدم',   Icons.people_rounded,       Colors.blueGrey),
              _statCard('${c[2]}', 'فصل',       Icons.menu_book_rounded,    _gold),
              _statCard('${c[3]}', 'بلاغ',      Icons.flag_rounded,         Colors.redAccent),
            ],
          );
        },
      ),
      const SizedBox(height: 20),
      _sectionTitle('التسجيلات — آخر 7 أيام'),
      const SizedBox(height: 10),
      _buildWeeklyBar(),
      const SizedBox(height: 20),
      _sectionTitle('أعلى 5 روايات قراءةً'),
      const SizedBox(height: 8),
      StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('novels').orderBy('readers', descending: true).limit(5).snapshots(),
        builder: (_, s) {
          if (!s.hasData) return const SizedBox();
          return Column(children: s.data!.docs.map((d) {
            final data = d.data() as Map<String,dynamic>;
            return ListTile(
              contentPadding: EdgeInsets.zero, dense: true,
              leading: Icon(Icons.auto_stories_rounded, color: _accent, size: 18),
              title: Text(data['title'] ?? '', style: GoogleFonts.cairo(fontSize: 13, color: _textPrimary), maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text(data['authorName'] ?? '', style: GoogleFonts.cairo(fontSize: 11, color: _textSecondary)),
              trailing: Text('${data['readers'] ?? 0} قارئ', style: GoogleFonts.cairo(fontSize: 11, color: _textSecondary)),
            );
          }).toList());
        },
      ),
    ]),
  );

  Widget _buildWeeklyBar() {
    final days = List.generate(7, (i) {
      final d = DateTime.now().subtract(Duration(days: 6 - i));
      return DateTime(d.year, d.month, d.day);
    });
    const dayNames = ['أحد','اثنين','ثلاثاء','أربعاء','خميس','جمعة','سبت'];
    return FutureBuilder<List<int>>(
      future: Future.wait(days.map((day) async {
        final next = day.add(const Duration(days: 1));
        final s = await FirebaseFirestore.instance.collection('users')
            .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(day))
            .where('createdAt', isLessThan: Timestamp.fromDate(next))
            .count().get();
        return s.count ?? 0;
      })),
      builder: (_, snap) {
        if (!snap.hasData) return const SizedBox(height: 50, child: Center(child: CircularProgressIndicator(color: _accent)));
        final counts = snap.data!;
        final maxVal = counts.reduce((a, b) => a > b ? a : b).clamp(1, 9999);
        return Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: List.generate(7, (i) {
            final h = (counts[i] / maxVal * 70).clamp(4.0, 70.0);
            return Expanded(child: Column(children: [
              Text('${counts[i]}', style: GoogleFonts.cairo(fontSize: 10, color: _accent)),
              const SizedBox(height: 2),
              Container(height: h, margin: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(color: counts[i] > 0 ? _accent.withOpacity(0.6) : _surfaceHigh, borderRadius: BorderRadius.circular(4))),
              const SizedBox(height: 4),
              Text(dayNames[days[i].weekday % 7], style: GoogleFonts.cairo(fontSize: 9, color: _textSecondary)),
            ]));
          }),
        );
      },
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // ② المستخدمون
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildUsersTab() => Column(children: [
    Padding(padding: const EdgeInsets.fromLTRB(16,12,16,8),
      child: _searchField('ابحث بالاسم أو البريد...', (v) => setState(() => _userSearch = v.trim().toLowerCase()))),
    Expanded(child: StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('users').orderBy('createdAt', descending: true).snapshots(),
      builder: (_, snap) {
        if (snap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: _accent));
        final all = snap.data?.docs ?? [];
        final users = _userSearch.isEmpty ? all : all.where((d) {
          final data = d.data() as Map<String,dynamic>;
          return (data['displayName'] ?? '').toString().toLowerCase().contains(_userSearch)
              || (data['email'] ?? '').toString().toLowerCase().contains(_userSearch);
        }).toList();
        if (users.isEmpty) return Center(child: Text('لا نتائج', style: GoogleFonts.cairo(color: _textSecondary)));
        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 4),
          itemCount: users.length,
          itemBuilder: (_, i) => _userCard(users[i].id, users[i].data() as Map<String,dynamic>),
        );
      },
    )),
  ]);

  Widget _userCard(String uid, Map<String,dynamic> data) {
    final role    = data['role'] ?? 'user';
    final pts     = (data['points'] ?? 0) as int;
    final banned  = data['bannedUntil'] as Timestamp?;
    final isBanned = banned != null && banned.toDate().isAfter(DateTime.now());
    final isPerm  = data['isPermanentBan'] == true;
    final joined  = (data['createdAt'] as Timestamp?)?.toDate();

    return Card(
      color: _surface, margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: isPerm ? Colors.red.shade900.withOpacity(0.5) : isBanned ? Colors.redAccent.withOpacity(0.3) : _border)),
      child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          CircleAvatar(radius: 18, backgroundColor: _accent.withOpacity(0.15),
            backgroundImage: data['profilePicture'] != null ? NetworkImage(data['profilePicture']) : null,
            child: data['profilePicture'] == null ? Text((data['displayName'] ?? '؟')[0], style: GoogleFonts.cairo(color: _accent, fontWeight: FontWeight.w700)) : null),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(data['displayName'] ?? data['email'] ?? 'مستخدم', style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: _textPrimary, fontSize: 13)),
            Text(data['email'] ?? '', style: GoogleFonts.cairo(fontSize: 10, color: _textSecondary), maxLines: 1, overflow: TextOverflow.ellipsis),
          ])),
          _roleBadge(role),
        ]),
        const SizedBox(height: 6),
        Row(children: [
          Icon(Icons.star_rounded, size: 12, color: _gold), const SizedBox(width: 3),
          Text('$pts نقطة', style: GoogleFonts.cairo(fontSize: 11, color: _textSecondary)),
          if (joined != null) ...[const SizedBox(width: 12), Icon(Icons.calendar_today_outlined, size: 12, color: _textSecondary), const SizedBox(width: 3), Text('${joined.day}/${joined.month}/${joined.year}', style: GoogleFonts.cairo(fontSize: 11, color: _textSecondary))],
          if (isPerm)   ...[const SizedBox(width: 8), _badge('حظر دائم', Colors.red.shade900)],
          if (isBanned && !isPerm) ...[const SizedBox(width: 8), _badge('محظور', Colors.redAccent)],
        ]),
        const SizedBox(height: 10),
        Wrap(spacing: 6, runSpacing: 6, children: [
          _actionBtn(label: role == 'admin' ? 'خفض' : 'ترقية', color: _accent, onTap: () async {
            if (!await _confirm(role == 'admin' ? 'خفض عن الأدمن؟' : 'ترقية لأدمن؟')) return;
            await context.read<NovelsProvider>().setUserRole(uid, role == 'admin' ? 'user' : 'admin');
            await _log('toggle_role', extra: {'targetUid': uid});
            _snack('تم ✅', _accent);
          }),
          _actionBtn(label: isBanned ? 'رفع الحظر' : 'حظر 24h', color: Colors.orange, onTap: () async {
            if (!await _confirm(isBanned ? 'رفع الحظر؟' : 'حظر 24 ساعة؟')) return;
            final until = isBanned ? DateTime(2000) : DateTime.now().add(const Duration(days: 1));
            await FirebaseFirestore.instance.collection('users').doc(uid).update({'bannedUntil': Timestamp.fromDate(until), 'isPermanentBan': false});
            await _log(isBanned ? 'unban' : 'ban_24h', extra: {'targetUid': uid});
            _snack(isBanned ? 'رُفع الحظر' : 'محظور 24h', Colors.orange);
          }),
          _actionBtn(label: 'حظر أسبوع', color: Colors.redAccent, onTap: () async {
            if (!await _confirm('حظر أسبوعاً كاملاً؟')) return;
            await FirebaseFirestore.instance.collection('users').doc(uid)
                .update({'bannedUntil': Timestamp.fromDate(DateTime.now().add(const Duration(days: 7))), 'isPermanentBan': false});
            await _log('ban_week', extra: {'targetUid': uid});
            _snack('محظور أسبوع', Colors.redAccent);
          }),
          _actionBtn(label: 'حظر دائم', color: Colors.red.shade900, onTap: () async {
            if (!await _confirm('حظر دائم؟ لا يمكن التراجع إلا يدوياً.')) return;
            await FirebaseFirestore.instance.collection('users').doc(uid)
                .update({'bannedUntil': Timestamp.fromDate(DateTime(2099)), 'isPermanentBan': true});
            await _log('ban_permanent', extra: {'targetUid': uid});
            _snack('محظور بشكل دائم', Colors.red.shade900);
          }),
          _actionBtn(label: 'منح نقاط', color: Colors.blueGrey, onTap: () => _showGrantPoints(uid, data['displayName'] ?? '')),
          _actionBtn(label: 'تصفير', color: _textSecondary, onTap: () async {
            if (!await _confirm('تصفير النقاط؟')) return;
            await FirebaseFirestore.instance.collection('users').doc(uid).update({'points': 0});
            await _log('reset_points', extra: {'targetUid': uid});
            _snack('تم التصفير', _textSecondary);
          }),
        ]),
      ])),
    );
  }

  void _showGrantPoints(String uid, String name) {
    final ptsCtrl = TextEditingController();
    final msgCtrl = TextEditingController();
    showDialog(context: context, builder: (ctx) => AlertDialog(
      backgroundColor: _surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      title: Text('منح نقاط لـ $name', style: GoogleFonts.cairo(color: _textPrimary, fontSize: 15, fontWeight: FontWeight.w700)),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: ptsCtrl, keyboardType: TextInputType.number, style: GoogleFonts.cairo(color: _textPrimary), decoration: _inputDeco('عدد النقاط')),
        const SizedBox(height: 12),
        TextField(controller: msgCtrl, style: GoogleFonts.cairo(color: _textPrimary), decoration: _inputDeco('رسالة للمستخدم (اختياري)')),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: Text('إلغاء', style: GoogleFonts.cairo(color: _textSecondary))),
        TextButton(onPressed: () async {
          final pts = int.tryParse(ptsCtrl.text.trim()) ?? 0;
          if (pts <= 0) return;
          Navigator.pop(ctx);
          await FirebaseFirestore.instance.collection('users').doc(uid).update({'points': FieldValue.increment(pts)});
          await FirebaseFirestore.instance.collection('users').doc(uid).collection('pointsHistory').add(
              {'delta': pts, 'reason': 'منحة من الأدمن', 'createdAt': FieldValue.serverTimestamp()});
          if (msgCtrl.text.trim().isNotEmpty) {
            await FirebaseFirestore.instance.collection('notifications').add({
              'userId': uid, 'type': 'admin_points', 'isRead': false,
              'body': '${msgCtrl.text.trim()} (+$pts نقطة)', 'createdAt': FieldValue.serverTimestamp(),
            });
          }
          await _log('grant_points', extra: {'targetUid': uid, 'points': pts});
          _snack('تم منح $pts نقطة ✅', _accent);
        }, child: Text('منح', style: GoogleFonts.cairo(color: _accent, fontWeight: FontWeight.w700))),
      ],
    ));
  }

  // ══════════════════════════════════════════════════════════════════════════
  // ③ الروايات
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildNovelsTab() => Column(children: [
    Padding(padding: const EdgeInsets.fromLTRB(16,12,16,8),
      child: _searchField('ابحث بعنوان الرواية...', (v) => setState(() => _novelSearch = v.trim().toLowerCase()))),
    SizedBox(height: 36, child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [_filterChip('الكل','all'), _filterChip('مميزة ⭐','featured'), _filterChip('مجمدة ❄️','frozen'), _filterChip('مكتملة','completed')])),
    const SizedBox(height: 8),
    Expanded(child: StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('novels').orderBy('createdAt', descending: true).snapshots(),
      builder: (_, snap) {
        if (snap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: _accent));
        final all = snap.data?.docs ?? [];
        final novels = all.where((d) {
          final data = d.data() as Map<String,dynamic>;
          if (_novelSearch.isNotEmpty && !(data['title'] ?? '').toString().toLowerCase().contains(_novelSearch)) return false;
          if (_novelFilter == 'featured')  return data['isFeatured'] == true;
          if (_novelFilter == 'frozen')    return data['isFrozen'] == true;
          if (_novelFilter == 'completed') return data['status'] == 'completed';
          return true;
        }).toList();
        if (novels.isEmpty) return Center(child: Text('لا توجد روايات', style: GoogleFonts.cairo(color: _textSecondary)));
        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 4),
          itemCount: novels.length,
          itemBuilder: (_, i) => _novelCard(novels[i].id, novels[i].data() as Map<String,dynamic>),
        );
      },
    )),
  ]);

  Widget _novelCard(String id, Map<String,dynamic> data) {
    final isFrozen   = data['isFrozen'] == true;
    final isCompleted= data['status'] == 'completed';
    final isFeatured = data['isFeatured'] == true;
    return Card(
      color: _surface, margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: isFeatured ? _gold.withOpacity(0.5) : isFrozen ? Colors.blueGrey.withOpacity(0.4) : _border)),
      child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(data['title'] ?? '', style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: _textPrimary, fontSize: 13), maxLines: 2, overflow: TextOverflow.ellipsis)),
          const SizedBox(width: 8),
          if (isFeatured) _badge('⭐', _gold),
          if (isFrozen)   _badge('❄️', Colors.blueGrey),
          if (isCompleted && !isFrozen) _badge('✅', Colors.green),
        ]),
        const SizedBox(height: 4),
        Text('${data['authorName'] ?? '—'}', style: GoogleFonts.cairo(fontSize: 11, color: _textSecondary)),
        const SizedBox(height: 6),
        Row(children: [
          Icon(Icons.remove_red_eye_outlined, size: 12, color: _textSecondary), const SizedBox(width: 3),
          Text('${data['readers'] ?? 0}', style: GoogleFonts.cairo(fontSize: 11, color: _textSecondary)),
          const SizedBox(width: 12),
          Icon(Icons.menu_book_rounded, size: 12, color: _textSecondary), const SizedBox(width: 3),
          Text('${data['chaptersCount'] ?? 0} فصل', style: GoogleFonts.cairo(fontSize: 11, color: _textSecondary)),
        ]),
        const SizedBox(height: 10),
        Wrap(spacing: 6, runSpacing: 6, children: [
          _actionBtn(label: isFeatured ? 'إلغاء التمييز' : 'تمييز ⭐', color: _gold, onTap: () async {
            await FirebaseFirestore.instance.collection('novels').doc(id).update({'isFeatured': !isFeatured});
            await _log(isFeatured ? 'unfeature' : 'feature', extra: {'novelId': id});
            _snack(isFeatured ? 'أُزيل التمييز' : 'مميزة ⭐', _gold);
          }),
          _actionBtn(label: isFrozen ? 'رفع التجميد' : 'تجميد', color: Colors.blueGrey, onTap: () async {
            if (!await _confirm(isFrozen ? 'رفع التجميد؟' : 'تجميد الرواية؟')) return;
            await FirebaseFirestore.instance.collection('novels').doc(id).update({'isFrozen': !isFrozen});
            await _log(isFrozen ? 'unfreeze' : 'freeze', extra: {'novelId': id});
            _snack(isFrozen ? 'رُفع التجميد ✅' : 'مجمدة ❄️', isFrozen ? Colors.green : Colors.blueGrey);
          }),
          _actionBtn(label: 'حذف', color: Colors.redAccent, onTap: () async {
            if (!await _confirm('حذف "${data['title']}" نهائياً؟')) return;
            await FirebaseFirestore.instance.collection('novels').doc(id).delete();
            await _log('delete_novel', extra: {'novelId': id, 'title': data['title']});
            _snack('تم الحذف ✅', Colors.green);
          }),
        ]),
      ])),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // ④ البلاغات
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildReportsTab() => StreamBuilder<QuerySnapshot>(
    stream: FirebaseFirestore.instance.collection('reports').orderBy('createdAt', descending: true).limit(50).snapshots(),
    builder: (_, snap) {
      if (snap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: _accent));
      final docs = snap.data?.docs ?? [];
      if (docs.isEmpty) return Center(child: Text('لا توجد بلاغات', style: GoogleFonts.cairo(color: _textSecondary)));
      final freq = <String,int>{};
      for (final d in docs) { final uid = (d.data() as Map<String,dynamic>)['reportedUser'] as String? ?? ''; if (uid.isNotEmpty) freq[uid] = (freq[uid] ?? 0) + 1; }
      return ListView.builder(
        padding: const EdgeInsets.all(16), itemCount: docs.length,
        itemBuilder: (_, i) {
          final doc  = docs[i];
          final data = doc.data() as Map<String,dynamic>;
          final rUid = data['reportedUser'] as String? ?? '';
          final cnt  = freq[rUid] ?? 1;
          final dismissed = data['status'] == 'dismissed';
          final ts   = (data['createdAt'] as Timestamp?)?.toDate();
          return Card(
            color: dismissed ? _surfaceHigh : _surface, margin: const EdgeInsets.only(bottom: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: cnt >= 3 ? Colors.redAccent.withOpacity(0.4) : _border)),
            child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text('بلاغ: ${data['reason'] ?? data['type'] ?? 'مخالفة'}', style: GoogleFonts.cairo(fontSize: 13, fontWeight: FontWeight.w700, color: dismissed ? _textSecondary : _textPrimary))),
                if (cnt >= 3) _badge('$cnt بلاغات', Colors.redAccent),
                if (dismissed) _badge('مُتجاهل', _textSecondary),
              ]),
              if (data['content'] != null) ...[
                const SizedBox(height: 6),
                Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: _surfaceHigh, borderRadius: BorderRadius.circular(8)),
                  child: Text('${data['content']}', style: GoogleFonts.cairo(fontSize: 12, color: _textSecondary), maxLines: 3, overflow: TextOverflow.ellipsis)),
              ],
              if (ts != null) ...[const SizedBox(height: 4), Text('${ts.day}/${ts.month}/${ts.year}', style: GoogleFonts.cairo(fontSize: 10, color: _textSecondary))],
              if (!dismissed) ...[
                const SizedBox(height: 10),
                Wrap(spacing: 6, runSpacing: 6, children: [
                  if (rUid.isNotEmpty) _actionBtn(label: 'حظر 24h', color: Colors.orange, onTap: () async {
                    if (!await _confirm('حظر المُبلَّغ عنه 24h؟')) return;
                    await FirebaseFirestore.instance.collection('users').doc(rUid).update({'bannedUntil': Timestamp.fromDate(DateTime.now().add(const Duration(days: 1)))});
                    await _log('ban_from_report', extra: {'targetUid': rUid});
                    _snack('تم الحظر', Colors.orange);
                  }),
                  _actionBtn(label: 'تجاهل', color: _textSecondary, onTap: () async {
                    await FirebaseFirestore.instance.collection('reports').doc(doc.id).update({'status': 'dismissed'});
                    await _log('dismiss_report', extra: {'reportId': doc.id});
                    _snack('تم التجاهل', _textSecondary);
                  }),
                ]),
              ],
            ])),
          );
        },
      );
    },
  );

  // ══════════════════════════════════════════════════════════════════════════
  // ⑤ الدعم الفني
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildSupportTab() => StreamBuilder<QuerySnapshot>(
    stream: FirebaseFirestore.instance.collection('support_requests').orderBy('createdAt', descending: true).snapshots(),
    builder: (_, snap) {
      if (snap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: _accent));
      final docs = snap.data?.docs ?? [];
      final pend = docs.where((d) => (d.data() as Map)['status'] == 'pending').toList();
      final done = docs.where((d) => (d.data() as Map)['status'] != 'pending').toList();
      return ListView(padding: const EdgeInsets.all(16), children: [
        if (pend.isNotEmpty) ...[
          Row(children: [_sectionTitle('قيد الانتظار'), const SizedBox(width: 8), _badge('${pend.length}', _gold)]),
          const SizedBox(height: 8), ...pend.map(_supportCard), const SizedBox(height: 16),
        ],
        if (done.isNotEmpty) ...[_sectionTitle('تمت المعالجة'), const SizedBox(height: 8), ...done.take(10).map(_supportCard)],
      ]);
    },
  );

  Widget _supportCard(DocumentSnapshot doc) {
    final data  = doc.data() as Map<String,dynamic>;
    final status= data['status'] ?? 'pending';
    final isPend= status == 'pending';
    return Card(
      color: _surface, margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: isPend ? _gold.withOpacity(0.3) : _border)),
      child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Expanded(child: Text(data['title'] ?? 'طلب دعم', style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: _textPrimary, fontSize: 13))),
          _statusBadge(status),
        ]),
        const SizedBox(height: 4),
        Text('${data['type'] ?? '—'} | ${data['authorName'] ?? data['authorEmail'] ?? '—'}', style: GoogleFonts.cairo(fontSize: 11, color: _textSecondary)),
        const SizedBox(height: 8),
        Text(data['description'] ?? '', style: GoogleFonts.cairo(fontSize: 13, color: _textPrimary, height: 1.6)),
        if (!isPend) ...[const SizedBox(height: 6), Text('الرد: ${data['response'] ?? '—'}', style: GoogleFonts.cairo(fontSize: 12, color: _textSecondary))],
        if (isPend) ...[
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: _actionBtn(label: 'موافقة', color: _accent, onTap: () => _resolve(doc.id, 'approved'))),
            const SizedBox(width: 8),
            Expanded(child: _actionBtn(label: 'رفض', color: Colors.redAccent, onTap: () => _resolve(doc.id, 'rejected'))),
          ]),
        ],
      ])),
    );
  }

  Future<void> _resolve(String id, String status) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final doc  = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    final name = doc.data()?['displayName'] ?? user.email ?? 'الأدمن';
    await context.read<NovelsProvider>().resolveSupportRequest(
        id, status, 'تم ${status == 'approved' ? 'الموافقة' : 'الرفض'} من الأدمن $name.', user.uid, name);
    await _log('resolve_support', extra: {'requestId': id, 'status': status});
    _snack(status == 'approved' ? 'موافق ✅' : 'مرفوض', status == 'approved' ? _accent : Colors.redAccent);
  }

  // ══════════════════════════════════════════════════════════════════════════
  // ⑥ الإعلانات
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildAnnouncementsTab() => SingleChildScrollView(
    padding: const EdgeInsets.all(16),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // بانر داخل التطبيق
      _sectionTitle('بانر داخل التطبيق'),
      const SizedBox(height: 10),
      StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('system_settings').doc('banner').snapshots(),
        builder: (_, snap) {
          final d = (snap.data?.data() as Map?);
          final active = d?['active'] == true;
          final text   = d?['text'] ?? '';
          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(active ? 'نشط: "$text"' : 'البانر مُعطَّل', style: GoogleFonts.cairo(fontSize: 12, color: active ? _accent : _textSecondary))),
              Switch(value: active, activeColor: _accent, onChanged: (v) async {
                await FirebaseFirestore.instance.collection('system_settings').doc('banner').set({'active': v, 'text': text}, SetOptions(merge: true));
                await _log(v ? 'enable_banner' : 'disable_banner');
              }),
            ]),
            Row(children: [
              Expanded(child: TextField(controller: _bannerCtrl, style: GoogleFonts.cairo(color: _textPrimary, fontSize: 13), decoration: _inputDeco('نص البانر...'))),
              const SizedBox(width: 10),
              _actionBtn(label: 'نشر', color: _accent, onTap: () async {
                if (_bannerCtrl.text.trim().isEmpty) return;
                await FirebaseFirestore.instance.collection('system_settings').doc('banner').set({'text': _bannerCtrl.text.trim(), 'active': true}, SetOptions(merge: true));
                await _log('update_banner', extra: {'text': _bannerCtrl.text.trim()});
                _snack('تم تفعيل البانر ✅', _accent);
              }),
            ]),
          ]);
        },
      ),
      const SizedBox(height: 20), const Divider(), const SizedBox(height: 16),

      // إشعار جماعي
      _sectionTitle('إشعار جماعي'),
      const SizedBox(height: 10),
      Row(children: [_segBtn('للجميع','all'), const SizedBox(width: 8), _segBtn('للكتّاب فقط','writers')]),
      const SizedBox(height: 10),
      TextField(controller: _broadcastCtrl, maxLines: 3, style: GoogleFonts.cairo(color: _textPrimary, fontSize: 13), decoration: _inputDeco('نص الإشعار...')),
      const SizedBox(height: 10),
      SizedBox(width: double.infinity, child: _actionBtn(label: 'إرسال ${_broadcastTarget == 'writers' ? 'للكتّاب' : 'للجميع'}', color: _accent, onTap: () async {
        if (_broadcastCtrl.text.trim().isEmpty) return;
        if (!await _confirm('إرسال هذا الإشعار؟')) return;
        await _sendBroadcast(_broadcastCtrl.text.trim(), _broadcastTarget == 'writers');
        _broadcastCtrl.clear();
        _snack('تم الإرسال ✅', _accent);
      })),
      const SizedBox(height: 20), const Divider(), const SizedBox(height: 16),

      // رسالة لمستخدم
      _sectionTitle('رسالة لمستخدم محدد'),
      const SizedBox(height: 10),
      TextField(controller: _msgUserCtrl, style: GoogleFonts.cairo(color: _textPrimary, fontSize: 13), decoration: _inputDeco('UID أو بريد المستخدم')),
      const SizedBox(height: 8),
      TextField(controller: _msgTextCtrl, maxLines: 2, style: GoogleFonts.cairo(color: _textPrimary, fontSize: 13), decoration: _inputDeco('نص الرسالة...')),
      const SizedBox(height: 10),
      SizedBox(width: double.infinity, child: _actionBtn(label: 'إرسال', color: Colors.blueGrey, onTap: () async {
        final target = _msgUserCtrl.text.trim();
        final msg    = _msgTextCtrl.text.trim();
        if (target.isEmpty || msg.isEmpty) return;
        String? uid;
        if (target.contains('@')) {
          final s = await FirebaseFirestore.instance.collection('users').where('email', isEqualTo: target).limit(1).get();
          if (s.docs.isNotEmpty) uid = s.docs.first.id;
        } else { uid = target; }
        if (uid == null) { _snack('المستخدم غير موجود', Colors.redAccent); return; }
        await FirebaseFirestore.instance.collection('notifications').add({'userId': uid, 'type': 'admin_message', 'isRead': false, 'body': msg, 'createdAt': FieldValue.serverTimestamp()});
        await _log('message_user', extra: {'targetUid': uid});
        _msgUserCtrl.clear(); _msgTextCtrl.clear();
        _snack('تم الإرسال ✅', _accent);
      })),
    ]),
  );

  Future<void> _sendBroadcast(String text, bool writersOnly) async {
    Query q = FirebaseFirestore.instance.collection('users');
    if (writersOnly) q = q.where('role', isEqualTo: 'writer');
    final snap = await q.get();
    final batch = FirebaseFirestore.instance.batch();
    for (final doc in snap.docs) {
      batch.set(FirebaseFirestore.instance.collection('notifications').doc(), {
        'userId': doc.id, 'type': 'broadcast', 'isRead': false, 'body': text, 'createdAt': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
    await _log('broadcast', extra: {'target': writersOnly ? 'writers' : 'all', 'count': snap.docs.length});
  }

  Widget _segBtn(String label, String val) {
    final sel = _broadcastTarget == val;
    return GestureDetector(
      onTap: () => setState(() => _broadcastTarget = val),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(color: sel ? _accent : _surface, borderRadius: BorderRadius.circular(20), border: Border.all(color: sel ? _accent : _border)),
        child: Text(label, style: GoogleFonts.cairo(fontSize: 12, color: sel ? const Color(0xFF0D0F14) : _textSecondary, fontWeight: sel ? FontWeight.w700 : FontWeight.w400)),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // ⑦ الإعدادات
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildSettingsTab() => SingleChildScrollView(
    padding: const EdgeInsets.all(16),
    child: StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('system_settings').doc('app_config').snapshots(),
      builder: (_, snap) {
        final data = (snap.data?.data() as Map<String,dynamic>?) ?? {};
        final cats  = List<String>.from(data['categories'] ?? ['عام','فانتازيا','رعب','رومانسية','غموض','تاريخية','خيال علمي']);
        final baned = List<String>.from(data['bannedWords'] ?? []);
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // حدود الكلمات
          _sectionTitle('حدود كلمات الفصل'),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('الحد الأدنى', style: GoogleFonts.cairo(fontSize: 11, color: _textSecondary)), const SizedBox(height: 4), TextField(controller: _minWordsCtrl, keyboardType: TextInputType.number, style: GoogleFonts.cairo(color: _textPrimary, fontSize: 13), decoration: _inputDeco(''))])),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('الحد الأقصى', style: GoogleFonts.cairo(fontSize: 11, color: _textSecondary)), const SizedBox(height: 4), TextField(controller: _maxWordsCtrl, keyboardType: TextInputType.number, style: GoogleFonts.cairo(color: _textPrimary, fontSize: 13), decoration: _inputDeco(''))])),
          ]),
          const SizedBox(height: 10),
          SizedBox(width: double.infinity, child: _actionBtn(label: 'حفظ الحدود', color: _accent, onTap: () async {
            final min = int.tryParse(_minWordsCtrl.text.trim()) ?? 500;
            final max = int.tryParse(_maxWordsCtrl.text.trim()) ?? 5000;
            await FirebaseFirestore.instance.collection('system_settings').doc('app_config').set({'minWords': min, 'maxWords': max}, SetOptions(merge: true));
            await _log('update_limits', extra: {'min': min, 'max': max});
            _snack('تم حفظ الحدود ✅', _accent);
          })),
          const SizedBox(height: 20), const Divider(), const SizedBox(height: 16),

          // التصنيفات
          _sectionTitle('تصنيفات الروايات'),
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, children: cats.map((c) => Chip(
            label: Text(c, style: GoogleFonts.cairo(fontSize: 12, color: _textPrimary)),
            backgroundColor: _surfaceHigh, side: BorderSide(color: _border),
            deleteIcon: Icon(Icons.close, size: 14, color: _textSecondary),
            onDeleted: cats.length > 1 ? () async {
              final updated = List<String>.from(cats)..remove(c);
              await FirebaseFirestore.instance.collection('system_settings').doc('app_config').set({'categories': updated}, SetOptions(merge: true));
              await _log('delete_category', extra: {'category': c});
            } : null,
          )).toList()),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: TextField(controller: _newCatCtrl, style: GoogleFonts.cairo(color: _textPrimary, fontSize: 13), decoration: _inputDeco('تصنيف جديد...'))),
            const SizedBox(width: 10),
            _actionBtn(label: 'إضافة', color: _accent, onTap: () async {
              final cat = _newCatCtrl.text.trim();
              if (cat.isEmpty || cats.contains(cat)) return;
              await FirebaseFirestore.instance.collection('system_settings').doc('app_config').set({'categories': [...cats, cat]}, SetOptions(merge: true));
              await _log('add_category', extra: {'category': cat});
              _newCatCtrl.clear(); _snack('"$cat" أُضيف ✅', _accent);
            }),
          ]),
          const SizedBox(height: 20), const Divider(), const SizedBox(height: 16),

          // الكلمات المحظورة
          _sectionTitle('الكلمات المحظورة'),
          const SizedBox(height: 10),
          if (baned.isEmpty) Text('لا توجد كلمات محظورة', style: GoogleFonts.cairo(fontSize: 12, color: _textSecondary))
          else Wrap(spacing: 8, runSpacing: 8, children: baned.map((w) => Chip(
            label: Text(w, style: GoogleFonts.cairo(fontSize: 12, color: Colors.redAccent)),
            backgroundColor: Colors.redAccent.withOpacity(0.08), side: BorderSide(color: Colors.redAccent.withOpacity(0.3)),
            deleteIcon: const Icon(Icons.close, size: 14, color: Colors.redAccent),
            onDeleted: () async {
              final updated = List<String>.from(baned)..remove(w);
              await FirebaseFirestore.instance.collection('system_settings').doc('app_config').set({'bannedWords': updated}, SetOptions(merge: true));
              await _log('remove_banned_word', extra: {'word': w});
            },
          )).toList()),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: TextField(controller: _bannedWordCtrl, style: GoogleFonts.cairo(color: _textPrimary, fontSize: 13), decoration: _inputDeco('كلمة محظورة...'))),
            const SizedBox(width: 10),
            _actionBtn(label: 'حظر', color: Colors.redAccent, onTap: () async {
              final w = _bannedWordCtrl.text.trim().toLowerCase();
              if (w.isEmpty || baned.contains(w)) return;
              await FirebaseFirestore.instance.collection('system_settings').doc('app_config').set({'bannedWords': [...baned, w]}, SetOptions(merge: true));
              await _log('add_banned_word', extra: {'word': w});
              _bannedWordCtrl.clear(); _snack('"$w" مُحظَر ✅', Colors.redAccent);
            }),
          ]),
        ]);
      },
    ),
  );

  // ══════════════════════════════════════════════════════════════════════════
  // ⑧ سجل التدقيق
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildAuditTab() => StreamBuilder<QuerySnapshot>(
    stream: FirebaseFirestore.instance.collection('admin_logs').orderBy('at', descending: true).limit(60).snapshots(),
    builder: (_, snap) {
      if (snap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: _accent));
      final docs = snap.data?.docs ?? [];
      if (docs.isEmpty) return Center(child: Text('لا توجد سجلات بعد', style: GoogleFonts.cairo(color: _textSecondary)));
      return ListView.builder(
        padding: const EdgeInsets.all(16), itemCount: docs.length,
        itemBuilder: (_, i) {
          final data   = docs[i].data() as Map<String,dynamic>;
          final ts     = (data['at'] as Timestamp?)?.toDate();
          final action = data['action'] as String? ?? '';
          return Card(
            color: _surface, margin: const EdgeInsets.only(bottom: 8),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: _border)),
            child: ListTile(
              dense: true,
              leading: Icon(_auditIcon(action), color: _auditColor(action), size: 18),
              title: Text(action, style: GoogleFonts.cairo(fontSize: 12, color: _textPrimary, fontWeight: FontWeight.w600)),
              subtitle: Text(data['adminEmail'] ?? '', style: GoogleFonts.cairo(fontSize: 10, color: _textSecondary)),
              trailing: ts != null ? Text(
                '${ts.day}/${ts.month}\n${ts.hour.toString().padLeft(2,'0')}:${ts.minute.toString().padLeft(2,'0')}',
                style: GoogleFonts.cairo(fontSize: 9, color: _textSecondary), textAlign: TextAlign.end,
              ) : null,
              onTap: () {
                final extra = data.entries.where((e) => !['action','adminEmail','adminUid','at'].contains(e.key)).map((e) => '${e.key}: ${e.value}').join('\n');
                if (extra.isNotEmpty) { Clipboard.setData(ClipboardData(text: extra)); _snack('تم النسخ', _textSecondary); }
              },
            ),
          );
        },
      );
    },
  );

  IconData _auditIcon(String a) {
    if (a.contains('ban'))     return Icons.block_rounded;
    if (a.contains('delete'))  return Icons.delete_outline_rounded;
    if (a.contains('grant'))   return Icons.star_rounded;
    if (a.contains('feature')) return Icons.star_rounded;
    if (a.contains('freeze'))  return Icons.ac_unit_rounded;
    if (a.contains('role'))    return Icons.admin_panel_settings_rounded;
    if (a.contains('broadcast') || a.contains('message')) return Icons.send_rounded;
    if (a.contains('banner'))  return Icons.campaign_rounded;
    return Icons.history_rounded;
  }

  Color _auditColor(String a) {
    if (a.contains('ban') || a.contains('delete'))   return Colors.redAccent;
    if (a.contains('unban') || a.contains('unfreeze')) return Colors.green;
    if (a.contains('feature') || a.contains('grant')) return _gold;
    if (a.contains('broadcast') || a.contains('banner') || a.contains('message')) return _accent;
    return _textSecondary;
  }

  // ══════════════════════════════════════════════════════════════════════════
  // ── مساعدات الواجهة ──────────────────────────────────────────────────────
  // ══════════════════════════════════════════════════════════════════════════
  Widget _searchField(String hint, ValueChanged<String> cb) => TextField(
    style: GoogleFonts.cairo(color: _textPrimary, fontSize: 13),
    decoration: InputDecoration(
      hintText: hint, hintStyle: GoogleFonts.cairo(color: _textSecondary, fontSize: 13),
      prefixIcon: Icon(Icons.search_rounded, color: _textSecondary, size: 20),
      filled: true, fillColor: _surface, contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: _border)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: _border)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _accent)),
    ),
    onChanged: cb,
  );

  InputDecoration _inputDeco(String hint) => InputDecoration(
    hintText: hint, hintStyle: GoogleFonts.cairo(color: _textSecondary, fontSize: 12),
    filled: true, fillColor: _surfaceHigh, contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: _border)),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: _border)),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _accent)),
  );

  Widget _filterChip(String label, String val) {
    final sel = _novelFilter == val;
    return GestureDetector(
      onTap: () => setState(() => _novelFilter = val),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150), margin: const EdgeInsets.only(left: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(color: sel ? _accent : _surface, borderRadius: BorderRadius.circular(20), border: Border.all(color: sel ? _accent : _border)),
        child: Text(label, style: GoogleFonts.cairo(fontSize: 12, color: sel ? const Color(0xFF0D0F14) : _textSecondary, fontWeight: sel ? FontWeight.w700 : FontWeight.w400)),
      ),
    );
  }

  Widget _actionBtn({required String label, required Color color, required VoidCallback onTap}) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: color.withOpacity(0.4))),
          child: Center(child: Text(label, style: GoogleFonts.cairo(fontSize: 11, color: color, fontWeight: FontWeight.w700))),
        ),
      );

  Widget _roleBadge(String role) {
    final isAdmin = role == 'admin';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: isAdmin ? _gold.withOpacity(0.12) : _surfaceHigh, borderRadius: BorderRadius.circular(6), border: Border.all(color: isAdmin ? _gold : _border)),
      child: Text(isAdmin ? 'أدمن' : 'مستخدم', style: GoogleFonts.cairo(fontSize: 10, color: isAdmin ? _gold : _textSecondary, fontWeight: FontWeight.w700)),
    );
  }

  Widget _badge(String text, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(6)),
    child: Text(text, style: GoogleFonts.cairo(fontSize: 10, color: color, fontWeight: FontWeight.w700)),
  );

  Widget _statusBadge(String s) => _badge(
    s == 'approved' ? 'موافق ✅' : s == 'rejected' ? 'مرفوض' : 'انتظار',
    s == 'approved' ? Colors.green : s == 'rejected' ? Colors.redAccent : _gold,
  );

  Widget _sectionTitle(String t) => Text(t, style: GoogleFonts.cairo(fontSize: 14, fontWeight: FontWeight.w700, color: _textSecondary));

  Widget _statCard(String val, String label, IconData icon, Color color) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: _surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: _border)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Icon(icon, color: color, size: 22),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(val, style: GoogleFonts.cairo(fontSize: 22, fontWeight: FontWeight.w700, color: _textPrimary)),
        Text(label, style: GoogleFonts.cairo(fontSize: 11, color: _textSecondary)),
      ]),
    ]),
  );

  // ══════════════════════════════════════════════════════════════════════════
  // Build
  // ══════════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDarkMode;
    _bg          = isDark ? const Color(0xFF0D0F14) : const Color(0xFFF5F5F7);
    _surface     = isDark ? const Color(0xFF161920) : const Color(0xFFFFFFFF);
    _surfaceHigh = isDark ? const Color(0xFF1E2130) : const Color(0xFFEEEEF0);
    _border      = isDark ? const Color(0xFF252836) : const Color(0xFFE0E0E4);
    _textPrimary = isDark ? const Color(0xFFECECEC) : const Color(0xFF111827);
    _textSecondary=isDark ? const Color(0xFF6B7280) : const Color(0xFF555F6E);

    final user = FirebaseAuth.instance.currentUser;
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg, elevation: 0,
        title: Row(children: [
          const Icon(Icons.shield_rounded, color: _accent, size: 20),
          const SizedBox(width: 8),
          Text('لوحة التحكم', style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: _textPrimary, fontSize: 16)),
        ]),
        bottom: TabBar(
          controller: _tab,
          indicatorColor: _accent, labelColor: _accent, unselectedLabelColor: _textSecondary,
          isScrollable: true, tabAlignment: TabAlignment.start, indicatorWeight: 2.5,
          labelStyle: GoogleFonts.cairo(fontWeight: FontWeight.w700, fontSize: 11),
          unselectedLabelStyle: GoogleFonts.cairo(fontSize: 11),
          tabs: const [
            Tab(icon: Icon(Icons.bar_chart_rounded,     size: 14), text: 'إحصائيات'),
            Tab(icon: Icon(Icons.people_rounded,          size: 14), text: 'المستخدمون'),
            Tab(icon: Icon(Icons.auto_stories_rounded,    size: 14), text: 'الروايات'),
            Tab(icon: Icon(Icons.flag_rounded,            size: 14), text: 'البلاغات'),
            Tab(icon: Icon(Icons.headset_mic_rounded,     size: 14), text: 'الدعم'),
            Tab(icon: Icon(Icons.campaign_rounded,        size: 14), text: 'الإعلانات'),
            Tab(icon: Icon(Icons.settings_rounded,        size: 14), text: 'الإعدادات'),
            Tab(icon: Icon(Icons.history_rounded,         size: 14), text: 'السجل'),
          ],
        ),
      ),
      body: user == null
          ? Center(child: Text('يجب تسجيل الدخول', style: GoogleFonts.cairo(color: _textSecondary)))
          : StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(),
              builder: (_, snap) {
                if (snap.data?.data() == null) return const Center(child: CircularProgressIndicator(color: _accent));
                if ((snap.data!.data() as Map?)?['role'] != 'admin') {
                  return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.lock_rounded, size: 48, color: Colors.redAccent),
                    const SizedBox(height: 12),
                    Text('للمشرفين فقط', style: GoogleFonts.cairo(color: _textSecondary, fontSize: 16)),
                  ]));
                }
                return TabBarView(controller: _tab, children: [
                  _buildStatsTab(),
                  _buildUsersTab(),
                  _buildNovelsTab(),
                  _buildReportsTab(),
                  _buildSupportTab(),
                  _buildAnnouncementsTab(),
                  _buildSettingsTab(),
                  _buildAuditTab(),
                ]);
              },
            ),
    );
  }
}
