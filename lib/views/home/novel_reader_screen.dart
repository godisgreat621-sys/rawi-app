import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:my_first_app/providers/novels_provider.dart';
import 'package:my_first_app/repositories/novel_repository.dart';
import 'package:my_first_app/core/constants.dart';

class NovelReaderScreen extends StatefulWidget {
  final Map<String, dynamic> novel;

  const NovelReaderScreen({super.key, required this.novel});

  @override
  State<NovelReaderScreen> createState() => _NovelReaderScreenState();
}

class _NovelReaderScreenState extends State<NovelReaderScreen> {
  double _fontSize = 16.0;
  bool _isLiked = false;
  bool _isLikeLoading = false;
  int _likesCount = 0;
  bool _isPostingComment = false;

  // ── نظام التقييم ──
  bool _canRate = false; // يفعّل بعد 70% من وقت القراءة
  int _userRating = 0;
  bool _isRatingLoading = false;
  bool _hasRated = false;
  Timer? _readTimer;
  Timer? _saveTimer;
  int _secondsRead = 0;
  int _requiredSeconds = 0; // 70% من الوقت المتوقع
  double _savedPagePercent = 0.0;
  bool _hasRestoredScroll = false;

  final _scrollController = ScrollController();
  final _commentController = TextEditingController();
  final _ratingCommentController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _likesCount = int.tryParse(widget.novel['likes'] ?? '') ?? 0;
    _checkIfLiked();
    _incrementReaders();
    _loadUserRating();
    _loadReadingProgress();
    _scrollController.addListener(_onScrollChanged);
    _startReadTimer();
    _startAutoSave();
  }

  @override
  void dispose() {
    _readTimer?.cancel();
    _saveTimer?.cancel();
    _scrollController.dispose();
    _commentController.dispose();
    _ratingCommentController.dispose();
    // Save progress one last time
    _saveProgress();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // مؤقت القراءة
  // ─────────────────────────────────────────────────────────────────────────────
  void _startReadTimer() {
    final content = widget.novel['content'] ?? '';
    final wordCount = content.split(RegExp(r'\s+')).length;
    // متوسط القراءة العربية: 150-200 كلمة / دقيقة → نأخذ 170
    final totalSeconds = ((wordCount / 170) * 60).round();
    _requiredSeconds = (totalSeconds * 0.7).round().clamp(30, 3600);

    _readTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() {
        _secondsRead++;
        if (_secondsRead >= _requiredSeconds && !_canRate) {
          _canRate = true;
        }
      });
    });
  }

  void _startAutoSave() {
    // Save reading progress every 15 seconds
    _saveTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (!mounted) return;
      _saveProgress();
    });
  }

  void _onScrollChanged() {
    if (!_scrollController.hasClients) return;
    final max = _scrollController.position.maxScrollExtent;
    if (max <= 0) return;
    // تحديث القيمة داخلياً بدون إعادة بناء الواجهة (setState) في كل لحظة تمرير
    _savedPagePercent = (_scrollController.offset / max).clamp(0.0, 1.0);
  }

  Future<void> _loadReadingProgress() async {
    final progress = await NovelRepository.getReadingProgress(_novelId);
    if (progress == null) return;
    final savedFont = (progress['fontSize'] ?? _fontSize).toDouble();
    final savedPercent = (progress['pagePercent'] ?? 0.0).toDouble();
    setState(() {
      _fontSize = savedFont.clamp(12.0, 30.0);
      _savedPagePercent = savedPercent.clamp(0.0, 1.0);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients && !_hasRestoredScroll) {
        final max = _scrollController.position.maxScrollExtent;
        if (max > 0) {
          _scrollController.jumpTo(max * _savedPagePercent);
          _hasRestoredScroll = true;
        }
      }
    });
  }

  Future<void> _saveProgress() async {
    try {
      final pagePercent =
          _scrollController.hasClients &&
              _scrollController.position.maxScrollExtent > 0
          ? (_scrollController.offset /
                    _scrollController.position.maxScrollExtent)
                .clamp(0.0, 1.0)
          : _savedPagePercent;
      await NovelRepository.saveReadingProgress(
        novelId: _novelId,
        chapterId: _chapterId,
        secondsRead: _secondsRead,
        pagePercent: pagePercent,
        fontSize: _fontSize,
      );
    } catch (_) {
      // ignore save errors silently to avoid interrupting reading
    }
  }

  double get _readProgress => _requiredSeconds == 0
      ? 1.0
      : (_secondsRead / _requiredSeconds).clamp(0.0, 1.0);

  // ─────────────────────────────────────────────────────────────────────────────
  // Firestore helpers
  // ─────────────────────────────────────────────────────────────────────────────
  String get _novelId => widget.novel['id'] ?? '';
  String get _chapterId => widget.novel['chapterId'] ?? '';

  DocumentReference get _novelRef =>
      FirebaseFirestore.instance.collection('novels').doc(_novelId);
  DocumentReference get _chapterRef =>
      _novelRef.collection('chapters').doc(_chapterId);

  Future<void> _checkIfLiked() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || _novelId.isEmpty) return;
    final doc = await _novelRef.collection('likes').doc(user.uid).get();
    if (mounted) setState(() => _isLiked = doc.exists);
  }

  Future<void> _incrementReaders() async {
    if (_novelId.isEmpty) return;
    await _novelRef.update({'readers': FieldValue.increment(1)});
  }

  Future<void> _loadUserRating() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || _chapterId.isEmpty) return;
    final doc = await _chapterRef.collection('ratings').doc(user.uid).get();
    if (mounted && doc.exists) {
      final ratingData = doc.data() as Map<String, dynamic>?;
      setState(() {
        _userRating = (ratingData?['rating'] ?? 0) as int;
        _hasRated = true;
      });
    }
  }

  Future<void> _toggleLike() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || _novelId.isEmpty) return;

    final likeRef = _novelRef.collection('likes').doc(user.uid);
    final wasLiked = _isLiked;
    final newCount = wasLiked ? (_likesCount - 1) : (_likesCount + 1);

    setState(() {
      _isLiked = !wasLiked;
      _likesCount = newCount < 0 ? 0 : newCount;
      _isLikeLoading = true;
    });

    try {
      if (wasLiked) {
        await likeRef.delete();
        await _novelRef.update({'likes': FieldValue.increment(-1)});
      } else {
        await likeRef.set({'likedAt': FieldValue.serverTimestamp()});
        await _novelRef.update({'likes': FieldValue.increment(1)});
        final novelDoc = await _novelRef.get();
        final novelData = novelDoc.data() as Map<String, dynamic>?;
        final authorId = novelData?['authorId'] ?? '';
        if (authorId.isNotEmpty) {
          final likeName = user.displayName ?? user.email ?? 'قارئ';
          await context.read<NovelsProvider>().notifyAuthorOfLike(
            authorId,
            novelData?['title'] ?? '',
            likeName,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLiked = wasLiked;
          _likesCount = wasLiked ? _likesCount + 1 : _likesCount - 1;
          if (_likesCount < 0) _likesCount = 0;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'حدث خطأ أثناء تحديث الإعجاب، حاول مرة أخرى.',
              style: GoogleFonts.cairo(),
            ),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLikeLoading = false);
    }
  }

  Future<void> _postComment() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || _novelId.isEmpty) return;
    if (_commentController.text.trim().isEmpty) return;
    setState(() => _isPostingComment = true);

    // جلب اسم المستخدم
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    final userData = userDoc.data() as Map<String, dynamic>?;
    final name = userData?['displayName'] ?? user.email ?? 'مجهول';

    await _novelRef.collection('comments').add({
      'text': _commentController.text.trim(),
      'authorEmail': user.email,
      'authorName': name,
      'authorId': user.uid,
      'chapterId': _chapterId,
      'createdAt': FieldValue.serverTimestamp(),
    });

    final novelDoc = await _novelRef.get();
    final novelInfo = novelDoc.data() as Map<String, dynamic>?;
    final authorId = novelInfo?['authorId'] ?? '';
    if (authorId.isNotEmpty) {
      await context.read<NovelsProvider>().notifyAuthorOfComment(
        authorId,
        widget.novel['title'] ?? '',
        name,
      );
    }
    _commentController.clear();
    if (mounted) setState(() => _isPostingComment = false);
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // نافذة التقييم
  // ─────────────────────────────────────────────────────────────────────────────
  void _showRatingSheet() {
    final theme = Theme.of(context);
    int tempRating = _userRating;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
          ),
          decoration: BoxDecoration(
            color: theme.scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Text(
                          'قيّم هذا الفصل',
                          style: GoogleFonts.cairo(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          Icons.star_rounded,
                          size: kIconSmall,
                          color: Colors.amber,
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),

                // نجوم
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (i) {
                    final star = i + 1;
                    return GestureDetector(
                      onTap: () => setS(() => tempRating = star),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: Icon(
                          star <= tempRating
                              ? Icons.star_rounded
                              : Icons.star_outline_rounded,
                          color: Colors.amber,
                          size: 44,
                        ),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 16),

                // تعليق إلزامي
                Text(
                  'التعليق (50 حرف على الأقل — إلزامي)',
                  style: GoogleFonts.cairo(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _ratingCommentController,
                  maxLines: 3,
                  style: GoogleFonts.cairo(fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'شاركنا رأيك بتفصيل...',
                    hintStyle: GoogleFonts.cairo(color: Colors.grey),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    contentPadding: const EdgeInsets.all(12),
                  ),
                ),
                const SizedBox(height: 16),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: tempRating == 0
                        ? null
                        : () async {
                            if (_ratingCommentController.text.trim().length <
                                50) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'التعليق يجب أن يكون 50 حرفاً على الأقل (حالياً: ${_ratingCommentController.text.trim().length})',
                                    style: GoogleFonts.cairo(),
                                  ),
                                  backgroundColor: Colors.orange,
                                ),
                              );
                              return;
                            }
                            Navigator.pop(ctx);
                            await _submitRating(tempRating);
                          },
                    child: Text(
                      'إرسال التقييم',
                      style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submitRating(int rating) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || _chapterId.isEmpty) return;
    setState(() => _isRatingLoading = true);

    // جلب اسم المستخدم
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    final userData = userDoc.data() as Map<String, dynamic>?;
    final name = userData?['displayName'] ?? user.email ?? 'مجهول';

    // حفظ التقييم في الفصل
    await _chapterRef.collection('ratings').doc(user.uid).set({
      'rating': rating,
      'comment': _ratingCommentController.text.trim(),
      'authorId': user.uid,
      'authorName': name,
      'createdAt': FieldValue.serverTimestamp(),
    });

    // حساب متوسط تقييم الفصل
    final allRatings = await _chapterRef.collection('ratings').get();
    final total = allRatings.docs.fold<int>(
      0,
      (s, d) => s + ((d.data()['rating'] ?? 0) as int),
    );
    final avg = total / allRatings.docs.length;

    await _chapterRef.update({
      'rating': double.parse(avg.toStringAsFixed(1)),
      'ratingsCount': allRatings.docs.length,
    });

    // جلب كاتب الرواية لتحديث lastChapterRatingsReceived
    final novelDoc = await _novelRef.get();
    final novelData = novelDoc.data() as Map<String, dynamic>?;
    final authorId = novelData?['authorId'] ?? '';

    if (authorId.isNotEmpty) {
      final authorDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(authorId)
          .get();
      final authorData = authorDoc.data() as Map<String, dynamic>?;
      final authorLastChapter = authorData?['lastChapterId'] ?? '';
      if (authorLastChapter == _chapterId) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(authorId)
            .update({'lastChapterRatingsReceived': FieldValue.increment(1)});
      }
      await context.read<NovelsProvider>().notifyAuthorOfRating(
        authorId,
        novelData?['title'] ?? '',
        widget.novel['chapterTitle'] ?? '',
        name,
      );
    }

    // تحديث نقاط المُقيِّم + عداد التقييمات المُعطاة
    await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
      'points': FieldValue.increment(10),
      'ratingsGiven': FieldValue.increment(1),
    }, SetOptions(merge: true));

    // حساب متوسط تقييم الرواية من كل الفصول
    final allChapters = await _novelRef.collection('chapters').get();
    if (allChapters.docs.isNotEmpty) {
      final novelAvg =
          allChapters.docs.fold<double>(
            0,
            (s, d) => s + ((d.data()['rating'] ?? 0.0) as num).toDouble(),
          ) /
          allChapters.docs.length;
      await _novelRef.update({
        'rating': double.parse(novelAvg.toStringAsFixed(1)),
      });
    }

    if (mounted) {
      setState(() {
        _userRating = rating;
        _hasRated = true;
        _isRatingLoading = false;
      });
      _ratingCommentController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Expanded(
                child: Text(
                  'شكراً على تقييمك! +10 نقاط',
                  style: GoogleFonts.cairo(),
                ),
              ),
              const SizedBox(width: 6),
              const Icon(Icons.star, size: 16, color: Colors.amber),
            ],
          ),
          backgroundColor: Colors.amber,
        ),
      );
    }
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // طلب دعم
  // ─────────────────────────────────────────────────────────────────────────────
  void _showSupportRequestSheet() {
    final theme = Theme.of(context);
    String reqType = 'spelling';
    final originalCtrl = TextEditingController();
    final correctedCtrl = TextEditingController();
    final reasonCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
          ),
          decoration: BoxDecoration(
            color: theme.scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'طلب دعم 📩',
                      style: GoogleFonts.cairo(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),

                // نوع الطلب
                Row(
                  children: [
                    _typeChip(
                      'تصحيح إملائي',
                      'spelling',
                      reqType,
                      (v) => setS(() => reqType = v),
                      theme,
                    ),
                    const SizedBox(width: 8),
                    _typeChip(
                      'إزالة مخالفة',
                      'violation',
                      reqType,
                      (v) => setS(() => reqType = v),
                      theme,
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                if (reqType == 'spelling') ...[
                  TextField(
                    controller: originalCtrl,
                    style: GoogleFonts.cairo(fontSize: 13),
                    decoration: InputDecoration(
                      labelText: 'الكلمة الخاطئة',
                      labelStyle: GoogleFonts.cairo(),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: correctedCtrl,
                    style: GoogleFonts.cairo(fontSize: 13),
                    decoration: InputDecoration(
                      labelText: 'الكلمة الصحيحة',
                      labelStyle: GoogleFonts.cairo(),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                    ),
                  ),
                ] else ...[
                  TextField(
                    controller: reasonCtrl,
                    maxLines: 3,
                    style: GoogleFonts.cairo(fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'اشرح سبب طلب إزالة المخالفة...',
                      hintStyle: GoogleFonts.cairo(color: Colors.grey),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      contentPadding: const EdgeInsets.all(12),
                    ),
                  ),
                ],
                const SizedBox(height: 16),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () async {
                      final user = FirebaseAuth.instance.currentUser;
                      if (user == null) return;
                      await FirebaseFirestore.instance
                          .collection('support_requests')
                          .add({
                            'type': reqType,
                            'novelId': _novelId,
                            'chapterId': _chapterId,
                            'authorId': user.uid,
                            'originalText': originalCtrl.text.trim(),
                            'correctedText': correctedCtrl.text.trim(),
                            'description': reasonCtrl.text.trim(),
                            'status': 'pending',
                            'createdAt': FieldValue.serverTimestamp(),
                          });
                      if (ctx.mounted) {
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'تم إرسال طلبك للدعم ✅',
                              style: GoogleFonts.cairo(),
                            ),
                            backgroundColor: Colors.green,
                          ),
                        );
                      }
                    },
                    child: Text(
                      'إرسال الطلب',
                      style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _typeChip(
    String label,
    String value,
    String current,
    void Function(String) onTap,
    ThemeData theme,
  ) {
    final selected = current == value;
    return GestureDetector(
      onTap: () => onTap(value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? theme.colorScheme.primary
              : Colors.grey.withAlpha(26),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: GoogleFonts.cairo(
            fontSize: 13,
            color: selected ? Colors.black : Colors.grey,
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // التبليغ
  // ─────────────────────────────────────────────────────────────────────────────
  void _showReportDialog() {
    final theme = Theme.of(context);
    String? selectedReason;
    final detailsCtrl = TextEditingController();

    final reasons = [
      'محتوى مسيء أو غير لائق',
      'سرقة أدبية أو انتحال',
      'محتوى يحتوي على عنف مفرط',
      'معلومات مضللة',
      'انتهاك حقوق الملكية الفكرية',
      'أخرى',
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
          ),
          decoration: BoxDecoration(
            color: theme.scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                Text(
                  'سبب التبليغ',
                  style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                ...reasons.map(
                  (r) => RadioListTile<String>(
                    value: r,
                    groupValue: selectedReason,
                    onChanged: (v) => setS(() => selectedReason = v),
                    title: Text(r, style: GoogleFonts.cairo(fontSize: 13)),
                    activeColor: Colors.redAccent,
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: detailsCtrl,
                  maxLines: 2,
                  style: GoogleFonts.cairo(fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'تفاصيل إضافية (اختياري)...',
                    hintStyle: GoogleFonts.cairo(
                      color: Colors.grey,
                      fontSize: 13,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    contentPadding: const EdgeInsets.all(10),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: selectedReason == null
                        ? null
                        : () async {
                            final user = FirebaseAuth.instance.currentUser;
                            if (user == null) return;
                            await FirebaseFirestore.instance
                                .collection('reports')
                                .add({
                                  'novelId': _novelId,
                                  'chapterId': _chapterId,
                                  'novelTitle': widget.novel['title'],
                                  'reportedBy': user.uid,
                                  'reason': selectedReason,
                                  'details': detailsCtrl.text.trim(),
                                  'createdAt': FieldValue.serverTimestamp(),
                                });
                            if (ctx.mounted) {
                              Navigator.pop(ctx);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'تم إرسال تبليغك، شكراً! 🙏',
                                    style: GoogleFonts.cairo(),
                                  ),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            }
                          },
                    child: Text(
                      'إرسال التبليغ',
                      style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // تعليقات
  // ─────────────────────────────────────────────────────────────────────────────
  void _showCommentsSheet() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(context).size.height * 0.75,
        decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
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
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('novels')
                    .doc(_novelId)
                    .collection('comments')
                    .orderBy('createdAt', descending: true)
                    .snapshots(),
                builder: (_, snap) {
                  if (!snap.hasData || snap.data!.docs.isEmpty) {
                    return Center(
                      child: Text(
                        'كن أول من يعلق! 💬',
                        style: GoogleFonts.cairo(color: Colors.grey),
                      ),
                    );
                  }
                  final comments = snap.data!.docs;
                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    itemCount: comments.length,
                    itemBuilder: (_, i) {
                      final d = comments[i].data() as Map<String, dynamic>;
                      final name =
                          d['authorName'] ?? d['authorEmail'] ?? 'مجهول';
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CircleAvatar(
                              radius: 18,
                              backgroundColor: theme.colorScheme.primary
                                  .withAlpha(51),
                              child: Text(
                                name.isNotEmpty ? name[0].toUpperCase() : '؟',
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
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      name,
                                      style: GoogleFonts.cairo(
                                        fontSize: 11,
                                        color: Colors.grey,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      d['text'] ?? '',
                                      style: GoogleFonts.cairo(fontSize: 14),
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
            Container(
              padding: EdgeInsets.only(
                left: 12,
                right: 12,
                top: 8,
                bottom: MediaQuery.of(context).viewInsets.bottom + 12,
              ),
              decoration: BoxDecoration(
                color: theme.scaffoldBackgroundColor,
                border: Border(
                  top: BorderSide(color: Colors.grey.withAlpha(51)),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _commentController,
                      style: GoogleFonts.cairo(fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'اكتب تعليقك...',
                        hintStyle: GoogleFonts.cairo(
                          color: Colors.grey,
                          fontSize: 13,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: isDark
                            ? theme.colorScheme.surface
                            : Colors.grey.shade100,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _isPostingComment
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : IconButton(
                          onPressed: () async {
                            await _postComment();
                          },
                          icon: Icon(
                            Icons.send_rounded,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Build
  // ─────────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final content = widget.novel['content'] ?? '';
    final chNum = widget.novel['chapterNumber'] ?? '1';

    return Scaffold(
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.close,
            color: isDark ? Colors.white : Colors.black87,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.novel['title'] ?? '',
              style: GoogleFonts.cairo(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              'الفصل $chNum',
              style: GoogleFonts.cairo(fontSize: 11, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(
              Icons.text_decrease,
              color: isDark ? Colors.white70 : Colors.black54,
            ),
            onPressed: () {
              if (_fontSize > 12) setState(() => _fontSize -= 2);
            },
          ),
          IconButton(
            icon: Icon(
              Icons.text_increase,
              color: isDark ? Colors.white : Colors.black87,
            ),
            onPressed: () {
              if (_fontSize < 30) setState(() => _fontSize += 2);
            },
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (v) {
              if (v == 'report') _showReportDialog();
              if (v == 'support') _showSupportRequestSheet();
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'report',
                child: Row(
                  children: [
                    const Icon(
                      Icons.flag_outlined,
                      color: Colors.redAccent,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'تبليغ عن محتوى',
                      style: GoogleFonts.cairo(fontSize: 13),
                    ),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'support',
                child: Row(
                  children: [
                    const Icon(Icons.support_agent_outlined, size: 18),
                    const SizedBox(width: 8),
                    Text('طلب دعم', style: GoogleFonts.cairo(fontSize: 13)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),

      body: SafeArea(
        child: content.isEmpty
            ? Center(
                child: Text(
                  'لا يوجد محتوى لهذا الفصل.',
                  style: GoogleFonts.cairo(color: Colors.grey),
                ),
              )
            : SingleChildScrollView(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 20,
                ),
                child: Directionality(
                  textDirection: TextDirection.rtl,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.novel['chapterTitle'] ?? 'الفصل $chNum',
                        style: GoogleFonts.cairo(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      if (_savedPagePercent > 0.02) ...[
                        Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary.withAlpha(26),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'تمت استعادة وضع القراءة من آخر زيارة عند ${(_savedPagePercent * 100).toInt()}٪.',
                            style: GoogleFonts.cairo(fontSize: 13),
                          ),
                        ),
                      ],
                      Text(
                        'بقلم: ${widget.novel['author'] ?? 'كاتب مجهول'}',
                        style: GoogleFonts.cairo(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                      const Divider(height: 28),

                      // المحتوى — منع النسخ
                      Text(
                        content,
                        style: GoogleFonts.cairo(
                          fontSize: _fontSize,
                          height: 2.0,
                          color: isDark ? Colors.grey.shade300 : Colors.black87,
                        ),
                      ),

                      const SizedBox(height: 40),
                      Center(
                        child: Text(
                          '— نهاية الفصل $chNum —',
                          style: GoogleFonts.cairo(
                            fontSize: 13,
                            color: Colors.grey,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                      const SizedBox(height: 30),

                      // ── شريط التقدم للتقييم ──
                      if (!_canRate) ...[
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.amber.withAlpha(20),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.amber.withAlpha(77),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    'اقرأ الفصل لتتمكن من التقييم',
                                    style: GoogleFonts.cairo(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.amber.shade700,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  const Icon(
                                    Icons.star,
                                    size: 14,
                                    color: Colors.amber,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: _readProgress,
                                  minHeight: 6,
                                  backgroundColor: Colors.grey.withAlpha(51),
                                  valueColor:
                                      const AlwaysStoppedAnimation<Color>(
                                        Colors.amber,
                                      ),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '${(_readProgress * 100).toInt()}٪ — '
                                'يُفعَّل التقييم عند 70٪',
                                style: GoogleFonts.cairo(
                                  fontSize: 11,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ] else if (!_hasRated) ...[
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _isRatingLoading
                                ? null
                                : _showRatingSheet,
                            icon: const Icon(
                              Icons.star_rounded,
                              color: Colors.black,
                            ),
                            label: Text(
                              'قيّم هذا الفصل',
                              style: GoogleFonts.cairo(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.amber,
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ] else ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.green.withAlpha(20),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.check_circle,
                                color: Colors.green,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Row(
                                children: [
                                  Text(
                                    'قيّمت هذا الفصل بـ $_userRating نجوم',
                                    style: GoogleFonts.cairo(
                                      fontSize: 13,
                                      color: Colors.green,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  const Icon(
                                    Icons.star,
                                    size: 14,
                                    color: Colors.green,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: 80),
                    ],
                  ),
                ),
              ),
      ),

      // ── الشريط السفلي ──
      bottomNavigationBar: StreamBuilder<DocumentSnapshot>(
        stream: _novelId.isEmpty
            ? null
            : FirebaseFirestore.instance
                  .collection('novels')
                  .doc(_novelId)
                  .snapshots(),
        builder: (_, snap) {
          final data = snap.hasData && snap.data!.exists
              ? snap.data!.data() as Map<String, dynamic>
              : <String, dynamic>{};
          final likesCount = _likesCount.toString();
          final readersCount = (data['readers'] ?? 0).toString();

          return Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
            decoration: BoxDecoration(
              color: isDark ? theme.colorScheme.surface : Colors.grey.shade100,
              border: Border(top: BorderSide(color: Colors.grey.withAlpha(51))),
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
                                  strokeWidth: 2,
                                ),
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
                          likesCount,
                          style: GoogleFonts.cairo(
                            fontSize: 13,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // تعليقات
                  GestureDetector(
                    onTap: _showCommentsSheet,
                    child: Row(
                      children: [
                        Icon(
                          Icons.chat_bubble_outline,
                          size: 22,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'تعليق',
                          style: GoogleFonts.cairo(
                            fontSize: 13,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // قراء
                  Row(
                    children: [
                      const Icon(
                        Icons.remove_red_eye_outlined,
                        size: 18,
                        color: Colors.blueGrey,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        readersCount,
                        style: GoogleFonts.cairo(
                          fontSize: 13,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}