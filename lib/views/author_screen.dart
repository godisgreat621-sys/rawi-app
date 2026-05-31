import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:my_first_app/models/novel_model.dart';
import 'package:my_first_app/views/home/novel_detail_screen.dart';

class AuthorScreen extends StatefulWidget {
  final String authorId;
  final String authorName;

  const AuthorScreen({
    super.key,
    required this.authorId,
    required this.authorName,
  });

  @override
  State<AuthorScreen> createState() => _AuthorScreenState();
}

class _AuthorScreenState extends State<AuthorScreen> {
  bool _isFollowing = false;
  bool _isFollowLoading = false;

  @override
  void initState() {
    super.initState();
    _checkIfFollowing();
  }

  Future<void> _checkIfFollowing() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('following')
        .doc(widget.authorId)
        .get();
    if (mounted) setState(() => _isFollowing = doc.exists);
  }

  Future<void> _toggleFollow() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.uid == widget.authorId) return;
    setState(() => _isFollowLoading = true);

    final followingRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('following')
        .doc(widget.authorId);
    final followersRef = FirebaseFirestore.instance
        .collection('users')
        .doc(widget.authorId)
        .collection('followers')
        .doc(user.uid);

    if (_isFollowing) {
      await followingRef.delete();
      await followersRef.delete();
    } else {
      await followingRef.set({'followedAt': FieldValue.serverTimestamp()});
      await followersRef.set({'followedAt': FieldValue.serverTimestamp()});
    }
    if (mounted)
      setState(() {
        _isFollowing = !_isFollowing;
        _isFollowLoading = false;
      });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final currentUser = FirebaseAuth.instance.currentUser;
    final isMe = currentUser?.uid == widget.authorId;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
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
            expandedHeight: 200,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      theme.colorScheme.primary.withOpacity(0.2),
                      theme.scaffoldBackgroundColor,
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 40),
                    CircleAvatar(
                      radius: 44,
                      backgroundColor: theme.colorScheme.primary.withOpacity(
                        0.2,
                      ),
                      child: Icon(
                        Icons.person,
                        size: 44,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      widget.authorName,
                      style: GoogleFonts.cairo(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'كاتب في منصة راوي ',
                      style: GoogleFonts.cairo(
                        color: Colors.grey,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // إحصائيات + زر متابعة
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('novels')
                        .where('authorId', isEqualTo: widget.authorId)
                        .snapshots(),
                    builder: (_, snap) {
                      final novels = snap.hasData
                          ? snap.data!.docs
                                .map((d) => Novel.fromFirestore(d))
                                .toList()
                          : <Novel>[];
                      final totalLikes = novels.fold(0, (s, n) => s + n.likes);
                      final totalReaders = novels.fold(
                        0,
                        (s, n) => s + n.readers,
                      );

                      return Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? theme.colorScheme.surface
                                  : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                _stat(novels.length.toString(), 'رواية', theme),
                                _divider(),
                                _stat(totalLikes.toString(), 'إعجاب', theme),
                                _divider(),
                                _stat(totalReaders.toString(), 'قارئ', theme),
                                _divider(),
                                StreamBuilder<QuerySnapshot>(
                                  stream: FirebaseFirestore.instance
                                      .collection('users')
                                      .doc(widget.authorId)
                                      .collection('followers')
                                      .snapshots(),
                                  builder: (_, fs) {
                                    final cnt = fs.hasData
                                        ? fs.data!.docs.length
                                        : 0;
                                    return _stat(
                                      cnt.toString(),
                                      'متابع',
                                      theme,
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                          if (!isMe) ...[
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: _isFollowLoading
                                  ? const Center(
                                      child: CircularProgressIndicator(),
                                    )
                                  : ElevatedButton.icon(
                                      onPressed: _toggleFollow,
                                      icon: Icon(
                                        _isFollowing
                                            ? Icons.person_remove_outlined
                                            : Icons.person_add_outlined,
                                      ),
                                      label: Text(
                                        _isFollowing
                                            ? 'إلغاء المتابعة'
                                            : 'متابعة',
                                        style: GoogleFonts.cairo(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: _isFollowing
                                            ? Colors.grey.shade300
                                            : theme.colorScheme.primary,
                                        foregroundColor: _isFollowing
                                            ? Colors.black54
                                            : Colors.black,
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 12,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                      ),
                                    ),
                            ),
                          ],
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 24),

                  // روايات الكاتب
                  Text(
                    'روايات الكاتب ',
                    style: GoogleFonts.cairo(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 12),

                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('novels')
                        .where('authorId', isEqualTo: widget.authorId)
                        .where('status', isEqualTo: 'active')
                        .snapshots(),
                    builder: (_, snap) {
                      if (snap.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (!snap.hasData || snap.data!.docs.isEmpty) {
                        return Center(
                          child: Text(
                            'لا توجد روايات بعد.',
                            style: GoogleFonts.cairo(color: Colors.grey),
                          ),
                        );
                      }

                      final novels = snap.data!.docs
                          .map((d) => Novel.fromFirestore(d))
                          .toList();

                      return ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: novels.length,
                        itemBuilder: (_, i) {
                          final n = novels[i];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 10),
                            elevation: 1.5,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: ListTile(
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => NovelDetailScreen(
                                    novel: {
                                      'id': n.id,
                                      'title': n.title,
                                      'author': n.author,
                                      'authorId': n.authorId,
                                      'category': n.category,
                                      'description': n.description,
                                      'content': n.content,
                                      'rating': n.rating.toString(),
                                      'likes': n.likes.toString(),
                                      'readers': n.readers.toString(),
                                    },
                                  ),
                                ),
                              ),
                              leading: CircleAvatar(
                                backgroundColor: theme.colorScheme.primary
                                    .withOpacity(0.1),
                                child: Icon(
                                  Icons.auto_stories,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                              title: Text(
                                n.title,
                                style: GoogleFonts.cairo(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      '${n.category}  •  ${n.chaptersCount} فصل  •  ${n.rating.toStringAsFixed(1)}',
                                      style: GoogleFonts.cairo(
                                        fontSize: 11,
                                        color: Colors.grey,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  const Icon(
                                    Icons.star,
                                    size: 12,
                                    color: Colors.amber,
                                  ),
                                ],
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.favorite,
                                    size: 13,
                                    color: Colors.redAccent,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    n.likes.toString(),
                                    style: GoogleFonts.cairo(
                                      fontSize: 12,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _stat(String value, String label, ThemeData theme) {
    return Column(
      children: [
        Text(
          value,
          style: GoogleFonts.cairo(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.primary,
          ),
        ),
        Text(label, style: GoogleFonts.cairo(fontSize: 11, color: Colors.grey)),
      ],
    );
  }

  Widget _divider() =>
      Container(height: 36, width: 1, color: Colors.grey.withOpacity(0.3));
}
