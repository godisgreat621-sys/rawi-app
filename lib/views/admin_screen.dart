import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:my_first_app/providers/novels_provider.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  static const _bg            = Color(0xFF0D0F14);
  static const _surface       = Color(0xFF161920);
  static const _surfaceHigh   = Color(0xFF1E2130);
  static const _accent        = Color(0xFF8BAF7C);
  static const _border        = Color(0xFF252836);
  static const _textPrimary   = Color(0xFFECECEC);
  static const _textSecondary = Color(0xFF6B7280);
  static const _gold          = Color(0xFFD4A843);

  // #47 بحث المستخدمين
  String _userSearch = '';

  Future<void> _resolveRequest(
    BuildContext context,
    String requestId,
    String status,
  ) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    final adminName = userDoc.data()?['displayName'] ?? user.email ?? 'الأدمن';

    await context.read<NovelsProvider>().resolveSupportRequest(
      requestId,
      status,
      'تم ${status == 'approved' ? 'الموافقة' : 'الرفض'} من قبل الأدمن $adminName.',
      user.uid,
      adminName,
    );
  }

  Widget _buildSupportRequestsTab(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('support_requests')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: _accent));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Text(
              'لا توجد طلبات دعم حالياً.',
              style: GoogleFonts.cairo(color: _textSecondary),
            ),
          );
        }

        final requests = snapshot.data!.docs;
        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 12),
          itemCount: requests.length,
          itemBuilder: (context, index) {
            final doc = requests[index];
            final data = doc.data() as Map<String, dynamic>;
            final status = data['status'] ?? 'pending';
            return Card( 
              color: _surface,
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: _border),
              ),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          data['title'] ?? 'طلب دعم',
                          style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: _textPrimary),
                        ),
                        Text(
                          status == 'pending'
                              ? 'قيد الانتظار'
                              : status == 'approved'
                              ? 'تم الموافقة'
                              : 'مرفوض',
                          style: GoogleFonts.cairo(
                            fontSize: 12,
                            color: status == 'approved'
                                ? Colors.green
                                : status == 'rejected'
                                ? Colors.redAccent
                                : _gold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'النوع: ${data['type'] ?? 'عام'}',
                      style: GoogleFonts.cairo(
                        fontSize: 12,
                        color: _textSecondary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      data['description'] ?? '',
                      style: GoogleFonts.cairo(fontSize: 14, color: _textPrimary),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'الكاتب: ${data['authorName'] ?? data['authorEmail'] ?? 'مستخدم'}',
                      style: GoogleFonts.cairo(
                        fontSize: 12,
                        color: _textSecondary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (status == 'pending')
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(side: const BorderSide(color: _accent), foregroundColor: _accent),
                              onPressed: () =>
                                  _resolveRequest(context, doc.id, 'approved'),
                              child: Text(
                                'الموافقة',
                                style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.redAccent,
                                side: const BorderSide(color: Colors.redAccent),
                              ),
                              onPressed: () =>
                                  _resolveRequest(context, doc.id, 'rejected'),
                              child: Text('الرفض', style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ],
                      ),
                    if (status != 'pending') ...[
                      Text(
                        'الرد: ${data['response'] ?? '—'}',
                        style: GoogleFonts.cairo(
                          fontSize: 13,
                          color: _textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // #36 تقرير أسبوعي بالحسابات الأعلى بلاغاً
  Widget _buildWeeklyReportsTab(BuildContext context) {
    final since = DateTime.now().subtract(const Duration(days: 7));
    return FutureBuilder<QuerySnapshot>(
      future: FirebaseFirestore.instance
          .collection('reports')
          .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(since))
          .get(),
      builder: (_, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator(color: _accent));
        }
        // تجميع البلاغات حسب المستخدم المُبلَّغ عنه
        final freq = <String, int>{};
        for (final doc in snap.data!.docs) {
          final uid = (doc.data() as Map<String,dynamic>)['reportedUser'] as String?;
          if (uid != null && uid.isNotEmpty) freq[uid] = (freq[uid] ?? 0) + 1;
        }
        final sorted = freq.entries.toList()..sort((a,b) => b.value.compareTo(a.value));
        if (sorted.isEmpty) {
          return Center(child: Text('لا توجد بلاغات هذا الأسبوع.',
              style: GoogleFonts.cairo(color: _textSecondary)));
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: sorted.length,
          itemBuilder: (_, i) {
            final uid   = sorted[i].key;
            final count = sorted[i].value;
            return Card(
              color: _surface,
              margin: const EdgeInsets.only(bottom: 10),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: count >= 5 ? Colors.redAccent : _border)),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: count >= 5
                      ? Colors.redAccent.withOpacity(0.15)
                      : _surfaceHigh,
                  child: Text('$count',
                      style: GoogleFonts.cairo(
                          color: count >= 5 ? Colors.redAccent : _textSecondary,
                          fontWeight: FontWeight.w700)),
                ),
                title: Text('مستخدم: ${uid.substring(0, 8)}...',
                    style: GoogleFonts.cairo(fontSize: 12, color: _textPrimary)),
                subtitle: Text('$count بلاغ هذا الأسبوع',
                    style: GoogleFonts.cairo(fontSize: 11,
                        color: count >= 5 ? Colors.redAccent : _textSecondary)),
                trailing: count >= 5
                    ? TextButton(
                        onPressed: () async {
                          final ban = DateTime.now().add(const Duration(days: 1));
                          await FirebaseFirestore.instance
                              .collection('users').doc(uid)
                              .update({'bannedUntil': Timestamp.fromDate(ban)});
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text('تم حظر المستخدم 24 ساعة',
                                style: GoogleFonts.cairo()),
                            backgroundColor: Colors.redAccent,
                          ));
                        },
                        child: Text('حظر',
                            style: GoogleFonts.cairo(color: Colors.redAccent, fontSize: 12)),
                      )
                    : null,
              ),
            );
          },
        );
      },
    );
  }


  // #46 تبويب الإحصائيات
  Widget _buildStatsTab() {
    return FutureBuilder<List<int>>(
      future: Future.wait([
        FirebaseFirestore.instance.collection('novels').count().get().then((s) => s.count ?? 0),
        FirebaseFirestore.instance.collection('users').count().get().then((s) => s.count ?? 0),
        FirebaseFirestore.instance.collection('notifications').count().get().then((s) => s.count ?? 0),
        FirebaseFirestore.instance.collection('reports').count().get().then((s) => s.count ?? 0),
      ]),
      builder: (_, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator(color: _accent));
        }
        final counts = snap.data!;
        final stats = [
          ('إجمالي الروايات',   counts[0], Icons.auto_stories_rounded,        _accent),
          ('إجمالي المستخدمين', counts[1], Icons.people_rounded,               Colors.blueGrey),
          ('الإشعارات',         counts[2], Icons.notifications_rounded,         _gold),
          ('البلاغات',          counts[3], Icons.flag_rounded,                  Colors.redAccent),
        ];
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('إحصائيات التطبيق',
                  style: GoogleFonts.cairo(
                      fontSize: 18, fontWeight: FontWeight.w700, color: _textPrimary)),
              const SizedBox(height: 16),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.6,
                children: stats.map((s) => Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: _surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Icon(s.$3, color: s.$4, size: 22),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${s.$2}',
                              style: GoogleFonts.cairo(
                                  fontSize: 22, fontWeight: FontWeight.w700,
                                  color: _textPrimary)),
                          Text(s.$1,
                              style: GoogleFonts.cairo(
                                  fontSize: 11, color: _textSecondary)),
                        ],
                      ),
                    ],
                  ),
                )).toList(),
              ),
              const SizedBox(height: 20),
              // أحدث الروايات اليوم
              Text('الروايات المضافة اليوم',
                  style: GoogleFonts.cairo(
                      fontSize: 14, fontWeight: FontWeight.w600, color: _textSecondary)),
              const SizedBox(height: 8),
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('novels')
                    .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(
                        DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day)))
                    .orderBy('createdAt', descending: true).limit(5).snapshots(),
                builder: (_, s) {
                  if (!s.hasData || s.data!.docs.isEmpty) {
                    return Text('لا توجد روايات اليوم',
                        style: GoogleFonts.cairo(fontSize: 12, color: _textSecondary));
                  }
                  return Column(
                    children: s.data!.docs.map((d) {
                      final data = d.data() as Map<String, dynamic>;
                      return ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.book_rounded, color: _accent, size: 18),
                        title: Text(data['title'] ?? '',
                            style: GoogleFonts.cairo(fontSize: 13, color: _textPrimary)),
                        subtitle: Text(data['authorName'] ?? '',
                            style: GoogleFonts.cairo(fontSize: 11, color: _textSecondary)),
                      );
                    }).toList(),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // #47 بناء تبويب المستخدمين مع البحث
  Widget _buildUsersSection() {
    return Column(
      children: [
        // حقل البحث
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: TextField(
            style: GoogleFonts.cairo(color: _textPrimary, fontSize: 13),
            decoration: InputDecoration(
              hintText: 'ابحث بالاسم أو البريد...',
              hintStyle: GoogleFonts.cairo(color: _textSecondary, fontSize: 13),
              prefixIcon: const Icon(Icons.search_rounded, color: _textSecondary, size: 20),
              filled: true,
              fillColor: _surface,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: _border)),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: _border)),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: _accent)),
            ),
            onChanged: (v) => setState(() => _userSearch = v.trim().toLowerCase()),
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .orderBy('displayName', descending: false)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: _accent));
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return Center(child: Text('لا توجد مستخدمين.',
                    style: GoogleFonts.cairo(color: _textSecondary)));
              }
              final users = snapshot.data!.docs.where((doc) {
                if (_userSearch.isEmpty) return true;
                final data = doc.data() as Map<String, dynamic>;
                final name  = (data['displayName'] ?? '').toString().toLowerCase();
                final email = (data['email'] ?? '').toString().toLowerCase();
                return name.contains(_userSearch) || email.contains(_userSearch);
              }).toList();

              if (users.isEmpty) {
                return Center(child: Text('لا نتائج للبحث',
                    style: GoogleFonts.cairo(color: _textSecondary)));
              }

              return ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 4),
                itemCount: users.length,
                itemBuilder: (context, index) {
                  final doc    = users[index];
                  final data   = doc.data() as Map<String, dynamic>;
                  final role   = data['role'] ?? 'user';
                  final isActive = data['isActive'] ?? true;
                  return Card(
                    color: _surface,
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: const BorderSide(color: _border)),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            Expanded(
                              child: Text(
                                data['displayName'] ?? data['email'] ?? 'مستخدم',
                                style: GoogleFonts.cairo(
                                    fontWeight: FontWeight.bold, color: _textPrimary),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: role == 'admin'
                                    ? _gold.withValues(alpha: 0.15)
                                    : _surface,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: role == 'admin' ? _gold : _border),
                              ),
                              child: Text(role == 'admin' ? 'مشرف' : 'مستخدم',
                                  style: GoogleFonts.cairo(
                                      fontSize: 10,
                                      color: role == 'admin' ? _gold : _textSecondary)),
                            ),
                          ]),
                          const SizedBox(height: 4),
                          Text(data['email'] ?? '',
                              style: GoogleFonts.cairo(fontSize: 11, color: _textSecondary)),
                          const SizedBox(height: 4),
                          Row(children: [
                            Icon(Icons.star_rounded, size: 11, color: _gold),
                            const SizedBox(width: 3),
                            Text('${data['points'] ?? 0} نقطة',
                                style: GoogleFonts.cairo(fontSize: 11, color: _textSecondary)),
                            const SizedBox(width: 12),
                            Icon(isActive ? Icons.check_circle : Icons.cancel,
                                size: 11,
                                color: isActive ? Colors.green : Colors.redAccent),
                            const SizedBox(width: 3),
                            Text(isActive ? 'نشط' : 'موقوف',
                                style: GoogleFonts.cairo(
                                    fontSize: 11,
                                    color: isActive ? Colors.green : Colors.redAccent)),
                          ]),
                          const SizedBox(height: 10),
                          Row(children: [
                            Expanded(
                              child: OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                    side: const BorderSide(color: _accent),
                                    foregroundColor: _accent,
                                    padding: const EdgeInsets.symmetric(vertical: 8)),
                                onPressed: () async {
                                  await context.read<NovelsProvider>()
                                      .setUserRole(doc.id, role == 'admin' ? 'user' : 'admin');
                                },
                                child: Text(role == 'admin' ? 'خفض' : 'ترقية',
                                    style: GoogleFonts.cairo(fontSize: 12)),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                    foregroundColor: isActive ? Colors.redAccent : _accent,
                                    side: BorderSide(color: isActive ? Colors.redAccent : _accent),
                                    padding: const EdgeInsets.symmetric(vertical: 8)),
                                onPressed: () async {
                                  await context.read<NovelsProvider>()
                                      .setUserActive(doc.id, !isActive);
                                },
                                child: Text(isActive ? 'تعطيل' : 'تفعيل',
                                    style: GoogleFonts.cairo(fontSize: 12)),
                              ),
                            ),
                          ]),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        backgroundColor: _bg,
        appBar: AppBar(
          backgroundColor: _bg,
          title: Text('لوحة الأدمن',
              style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: _textPrimary)),
          bottom: TabBar(
            indicatorColor: _accent,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            labelStyle: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 12),
            unselectedLabelStyle: GoogleFonts.cairo(fontSize: 12),
            tabs: const [
              Tab(text: 'الدعم'),
              Tab(text: 'المحتوى'),
              Tab(text: 'البلاغات'),
              Tab(text: 'إحصائيات'),
            ],
          ),
        ),
        body: user == null
            ? Center(child: Text('يجب تسجيل الدخول.',
                style: GoogleFonts.cairo(color: _textSecondary)))
            : StreamBuilder<DocumentSnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('users').doc(user.uid).snapshots(),
                builder: (context, userSnap) {
                  final userData = userSnap.data?.data() as Map<String, dynamic>?;
                  if (userData?['role'] != 'admin') {
                    return Center(child: Text('للمشرفين فقط.',
                        style: GoogleFonts.cairo(color: _textSecondary)));
                  }
                  return TabBarView(children: [
                    _buildSupportRequestsTab(context),
                    _buildUsersSection(),          // #47 مع بحث
                    _buildWeeklyReportsTab(context), // #48
                    _buildStatsTab(),               // #46
                  ]);
                },
              ),
      ),
    );
  }
}
