import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class NovelReaderScreen extends StatefulWidget {
  final Map<String, String> novel;

  const NovelReaderScreen({super.key, required this.novel});

  @override
  State<NovelReaderScreen> createState() => _NovelReaderScreenState();
}

class _NovelReaderScreenState extends State<NovelReaderScreen> {
  double _fontSize = 16.0;
  bool _isLiked = false;
  bool _isLikeLoading = false;
  final _commentController = TextEditingController();
  bool _isPostingComment = false;

  @override
  void initState() {
    super.initState();
    _checkIfLiked();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _checkIfLiked() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || widget.novel['id'] == null) return;
    final doc = await FirebaseFirestore.instance
        .collection('novels')
        .doc(widget.novel['id'])
        .collection('likes')
        .doc(user.uid)
        .get();
    if (mounted) setState(() => _isLiked = doc.exists);
  }

  Future<void> _toggleLike() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || widget.novel['id'] == null) return;
    setState(() => _isLikeLoading = true);
    final novelRef = FirebaseFirestore.instance
        .collection('novels')
        .doc(widget.novel['id']);
    final likeRef = novelRef.collection('likes').doc(user.uid);
    if (_isLiked) {
      await likeRef.delete();
      await novelRef.update({'likes': FieldValue.increment(-1)});
    } else {
      await likeRef.set({'likedAt': FieldValue.serverTimestamp()});
      await novelRef.update({'likes': FieldValue.increment(1)});
    }
    if (mounted) {
      setState(() {
        _isLiked = !_isLiked;
        _isLikeLoading = false;
      });
    }
  }

  Future<void> _postComment() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || widget.novel['id'] == null) return;
    if (_commentController.text.trim().isEmpty) return;

    setState(() => _isPostingComment = true);
    await FirebaseFirestore.instance
        .collection('novels')
        .doc(widget.novel['id'])
        .collection('comments')
        .add({
      'text': _commentController.text.trim(),
      'authorEmail': user.email,
      'authorId': user.uid,
      'createdAt': FieldValue.serverTimestamp(),
    });
    _commentController.clear();
    if (mounted) setState(() => _isPostingComment = false);
  }

  void _showReportDialog({String? selectedText}) {
    final theme = Theme.of(context);
    String? _selectedReason;
    final _detailsController = TextEditingController(
      text: selectedText ?? '',
    );

    final reasons = [
      'محتوى مسيء أو غير لائق',
      'سرقة أدبية أو انتحال',
      'محتوى يحتوي على عنف مفرط',
      'معلومات مضللة أو كاذبة',
      'انتهاك حقوق الملكية الفكرية',
      'أخرى',
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          decoration: BoxDecoration(
            color: theme.scaffoldBackgroundColor,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // هيدر
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'تبليغ عن محتوى 🚩',
                      style: GoogleFonts.cairo(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.redAccent,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                if (selectedText != null) ...[
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.redAccent.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: Colors.redAccent.withOpacity(0.3)),
                    ),
                    child: Text(
                      '"$selectedText"',
                      style: GoogleFonts.cairo(
                          fontSize: 13, color: Colors.redAccent),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                Text(
                  'سبب التبليغ',
                  style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                // أسباب التبليغ
                ...reasons.map((reason) => RadioListTile<String>(
                      value: reason,
                      groupValue: _selectedReason,
                      onChanged: (val) =>
                          setModalState(() => _selectedReason = val),
                      title: Text(reason,
                          style: GoogleFonts.cairo(fontSize: 13)),
                      activeColor: Colors.redAccent,
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                    )),
                const SizedBox(height: 8),
                // تفاصيل إضافية
                TextField(
                  controller: _detailsController,
                  maxLines: 2,
                  style: GoogleFonts.cairo(fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'تفاصيل إضافية (اختياري)...',
                    hintStyle:
                        GoogleFonts.cairo(color: Colors.grey, fontSize: 13),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                    contentPadding: const EdgeInsets.all(10),
                  ),
                ),
                const SizedBox(height: 16),
                // زر الإرسال
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _selectedReason == null
                        ? null
                        : () async {
                            final user =
                                FirebaseAuth.instance.currentUser;
                            if (user == null) return;
                            await FirebaseFirestore.instance
                                .collection('reports')
                                .add({
                              'novelId': widget.novel['id'],
                              'novelTitle': widget.novel['title'],
                              'reportedBy': user.uid,
                              'reason': _selectedReason,
                              'details': _detailsController.text.trim(),
                              'selectedText': selectedText ?? '',
                              'createdAt': FieldValue.serverTimestamp(),
                            });
                            if (context.mounted) {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'تم إرسال تبليغك، شكراً لمساعدتك! 🙏',
                                    style: GoogleFonts.cairo(),
                                  ),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text('إرسال التبليغ',
                        style: GoogleFonts.cairo(
                            fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showCommentsSheet() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.75,
        decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor,
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            // هيدر
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'التعليقات 💬',
                    style: GoogleFonts.cairo(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // قائمة التعليقات
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('novels')
                    .doc(widget.novel['id'])
                    .collection('comments')
                    .orderBy('createdAt', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState ==
                      ConnectionState.waiting) {
                    return const Center(
                        child: CircularProgressIndicator());
                  }
                  if (!snapshot.hasData ||
                      snapshot.data!.docs.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.chat_bubble_outline,
                              size: 50,
                              color: theme.colorScheme.primary
                                  .withOpacity(0.3)),
                          const SizedBox(height: 12),
                          Text(
                            'كن أول من يعلق! 💬',
                            style: GoogleFonts.cairo(color: Colors.grey),
                          ),
                        ],
                      ),
                    );
                  }

                  final comments = snapshot.data!.docs;
                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    itemCount: comments.length,
                    itemBuilder: (context, index) {
                      final data = comments[index].data()
                          as Map<String, dynamic>;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CircleAvatar(
                              radius: 18,
                              backgroundColor: theme.colorScheme.primary
                                  .withOpacity(0.2),
                              child: Text(
                                (data['authorEmail'] ?? '؟')[0]
                                    .toUpperCase(),
                                style: GoogleFonts.cairo(
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? theme.colorScheme.surface
                                      : Colors.grey.shade100,
                                  borderRadius:
                                      BorderRadius.circular(12),
                                ),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      data['authorEmail'] ?? 'مجهول',
                                      style: GoogleFonts.cairo(
                                        fontSize: 11,
                                        color: Colors.grey,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      data['text'] ?? '',
                                      style: GoogleFonts.cairo(
                                          fontSize: 14),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),

            // حقل كتابة التعليق
            Container(
              padding: EdgeInsets.only(
                left: 12,
                right: 12,
                top: 8,
                bottom:
                    MediaQuery.of(context).viewInsets.bottom + 12,
              ),
              decoration: BoxDecoration(
                color: theme.scaffoldBackgroundColor,
                border: Border(
                  top: BorderSide(
                      color: Colors.grey.withOpacity(0.2)),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _commentController,
                      style: GoogleFonts.cairo(fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'اكتب تعليقك هنا...',
                        hintStyle: GoogleFonts.cairo(
                            color: Colors.grey, fontSize: 13),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: isDark
                            ? theme.colorScheme.surface
                            : Colors.grey.shade100,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _isPostingComment
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child:
                              CircularProgressIndicator(strokeWidth: 2),
                        )
                      : IconButton(
                          onPressed: () async {
                            await _postComment();
                          },
                          icon: Icon(Icons.send_rounded,
                              color: theme.colorScheme.primary),
                        ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final content = widget.novel['content'] ?? '';

    return Scaffold(
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close,
              color: isDark ? Colors.white : Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.novel['title'] ?? '',
          style: GoogleFonts.cairo(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.primary,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.text_decrease,
                color: isDark ? Colors.white70 : Colors.black54),
            onPressed: () {
              if (_fontSize > 12) setState(() => _fontSize -= 2);
            },
          ),
          IconButton(
            icon: Icon(Icons.text_increase,
                color: isDark ? Colors.white : Colors.black87),
            onPressed: () {
              if (_fontSize < 30) setState(() => _fontSize += 2);
            },
          ),
          // زر التبليغ عن الرواية كاملة
          IconButton(
            icon: const Icon(Icons.flag_outlined, color: Colors.redAccent),
            onPressed: () => _showReportDialog(),
          ),
          const SizedBox(width: 4),
        ],
      ),

      body: SafeArea(
        child: content.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.book_outlined,
                        size: 60,
                        color:
                            theme.colorScheme.primary.withOpacity(0.3)),
                    const SizedBox(height: 16),
                    Text(
                      'لا يوجد محتوى لهذه الرواية بعد.',
                      style: GoogleFonts.cairo(color: Colors.grey),
                    ),
                  ],
                ),
              )
            : SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                    horizontal: 24.0, vertical: 20.0),
                child: Directionality(
                  textDirection: TextDirection.rtl,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.novel['title'] ?? '',
                        style: GoogleFonts.cairo(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'بقلم: ${widget.novel['author'] ?? 'كاتب مجهول'}',
                        style: GoogleFonts.cairo(
                            fontSize: 13, color: Colors.grey),
                      ),
                      const Divider(height: 32),
                      // النص مع إمكانية التحديد والتبليغ
                      SelectableText(
                        content,
                        style: GoogleFonts.cairo(
                          fontSize: _fontSize,
                          height: 2.0,
                          color: isDark
                              ? Colors.grey.shade300
                              : Colors.black87,
                        ),
                        contextMenuBuilder: (context, editableTextState) {
                          final selectedText = editableTextState
                              .textEditingValue.selection
                              .textInside(editableTextState
                                  .textEditingValue.text);
                          return AdaptiveTextSelectionToolbar(
                            anchors:
                                editableTextState.contextMenuAnchors,
                            children: [
                              if (selectedText.isNotEmpty)
                                TextButton.icon(
                                  onPressed: () {
                                    editableTextState
                                        .hideToolbar();
                                    _showReportDialog(
                                        selectedText: selectedText);
                                  },
                                  icon: const Icon(Icons.flag,
                                      color: Colors.redAccent,
                                      size: 16),
                                  label: Text(
                                    'تبليغ عن هذا النص',
                                    style: GoogleFonts.cairo(
                                        color: Colors.redAccent,
                                        fontSize: 13),
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 40),
                      Center(
                        child: Text(
                          '— نهاية الفصل الأول —',
                          style: GoogleFonts.cairo(
                            fontSize: 13,
                            color: Colors.grey,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
      ),

      bottomNavigationBar: Container(
        padding:
            const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
        decoration: BoxDecoration(
          color: isDark ? theme.colorScheme.surface : Colors.grey.shade100,
          border: Border(
            top: BorderSide(
                color: isDark
                    ? Colors.grey.withOpacity(0.1)
                    : Colors.grey.withOpacity(0.2)),
          ),
        ),
        child: SafeArea(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              // إعجاب
              GestureDetector(
                onTap: _isLikeLoading ? null : _toggleLike,
                child: Row(
                  children: [
                    _isLikeLoading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2),
                          )
                        : Icon(
                            _isLiked
                                ? Icons.favorite
                                : Icons.favorite_border,
                            size: 22,
                            color: Colors.redAccent,
                          ),
                    const SizedBox(width: 6),
                    Text(
                      widget.novel['likes'] ?? '0',
                      style: GoogleFonts.cairo(
                          fontSize: 13, color: Colors.grey),
                    ),
                  ],
                ),
              ),

              // تعليقات
              GestureDetector(
                onTap: _showCommentsSheet,
                child: Row(
                  children: [
                    Icon(Icons.chat_bubble_outline,
                        size: 22,
                        color: theme.colorScheme.primary),
                    const SizedBox(width: 6),
                    Text(
                      'تعليق',
                      style: GoogleFonts.cairo(
                          fontSize: 13,
                          color: theme.colorScheme.primary),
                    ),
                  ],
                ),
              ),

              // قراء
              Row(
                children: [
                  Icon(Icons.remove_red_eye_outlined,
                      size: 18, color: Colors.blueGrey),
                  const SizedBox(width: 4),
                  Text(
                    widget.novel['readers'] ?? '0',
                    style: GoogleFonts.cairo(
                        fontSize: 13, color: Colors.grey),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}