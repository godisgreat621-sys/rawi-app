import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../providers/novels_provider.dart';
import 'add_novel_screen.dart';

class DraftsListScreen extends StatelessWidget {
  const DraftsListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.read<NovelsProvider>();
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('مسوداتي 📝', style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 16)),
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
                  Icon(Icons.note_alt_outlined, size: 64, color: Colors.grey.withOpacity(0.5)),
                  const SizedBox(height: 16),
                  Text(
                    'لا توجد مسودات محفوظة حالياً',
                    style: GoogleFonts.cairo(color: Colors.grey),
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
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  title: Text(
                    title,
                    style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    isNewNovel ? 'رواية جديدة • ${draft['wordCount'] ?? 0} كلمة' : 'إضافة فصل • ${draft['wordCount'] ?? 0} كلمة',
                    style: GoogleFonts.cairo(fontSize: 12, color: Colors.grey),
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
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
    provider.deleteDraft(id);
  }
}