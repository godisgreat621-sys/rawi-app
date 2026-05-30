import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/novel_model.dart';
import 'novel_detail_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

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
            title: Text(
              'المكتبة العامة 📚',
              style: GoogleFonts.cairo(
                fontWeight: FontWeight.bold,
                fontSize: 22,
                color: theme.colorScheme.primary,
              ),
            ),
            actions: [
              IconButton(
                icon: Icon(Icons.search, color: theme.colorScheme.primary),
                onPressed: () {},
              ),
            ],
          ),

          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // بنر رواية الأسبوع
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
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black26,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              'منصة راوي ✨',
                              style: GoogleFonts.cairo(
                                fontSize: 12,
                                color: Colors.white,
                              ),
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
                              fontSize: 13,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // الروايات الحية من Firestore
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 8.0,
                  ),
                  child: Text(
                    'أحدث الروايات 🖋️',
                    style: GoogleFonts.cairo(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: theme.brightness == Brightness.dark
                          ? Colors.white
                          : Colors.black87,
                    ),
                  ),
                ),

                // Stream Builder يجلب الروايات لحظة بلحظة
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('novels')
                      .orderBy('createdAt', descending: true)
                      .snapshots(),
                  builder: (context, snapshot) {
                    // حالة التحميل
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(40.0),
                          child: CircularProgressIndicator(),
                        ),
                      );
                    }

                    // حالة الخطأ
                    if (snapshot.hasError) {
                      return Center(
                        child: Text(
                          'حدث خطأ في تحميل الروايات',
                          style: GoogleFonts.cairo(color: Colors.grey),
                        ),
                      );
                    }

                    // حالة فارغة
                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(40.0),
                          child: Column(
                            children: [
                              Icon(
                                Icons.book_outlined,
                                size: 60,
                                color: theme.colorScheme.primary.withOpacity(
                                  0.4,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'لا توجد روايات بعد\nكن أول من ينشر! 🚀',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.cairo(
                                  color: Colors.grey,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    // عرض الروايات
                    final novels = snapshot.data!.docs
                        .map((doc) => Novel.fromFirestore(doc))
                        .toList();

                    return SizedBox(
                      height: 230,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        itemCount: novels.length,
                        itemBuilder: (context, index) {
                          final novel = novels[index];
                          return Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8.0,
                            ),
                            child: GestureDetector(
                              onTap: () {
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
                                      },
                                    ),
                                  ),
                                );
                              },
                              child: SizedBox(
                                width: 130,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: theme.colorScheme.surface,
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          border: Border.all(
                                            color: theme.colorScheme.primary
                                                .withOpacity(0.2),
                                          ),
                                        ),
                                        child: Center(
                                          child: Column(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Icon(
                                                Icons.book_rounded,
                                                size: 45,
                                                color: theme.colorScheme.primary
                                                    .withOpacity(0.7),
                                              ),
                                              const SizedBox(height: 8),
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 3,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: theme
                                                      .colorScheme
                                                      .primary
                                                      .withOpacity(0.15),
                                                  borderRadius:
                                                      BorderRadius.circular(10),
                                                ),
                                                child: Text(
                                                  novel.category,
                                                  style: GoogleFonts.cairo(
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
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      novel.author,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.cairo(
                                        fontSize: 11,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
                const SizedBox(height: 30),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
