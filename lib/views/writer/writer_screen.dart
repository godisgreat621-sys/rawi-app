import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:my_first_app/providers/novels_provider.dart';
import '../../models/novel_model.dart';
import 'add_novel_screen.dart';
import '../home/novel_detail_screen.dart';

class WriterScreen extends StatelessWidget {
  const WriterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cairoStyle = GoogleFonts.cairo();
    final currentUser = FirebaseAuth.instance.currentUser;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'مؤلفاتي 🖋️',
                    style: cairoStyle.copyWith(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const AddNovelScreen(),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    icon: const Icon(Icons.add, size: 18),
                    label: Text(
                      'رواية جديدة',
                      style: cairoStyle.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('novels')
                      .where('authorId', isEqualTo: currentUser?.uid)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (snapshot.hasError) {
                      return Center(
                        child: Text(
                          'حدث خطأ في تحميل رواياتك',
                          style: cairoStyle.copyWith(color: Colors.grey),
                        ),
                      );
                    }

                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.edit_note,
                              size: 70,
                              color: theme.colorScheme.primary.withOpacity(0.3),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'لم تكتب أي رواية بعد\nابدأ بروايتك الأولى! 🚀',
                              textAlign: TextAlign.center,
                              style: cairoStyle.copyWith(
                                color: Colors.grey,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    final novels = snapshot.data!.docs
                        .map((doc) => Novel.fromFirestore(doc))
                        .toList();

                    return ListView.builder(
                      itemCount: novels.length,
                      itemBuilder: (context, index) {
                        final novel = novels[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: theme.colorScheme.primary
                                  .withOpacity(0.1),
                              child: Icon(
                                Icons.auto_stories,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                            title: Text(
                              novel.title,
                              style: cairoStyle.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Text(
                              novel.category,
                              style: cairoStyle.copyWith(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.green.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    'منشورة',
                                    style: cairoStyle.copyWith(
                                      fontSize: 11,
                                      color: Colors.greenAccent,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                PopupMenuButton<String>(
                                  icon: Icon(
                                    Icons.more_vert,
                                    color: theme.colorScheme.primary,
                                  ),
                                  onSelected: (value) async {
                                    if (value == 'view') {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              NovelDetailScreen(
                                                novel: {
                                                  'id': novel.id,
                                                  'title': novel.title,
                                                  'description':
                                                      novel.description,
                                                  'category': novel.category,
                                                  'author': novel.author,
                                                  'authorId': novel.authorId,
                                                },
                                              ),
                                        ),
                                      );
                                    } else if (value == 'delete') {
                                      final confirm = await showDialog<bool>(
                                        context: context,
                                        builder: (ctx) => AlertDialog(
                                          title: Text(
                                            'حذف الرواية',
                                            style: cairoStyle.copyWith(
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          content: Text(
                                            'هل أنت متأكد من حذف هذه الرواية؟',
                                            style: cairoStyle,
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed: () =>
                                                  Navigator.pop(ctx, false),
                                              child: Text(
                                                'إلغاء',
                                                style: cairoStyle,
                                              ),
                                            ),
                                            TextButton(
                                              onPressed: () =>
                                                  Navigator.pop(ctx, true),
                                              child: Text(
                                                'حذف',
                                                style: cairoStyle.copyWith(
                                                  color: Colors.redAccent,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                      if (confirm == true) {
                                        final error = await context
                                            .read<NovelsProvider>()
                                            .deleteNovel(novel.id);
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                error == null
                                                    ? 'تم حذف الرواية.'
                                                    : error,
                                                style: cairoStyle,
                                              ),
                                              backgroundColor: error == null
                                                  ? Colors.green
                                                  : Colors.redAccent,
                                            ),
                                          );
                                        }
                                      }
                                    }
                                  },
                                  itemBuilder: (_) => [
                                    PopupMenuItem(
                                      value: 'view',
                                      child: Text(
                                        'عرض الرواية',
                                        style: cairoStyle,
                                      ),
                                    ),
                                    PopupMenuItem(
                                      value: 'delete',
                                      child: Text(
                                        'حذف الرواية',
                                        style: cairoStyle.copyWith(
                                          color: Colors.redAccent,
                                        ),
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
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
