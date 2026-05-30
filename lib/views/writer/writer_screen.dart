import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/novel_model.dart';
import 'add_novel_screen.dart';

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
                      .orderBy('createdAt', descending: true)
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
                              backgroundColor:
                                  theme.colorScheme.primary.withOpacity(0.1),
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
                            trailing: Container(
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