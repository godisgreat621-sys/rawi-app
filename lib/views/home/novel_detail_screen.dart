import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:my_first_app/views/home/novel_reader_screen.dart';

class NovelDetailScreen extends StatelessWidget {
  final Map<String, String> novel;

  const NovelDetailScreen({super.key, required this.novel});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 340.0,
            pinned: true,
            backgroundColor: theme.scaffoldBackgroundColor,
            leading: CircleAvatar(
              backgroundColor: isDark ? Colors.black54 : Colors.white70,
              child: IconButton(
                icon: Icon(
                  Icons.arrow_back,
                  color: isDark ? Colors.white : Colors.black87,
                ),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            actions: [
              CircleAvatar(
                backgroundColor: isDark ? Colors.black54 : Colors.white70,
                child: IconButton(
                  icon: const Icon(
                    Icons.favorite_border,
                    color: Colors.redAccent,
                  ),
                  onPressed: () {},
                ),
              ),
              const SizedBox(width: 12),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      theme.colorScheme.primary.withOpacity(0.15),
                      theme.scaffoldBackgroundColor,
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: Center(
                  child: Container(
                    width: 160,
                    height: 240,
                    margin: const EdgeInsets.only(top: 40),
                    decoration: BoxDecoration(
                      color: isDark
                          ? theme.colorScheme.surface
                          : Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: isDark ? Colors.black54 : Colors.black12,
                          blurRadius: 15,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Icon(
                        Icons.book_rounded,
                        size: 70,
                        color: theme.colorScheme.primary.withOpacity(0.8),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // التصنيف
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      novel['category'] ?? 'عام',
                      style: GoogleFonts.cairo(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // العنوان
                  Text(
                    novel['title'] ?? '',
                    style: GoogleFonts.cairo(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),

                  // الكاتب
                  Text(
                    'بقلم: ${novel['author'] ?? 'كاتب مجهول'}',
                    style: GoogleFonts.cairo(
                      fontSize: 16,
                      color: isDark ? Colors.grey : Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // إحصائيات من Firebase
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark
                          ? theme.colorScheme.surface
                          : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildInfoColumn(
                          Icons.star_rounded,
                          novel['rating'] ?? '0',
                          'التقييم',
                          theme,
                        ),
                        _buildInfoColumn(
                          Icons.favorite_rounded,
                          novel['likes'] ?? '0',
                          'إعجاب',
                          theme,
                        ),
                        _buildInfoColumn(
                          Icons.remove_red_eye_rounded,
                          novel['readers'] ?? '0',
                          'قارئ',
                          theme,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // الوصف
                  Text(
                    'نبذة عن الرواية',
                    style: GoogleFonts.cairo(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    novel['description'] != null &&
                            novel['description']!.isNotEmpty
                        ? novel['description']!
                        : 'لا يوجد وصف لهذه الرواية.',
                    style: GoogleFonts.cairo(
                      fontSize: 14,
                      height: 1.6,
                      color: isDark ? Colors.white70 : Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ],
      ),

      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => NovelReaderScreen(
                    novel: {
                      'id': novel['id'] ?? '',
                      'title': novel['title'] ?? '',
                      'author': novel['author'] ?? '',
                      'content': novel['content'] ?? '',
                      'likes': novel['likes'] ?? '0',
                      'readers': novel['readers'] ?? '0',
                    },
                  ),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: Colors.black,
              minimumSize: const Size(double.infinity, 54),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              elevation: 4,
            ),
            child: Text(
              'ابدأ القراءة الآن 📖',
              style: GoogleFonts.cairo(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoColumn(
    IconData icon,
    String value,
    String label,
    ThemeData theme,
  ) {
    final isDark = theme.brightness == Brightness.dark;
    return Column(
      children: [
        Icon(icon, color: theme.colorScheme.primary, size: 24),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.cairo(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        Text(label, style: GoogleFonts.cairo(fontSize: 11, color: Colors.grey)),
      ],
    );
  }
}
