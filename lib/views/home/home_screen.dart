import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/novel_model.dart';
import 'novel_detail_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isSearching = false;
  String _selectedCategory = 'الكل';

  final List<String> _categories = [
    'الكل',
    'رومانسي',
    'مغامرات',
    'خيال علمي',
    'رعب',
    'تاريخي',
    'بوليسي',
    'عام',
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _navigateToDetail(BuildContext context, Novel novel) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => NovelDetailScreen(
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
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            floating: true,
            pinned: true,
            expandedHeight: 70.0,
            backgroundColor: theme.scaffoldBackgroundColor,
            elevation: 0,
            title: _isSearching
                ? TextField(
                    controller: _searchController,
                    autofocus: true,
                    style: GoogleFonts.cairo(fontSize: 16),
                    decoration: InputDecoration(
                      hintText: 'ابحث عن رواية أو كاتب...',
                      hintStyle:
                          GoogleFonts.cairo(color: Colors.grey, fontSize: 14),
                      border: InputBorder.none,
                    ),
                    onChanged: (val) =>
                        setState(() => _searchQuery = val.trim().toLowerCase()),
                  )
                : Text(
                    'المكتبة العامة 📚',
                    style: GoogleFonts.cairo(
                      fontWeight: FontWeight.bold,
                      fontSize: 22,
                      color: theme.colorScheme.primary,
                    ),
                  ),
            actions: [
              _isSearching
                  ? IconButton(
                      icon: const Icon(Icons.close),
                      color: theme.colorScheme.primary,
                      onPressed: () {
                        setState(() {
                          _isSearching = false;
                          _searchQuery = '';
                          _searchController.clear();
                        });
                      },
                    )
                  : IconButton(
                      icon: Icon(Icons.search,
                          color: theme.colorScheme.primary),
                      onPressed: () => setState(() => _isSearching = true),
                    ),
            ],
          ),

          SliverToBoxAdapter(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('novels')
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(40.0),
                      child: CircularProgressIndicator(),
                    ),
                  );
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'حدث خطأ في تحميل الروايات',
                      style: GoogleFonts.cairo(color: Colors.grey),
                    ),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(40.0),
                      child: Column(
                        children: [
                          Icon(Icons.book_outlined,
                              size: 60,
                              color:
                                  theme.colorScheme.primary.withOpacity(0.4)),
                          const SizedBox(height: 16),
                          Text(
                            'لا توجد روايات بعد\nكن أول من ينشر! 🚀',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.cairo(
                                color: Colors.grey, fontSize: 16),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final allNovels = snapshot.data!.docs
                    .map((doc) => Novel.fromFirestore(doc))
                    .toList();

                // فلترة البحث
                final searchFiltered = _searchQuery.isEmpty
                    ? allNovels
                    : allNovels.where((n) {
                        return n.title
                                .toLowerCase()
                                .contains(_searchQuery) ||
                            n.author
                                .toLowerCase()
                                .contains(_searchQuery) ||
                            n.category
                                .toLowerCase()
                                .contains(_searchQuery);
                      }).toList();

                // فلترة التصنيف
                final filtered = _selectedCategory == 'الكل'
                    ? searchFiltered
                    : searchFiltered
                        .where((n) => n.category == _selectedCategory)
                        .toList();

                // شاشة البحث
                if (_isSearching) {
                  return Column(
                    children: [
                      // تصنيفات في وضع البحث
                      _buildCategoryChips(theme),
                      filtered.isEmpty
                          ? Padding(
                              padding: const EdgeInsets.all(40.0),
                              child: Center(
                                child: Column(
                                  children: [
                                    Icon(Icons.search_off,
                                        size: 60,
                                        color: theme.colorScheme.primary
                                            .withOpacity(0.3)),
                                    const SizedBox(height: 16),
                                    Text(
                                      'لا توجد نتائج',
                                      style: GoogleFonts.cairo(
                                          color: Colors.grey),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              padding: const EdgeInsets.all(16),
                              itemCount: filtered.length,
                              itemBuilder: (context, index) {
                                return _buildSearchResult(
                                    context, filtered[index], theme);
                              },
                            ),
                    ],
                  );
                }

                // الشاشة الرئيسية
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // بنر
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Container(
                        width: double.infinity,
                        height: 160,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              theme.colorScheme.primary.withOpacity(0.85),
                              Colors.black87,
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(20.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.black26,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  'منصة راوي ✨',
                                  style: GoogleFonts.cairo(
                                      fontSize: 12, color: Colors.white),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'اكتب. انشر. تألّق.',
                                style: GoogleFonts.cairo(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              Text(
                                'شارك روايتك مع آلاف القراء',
                                style: GoogleFonts.cairo(
                                    fontSize: 13, color: Colors.white70),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // التصنيفات
                    _buildCategoryChips(theme),

                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16.0, vertical: 8.0),
                      child: Text(
                        _selectedCategory == 'الكل'
                            ? 'أحدث الروايات 🖋️'
                            : 'روايات $_selectedCategory 🖋️',
                        style: GoogleFonts.cairo(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: theme.brightness == Brightness.dark
                              ? Colors.white
                              : Colors.black87,
                        ),
                      ),
                    ),

                    filtered.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.all(40.0),
                            child: Center(
                              child: Column(
                                children: [
                                  Icon(Icons.book_outlined,
                                      size: 60,
                                      color: theme.colorScheme.primary
                                          .withOpacity(0.3)),
                                  const SizedBox(height: 16),
                                  Text(
                                    'لا توجد روايات في هذا التصنيف',
                                    style:
                                        GoogleFonts.cairo(color: Colors.grey),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : SizedBox(
                            height: 230,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12),
                              itemCount: filtered.length,
                              itemBuilder: (context, index) {
                                final novel = filtered[index];
                                return Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8.0),
                                  child: GestureDetector(
                                    onTap: () =>
                                        _navigateToDetail(context, novel),
                                    child: SizedBox(
                                      width: 130,
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Expanded(
                                            child: Container(
                                              decoration: BoxDecoration(
                                                color: theme
                                                    .colorScheme.surface,
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                                border: Border.all(
                                                  color: theme
                                                      .colorScheme.primary
                                                      .withOpacity(0.2),
                                                ),
                                              ),
                                              child: Center(
                                                child: Column(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.center,
                                                  children: [
                                                    Icon(Icons.book_rounded,
                                                        size: 45,
                                                        color: theme
                                                            .colorScheme
                                                            .primary
                                                            .withOpacity(0.7)),
                                                    const SizedBox(height: 8),
                                                    Container(
                                                      padding: const EdgeInsets
                                                          .symmetric(
                                                          horizontal: 8,
                                                          vertical: 3),
                                                      decoration: BoxDecoration(
                                                        color: theme
                                                            .colorScheme
                                                            .primary
                                                            .withOpacity(0.15),
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(10),
                                                      ),
                                                      child: Text(
                                                        novel.category,
                                                        style:
                                                            GoogleFonts.cairo(
                                                          fontSize: 10,
                                                          color: theme
                                                              .colorScheme
                                                              .primary,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            novel.title,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: GoogleFonts.cairo(
                                                fontSize: 13,
                                                fontWeight: FontWeight.bold),
                                          ),
                                          Text(
                                            novel.author,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: GoogleFonts.cairo(
                                                fontSize: 11,
                                                color: Colors.grey),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
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

  Widget _buildCategoryChips(ThemeData theme) {
    return SizedBox(
      height: 48,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        itemCount: _categories.length,
        itemBuilder: (context, index) {
          final cat = _categories[index];
          final isSelected = _selectedCategory == cat;
          return Padding(
            padding: const EdgeInsets.only(left: 8),
            child: GestureDetector(
              onTap: () => setState(() => _selectedCategory = cat),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  color: isSelected
                      ? theme.colorScheme.primary
                      : theme.colorScheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  cat,
                  style: GoogleFonts.cairo(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? Colors.black : theme.colorScheme.primary,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSearchResult(
      BuildContext context, Novel novel, ThemeData theme) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        onTap: () => _navigateToDetail(context, novel),
        leading: CircleAvatar(
          backgroundColor: theme.colorScheme.primary.withOpacity(0.15),
          child:
              Icon(Icons.book_rounded, color: theme.colorScheme.primary),
        ),
        title: Text(
          novel.title,
          style:
              GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        subtitle: Text(
          '${novel.author} • ${novel.category}',
          style: GoogleFonts.cairo(fontSize: 12, color: Colors.grey),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.favorite, size: 14, color: Colors.redAccent),
            const SizedBox(width: 4),
            Text(
              novel.likes.toString(),
              style: GoogleFonts.cairo(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}