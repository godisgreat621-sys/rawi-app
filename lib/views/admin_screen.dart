import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
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
  // ── ألوان ──────────────────────────────────────────────────────────────────
  static const _accent        = Color(0xFF8BAF7C);
  static const _gold          = Color(0xFFD4A843);
  Color _bg           = const Color(0xFF0D0F14);
  Color _surface      = const Color(0xFF161920);
  Color _surfaceHigh  = const Color(0xFF1E2130);
  Color _border       = const Color(0xFF252836);
  Color _textPrimary  = const Color(0xFFECECEC);
  Color _textSecondary= const Color(0xFF6B7280);

  // ── حقول البحث ─────────────────────────────────────────────────────────────
  String _userSearch  = '';
  String _novelSearch = '';
  String _novelFilter = 'all'; // all | frozen | completed | ongoing
  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  // ── مساعد: تأكيد قبل الإجراء ───────────────────────────────────────────────
  Future<bool> _confirm(String msg) async {
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: _surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            title: Text('تأكيد', style: GoogleFonts.cairo(color: _textPrimary, fontWeight: FontWeight.w700)),
            content: Text(msg, style: GoogleFonts.cairo(color: _textSecondary, height: 1.6)),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false),
                  child: Text('إلغاء', style: GoogleFonts.cairo(color: _textSecondary))),
              TextButton(onPressed: () => Navigator.pop(ctx, true),
                  child: Text('تأكيد', style: GoogleFonts.cairo(color: Colors.redAccent, fontWeight: FontWeight.w700))),
            ],
          ),
        ) ??
        false;
  }

  void _snack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: GoogleFonts.cairo()),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  // ════════════════════════════════════════════════════════════════════════════
  // ① تبويب الإحصائيات
  // ════════════════════════════════════════════════════════════════════════════
  Widget _buildStatsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // ── أرقام عامة ─────────────────────────────────────────────────────
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
              crossAxisCount: 2, crossAxisSpacing: 10, mainAxisSpacing: 10,
              childAspectRatio: 1.7,
              children: [
                _statCard('${c[0]}', 'رواية منشورة',   Icons.auto_stories_rounded,   _accent),
                _statCard('${c[1]}', 'مستخدم مسجل',    Icons.people_rounded,          Colors.blueGrey),
                _statCard('${c[2]}', 'فصل منشور',       Icons.menu_book_rounded,       _gold),
                _statCard('${c[3]}', 'بلاغ مستلم',      Icons.flag_rounded,            Colors.redAccent),
              ],
            );
          },
        ),
        const SizedBox(height: 20),

        // ── أحدث المستخدمين ─────────────────────────────────────────────────
        _sectionTitle('آخر 5 مستخدمين سجلوا'),
        const SizedBox(height: 8),
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('users')
              .orderBy('createdAt', descending: true).limit(5).snapshots(),
          builder: (_, s) {
            if (!s.hasData) return const SizedBox();
            return Column(children: s.data!.docs.map((d) {
              final data = d.data() as Map<String, dynamic>;
              final ts = (data['createdAt'] as Timestamp?)?.toDate();
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  radius: 18, backgroundColor: _accent.withOpacity(0.15),
                  backgroundImage: data['profilePicture'] != null
                      ? NetworkImage(data['profilePicture']) : null,
                  child: data['profilePicture'] == null
                      ? Text((data['displayName'] ?? '؟')[0],
                          style: GoogleFonts.cairo(color: _accent, fontWeight: FontWeight.w700)) : null,
                ),
                title: Text(data['displayName'] ?? data['email'] ?? '',
                    style: GoogleFonts.cairo(fontSize: 13, color: _textPrimary)),
                subtitle: ts != null
                    ? Text('${ts.day}/${ts.month}/${ts.year}',
                        style: GoogleFonts.cairo(fontSize: 10, color: _textSecondary))
                    : null,
                trailing: _roleBadge(data['role'] ?? 'user'),
              );
            }).toList());
          },
        ),
        const SizedBox(height: 20),

        // ── أكثر الروايات قراءةً ───────────────────────────────────────────
        _sectionTitle('أعلى 5 روايات قراءةً'),
        const SizedBox(height: 8),
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('novels')
              .orderBy('readers', descending: true).limit(5).snapshots(),
          builder: (_, s) {
            if (!s.hasData) return const SizedBox();
            return Column(children: s.data!.docs.map((d) {
              final data = d.data() as Map<String, dynamic>;
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.auto_stories_rounded, color: _accent, size: 20),
                title: Text(data['title'] ?? '',
                    style: GoogleFonts.cairo(fontSize: 13, color: _textPrimary),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text(data['authorName'] ?? '',
                    style: GoogleFonts.cairo(fontSize: 11, color: _textSecondary)),
                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.remove_red_eye_outlined, size: 13, color: _textSecondary),
                  const SizedBox(width: 3),
                  Text('${data['readers'] ?? 0}',
                      style: GoogleFonts.cairo(fontSize: 12, color: _textSecondary)),
                ]),
              );
            }).toList());
          },
        ),
      ]),
    );
  }

  Widget _statCard(String val, String label, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _surface, borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Icon(icon, color: color, size: 22),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(val, style: GoogleFonts.cairo(fontSize: 22, fontWeight: FontWeight.w700, color: _textPrimary)),
          Text(label, style: GoogleFonts.cairo(fontSize: 11, color: _textSecondary)),
        ]),
      ]),
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  // ② تبويب المستخدمين
  // ════════════════════════════════════════════════════════════════════════════
  Widget _buildUsersTab() {
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: _searchField('ابحث بالاسم أو البريد...', (v) => setState(() => _userSearch = v.trim().toLowerCase())),
      ),
      Expanded(
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('users')
              .orderBy('createdAt', descending: true).snapshots(),
          builder: (_, snap) {
            if (snap.connectionState == ConnectionState.waiting)
              return const Center(child: CircularProgressIndicator(color: _accent));
            final all = snap.data?.docs ?? [];
            final users = _userSearch.isEmpty ? all : all.where((d) {
              final data = d.data() as Map<String, dynamic>;
              final name  = (data['displayName'] ?? '').toString().toLowerCase();
              final email = (data['email'] ?? '').toString().toLowerCase();
              return name.contains(_userSearch) || email.contains(_userSearch);
            }).toList();
            if (users.isEmpty) return Center(child: Text('لا نتائج', style: GoogleFonts.cairo(color: _textSecondary)));
            return ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 4),
              itemCount: users.length,
              itemBuilder: (_, i) {
                final doc  = users[i];
                final data = doc.data() as Map<String, dynamic>;
                return _userCard(doc.id, data);
              },
            );
          },
        ),
      ),
    ]);
  }

  Widget _userCard(String uid, Map<String, dynamic> data) {
    final role     = data['role'] ?? 'user';
    final points   = data['points'] ?? 0;
    final banned   = data['bannedUntil'] as Timestamp?;
    final isBanned = banned != null && banned.toDate().isAfter(DateTime.now());
    final joined   = (data['createdAt'] as Timestamp?)?.toDate();

    return Card(
      color: _surface,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: isBanned ? Colors.redAccent.withOpacity(0.4) : _border)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            CircleAvatar(
              radius: 20, backgroundColor: _accent.withOpacity(0.15),
              backgroundImage: data['profilePicture'] != null ? NetworkImage(data['profilePicture']) : null,
              child: data['profilePicture'] == null
                  ? Text((data['displayName'] ?? '؟')[0],
                      style: GoogleFonts.cairo(color: _accent, fontWeight: FontWeight.w700)) : null,
            ),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(data['displayName'] ?? data['email'] ?? 'مستخدم',
                  style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: _textPrimary, fontSize: 13)),
              Text(data['email'] ?? '',
                  style: GoogleFonts.cairo(fontSize: 10, color: _textSecondary),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
            ])),
            _roleBadge(role),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Icon(Icons.star_rounded, size: 12, color: _gold),
            const SizedBox(width: 3),
            Text('$points نقطة', style: GoogleFonts.cairo(fontSize: 11, color: _textSecondary)),
            if (joined != null) ...[
              const SizedBox(width: 12),
              Icon(Icons.calendar_today_outlined, size: 12, color: _textSecondary),
              const SizedBox(width: 3),
              Text('${joined.day}/${joined.month}/${joined.year}',
                  style: GoogleFonts.cairo(fontSize: 11, color: _textSecondary)),
            ],
            if (isBanned) ...[
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text('محظور', style: GoogleFonts.cairo(fontSize: 10, color: Colors.redAccent)),
              ),
            ],
          ]),
          const SizedBox(height: 10),
          Wrap(spacing: 6, runSpacing: 6, children: [
            // ترقية / خفض
            _actionBtn(
              label: role == 'admin' ? 'خفض لمستخدم' : 'ترقية لأدمن',
              color: _accent,
              onTap: () async {
                if (!await _confirm(role == 'admin'
                    ? 'هل تريد خفض هذا المستخدم من منصب الأدمن؟'
                    : 'هل تريد ترقية هذا المستخدم لأدمن؟')) return;
                await context.read<NovelsProvider>().setUserRole(uid, role == 'admin' ? 'user' : 'admin');
                _snack(role == 'admin' ? 'تم الخفض' : 'تمت الترقية ✅', _accent);
              },
            ),
            // حظر 24 ساعة
            _actionBtn(
              label: isBanned ? 'رفع الحظر' : 'حظر 24h',
              color: Colors.orange,
              onTap: () async {
                if (!await _confirm(isBanned ? 'رفع الحظر عن هذا المستخدم؟' : 'حظر المستخدم 24 ساعة؟')) return;
                final until = isBanned ? DateTime(2000) : DateTime.now().add(const Duration(days: 1));
                await FirebaseFirestore.instance.collection('users').doc(uid)
                    .update({'bannedUntil': Timestamp.fromDate(until)});
                _snack(isBanned ? 'تم رفع الحظر' : 'تم الحظر 24 ساعة', Colors.orange);
              },
            ),
            // حظر أسبوع
            if (!isBanned)
              _actionBtn(
                label: 'حظر أسبوع',
                color: Colors.redAccent,
                onTap: () async {
                  if (!await _confirm('حظر المستخدم أسبوعاً كاملاً؟')) return;
                  final until = DateTime.now().add(const Duration(days: 7));
                  await FirebaseFirestore.instance.collection('users').doc(uid)
                      .update({'bannedUntil': Timestamp.fromDate(until)});
                  _snack('تم الحظر أسبوعاً', Colors.redAccent);
                },
              ),
            // إعادة تعيين النقاط
            _actionBtn(
              label: 'تصفير النقاط',
              color: Colors.blueGrey,
              onTap: () async {
                if (!await _confirm('إعادة تعيين نقاط هذا المستخدم إلى صفر؟')) return;
                await FirebaseFirestore.instance.collection('users').doc(uid).update({'points': 0});
                _snack('تم تصفير النقاط', Colors.blueGrey);
              },
            ),
          ]),
        ]),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  // ③ تبويب الروايات
  // ════════════════════════════════════════════════════════════════════════════
  Widget _buildNovelsTab() {
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: _searchField('ابحث بعنوان الرواية...', (v) => setState(() => _novelSearch = v.trim().toLowerCase())),
      ),
      // فلاتر
      SizedBox(
        height: 36,
        child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 16),
          children: [
            _filterChip('الكل',       'all'),
            _filterChip('مجمدة',     'frozen'),
            _filterChip('مكتملة',    'completed'),
            _filterChip('جارية',     'ongoing'),
          ],
        ),
      ),
      const SizedBox(height: 8),
      Expanded(
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('novels')
              .orderBy('createdAt', descending: true).snapshots(),
          builder: (_, snap) {
            if (snap.connectionState == ConnectionState.waiting)
              return const Center(child: CircularProgressIndicator(color: _accent));
            final all = snap.data?.docs ?? [];
            final novels = all.where((d) {
              final data = d.data() as Map<String, dynamic>;
              final title = (data['title'] ?? '').toString().toLowerCase();
              if (_novelSearch.isNotEmpty && !title.contains(_novelSearch)) return false;
              if (_novelFilter == 'frozen') return data['isFrozen'] == true;
              if (_novelFilter == 'completed') return data['status'] == 'completed';
              if (_novelFilter == 'ongoing') return data['status'] != 'completed' && data['isFrozen'] != true;
              return true;
            }).toList();
            if (novels.isEmpty) return Center(child: Text('لا توجد روايات', style: GoogleFonts.cairo(color: _textSecondary)));
            return ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 4),
              itemCount: novels.length,
              itemBuilder: (_, i) {
                final doc  = novels[i];
                final data = doc.data() as Map<String, dynamic>;
                return _novelCard(doc.id, data);
              },
            );
          },
        ),
      ),
    ]);
  }

  Widget _filterChip(String label, String val) {
    final sel = _novelFilter == val;
    return GestureDetector(
      onTap: () => setState(() => _novelFilter = val),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(left: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: sel ? _accent : _surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: sel ? _accent : _border),
        ),
        child: Text(label, style: GoogleFonts.cairo(
            fontSize: 12,
            color: sel ? const Color(0xFF0D0F14) : _textSecondary,
            fontWeight: sel ? FontWeight.w700 : FontWeight.w400)),
      ),
    );
  }

  Widget _novelCard(String id, Map<String, dynamic> data) {
    final isFrozen    = data['isFrozen'] == true;
    final isCompleted = data['status'] == 'completed';
    final readers     = data['readers'] ?? 0;
    final chapters    = data['chaptersCount'] ?? 0;
    final likes       = data['likes'] ?? 0;

    return Card(
      color: _surface,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: isFrozen ? Colors.blueGrey.withOpacity(0.4) : _border)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(data['title'] ?? '',
                style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: _textPrimary, fontSize: 13),
                maxLines: 2, overflow: TextOverflow.ellipsis)),
            const SizedBox(width: 8),
            if (isFrozen) _badge('مجمدة ❄️', Colors.blueGrey),
            if (isCompleted && !isFrozen) _badge('مكتملة ✅', Colors.green),
          ]),
          const SizedBox(height: 4),
          Text('الكاتب: ${data['authorName'] ?? '—'}',
              style: GoogleFonts.cairo(fontSize: 11, color: _textSecondary)),
          const SizedBox(height: 6),
          Row(children: [
            Icon(Icons.remove_red_eye_outlined, size: 12, color: _textSecondary),
            const SizedBox(width: 3),
            Text('$readers', style: GoogleFonts.cairo(fontSize: 11, color: _textSecondary)),
            const SizedBox(width: 12),
            Icon(Icons.menu_book_rounded, size: 12, color: _textSecondary),
            const SizedBox(width: 3),
            Text('$chapters فصل', style: GoogleFonts.cairo(fontSize: 11, color: _textSecondary)),
            const SizedBox(width: 12),
            Icon(Icons.favorite_rounded, size: 12, color: Colors.redAccent),
            const SizedBox(width: 3),
            Text('$likes', style: GoogleFonts.cairo(fontSize: 11, color: _textSecondary)),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            // تجميد / رفع تجميد
            _actionBtn(
              label: isFrozen ? 'رفع التجميد' : 'تجميد',
              color: Colors.blueGrey,
              onTap: () async {
                if (!await _confirm(isFrozen
                    ? 'رفع التجميد عن الرواية؟'
                    : 'تجميد الرواية ومنع القراءة؟')) return;
                await FirebaseFirestore.instance.collection('novels').doc(id)
                    .update({'isFrozen': !isFrozen});
                _snack(isFrozen ? 'تم رفع التجميد ✅' : 'تم تجميد الرواية ❄️',
                    isFrozen ? Colors.green : Colors.blueGrey);
              },
            ),
            const SizedBox(width: 8),
            // حذف
            _actionBtn(
              label: 'حذف نهائي',
              color: Colors.redAccent,
              onTap: () async {
                if (!await _confirm('حذف الرواية "${data['title']}" نهائياً؟ لا يمكن التراجع.')) return;
                await FirebaseFirestore.instance.collection('novels').doc(id).delete();
                _snack('تم حذف الرواية ✅', Colors.green);
              },
            ),
          ]),
        ]),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  // ④ تبويب البلاغات
  // ════════════════════════════════════════════════════════════════════════════
  Widget _buildReportsTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('reports')
          .orderBy('createdAt', descending: true).limit(50).snapshots(),
      builder: (_, snap) {
        if (snap.connectionState == ConnectionState.waiting)
          return const Center(child: CircularProgressIndicator(color: _accent));
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) return Center(child: Text('لا توجد بلاغات', style: GoogleFonts.cairo(color: _textSecondary)));
        // تجميع حسب المُبلَّغ عنه
        final freq = <String, int>{};
        for (final d in docs) {
          final uid = (d.data() as Map<String,dynamic>)['reportedUser'] as String? ?? '';
          if (uid.isNotEmpty) freq[uid] = (freq[uid] ?? 0) + 1;
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (_, i) {
            final doc  = docs[i];
            final data = doc.data() as Map<String, dynamic>;
            final reportedUid = data['reportedUser'] as String? ?? '';
            final count = freq[reportedUid] ?? 1;
            final reason = data['reason'] ?? data['type'] ?? 'مخالفة';
            final ts = (data['createdAt'] as Timestamp?)?.toDate();
            return Card(
              color: _surface,
              margin: const EdgeInsets.only(bottom: 10),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: count >= 3 ? Colors.redAccent.withOpacity(0.4) : _border)),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(child: Text('بلاغ: $reason',
                        style: GoogleFonts.cairo(fontSize: 13, fontWeight: FontWeight.w700, color: _textPrimary))),
                    if (count >= 3)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.redAccent.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text('$count بلاغات', style: GoogleFonts.cairo(fontSize: 10, color: Colors.redAccent, fontWeight: FontWeight.w700)),
                      ),
                  ]),
                  if (data['content'] != null) ...[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: _surfaceHigh, borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(data['content'].toString(),
                          style: GoogleFonts.cairo(fontSize: 12, color: _textSecondary),
                          maxLines: 3, overflow: TextOverflow.ellipsis),
                    ),
                  ],
                  if (ts != null) ...[
                    const SizedBox(height: 6),
                    Text('${ts.day}/${ts.month}/${ts.year} — ${ts.hour}:${ts.minute.toString().padLeft(2,'0')}',
                        style: GoogleFonts.cairo(fontSize: 10, color: _textSecondary)),
                  ],
                  const SizedBox(height: 10),
                  Wrap(spacing: 6, runSpacing: 6, children: [
                    // حظر المُبلَّغ عنه
                    if (reportedUid.isNotEmpty)
                      _actionBtn(
                        label: 'حظر المُبلَّغ عنه 24h',
                        color: Colors.orange,
                        onTap: () async {
                          if (!await _confirm('حظر هذا المستخدم 24 ساعة؟')) return;
                          final until = DateTime.now().add(const Duration(days: 1));
                          await FirebaseFirestore.instance.collection('users').doc(reportedUid)
                              .update({'bannedUntil': Timestamp.fromDate(until)});
                          _snack('تم الحظر 24 ساعة', Colors.orange);
                        },
                      ),
                    // تجاهل البلاغ
                    _actionBtn(
                      label: 'تجاهل',
                      color: _textSecondary,
                      onTap: () async {
                        await FirebaseFirestore.instance.collection('reports').doc(doc.id)
                            .update({'status': 'dismissed'});
                        _snack('تم تجاهل البلاغ', _textSecondary);
                      },
                    ),
                  ]),
                ]),
              ),
            );
          },
        );
      },
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  // ⑤ تبويب الدعم الفني
  // ════════════════════════════════════════════════════════════════════════════
  Widget _buildSupportTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('support_requests')
          .orderBy('createdAt', descending: true).snapshots(),
      builder: (_, snap) {
        if (snap.connectionState == ConnectionState.waiting)
          return const Center(child: CircularProgressIndicator(color: _accent));
        final docs = snap.data?.docs ?? [];
        final pending  = docs.where((d) => (d.data() as Map)['status'] == 'pending').toList();
        final resolved = docs.where((d) => (d.data() as Map)['status'] != 'pending').toList();
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (pending.isNotEmpty) ...[
              Row(children: [
                _sectionTitle('قيد الانتظار'),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: _gold.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
                  child: Text('${pending.length}', style: GoogleFonts.cairo(fontSize: 11, color: _gold, fontWeight: FontWeight.w700)),
                ),
              ]),
              const SizedBox(height: 8),
              ...pending.map((d) => _supportCard(d)),
              const SizedBox(height: 16),
            ],
            if (resolved.isNotEmpty) ...[
              _sectionTitle('تمت المعالجة'),
              const SizedBox(height: 8),
              ...resolved.take(10).map((d) => _supportCard(d)),
            ],
          ],
        );
      },
    );
  }

  Widget _supportCard(DocumentSnapshot doc) {
    final data   = doc.data() as Map<String, dynamic>;
    final status = data['status'] ?? 'pending';
    final isPending = status == 'pending';
    return Card(
      color: _surface,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: isPending ? _gold.withOpacity(0.3) : _border)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Expanded(child: Text(data['title'] ?? 'طلب دعم',
                style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: _textPrimary, fontSize: 13))),
            _statusBadge(status),
          ]),
          const SizedBox(height: 4),
          Text('النوع: ${data['type'] ?? '—'} | ${data['authorName'] ?? data['authorEmail'] ?? '—'}',
              style: GoogleFonts.cairo(fontSize: 11, color: _textSecondary)),
          const SizedBox(height: 8),
          Text(data['description'] ?? '',
              style: GoogleFonts.cairo(fontSize: 13, color: _textPrimary, height: 1.6)),
          if (!isPending) ...[
            const SizedBox(height: 6),
            Text('الرد: ${data['response'] ?? '—'}',
                style: GoogleFonts.cairo(fontSize: 12, color: _textSecondary)),
          ],
          if (isPending) ...[
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: _actionBtn(
                label: 'موافقة',
                color: _accent,
                onTap: () => _resolveRequest(context, doc.id, 'approved'),
              )),
              const SizedBox(width: 8),
              Expanded(child: _actionBtn(
                label: 'رفض',
                color: Colors.redAccent,
                onTap: () => _resolveRequest(context, doc.id, 'rejected'),
              )),
            ]),
          ],
        ]),
      ),
    );
  }

  Future<void> _resolveRequest(BuildContext context, String id, String status) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final doc  = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    final name = doc.data()?['displayName'] ?? user.email ?? 'الأدمن';
    await context.read<NovelsProvider>().resolveSupportRequest(
      id, status,
      'تم ${status == 'approved' ? 'الموافقة' : 'الرفض'} من قبل الأدمن $name.',
      user.uid, name,
    );
    _snack(status == 'approved' ? 'تمت الموافقة ✅' : 'تم الرفض', status == 'approved' ? _accent : Colors.redAccent);
  }

  // ════════════════════════════════════════════════════════════════════════════
  // ── مساعدات الواجهة ──────────────────────────────────────────────────────
  // ════════════════════════════════════════════════════════════════════════════
  Widget _searchField(String hint, ValueChanged<String> onChanged) {
    return TextField(
      style: GoogleFonts.cairo(color: _textPrimary, fontSize: 13),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.cairo(color: _textSecondary, fontSize: 13),
        prefixIcon: Icon(Icons.search_rounded, color: _textSecondary, size: 20),
        filled: true, fillColor: _surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: _border)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: _border)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _accent)),
      ),
      onChanged: onChanged,
    );
  }

  Widget _actionBtn({required String label, required Color color, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.4)),
        ),
        child: Center(child: Text(label, style: GoogleFonts.cairo(fontSize: 11, color: color, fontWeight: FontWeight.w700))),
      ),
    );
  }

  Widget _roleBadge(String role) {
    final isAdmin = role == 'admin';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isAdmin ? _gold.withOpacity(0.12) : _surfaceHigh,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: isAdmin ? _gold : _border),
      ),
      child: Text(isAdmin ? 'أدمن' : 'مستخدم',
          style: GoogleFonts.cairo(fontSize: 10, color: isAdmin ? _gold : _textSecondary, fontWeight: FontWeight.w700)),
    );
  }

  Widget _badge(String text, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(6)),
    child: Text(text, style: GoogleFonts.cairo(fontSize: 10, color: color, fontWeight: FontWeight.w700)),
  );

  Widget _statusBadge(String status) {
    final color = status == 'approved' ? Colors.green : status == 'rejected' ? Colors.redAccent : _gold;
    final label = status == 'approved' ? 'موافق ✅' : status == 'rejected' ? 'مرفوض' : 'انتظار';
    return _badge(label, color);
  }

  Widget _sectionTitle(String t) => Text(t,
      style: GoogleFonts.cairo(fontSize: 14, fontWeight: FontWeight.w700, color: _textSecondary));

  // ════════════════════════════════════════════════════════════════════════════
  // ── Build ────────────────────────────────────────────────────────────────
  // ════════════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDarkMode;
    _bg           = isDark ? const Color(0xFF0D0F14) : const Color(0xFFF5F5F7);
    _surface      = isDark ? const Color(0xFF161920) : const Color(0xFFFFFFFF);
    _surfaceHigh  = isDark ? const Color(0xFF1E2130) : const Color(0xFFEEEEF0);
    _border       = isDark ? const Color(0xFF252836) : const Color(0xFFE0E0E4);
    _textPrimary  = isDark ? const Color(0xFFECECEC) : const Color(0xFF111827);
    _textSecondary= isDark ? const Color(0xFF6B7280) : const Color(0xFF555F6E);

    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        title: Row(children: [
          const Icon(Icons.admin_panel_settings_rounded, color: _accent, size: 20),
          const SizedBox(width: 8),
          Text('لوحة التحكم', style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: _textPrimary, fontSize: 16)),
        ]),
        bottom: TabBar(
          controller: _tabCtrl,
          indicatorColor: _accent,
          labelColor: _accent,
          unselectedLabelColor: _textSecondary,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          indicatorWeight: 2.5,
          labelStyle: GoogleFonts.cairo(fontWeight: FontWeight.w700, fontSize: 12),
          unselectedLabelStyle: GoogleFonts.cairo(fontSize: 12),
          tabs: const [
            Tab(icon: Icon(Icons.bar_chart_rounded, size: 16), text: 'إحصائيات'),
            Tab(icon: Icon(Icons.people_rounded,     size: 16), text: 'المستخدمون'),
            Tab(icon: Icon(Icons.auto_stories_rounded,size: 16), text: 'الروايات'),
            Tab(icon: Icon(Icons.flag_rounded,        size: 16), text: 'البلاغات'),
            Tab(icon: Icon(Icons.headset_mic_rounded, size: 16), text: 'الدعم'),
          ],
        ),
      ),
      body: user == null
          ? Center(child: Text('يجب تسجيل الدخول', style: GoogleFonts.cairo(color: _textSecondary)))
          : StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(),
              builder: (_, snap) {
                if (snap.data?.data() == null) return const Center(child: CircularProgressIndicator(color: _accent));
                if ((snap.data!.data() as Map)?['role'] != 'admin') {
                  return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.lock_rounded, size: 48, color: Colors.redAccent),
                    const SizedBox(height: 12),
                    Text('للمشرفين فقط', style: GoogleFonts.cairo(color: _textSecondary, fontSize: 16)),
                  ]));
                }
                return TabBarView(
                  controller: _tabCtrl,
                  children: [
                    _buildStatsTab(),
                    _buildUsersTab(),
                    _buildNovelsTab(),
                    _buildReportsTab(),
                    _buildSupportTab(),
                  ],
                );
              },
            ),
    );
  }
}
