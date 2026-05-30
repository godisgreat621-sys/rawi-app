import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:my_first_app/providers/novels_provider.dart';
import 'package:my_first_app/views/writer/add_novel_screen.dart';

class DraftsScreen extends StatelessWidget {
  const DraftsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    return Scaffold(
      appBar: AppBar(
        title: Text('المسودات', style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
      ),
      body: user == null
          ? Center(child: Text('يجب تسجيل الدخول لعرض المسودات.', style: GoogleFonts.cairo(color: Colors.grey)))
          : StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('drafts')
                  .where('authorId', isEqualTo: user.uid)
                  .orderBy('updatedAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Text('لا توجد مسودات حالياً.', style: GoogleFonts.cairo(color: Colors.grey)),
                  );
                }

                final drafts = snapshot.data!.docs;
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  itemCount: drafts.length,
                  itemBuilder: (context, index) {
                    final doc = drafts[index];
                    final data = doc.data() as Map<String, dynamic>;
                    final isNewNovel = data['isNewNovel'] == true;
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: ListTile(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => AddNovelScreen(
                                draftId: doc.id,
                                novelId: data['novelId'] as String?,
                                novelTitle: data['novelTitle'] as String?,
                              ),
                            ),
                          );
                        },
                        title: Text(
                          isNewNovel
                              ? 'مسودة رواية: ${data['novelTitle'] ?? 'بدون عنوان'}'
                              : 'مسودة فصل: ${data['chapterTitle'] ?? 'بدون عنوان'}',
                          style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          'تصنيف: ${data['category'] ?? 'عام'} • ${data['wordCount'] ?? 0} كلمة',
                          style: GoogleFonts.cairo(fontSize: 12, color: Colors.grey),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit, color: Colors.blueGrey),
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => AddNovelScreen(
                                      draftId: doc.id,
                                      novelId: data['novelId'] as String?,
                                      novelTitle: data['novelTitle'] as String?,
                                    ),
                                  ),
                                );
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                              onPressed: () async {
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    title: Text('حذف المسودة', style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
                                    content: Text('هل أنت متأكد من حذف هذه المسودة؟', style: GoogleFonts.cairo()),
                                    actions: [
                                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('إلغاء', style: GoogleFonts.cairo())),
                                      TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text('حذف', style: GoogleFonts.cairo(color: Colors.redAccent))),
                                    ],
                                  ),
                                );
                                if (confirm == true) {
                                  final error = await context.read<NovelsProvider>().deleteDraft(doc.id);
                                  if (error != null) {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                        content: Text(error, style: GoogleFonts.cairo()),
                                        backgroundColor: Colors.redAccent,
                                      ));
                                    }
                                  }
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}
