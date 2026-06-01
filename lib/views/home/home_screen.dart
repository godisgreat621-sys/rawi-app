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
  static const _bg = Color(0xFF0F1117);
  static const _surface = Color(0xFF1A1D27);
  static const _accent = Color(0xFF8BAF7C);
  static const _textPrimary = Color(0xFFEAEAEA);
  static const _textSecondary = Color(0xFF7A8090);
  static const _border = Color(0xFF2A2D3A);

  final _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isSearching = false;
  String _selectedCategory = 'الكل';

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
            'id': novel.id,
            'title': novel.title,
            'author': novel.author,
            'category': novel.category,
            'description': novel.description,
            'content': novel.content,
            'rating': novel.rating.toString(),
            'likes': novel.likes.toString(),
            'readers': novel.readers.toString(),
            'authorId': novel.authorId,
            'coverUrl': novel.coverUrl,
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
          // ── AppBar ──────────────────────────────────────────────────────────
          SliverAppBar(
            floating: true,
            pinned: true,
            backgroundColor: _bg,
            elevation: 0,
            expandedHeight: 56,
            title: _isSearching
                ? TextField(
                    controller: _searchController,
                    autofocus: true,
                    style: GoogleFonts.cairo(color: _textPrimary, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'ابحث عن رواية أو كاتب...',
                      hintStyle: GoogleFonts.cairo(color: _textSecondary, fontSize: 13),
                      border: InputBorder.none,
                    ),
                    onChanged: (v) => setState(() => _searchQuery = v.trim().toLowerCase()),
                  )
                : Text(
                    'المكتبة',
                    style: GoogleFonts.cairo(
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                      color: _textPrimary,
                    ),
                  ),
            actions: [
              if (_isSearching)
                IconButton(
                  icon: const Icon(Icons.close, color: _textSecondary, size: 20),
                  onPressed: () => setState(() {
                    _isSearching = false;
                    _searchQuery = '';
                    _searchController.clear();
                  }),
                )
              else ...[
                IconButton(
                  icon: const Icon(Icons.edit_note_rounded, color: _textSecondary, size: 22),
                  tooltip: 'المسودات',
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const DraftsListScreen()),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.search, color: _textSecondary, size: 22),
                  onPressed: () => setState(() => _isSearching = true),
                ),
              ],
            ],
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(1),
              child: Container(height: 1, color: _border),
            ),
          ),

          SliverToBoxAdapter(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('novels')
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.all(60),
                    child: Center(child: CircularProgressIndicator(color: _accent)),
                  );
                }

                if (snapshot.hasError || !snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.all(60),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(Icons.book_outlined, size: 48, color: _textSecondary.withOpacity(0.4)),
                          const SizedBox(height: 14),
                          Text(
                            'لا توجد روايات بعد\nكن أول من ينشر ✍️',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.cairo(color: _textSecondary, fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  );
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
                    const SizedBox(height: 16),

                    // ── التصنيفات ──────────────────────────────────────────
                    SizedBox(
                      height: 36,
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
                              duration: const Duration(milliseconds: 180),
                              margin: const EdgeInsets.only(left: 8),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                              decoration: BoxDecoration(
                                color: sel ? _accent : _surface,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: sel ? _accent : _border,
                                ),
                              ),
                              child: Text(
                                cat,
                                style: GoogleFonts.cairo(
                                  fontSize: 12,
                                  fontWeight: sel ? FontWeight.w700 : FontWeight.w400,
                                  color: sel ? const Color(0xFF0F1117) : _textSecondary,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                    const SizedBox(height: 20),

                    // ── عنوان القسم ────────────────────────────────────────
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        _isSearching && _searchQuery.isNotEmpty
                            ? 'نتائج البحث (${filtered.length})'
                            : _selectedCategory == 'الكل'
                                ? 'أحدث الروايات'
                                : _selectedCategory,
                        style: GoogleFonts.cairo(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: _textSecondary,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // ── الروايات ───────────────────────────────────────────
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

  // ── شبكة الروايات ────────────────────────────────────────────────────────────
  Widget _buildGrid(List<Novel> novels) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 0.58,
        crossAxisSpacing: 10,
        mainAxisSpacing: 14,
      ),
      itemCount: novels.length,
      itemBuilder: (_, i) => _buildNovelCard(novels[i]),
    );
  }

  Widget _buildNovelCard(Novel novel) {
    return GestureDetector(
      onTap: () => _navigateToDetail(novel),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // الغلاف
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: _surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _border),
                image: novel.coverUrl != null
                    ? DecorationImage(
                        image: NetworkImage(novel.coverUrl!),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: novel.coverUrl == null
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.book_rounded, size: 28, color: _accent.withOpacity(0.6)),
                        const SizedBox(height: 6),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: Text(
                            novel.category,
                            style: GoogleFonts.cairo(
                              fontSize: 9,
                              color: _textSecondary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    )
                  : null,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            novel.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.cairo(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: _textPrimary,
            ),
          ),
          Text(
            novel.author,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.cairo(fontSize: 10, color: _textSecondary),
          ),
          const SizedBox(height: 3),
          Row(
            children: [
              const Icon(Icons.star_rounded, size: 10, color: Color(0xFFD4A843)),
              const SizedBox(width: 3),
              Text(
                novel.rating.toStringAsFixed(1),
                style: GoogleFonts.cairo(fontSize: 10, color: _textSecondary),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── قائمة البحث ──────────────────────────────────────────────────────────────
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
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: _accent.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.book_rounded, color: _accent, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        n.title,
                        style: GoogleFonts.cairo(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: _textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '${n.author} · ${n.category}',
                        style: GoogleFonts.cairo(fontSize: 11, color: _textSecondary),
                      ),
                    ],
                  ),
                ),
                Row(
                  children: [
                    const Icon(Icons.favorite, size: 12, color: Colors.redAccent),
                    const SizedBox(width: 4),
                    Text(
                      n.likes.toString(),
                      style: GoogleFonts.cairo(fontSize: 11, color: _textSecondary),
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