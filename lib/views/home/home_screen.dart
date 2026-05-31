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
    'الكل', 'رومانسي', 'مغامرات', 'خيال علمي',
    'رعب', 'تاريخي', 'بوليسي', 'عام',
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
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // AppBar
          SliverAppBar(
            floating: true,
            pinned: true,
            expandedHeight: 60,
            backgroundColor: theme.scaffoldBackgroundColor,
            elevation: 0,
            title: _isSearching
                ? TextField(
                    controller: _searchController,
                    autofocus: true,
                    style: GoogleFonts.cairo(fontSize: 15),
                    decoration: InputDecoration(
                      hintText: 'ابحث عن رواية أو كاتب...',
                      hintStyle: GoogleFonts.cairo(
                        color: Colors.grey,
                        fontSize: 14,
                      ),
                      border: InputBorder.none,
                    ),
                    onChanged: (val) =>
                        setState(() => _searchQuery = val.trim().toLowerCase()),
                  )
                : Text(
                    'المكتبة',
                    style: GoogleFonts.cairo(
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
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
                      icon: Icon(
                        Icons.search,
                        color: theme.colorScheme.primary,
                      ),
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
                      padding: EdgeInsets.all(40),
                      child: CircularProgressIndicator(),
                    ),
                  );
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(40),
                      child: Text(
                        'حدث خطأ في تحميل الروايات',
                        style: GoogleFonts.cairo(color: Colors.grey),
                      ),
                    ),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(60),
                      child: Column(
                        children: [
                          Icon(
                            Icons.book_outlined,
                            size: 64,
                            color: theme.colorScheme.primary.withOpacity(0.3),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'لا توجد روايات بعد\nكن أول من ينشر',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.cairo(
                              color: Colors.grey,
                              fontSize: 15,
                            ),
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
                        return n.title.toLowerCase().contains(_searchQuery) ||
                            n.author.toLowerCase().contains(_searchQuery) ||
                            n.category.toLowerCase().contains(_searchQuery);
                      }).toList();

                // فلترة التصنيف
                final filtered = _selectedCategory == 'الكل'
                    ? searchFiltered
                    : searchFiltered
                        .where((n) => n.category == _selectedCategory)
                        .toList();

                // وضع البحث
                if (_isSearching) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildCategoryChips(theme),
                      const SizedBox(height: 8),
                      filtered.isEmpty
                          ? Padding(
                              padding: const EdgeInsets.all(40),
                              child: Center(
                                child: Column(
                                  children: [
                                    Icon(
                                      Icons.search_off,
                                      size: 56,
                                      color: theme.colorScheme.primary
                                          .withOpacity(0.3),
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      'لا توجد نتائج',
                                      style: GoogleFonts.cairo(
                                        color: Colors.grey,
                                        fontSize: 15,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              itemCount: filtered.length,
                              itemBuilder: (context, index) =>
                                  _buildSearchResult(
                                    context,
                                    filtered[index],
                                    theme,
                                  ),
                            ),
                    ],
                  );
                }

                // الشاشة الرئيسية
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // بنر مصغّر
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                      child: Container(
                        width: double.infinity,
                        height: 120,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              theme.colorScheme.primary.withOpacity(0.9),
                              isDark ? Colors.black87 : Colors.brown.shade800,
                            ],
                            begin: Alignment.centerRight,
                            end: Alignment.centerLeft,
                          ),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 16,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'اكتب. انشر. تألق.',
                                style: GoogleFonts.cairo(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'شارك روايتك مع آلاف القراء',
                                style: GoogleFonts.cairo(
                                  fontSize: 12,
                                  color: Colors.white70,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // التصنيفات
                    _buildCategoryChips(theme),
                    const SizedBox(height: 4),

                    // عنوان القسم
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: Text(
                        _selectedCategory == 'الكل'
                            ? 'أحدث الروايات'
                            : 'روايات — $_selectedCategory',
                        style: GoogleFonts.cairo(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                    ),

                    // شبكة الروايات
                    filtered.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.all(40),
                            child: Center(
                              child: Text(
                                'لا توجد روايات في هذا التصنيف',
                                style: GoogleFonts.cairo(color: Colors.grey),
                              ),
                            ),
                          )
                        : GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 4,
                            ),
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                              childAspectRatio: 0.62,
                              crossAxisSpacing: 10,
                              mainAxisSpacing: 10,
                            ),
                            itemCount: filtered.length,
                            itemBuilder: (context, index) {
                              final novel = filtered[index];
                              return GestureDetector(
                                onTap: () =>
                                    _navigateToDetail(context, novel),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    // غلاف
                                    Expanded(
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: theme.colorScheme.surface,
                                          borderRadius:
                                              BorderRadius.circular(10),
                                          border: Border.all(
                                            color: theme.colorScheme.primary
                                                .withOpacity(0.15),
                                          ),
                                        ),
                                        child: Center(
                                          child: Column(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Icon(
                                                Icons.book_rounded,
                                                size: 36,
                                                color: theme
                                                    .colorScheme.primary
                                                    .withOpacity(0.7),
                                              ),
                                              const SizedBox(height: 6),
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                  horizontal: 6,
                                                  vertical: 2,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: theme
                                                      .colorScheme.primary
                                                      .withOpacity(0.12),
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                ),
                                                child: Text(
                                                  novel.category,
                                                  style: GoogleFonts.cairo(
                                                    fontSize: 9,
                                                    color: theme
                                                        .colorScheme.primary,
                                                  ),
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      novel.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.cairo(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: isDark
                                            ? Colors.white
                                            : Colors.black87,
                                      ),
                                    ),
                                    Text(
                                      novel.author,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.cairo(
                                        fontSize: 10,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
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
      height: 44,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
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
                  horizontal: 14,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? theme.colorScheme.primary
                      : theme.colorScheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  cat,
                  style: GoogleFonts.cairo(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isSelected
                        ? Colors.black
                        : theme.colorScheme.primary,
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
    BuildContext context,
    Novel novel,
    ThemeData theme,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        onTap: () => _navigateToDetail(context, novel),
        leading: CircleAvatar(
          backgroundColor: theme.colorScheme.primary.withOpacity(0.12),
          child: Icon(
            Icons.book_rounded,
            color: theme.colorScheme.primary,
            size: 20,
          ),
        ),
        title: Text(
          novel.title,
          style: GoogleFonts.cairo(
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
        subtitle: Text(
          '${novel.author} — ${novel.category}',
          style: GoogleFonts.cairo(fontSize: 11, color: Colors.grey),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.favorite, size: 13, color: Colors.redAccent),
            const SizedBox(width: 3),
            Text(
              novel.likes.toString(),
              style: GoogleFonts.cairo(fontSize: 11, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}