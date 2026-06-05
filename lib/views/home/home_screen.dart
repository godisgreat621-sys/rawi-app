import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:my_first_app/providers/novels_provider.dart';
import 'package:my_first_app/providers/theme_provider.dart';
import '../../models/novel_model.dart';
import 'novel_detail_screen.dart';
import '../writer/drafts_list_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const _accent       = Color(0xFF8BAF7C);
  static const _accentDim    = Color(0xFF4A6741);
  static const _gold         = Color(0xFFD4A843);
  bool  _isDark        = true;
  Color _bg            = const Color(0xFF0D0F14);
  Color _surface       = const Color(0xFF161920);
  Color _surfaceHigh   = const Color(0xFF1E2130);
  Color _textPrimary   = const Color(0xFFECECEC);
  Color _textSecondary = const Color(0xFF6B7280);
  Color _border        = const Color(0xFF252836);

  final _searchController = TextEditingController();
  String _searchQuery     = '';
  bool   _isSearching     = false;
  Timer? _searchDebounce;
  String _selectedCategory= 'الكل';
  bool   _showBookmarkedOnly = false;
  bool   _sortByActivity  = false;
  // #21/#23/#24/#25/#28 فلاتر إضافية
  String _filterMode      = 'all'; // all | completed | today | topRated | discussed | unread
  // #46 تحميل تدريجي
  int    _limit           = 20;
  // #49 عرض قائمة أو شبكة
  bool   _isListView      = false;
  // #18 شارة المجتمع
  String? _communityPickId;

  final List<String> _categories = [
    'الكل', 'فانتازيا', 'دراما', 'رعب',
    'غموض', 'تاريخية', 'خيال علمي', 'عام',
  ];

  @override
  void initState() {
    super.initState();
    _getCommunityPickId().then((id) {
      if (mounted) setState(() => _communityPickId = id);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  // #21/#23/#24/#25/#28 بناء الاستعلام حسب الفلتر
  Stream<QuerySnapshot> _buildQuery() {
    final col = FirebaseFirestore.instance.collection('novels');
    switch (_filterMode) {
      case 'completed':
        return col.where('status', isEqualTo: 'completed')
            .orderBy('createdAt', descending: true).limit(_limit).snapshots();
      case 'today':
        final now = DateTime.now();
        final start = DateTime(now.year, now.month, now.day);
        return col.where('createdAt',
                isGreaterThanOrEqualTo: Timestamp.fromDate(start))
            .orderBy('createdAt', descending: true).limit(_limit).snapshots();
      case 'topRated':
        return col.orderBy('rating', descending: true).limit(_limit).snapshots();
      case 'discussed':
        return col.orderBy('likes', descending: true).limit(_limit).snapshots();
      default:
        return col
            .orderBy(_sortByActivity ? 'lastActivityAt' : 'createdAt',
                descending: true)
            .limit(_limit)
            .snapshots();
    }
  }

  // #27 Skeleton loading
  Widget _buildSkeleton() => GridView.builder(
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    padding: const EdgeInsets.all(16),
    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2, childAspectRatio: 0.62,
        crossAxisSpacing: 12, mainAxisSpacing: 16),
    itemCount: 6,
    itemBuilder: (ctx, i) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: Container(
          decoration: BoxDecoration(color: _surfaceHigh, borderRadius: BorderRadius.circular(12)))),
        const SizedBox(height: 6),
        Container(height: 10, width: 100,
            decoration: BoxDecoration(color: _surfaceHigh, borderRadius: BorderRadius.circular(5))),
        const SizedBox(height: 4),
        Container(height: 8, width: 60,
            decoration: BoxDecoration(color: _surface, borderRadius: BorderRadius.circular(5))),
      ],
    ),
  );

  // #18 شارة "مختارة من المجتمع" — أعلى تقييماً هذا الأسبوع
  Future<String?> _getCommunityPickId() async {
    final weekAgo = DateTime.now().subtract(const Duration(days: 7));
    final snap = await FirebaseFirestore.instance
        .collection('novels')
        .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(weekAgo))
        .orderBy('createdAt', descending: true)
        .get();
    if (snap.docs.isEmpty) return null;
    final top = snap.docs.reduce((a, b) =>
        ((a.data()['rating'] ?? 0.0) as num) >= ((b.data()['rating'] ?? 0.0) as num) ? a : b);
    return (top.data()['rating'] ?? 0.0) >= 4.0 ? top.id : null;
  }

  // #26 ما يقرأه أصدقاؤك — محسّن بدون N+1
  Future<List<Map<String, dynamic>>> _getFriendsReading() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return [];
    final followingSnap = await FirebaseFirestore.instance
        .collection('users').doc(user.uid)
        .collection('following').limit(10).get();
    if (followingSnap.docs.isEmpty) return [];

    final followingIds = followingSnap.docs.map((d) => d.id).toList();

    // جلب المستخدمين والتقدم بشكل متوازٍ
    final futures = await Future.wait([
      Future.wait(followingIds.map((id) => FirebaseFirestore.instance
          .collection('users').doc(id).get())),
      Future.wait(followingIds.map((id) => FirebaseFirestore.instance
          .collection('users').doc(id)
          .collection('readingProgress')
          .orderBy('updatedAt', descending: true)
          .limit(1).get())),
    ]);

    final userDocs    = futures[0] as List<DocumentSnapshot>;
    final progressSnaps = futures[1] as List<QuerySnapshot>;

    // جمع معرفات الروايات الفريدة
    final novelIds = <String>[];
    final friendNames = <String, String>{};
    for (int i = 0; i < followingIds.length; i++) {
      final ud = userDocs[i];
      if (ud.exists) {
        friendNames[followingIds[i]] =
            (ud.data() as Map<String, dynamic>?)?['displayName'] ?? 'صديق';
      }
      final ps = progressSnaps[i];
      if (ps.docs.isNotEmpty) novelIds.add(ps.docs.first.id);
    }
    if (novelIds.isEmpty) return [];

    // جلب الروايات بطلب واحد
    final novelSnap = await FirebaseFirestore.instance
        .collection('novels')
        .where(FieldPath.documentId, whereIn: novelIds.take(10).toList())
        .get();
    final novelMap = {for (final d in novelSnap.docs) d.id: d.data()};

    final results = <Map<String, dynamic>>[];
    for (int i = 0; i < followingIds.length; i++) {
      final ps = progressSnaps[i];
      if (ps.docs.isEmpty) continue;
      final novelId = ps.docs.first.id;
      if (!novelMap.containsKey(novelId)) continue;
      results.add({
        'novel':      novelMap[novelId],
        'novelId':    novelId,
        'friendName': friendNames[followingIds[i]] ?? 'صديق',
      });
    }
    return results;
  }

  // #16 "لم أقرأها بعد"
  Future<Set<String>> _getReadNovelIds() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return {};
    final snap = await FirebaseFirestore.instance
        .collection('users').doc(user.uid)
        .collection('readingProgress').get();
    return snap.docs.map((d) => d.id).toSet();
  }

  // #26 الروايات الموصى بها بناءً على تاريخ القراءة
  Future<List<Novel>> _getRecommended(List<Novel> all) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return [];
    final snap = await FirebaseFirestore.instance
        .collection('users').doc(user.uid)
        .collection('readingProgress').limit(10).get();
    if (snap.docs.isEmpty) return [];
    final readIds = snap.docs.map((d) => d.id).toSet();
    final readNovels = all.where((n) => readIds.contains(n.id)).toList();
    if (readNovels.isEmpty) return [];
    final catFreq = <String, int>{};
    for (final n in readNovels) {
      catFreq[n.category] = (catFreq[n.category] ?? 0) + 1;
    }
    final topCat = catFreq.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
    return all.where((n) => n.category == topCat && !readIds.contains(n.id)).take(6).toList();
  }

  void _navigateToDetail(Novel novel) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => NovelDetailScreen(
          novel: {
            'id':        novel.id,
            'title':     novel.title,
            'author':    novel.author,
            'category':  novel.category,
            'description': novel.description,
            'content':   novel.content,
            'rating':    novel.rating,
            'likes':     novel.likes,
            'readers':   novel.readers,
            'authorId':  novel.authorId,
            'coverUrl':  novel.coverUrl,
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    _isDark       = context.watch<ThemeProvider>().isDarkMode;
    _bg           = _isDark ? const Color(0xFF0D0F14) : const Color(0xFFF5F5F7);
    _surface      = _isDark ? const Color(0xFF161920) : const Color(0xFFFFFFFF);
    _surfaceHigh  = _isDark ? const Color(0xFF1E2130) : const Color(0xFFEEEEF0);
    _textPrimary  = _isDark ? const Color(0xFFECECEC) : const Color(0xFF111827);
    _textSecondary= _isDark ? const Color(0xFF6B7280) : const Color(0xFF555F6E);
    _border       = _isDark ? const Color(0xFF252836) : const Color(0xFFE0E0E4);
    return Scaffold(
      backgroundColor: _bg,
      body: RefreshIndicator(
        color: _accent,
        backgroundColor: _surface,
        onRefresh: () async => setState(() {}),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          // ── AppBar ──────────────────────────────────────────────────────
          SliverAppBar(
            floating: true,
            pinned:   true,
            backgroundColor: _bg,
            elevation: 0,
            expandedHeight: 56,
            title: _isSearching
                ? TextField(
                    controller: _searchController,
                    autofocus: true,
                    style: GoogleFonts.cairo(color: _textPrimary, fontSize: 15),
                    decoration: InputDecoration(
                      hintText: 'ابحث عن رواية أو كاتب...',
                      hintStyle: GoogleFonts.cairo(color: _textSecondary, fontSize: 14),
                      border: InputBorder.none,
                    ),
                    onChanged: (v) {
                      _searchDebounce?.cancel();
                      _searchDebounce = Timer(const Duration(milliseconds: 400), () {
                        if (mounted) setState(() => _searchQuery = v.trim().toLowerCase());
                      });
                    },
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        margin: const EdgeInsets.only(left: 8),
                        decoration: BoxDecoration(
                          color: _accent,
                          shape: BoxShape.circle,
                        ),
                      ),
                      Text(
                        'راوي',
                        style: GoogleFonts.cairo(
                          fontWeight: FontWeight.w700,
                          fontSize: 22,
                          color: _textPrimary,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
            actions: [
              if (_isSearching)
                IconButton(
                  icon: Icon(Icons.close_rounded, color: _textSecondary, size: 21),
                  onPressed: () => setState(() {
                    _isSearching = false;
                    _searchQuery = '';
                    _searchController.clear();
                  }),
                )
              else ...[
                // #49 تبديل Grid/List
                IconButton(
                  icon: Icon(_isListView ? Icons.grid_view_rounded : Icons.view_list_rounded,
                      color: _textSecondary, size: 21),
                  onPressed: () => setState(() => _isListView = !_isListView),
                ),
                IconButton(
                  icon: Icon(Icons.search_rounded, color: _textSecondary, size: 22),
                  onPressed: () => setState(() => _isSearching = true),
                ),
                const SizedBox(width: 4),
              ],
            ],
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(1),
              child: Container(height: 1, color: _border),
            ),
          ),

          // ── ميزة مبتكرة: متابعة القراءة الذكية ─────────────────────────────
          if (FirebaseAuth.instance.currentUser != null)
            SliverToBoxAdapter(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .doc(FirebaseAuth.instance.currentUser!.uid)
                    .collection('readingProgress')
                    .orderBy('updatedAt', descending: true)
                    .limit(1)
                    .snapshots(),
                builder: (context, snap) {
                  if (!snap.hasData || snap.data!.docs.isEmpty) return const SizedBox();
                  final novelId = snap.data!.docs.first.id;
                  return GestureDetector(
                    onTap: () async {
                      final doc = await FirebaseFirestore.instance
                          .collection('novels').doc(novelId).get();
                      if (!doc.exists || !context.mounted) return;
                      _navigateToDetail(Novel.fromFirestore(doc));
                    },
                    child: Container(
                      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _accent.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _accent.withOpacity(0.3)),
                      ),
                      child: Row(children: [
                        const Icon(Icons.play_circle_fill_rounded, color: _accent, size: 20),
                        const SizedBox(width: 10),
                        Expanded(child: Text('عد للقراءة: استكمل ما بدأت به الآن', style: GoogleFonts.cairo(fontSize: 12, color: _textPrimary, fontWeight: FontWeight.bold))),
                        const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: _accent),
                      ]),
                    ),
                  );
                },
              ),
            ),

          // ── المحتوى ─────────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: StreamBuilder<QuerySnapshot>(
              stream: _buildQuery(),
              builder: (context, snapshot) {
                // #27 Skeleton loading
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return _buildSkeleton();
                }

                if (snapshot.hasError || !snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return _buildEmptyState();
                }

                final allNovels = snapshot.data!.docs
                    .map((d) => Novel.fromFirestore(d))
                    .toList();

                return FutureBuilder<(List<Novel>, Set<String>)>(
                  future: Future.wait([
                    _showBookmarkedOnly
                        ? context.read<NovelsProvider>().getBookmarkedNovelsStream().first
                        : Future.value(allNovels),
                    _filterMode == 'unread' ? _getReadNovelIds() : Future.value(<String>{}),
                  ]).then((r) => (r[0] as List<Novel>, r[1] as Set<String>)),
                  builder: (context, snap) {
                    final bookmarkedList = snap.data?.$1 ?? allNovels;
                    final readIds        = snap.data?.$2 ?? <String>{};

                    var listToFilter = allNovels;
                    if (_showBookmarkedOnly) {
                      final bIds = bookmarkedList.map((e) => e.id).toSet();
                      listToFilter = allNovels.where((n) => bIds.contains(n.id)).toList();
                    }
                    // #16 فلتر "لم أقرأها بعد"
                    if (_filterMode == 'unread' && readIds.isNotEmpty) {
                      listToFilter = listToFilter.where((n) => !readIds.contains(n.id)).toList();
                    }

                    final searched = _searchQuery.isEmpty
                        ? listToFilter
                        : listToFilter.where((n) =>
                            n.title.toLowerCase().contains(_searchQuery) ||
                            n.author.toLowerCase().contains(_searchQuery)).toList();

                    final filtered = _selectedCategory == 'الكل'
                        ? searched
                        : searched.where((n) => n.category == _selectedCategory).toList();

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 14),

                        _buildCategoryBar(),
                        const SizedBox(height: 18),

                        // #26 ما يقرأه أصدقاؤك
                        if (!_isSearching && _filterMode == 'all' && _selectedCategory == 'الكل' &&
                            FirebaseAuth.instance.currentUser != null)
                          FutureBuilder<List<Map<String,dynamic>>>(
                            future: _getFriendsReading(),
                            builder: (_, snap) {
                              final list = snap.data ?? [];
                              if (list.isEmpty) return const SizedBox.shrink();
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 16),
                                    child: Row(children: [
                                      Container(width: 3, height: 14,
                                          decoration: BoxDecoration(color: Colors.blueGrey,
                                              borderRadius: BorderRadius.circular(2))),
                                      const SizedBox(width: 8),
                                      Text('يقرأ أصدقاؤك الآن',
                                          style: GoogleFonts.cairo(
                                              fontSize: 13, fontWeight: FontWeight.w600,
                                              color: _textSecondary)),
                                    ]),
                                  ),
                                  const SizedBox(height: 8),
                                  SizedBox(
                                    height: 90,
                                    child: ListView.builder(
                                      scrollDirection: Axis.horizontal,
                                      padding: const EdgeInsets.symmetric(horizontal: 16),
                                      itemCount: list.length,
                                      itemBuilder: (_, i) {
                                        final item     = list[i];
                                        final novel    = item['novel'] as Map<String,dynamic>?;
                                        final cover    = novel?['coverUrl'] as String?;
                                        final friend   = item['friendName'] as String;
                                        final novelId  = item['novelId'] as String;
                                        return GestureDetector(
                                          onTap: () => _navigateToDetail(
                                            allNovels.firstWhere((n) => n.id == novelId,
                                                orElse: () => allNovels.first)),
                                          child: Container(
                                            width: 65,
                                            margin: const EdgeInsets.only(left: 10),
                                            child: Column(children: [
                                              ClipRRect(
                                                borderRadius: BorderRadius.circular(8),
                                                child: cover != null && cover.isNotEmpty
                                                    ? Image.network(cover, width: 50, height: 65, fit: BoxFit.cover)
                                                    : Container(width: 50, height: 65, color: _surfaceHigh,
                                                        child: const Icon(Icons.book, color: _accent, size: 22)),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(friend,
                                                  style: GoogleFonts.cairo(fontSize: 8, color: _textSecondary),
                                                  maxLines: 1, overflow: TextOverflow.ellipsis),
                                            ]),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                ],
                              );
                            },
                          ),

                        // #26 موصى به
                        if (!_isSearching && _filterMode == 'all' && _selectedCategory == 'الكل')
                          FutureBuilder<List<Novel>>(
                            future: _getRecommended(allNovels),
                            builder: (_, snap) {
                              final rec = snap.data ?? [];
                              if (rec.isEmpty) return const SizedBox.shrink();
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 16),
                                    child: Row(children: [
                                      Container(width: 3, height: 14,
                                          decoration: BoxDecoration(color: _gold, borderRadius: BorderRadius.circular(2))),
                                      const SizedBox(width: 8),
                                      Text('موصى به لك',
                                          style: GoogleFonts.cairo(fontSize: 13, fontWeight: FontWeight.w600, color: _textSecondary)),
                                    ]),
                                  ),
                                  const SizedBox(height: 10),
                                  SizedBox(
                                    height: 200,
                                    child: ListView.builder(
                                      scrollDirection: Axis.horizontal,
                                      padding: const EdgeInsets.symmetric(horizontal: 16),
                                      itemCount: rec.length,
                                      itemBuilder: (_, i) => GestureDetector(
                                        onTap: () => _navigateToDetail(rec[i]),
                                        child: Container(
                                          width: 110,
                                          margin: const EdgeInsets.only(left: 10),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Expanded(
                                                child: ClipRRect(
                                                  borderRadius: BorderRadius.circular(10),
                                                  child: rec[i].coverUrl != null
                                                      ? Image.network(rec[i].coverUrl!, fit: BoxFit.cover, width: double.infinity)
                                                      : Container(color: _surfaceHigh,
                                                          child: Icon(Icons.auto_stories_rounded, color: _accent, size: 30)),
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(rec[i].title, maxLines: 1, overflow: TextOverflow.ellipsis,
                                                  style: GoogleFonts.cairo(fontSize: 11, color: _textPrimary, fontWeight: FontWeight.w600)),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                ],
                              );
                            },
                          ),

                        _buildSectionTitle(filtered.length),
                        const SizedBox(height: 14),

                        // #24 نص توضيحي للفلاتر
                        if (_filterMode == 'topRated')
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                            child: Text('الأعلى تقييماً خلال آخر 30 يوماً',
                                style: GoogleFonts.cairo(fontSize: 11, color: _textSecondary)),
                          ),

                        filtered.isEmpty
                            ? _buildNoResults()
                            : _isSearching && _searchQuery.isNotEmpty
                                ? _buildSearchList(filtered)
                                : _isListView // #49
                                    ? _buildListView(filtered)
                                    : _buildGrid(_filterMode == 'topRated'
                                        ? (filtered..sort((a, b) => b.rating.compareTo(a.rating)))
                                        : filtered),

                        // #46 زر تحميل المزيد
                        if (filtered.length >= _limit)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
                            child: GestureDetector(
                              onTap: () => setState(() => _limit += 20),
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                decoration: BoxDecoration(
                                  color: _surface,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: _border),
                                ),
                                child: Center(
                                  child: Text('تحميل المزيد',
                                      style: GoogleFonts.cairo(
                                          fontSize: 13, color: _accent, fontWeight: FontWeight.w600)),
                                ),
                              ),
                            ),
                          ),

                        const SizedBox(height: 30),
                      ],
                    );
                  }
                );
              },
            ),
          ),
        ],
      ),
      ),
    );
  }

  // شريط تصفية موحد (تصنيفات + فلاتر + محفوظات)
  Widget _buildCategoryBar() {
    // فلاتر مدمجة: محفوظات + تصنيفات + حالات خاصة
    final extraFilters = [
      ('bookmark', 'محفوظات', Icons.bookmark_outline_rounded),
      ('completed','مكتملة',   Icons.check_circle_outline),
      ('today',    'اليوم',    Icons.wb_sunny_outlined),
      ('topRated', 'الأعلى',   Icons.workspace_premium_outlined),
      ('unread',   'جديدة',    Icons.fiber_new_outlined),
      ('discussed','الأكثر',   Icons.chat_bubble_outline_rounded),
    ];

    return SizedBox(
      height: 36,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          // التصنيفات أولاً
          ..._categories.map((cat) {
            final sel = cat == _selectedCategory &&
                !_showBookmarkedOnly && _filterMode == 'all';
            return GestureDetector(
              onTap: () => setState(() {
                _selectedCategory  = cat;
                _showBookmarkedOnly = false;
                _filterMode        = 'all';
              }),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                margin: const EdgeInsets.only(left: 8),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color:  sel ? _accent : _surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: sel ? _accent : _border),
                ),
                child: Text(cat,
                    style: GoogleFonts.cairo(
                        fontSize: 12,
                        fontWeight: sel ? FontWeight.w700 : FontWeight.w400,
                        color: sel ? const Color(0xFF0D0F14) : _textSecondary)),
              ),
            );
          }),
          // فاصل
          Container(margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              width: 1, color: _border),
          // فلاتر إضافية
          ...extraFilters.map((f) {
            final isSel = f.$1 == 'bookmark'
                ? _showBookmarkedOnly
                : _filterMode == f.$1;
            final selColor = f.$1 == 'bookmark' ? _gold : _accent;
            return GestureDetector(
              onTap: () => setState(() {
                if (f.$1 == 'bookmark') {
                  _showBookmarkedOnly = !_showBookmarkedOnly;
                  _filterMode = 'all';
                } else {
                  _filterMode = isSel ? 'all' : f.$1;
                  _showBookmarkedOnly = false;
                }
              }),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                margin: const EdgeInsets.only(left: 8),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color:  isSel ? selColor : _surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: isSel ? selColor : _border),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(f.$3, size: 13,
                      color: isSel ? const Color(0xFF0D0F14) : _textSecondary),
                  const SizedBox(width: 4),
                  Text(f.$2,
                      style: GoogleFonts.cairo(
                          fontSize: 11,
                          fontWeight: isSel ? FontWeight.w700 : FontWeight.w400,
                          color: isSel ? const Color(0xFF0D0F14) : _textSecondary)),
                ]),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(int count) {
    String text = _selectedCategory == 'الكل'
        ? (_sortByActivity ? 'الأكثر نشاطاً' : 'أحدث الروايات')
        : _selectedCategory;
    if (_showBookmarkedOnly) text = 'المحفوظات';
    if (_isSearching && _searchQuery.isNotEmpty) text = 'نتائج البحث ($count)';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Container(width: 3, height: 16, decoration: BoxDecoration(color: _accent, borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: GoogleFonts.cairo(fontSize: 14, fontWeight: FontWeight.w600, color: _textSecondary))),
          if (!_showBookmarkedOnly && !(_isSearching && _searchQuery.isNotEmpty))
            GestureDetector(
              onTap: () => setState(() => _sortByActivity = !_sortByActivity),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _sortByActivity ? _accent.withOpacity(0.12) : _surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _sortByActivity ? _accent.withOpacity(0.4) : _border),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.local_fire_department_rounded,
                      size: 13, color: _sortByActivity ? _accent : _textSecondary),
                  const SizedBox(width: 4),
                  Text(_sortByActivity ? 'نشاط' : 'أحدث',
                      style: GoogleFonts.cairo(fontSize: 11,
                          color: _sortByActivity ? _accent : _textSecondary,
                          fontWeight: FontWeight.w600)),
                ]),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildNoResults() {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Center(child: Text(_showBookmarkedOnly ? 'لا توجد روايات محفوظة' : 'لا توجد نتائج', style: GoogleFonts.cairo(color: _textSecondary))),
    );
  }

  // ── حالة فارغة ───────────────────────────────────────────────────────────
  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 80),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: _surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _border),
              ),
              child: Icon(
                Icons.auto_stories_outlined,
                size: 38,
                color: _accent.withOpacity(0.5),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'لا توجد روايات بعد',
              style: GoogleFonts.cairo(
                color: _textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'كن أول من يشارك قصته ✍️',
              style: GoogleFonts.cairo(color: _textSecondary, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  // #49 عرض قائمة
  Widget _buildListView(List<Novel> novels) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: novels.length,
      itemBuilder: (_, i) {
        final n = novels[i];
        return GestureDetector(
          onTap: () => _navigateToDetail(n),
          child: Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _border),
            ),
            child: Row(children: [
              // #47 Hero animation
              Hero(
                tag: 'cover_${n.id}',
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: n.coverUrl != null
                      ? Image.network(n.coverUrl!, width: 50, height: 68, fit: BoxFit.cover)
                      : Container(width: 50, height: 68, color: _surfaceHigh,
                          child: Icon(Icons.auto_stories_rounded, color: _accent, size: 22)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(n.title, style: GoogleFonts.cairo(fontSize: 14, fontWeight: FontWeight.w700, color: _textPrimary),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 3),
                  Text(n.author, style: GoogleFonts.cairo(fontSize: 11, color: _textSecondary)),
                  const SizedBox(height: 4),
                  Row(children: [
                    Icon(Icons.star_rounded, size: 12, color: _gold),
                    const SizedBox(width: 3),
                    Text(n.rating.toStringAsFixed(1), style: GoogleFonts.cairo(fontSize: 11, color: _textSecondary)),
                    const SizedBox(width: 10),
                    Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: _accent.withOpacity(0.1), borderRadius: BorderRadius.circular(5)),
                        child: Text(n.category, style: GoogleFonts.cairo(fontSize: 9, color: _accent))),
                  ]),
                ],
              )),
            ]),
          ),
        );
      },
    );
  }

  // ── شبكة الروايات (2 عمود) ────────────────────────────────────────────────
  Widget _buildGrid(List<Novel> novels) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.62,
        crossAxisSpacing: 12,
        mainAxisSpacing: 16,
      ),
      itemCount: novels.length,
      itemBuilder: (_, i) => _buildNovelCard(novels[i]),
    );
  }

  Widget _buildNovelCard(Novel novel) {
    final categoryColors = _isDark
        ? <String, Color>{
            'فانتازيا':  const Color(0xFF2D1F4E),
            'دراما':     const Color(0xFF4E1F2D),
            'رعب':       const Color(0xFF1F2D1F),
            'غموض':      const Color(0xFF1F2A4E),
            'تاريخية':   const Color(0xFF4E3A1F),
            'خيال علمي': const Color(0xFF1F3A4E),
            'عام':       const Color(0xFF252836),
          }
        : <String, Color>{
            'فانتازيا':  const Color(0xFFEDE9F6),
            'دراما':     const Color(0xFFF6E9ED),
            'رعب':       const Color(0xFFE9F0E9),
            'غموض':      const Color(0xFFE9EDF6),
            'تاريخية':   const Color(0xFFF5EFE6),
            'خيال علمي': const Color(0xFFE9EFF5),
            'عام':       const Color(0xFFEEEEF0),
          };
    final coverBg = categoryColors[novel.category] ?? _surfaceHigh;
    final user = FirebaseAuth.instance.currentUser;

    final isCommunityPick = _communityPickId == novel.id; // #18

    return GestureDetector(
      onTap: () => _navigateToDetail(novel),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── الغلاف (#47 Hero) ────────────────────────────────────────────
          Expanded(
            child: Stack(
              children: [
            Hero(
              tag: 'cover_${novel.id}',
              child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: coverBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _border, width: 1),
                image: novel.coverUrl != null
                    ? DecorationImage(
                        image: NetworkImage(novel.coverUrl!),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: novel.coverUrl == null
                  ? Stack(
                      children: [
                        // نقوش خلفية خفية
                        Positioned(
                          top: -10,
                          right: -10,
                          child: Icon(
                            Icons.auto_stories_rounded,
                            size: 80,
                            color: Colors.white.withOpacity(0.04),
                          ),
                        ),
                        // محتوى الغلاف
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: _accent.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  novel.category,
                                  style: GoogleFonts.cairo(
                                    fontSize: 9,
                                    color: _accent,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              const Spacer(),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Icon(
                                    Icons.auto_stories_rounded,
                                    size: 24,
                                    color: _accent.withOpacity(0.4),
                                  ),
                                  StreamBuilder<bool>(
                                    stream: context.read<NovelsProvider>().isBookmarked(novel.id),
                                    builder: (context, bookmarkSnap) {
                                      final isBookmarked = bookmarkSnap.data ?? false;
                                      return IconButton(
                                        icon: Icon(
                                          isBookmarked ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                                          color: isBookmarked ? _gold : _textSecondary,
                                          size: 20,
                                        ),
                                        onPressed: () => context.read<NovelsProvider>().toggleBookmark(novel.id),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                // علامة القراءة
                if (user != null)
                  StreamBuilder<DocumentSnapshot>(
                    stream: FirebaseFirestore.instance.collection('users').doc(user.uid).collection('readingProgress').doc(novel.id).snapshots(),
                    builder: (context, snap) {
                      if (!snap.hasData || !snap.data!.exists) return const SizedBox();
                      final data = snap.data!.data() as Map<String, dynamic>;
                      final lastReadChapter = data['chapterId'] ?? '';
                      
                      // هل هناك فصول جديدة؟ (بسيطة: قارن عدد الفصول)
                      bool hasNew = (novel.chaptersCount > 1); // تبسيط للمثال
                      
                      return Positioned(
                        bottom: 8, left: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: _bg.withOpacity(0.8), borderRadius: BorderRadius.circular(4)),
                          child: Row(children: [
                            Icon(Icons.check_circle, size: 10, color: _accent),
                            const SizedBox(width: 4),
                            Text('مقروءة', style: GoogleFonts.cairo(fontSize: 8, color: _textPrimary)),
                          ]),
                        ),
                      );
                    },
                  ),
              ],
            )
                  : null,
            ),
            ), // Hero
            // #18 شارة المجتمع
            if (isCommunityPick)
              Positioned(
                top: 8, right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: _gold,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.star_rounded, size: 10, color: Color(0xFF0D0F14)),
                    const SizedBox(width: 3),
                    Text('مختارة', style: GoogleFonts.cairo(
                        fontSize: 8, color: const Color(0xFF0D0F14),
                        fontWeight: FontWeight.w700)),
                  ]),
                ),
              ),
            // #37 شريط تقدم القراءة
            if (user != null)
              Positioned(
                bottom: 0, left: 0, right: 0,
                child: StreamBuilder<DocumentSnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('users').doc(user.uid)
                      .collection('readingProgress').doc(novel.id).snapshots(),
                  builder: (_, snap) {
                    if (!snap.hasData || !snap.data!.exists) return const SizedBox();
                    final pct = ((snap.data!.data() as Map<String, dynamic>?)?['pagePercent'] ?? 0.0) as double;
                    if (pct < 0.02) return const SizedBox();
                    return ClipRRect(
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(12),
                        bottomRight: Radius.circular(12),
                      ),
                      child: LinearProgressIndicator(
                        value: pct.clamp(0.0, 1.0),
                        minHeight: 4,
                        backgroundColor: Colors.black38,
                        valueColor: AlwaysStoppedAnimation<Color>(_accent),
                      ),
                    );
                  },
                ),
              ),
          ]), // Stack
          ),  // Expanded

          const SizedBox(height: 8),

          // ── العنوان ──────────────────────────────────────────────────────
          Text(
            novel.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.cairo(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: _textPrimary,
            ),
          ),

          const SizedBox(height: 2),

          // ── المؤلف والتقييم ──────────────────────────────────────────────
          Row(
            children: [
              Expanded(
                child: Text(
                  novel.author,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.cairo(
                    fontSize: 11,
                    color: _textSecondary,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Icon(Icons.star_rounded, size: 11, color: _gold),
              const SizedBox(width: 2),
              Text(
                novel.rating.toStringAsFixed(1),
                style: GoogleFonts.cairo(
                  fontSize: 11,
                  color: _textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── قائمة البحث ──────────────────────────────────────────────────────────
  Widget _buildSearchList(List<Novel> novels) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: novels.length,
      itemBuilder: (_, i) {
        final n = novels[i];
        return GestureDetector(
          onTap: () => _navigateToDetail(n),
          child: Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _border),
            ),
            child: Row(
              children: [
                // مصغّر الغلاف
                Container(
                  width: 48,
                  height: 64,
                  decoration: BoxDecoration(
                    color: _surfaceHigh,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _border),
                    image: n.coverUrl != null
                        ? DecorationImage(
                            image: NetworkImage(n.coverUrl!),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: n.coverUrl == null
                      ? Icon(Icons.auto_stories_rounded, color: _accent.withOpacity(0.5), size: 22)
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        n.title,
                        style: GoogleFonts.cairo(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: _textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        n.author,
                        style: GoogleFonts.cairo(
                          fontSize: 11,
                          color: _textSecondary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: _accent.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Text(
                          n.category,
                          style: GoogleFonts.cairo(
                            fontSize: 10,
                            color: _accent,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  children: [
                    Icon(Icons.star_rounded, size: 14, color: _gold),
                    Text(
                      n.rating.toStringAsFixed(1),
                      style: GoogleFonts.cairo(
                        fontSize: 11,
                        color: _textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}