import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../providers/novels_provider.dart';
import '../../providers/theme_provider.dart';
import 'add_novel_screen.dart';

class DraftsListScreen extends StatelessWidget {
  const DraftsListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<NovelsProvider>();
    final isDark = context.watch<ThemeProvider>().isDarkMode;
    final bg           = isDark ? const Color(0xFF0D0F14) : const Color(0xFFF5F5F7);
    final surface      = isDark ? const Color(0xFF161920) : const Color(0xFFFFFFFF);
    final border       = isDark ? const Color(0xFF252836) : const Color(0xFFE0E0E4);
    final textPrimary  = isDark ? const Color(0xFFECECEC) : const Color(0xFF111827);
    final textSecondary= isDark ? const Color(0xFF6B7280) : const Color(0xFF555F6E);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        title: Text('مسوداتي 📝', style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 16, color: textPrimary)),
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: provider.getMyDraftsStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final drafts = snapshot.data ?? [];

          if (drafts.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.note_alt_outlined, size: 64, color: textSecondary.withValues(alpha: 0.3)),
                  const SizedBox(height: 16),
                  Text(
                    'لا توجد مسودات محفوظة حالياً',
                    style: GoogleFonts.cairo(color: textSecondary),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: drafts.length,
            itemBuilder: (context, index) {
              final draft = drafts[index];
              final isNewNovel = draft['isNewNovel'] ?? true;
              final title = isNewNovel ? (draft['novelTitle'] ?? 'بدون عنوان') : (draft['chapterTitle'] ?? 'فصل جديد');

              return Card(
                color: surface,
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: border),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  title: Text(
                    title,
                    style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: textPrimary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    isNewNovel ? 'رواية جديدة • ${draft['wordCount'] ?? 0} كلمة' : 'إضافة فصل • ${draft['wordCount'] ?? 0} كلمة',
                    style: GoogleFonts.cairo(fontSize: 12, color: textSecondary),
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20),
                    onPressed: () => _confirmDelete(context, provider, draft['id']),
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => AddNovelScreen(
                          draftId: draft['id'],
                          novelId: draft['novelId'],
                          novelTitle: draft['novelTitle'],
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _confirmDelete(BuildContext context, NovelsProvider provider, String id) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? const Color(0xFF161920) : const Color(0xFFFFFFFF);
    final textPrimary = isDark ? const Color(0xFFECECEC) : const Color(0xFF111827);
    final textSecondary = isDark ? const Color(0xFF6B7280) : const Color(0xFF555F6E);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text('حذف المسودة', style: GoogleFonts.cairo(color: textPrimary, fontWeight: FontWeight.w700)),
        content: Text('هل أنت متأكد من حذف هذه المسودة؟ لا يمكن التراجع عن هذا الإجراء.', style: GoogleFonts.cairo(color: textSecondary, height: 1.6)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('إلغاء', style: GoogleFonts.cairo(color: textSecondary))),
          TextButton(
            onPressed: () { Navigator.pop(ctx); provider.deleteDraft(id); },
            child: Text('حذف', style: GoogleFonts.cairo(color: Colors.redAccent, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}
