import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/novel_model.dart';
import 'novel_detail_screen.dart';
import '../writer/drafts_list_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // ── ألوان ثابتة ──────────────────────────────────────────────────────────
  static const _bg           = Color(0xFF0D0F14);
  static const _surface      = Color(0xFF161920);
  static const _surfaceHigh  = Color(0xFF1E2130);
  static const _accent       = Color(0xFF8BAF7C);
  static const _accentDim    = Color(0xFF4A6741);
  static const _textPrimary  = Color(0xFFECECEC);
  static const _textSecondary= Color(0xFF6B7280);
  static const _border       = Color(0xFF252836);
  static const _gold         = Color(0xFFD4A843);

  final _searchController = TextEditingController();
  String _searchQuery     = '';
  bool   _isSearching     = false;
  String _selectedCategory= 'الكل';

  final List<String> _categories = [
    'الكل', 'فانتازيا', 'رومانسية', 'رعب',
    'غموض', 'تاريخية', 'خيال علمي', 'عام',
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
            'rating':    novel.rating.toString(),
            'likes':     novel.likes.toString(),
            'readers':   novel.readers.toString(),
            'authorId':  novel.authorId,
            'coverUrl':  novel.coverUrl,
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: CustomScrollView(
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
                    onChanged: (v) => setState(() => _searchQuery = v.trim().toLowerCase()),
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
                  icon: const Icon(Icons.close_rounded, color: _textSecondary, size: 21),
                  onPressed: () => setState(() {
                    _isSearching = false;
                    _searchQuery = '';
                    _searchController.clear();
                  }),
                )
              else ...[
                IconButton(
                  icon: const Icon(Icons.search_rounded, color: _textSecondary, size: 22),
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

          // ── المحتوى ─────────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('novels')
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.all(80),
                    child: Center(
                      child: CircularProgressIndicator(
                        color: _accent,
                        strokeWidth: 2,
                      ),
                    ),
                  );
                }

                if (snapshot.hasError || !snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return _buildEmptyState();
                }

                final allNovels = snapshot.data!.docs
                    .map((d) => Novel.fromFirestore(d))
                    .toList();

                final searched = _searchQuery.isEmpty
                    ? allNovels
                    : allNovels.where((n) =>
                        n.title.toLowerCase().contains(_searchQuery) ||
                        n.author.toLowerCase().contains(_searchQuery)).toList();

                final filtered = _selectedCategory == 'الكل'
                    ? searched
                    : searched.where((n) => n.category == _selectedCategory).toList();

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 18),

                    // ── التصنيفات ─────────────────────────────────────────
                    SizedBox(
                      height: 38,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _categories.length,
                        itemBuilder: (_, i) {
                          final cat = _categories[i];
                          final sel = cat == _selectedCategory;
                          return GestureDetector(
                            onTap: () => setState(() => _selectedCategory = cat),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              margin: const EdgeInsets.only(left: 8),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                              decoration: BoxDecoration(
                                color: sel ? _accent : _surface,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: sel ? _accent : _border,
                                  width: 1,
                                ),
                              ),
                              child: Text(
                                cat,
                                style: GoogleFonts.cairo(
                                  fontSize: 12,
                                  fontWeight: sel ? FontWeight.w700 : FontWeight.w400,
                                  color: sel ? const Color(0xFF0D0F14) : _textSecondary,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                    const SizedBox(height: 22),

                    // ── عنوان القسم ──────────────────────────────────────
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          Container(
                            width: 3,
                            height: 16,
                            decoration: BoxDecoration(
                              color: _accent,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _isSearching && _searchQuery.isNotEmpty
                                ? 'نتائج البحث (${filtered.length})'
                                : _selectedCategory == 'الكل'
                                    ? 'أحدث الروايات'
                                    : _selectedCategory,
                            style: GoogleFonts.cairo(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: _textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 14),

                    // ── الروايات ──────────────────────────────────────────
                    filtered.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.all(40),
                            child: Center(
                              child: Text(
                                'لا توجد نتائج',
                                style: GoogleFonts.cairo(color: _textSecondary),
                              ),
                            ),
                          )
                        : _isSearching && _searchQuery.isNotEmpty
                            ? _buildSearchList(filtered)
                            : _buildGrid(filtered),

                    const SizedBox(height: 30),
                  ],
                );
              },
            ),
          ),
        ],
      ),
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
    // خلفية ملونة للغلاف بناءً على التصنيف
    final categoryColors = <String, Color>{
      'فانتازيا':   const Color(0xFF2D1F4E),
      'رومانسية':   const Color(0xFF4E1F2D),
      'رعب':        const Color(0xFF1F2D1F),
      'غموض':       const Color(0xFF1F2A4E),
      'تاريخية':    const Color(0xFF4E3A1F),
      'خيال علمي':  const Color(0xFF1F3A4E),
      'عام':        const Color(0xFF252836),
    };
    final coverBg = categoryColors[novel.category] ?? _surfaceHigh;

    return GestureDetector(
      onTap: () => _navigateToDetail(novel),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── الغلاف ──────────────────────────────────────────────────────
          Expanded(
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
                              Icon(
                                Icons.auto_stories_rounded,
                                size: 32,
                                color: _accent.withOpacity(0.4),
                              ),
                            ],
                          ),
                        ),
                      ],
                    )
                  : null,
            ),
          ),

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