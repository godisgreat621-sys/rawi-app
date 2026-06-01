import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:my_first_app/providers/novels_provider.dart';
import 'package:my_first_app/repositories/novel_repository.dart';

class NovelReaderScreen extends StatefulWidget {
  final Map<String, dynamic> novel;
  const NovelReaderScreen({super.key, required this.novel});

  @override
  State<NovelReaderScreen> createState() => _NovelReaderScreenState();
}

class _NovelReaderScreenState extends State<NovelReaderScreen> {
  // ── ألوان ─────────────────────────────────────────────────────────────────
  static const _bg            = Color(0xFF0D0F14);
  static const _surface       = Color(0xFF161920);
  static const _surfaceHigh   = Color(0xFF1E2130);
  static const _accent        = Color(0xFF8BAF7C);
  static const _border        = Color(0xFF252836);
  static const _textPrimary   = Color(0xFFECECEC);
  static const _textSecondary = Color(0xFF6B7280);
  static const _gold          = Color(0xFFD4A843);

  double _fontSize    = 16.0;
  bool   _isLiked     = false;
  bool   _isLikeLoading = false;
  int    _likesCount  = 0;
  bool   _isPostingComment = false;

  bool   _canRate     = false;
  int    _userRating  = 0;
  bool   _isRatingLoading = false;
  bool   _hasRated    = false;
  Timer? _readTimer;
  Timer? _saveTimer;
  int    _secondsRead = 0;
  int    _requiredSeconds = 0;
  double _savedPagePercent = 0.0;
  bool   _hasRestoredScroll = false;

  final _scrollController        = ScrollController();
  final _commentController       = TextEditingController();
  final _ratingCommentController = TextEditingController();
  int _commentCharCount = 0;

  @override
  void initState() {
    super.initState();
    _likesCount = int.tryParse(widget.novel['likes']?.toString() ?? '') ?? 0;
    _checkIfLiked();
    _incrementReaders();
    _loadUserRating();
    _loadReadingProgress();
    _scrollController.addListener(_onScrollChanged);
    _commentController.addListener(() {
      setState(() => _commentCharCount = _commentController.text.trim().length);
    });
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
    _saveProgress();
    super.dispose();
  }

  // ── مؤقت القراءة ──────────────────────────────────────────────────────────
  void _startReadTimer() {
    final content    = widget.novel['content'] ?? '';
    final wordCount  = content.split(RegExp(r'\s+')).length;
    final totalSecs  = ((wordCount / 170) * 60).round();
    _requiredSeconds = (totalSecs * 0.7).round().clamp(30, 3600);

    _readTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() {
        _secondsRead++;
        if (_secondsRead >= _requiredSeconds && !_canRate) _canRate = true;
      });
    });
  }

  void _startAutoSave() {
    _saveTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (!mounted) return;
      _saveProgress();
    });
  }

  void _onScrollChanged() {
    if (!_scrollController.hasClients) return;
    final max = _scrollController.position.maxScrollExtent;
    if (max <= 0) return;
    _savedPagePercent = (_scrollController.offset / max).clamp(0.0, 1.0);
  }

  Future<void> _loadReadingProgress() async {
    final progress = await NovelRepository.getReadingProgress(_novelId);
    if (progress == null) return;
    final savedFont    = (progress['fontSize']    ?? _fontSize).toDouble();
    final savedPercent = (progress['pagePercent'] ?? 0.0).toDouble();
    setState(() {
      _fontSize         = savedFont.clamp(12.0, 30.0);
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
      await NovelRepository.saveReadingProgress(
        novelId:     _novelId,
        chapterId:   _chapterId,
        secondsRead: _secondsRead,
        pagePercent: _savedPagePercent,
        fontSize:    _fontSize,
      );
    } catch (_) {}
  }

  double get _readProgress => _requiredSeconds == 0
      ? 1.0
      : (_secondsRead / _requiredSeconds).clamp(0.0, 1.0);

  // ── مراجع Firestore ────────────────────────────────────────────────────────
  String get _novelId   => widget.novel['id']        ?? '';
  String get _chapterId => widget.novel['chapterId'] ?? '';

  DocumentReference get _novelRef   =>
      FirebaseFirestore.instance.collection('novels').doc(_novelId);
  DocumentReference get _chapterRef =>
      _novelRef.collection('chapters').doc(_chapterId);

  // ── إعجاب ─────────────────────────────────────────────────────────────────
  Future<void> _checkIfLiked() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || _novelId.isEmpty) return;
    final doc = await _novelRef.collection('likes').doc(user.uid).get();
    if (mounted) setState(() => _isLiked = doc.exists);
  }

  // ── لا يُضاف القارئ مرتين ─────────────────────────────────────────────────
  Future<void> _incrementReaders() async {
    final user = FirebaseAuth.instance.currentUser;
    if (_novelId.isEmpty || user == null) return;

    final progressRef = FirebaseFirestore.instance
        .collection('users').doc(user.uid)
        .collection('readingProgress').doc(_novelId);
    final prog = await progressRef.get();
    // إذا لم يقرأ هذه الرواية من قبل نُضيف قارئاً واحداً فقط
    if (!prog.exists) {
      await _novelRef.update({'readers': FieldValue.increment(1)});
    }
  }

  Future<void> _loadUserRating() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || _chapterId.isEmpty) return;
    final doc = await _chapterRef.collection('ratings').doc(user.uid).get();
    if (mounted && doc.exists) {
      final data = doc.data() as Map<String, dynamic>?;
      setState(() {
        _userRating = (data?['rating'] ?? 0) as int;
        _hasRated   = true;
      });
    }
  }

  Future<void> _toggleLike() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || _novelId.isEmpty) return;

    final likeRef  = _novelRef.collection('likes').doc(user.uid);
    final wasLiked = _isLiked;
    setState(() {
      _isLiked     = !wasLiked;
      _likesCount  = (_likesCount + (wasLiked ? -1 : 1)).clamp(0, 99999);
      _isLikeLoading = true;
    });

    try {
      if (wasLiked) {
        await likeRef.delete();
        await _novelRef.update({'likes': FieldValue.increment(-1)});
      } else {
        await likeRef.set({'likedAt': FieldValue.serverTimestamp()});
        await _novelRef.update({'likes': FieldValue.increment(1)});
        final nd  = (await _novelRef.get()).data() as Map<String, dynamic>?;
        final aId = nd?['authorId'] ?? '';
        if (aId.isNotEmpty) {
          final uDoc = await FirebaseFirestore.instance
              .collection('users').doc(user.uid).get();
          final name = (uDoc.data() as Map<String,dynamic>?)?['displayName']
              ?? user.email ?? 'قارئ';
          await context.read<NovelsProvider>().notifyAuthorOfLike(
              aId, nd?['title'] ?? '', name);
        }
      }
    } catch (_) {
      if (mounted) setState(() {
        _isLiked    = wasLiked;
        _likesCount = (_likesCount + (wasLiked ? 1 : -1)).clamp(0, 99999);
      });
    } finally {
      if (mounted) setState(() => _isLikeLoading = false);
    }
  }

  // ── إضافة تعليق ───────────────────────────────────────────────────────────
  Future<void> _postComment({String? replyToId, String? replyToName}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || _novelId.isEmpty) return;
    final text = _commentController.text.trim();
    if (text.isEmpty) return;
    if (text.length < 30) {
      _showSnack('التعليق يجب أن يكون 30 حرفاً على الأقل', Colors.orange);
      return;
    }

    setState(() => _isPostingComment = true);

    // جلب اسم المستخدم
    final uDoc = await FirebaseFirestore.instance
        .collection('users').doc(user.uid).get();
    final name = (uDoc.data() as Map<String,dynamic>?)?['displayName']
        ?? user.email ?? 'مجهول';

    await _novelRef.collection('comments').add({
      'text':         text,
      'authorId':     user.uid,
      'authorName':   name,
      'chapterId':    _chapterId,
      'replyToId':    replyToId,
      'replyToName':  replyToName,
      'createdAt':    FieldValue.serverTimestamp(),
      'reported':     false,
    });

    // إشعار الكاتب
    final nd  = (await _novelRef.get()).data() as Map<String,dynamic>?;
    final aId = nd?['authorId'] ?? '';
    if (aId.isNotEmpty && aId != user.uid) {
      await context.read<NovelsProvider>().notifyAuthorOfComment(
          aId, widget.novel['title'] ?? '', name);
    }

    _commentController.clear();
    if (mounted) setState(() => _isPostingComment = false);
  }

  // ── نافذة التقييم ─────────────────────────────────────────────────────────
  void _showRatingSheet() {
    int tempRating = _userRating;
    final ratingCtrl = TextEditingController();
    int charCount = 0;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Container(
          padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 16),
          decoration: const BoxDecoration(
            color: Color(0xFF161920),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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
                    Text('قيّم هذا الفصل',
                        style: GoogleFonts.cairo(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: _textPrimary)),
                    IconButton(
                        icon: const Icon(Icons.close, color: _textSecondary),
                        onPressed: () => Navigator.pop(ctx)),
                  ],
                ),
                const SizedBox(height: 4),

                // نجوم
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (i) {
                    final star = i + 1;
                    return GestureDetector(
                      onTap: () => setS(() => tempRating = star),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Icon(
                          star <= tempRating
                              ? Icons.star_rounded
                              : Icons.star_outline_rounded,
                          color: _gold,
                          size: 44,
                        ),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 16),

                // تعليق 30 حرف
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('تعليق (30 حرفاً على الأقل)',
                        style: GoogleFonts.cairo(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: _textPrimary)),
                    Text('$charCount / 30',
                        style: GoogleFonts.cairo(
                            fontSize: 11,
                            color: charCount >= 30
                                ? _accent
                                : _textSecondary)),
                  ],
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: ratingCtrl,
                  maxLines: 3,
                  style: GoogleFonts.cairo(color: _textPrimary, fontSize: 13),
                  onChanged: (v) => setS(() => charCount = v.trim().length),
                  decoration: InputDecoration(
                    hintText: 'شاركنا رأيك...',
                    hintStyle: GoogleFonts.cairo(
                        color: _textSecondary, fontSize: 13),
                    filled: true,
                    fillColor: _surfaceHigh,
                    contentPadding: const EdgeInsets.all(12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: _border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: _border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          const BorderSide(color: _accent, width: 1.5),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _gold,
                      foregroundColor: const Color(0xFF0D0F14),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: (tempRating == 0 || charCount < 30)
                        ? null
                        : () async {
                            // ← إغلاق الشيت أولاً ثم الإرسال بدون انتظار إخفاء الكيبورد
                            Navigator.pop(ctx);
                            await _submitRating(tempRating,
                                comment: ratingCtrl.text.trim());
                          },
                    child: Text('إرسال التقييم',
                        style: GoogleFonts.cairo(fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submitRating(int rating, {required String comment}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || _chapterId.isEmpty) return;
    // ← منع تقييم الكاتب لنفسه
    final authorId = widget.novel['authorId'] ?? '';
    if (user.uid == authorId) {
      _showSnack('لا يمكنك تقييم فصلك الخاص', Colors.orange);
      return;
    }

    setState(() => _isRatingLoading = true);

    final uDoc = await FirebaseFirestore.instance
        .collection('users').doc(user.uid).get();
    final name = (uDoc.data() as Map<String,dynamic>?)?['displayName']
        ?? user.email ?? 'مجهول';

    await _chapterRef.collection('ratings').doc(user.uid).set({
      'rating':     rating,
      'comment':    comment,
      'authorId':   user.uid,
      'authorName': name,
      'createdAt':  FieldValue.serverTimestamp(),
    });

    // متوسط تقييم الفصل
    final allRatings = await _chapterRef.collection('ratings').get();
    final total = allRatings.docs
        .fold<int>(0, (s, d) => s + ((d.data()['rating'] ?? 0) as int));
    final avg = total / allRatings.docs.length;
    await _chapterRef.update({
      'rating':       double.parse(avg.toStringAsFixed(1)),
      'ratingsCount': allRatings.docs.length,
    });

    // تحديث lastChapterRatingsReceived للكاتب
    if (authorId.isNotEmpty) {
      final aDoc  = await FirebaseFirestore.instance
          .collection('users').doc(authorId).get();
      final aData = aDoc.data() as Map<String,dynamic>?;
      if ((aData?['lastChapterId'] ?? '') == _chapterId) {
        await FirebaseFirestore.instance
            .collection('users').doc(authorId)
            .update({'lastChapterRatingsReceived': FieldValue.increment(1)});
      }
      final nd = (await _novelRef.get()).data() as Map<String,dynamic>?;
      await context.read<NovelsProvider>().notifyAuthorOfRating(
          authorId, nd?['title'] ?? '',
          widget.novel['chapterTitle'] ?? '', name);
    }

    // نقاط المُقيِّم
    await FirebaseFirestore.instance
        .collection('users').doc(user.uid)
        .update({
      'points':       FieldValue.increment(10),
      'ratingsGiven': FieldValue.increment(1),
    });

    // متوسط تقييم الرواية
    final allChapters = await _novelRef.collection('chapters').get();
    if (allChapters.docs.isNotEmpty) {
      final novelAvg = allChapters.docs.fold<double>(
              0, (s, d) => s + ((d.data()['rating'] ?? 0.0) as num).toDouble()) /
          allChapters.docs.length;
      await _novelRef
          .update({'rating': double.parse(novelAvg.toStringAsFixed(1))});
    }

    if (mounted) {
      setState(() {
        _userRating       = rating;
        _hasRated         = true;
        _isRatingLoading  = false;
      });
      _showSnack('شكراً على تقييمك! +10 نقاط ⭐', _gold);
    }
  }

  // ── نافذة التعليقات ────────────────────────────────────────────────────────
  void _showCommentsSheet() {
    String? replyToId;
    String? replyToName;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Container(
          height: MediaQuery.of(context).size.height * 0.8,
          decoration: const BoxDecoration(
            color: Color(0xFF161920),
            borderRadius:
                BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // ── رأس الشيت ────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('التعليقات',
                        style: GoogleFonts.cairo(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: _textPrimary)),
                    IconButton(
                        icon: const Icon(Icons.close,
                            color: _textSecondary),
                        onPressed: () => Navigator.pop(ctx)),
                  ],
                ),
              ),
              Container(height: 1, color: _border),

              // ── بنر الرد ─────────────────────────────────────────────
              if (replyToName != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
                  color: _accent.withOpacity(0.08),
                  child: Row(children: [
                    const Icon(Icons.reply_rounded,
                        size: 15, color: _accent),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text('رداً على $replyToName',
                          style: GoogleFonts.cairo(
                              fontSize: 12, color: _accent)),
                    ),
                    GestureDetector(
                      onTap: () => setS(() {
                        replyToId   = null;
                        replyToName = null;
                      }),
                      child: const Icon(Icons.close,
                          size: 14, color: _textSecondary),
                    ),
                  ]),
                ),

              // ── قائمة التعليقات ──────────────────────────────────────
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('novels')
                      .doc(_novelId)
                      .collection('comments')
                      .orderBy('createdAt', descending: false)
                      .snapshots(),
                  builder: (_, snap) {
                    if (snap.connectionState == ConnectionState.waiting) {
                      return const Center(
                          child: CircularProgressIndicator(
                              color: _accent, strokeWidth: 2));
                    }
                    if (!snap.hasData || snap.data!.docs.isEmpty) {
                      return Center(
                        child: Text('كن أول من يعلق!',
                            style: GoogleFonts.cairo(
                                color: _textSecondary)),
                      );
                    }

                    // فصل التعليقات الرئيسية عن الردود
                    final allDocs = snap.data!.docs;
                    final roots = allDocs
                        .where((d) =>
                            (d.data() as Map)['replyToId'] == null)
                        .toList();

                    return ListView.builder(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      itemCount: roots.length,
                      itemBuilder: (_, i) {
                        final root =
                            roots[i].data() as Map<String, dynamic>;
                        final rootId   = roots[i].id;
                        final replies  = allDocs
                            .where((d) =>
                                (d.data() as Map)['replyToId'] ==
                                rootId)
                            .toList();

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // التعليق الرئيسي
                            _buildCommentBubble(
                              ctx: ctx,
                              docId:      rootId,
                              data:       root,
                              onReply: () => setS(() {
                                replyToId   = rootId;
                                replyToName = root['authorName'] ?? '';
                              }),
                            ),
                            // الردود
                            if (replies.isNotEmpty)
                              Padding(
                                padding:
                                    const EdgeInsets.only(right: 36),
                                child: Column(
                                  children: replies.map((r) {
                                    return _buildCommentBubble(
                                      ctx: ctx,
                                      docId: r.id,
                                      data:  r.data()
                                          as Map<String, dynamic>,
                                      isReply: true,
                                    );
                                  }).toList(),
                                ),
                              ),
                            const SizedBox(height: 4),
                          ],
                        );
                      },
                    );
                  },
                ),
              ),

              // ── حقل الإدخال ──────────────────────────────────────────
              Container(
                padding: EdgeInsets.only(
                  left: 12,
                  right: 12,
                  top: 8,
                  bottom:
                      MediaQuery.of(context).viewInsets.bottom + 12,
                ),
                decoration: const BoxDecoration(
                  color: Color(0xFF161920),
                  border: Border(
                      top: BorderSide(color: _border)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(children: [
                      Expanded(
                        child: TextField(
                          controller: _commentController,
                          style: GoogleFonts.cairo(
                              color: _textPrimary, fontSize: 14),
                          decoration: InputDecoration(
                            hintText: replyToName != null
                                ? 'رداً على $replyToName...'
                                : 'اكتب تعليقك...',
                            hintStyle: GoogleFonts.cairo(
                                color: _textSecondary, fontSize: 13),
                            filled: true,
                            fillColor: _surfaceHigh,
                            contentPadding:
                                const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 10),
                            border: OutlineInputBorder(
                              borderRadius:
                                  BorderRadius.circular(20),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _isPostingComment
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                  color: _accent, strokeWidth: 2))
                          : GestureDetector(
                              onTap: () async {
                                await _postComment(
                                  replyToId:   replyToId,
                                  replyToName: replyToName,
                                );
                                setS(() {
                                  replyToId   = null;
                                  replyToName = null;
                                });
                              },
                              child: Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: _accent,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                    Icons.send_rounded,
                                    color: Color(0xFF0D0F14),
                                    size: 18),
                              ),
                            ),
                    ]),
                    // عداد الحروف
                    if (_commentCharCount > 0 &&
                        _commentCharCount < 30)
                      Padding(
                        padding:
                            const EdgeInsets.only(top: 4, right: 4),
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            '$_commentCharCount / 30 حرفاً',
                            style: GoogleFonts.cairo(
                                fontSize: 11,
                                color: _textSecondary),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── فقاعة تعليق واحدة ─────────────────────────────────────────────────────
  Widget _buildCommentBubble({
    required BuildContext ctx,
    required String docId,
    required Map<String, dynamic> data,
    VoidCallback? onReply,
    bool isReply = false,
  }) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final name        = data['authorName'] ?? 'مجهول';
    final text        = data['text']       ?? '';
    final authorId    = data['authorId']   ?? '';
    final replyTo     = data['replyToName'];
    final isOwn       = currentUser?.uid == authorId;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // الأفاتار
          CircleAvatar(
            radius: isReply ? 14 : 18,
            backgroundColor: _accent.withOpacity(0.15),
            child: Text(
              name.isNotEmpty ? name[0].toUpperCase() : '؟',
              style: GoogleFonts.cairo(
                  fontWeight: FontWeight.w700,
                  color: _accent,
                  fontSize: isReply ? 11 : 13),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isOwn
                        ? _accent.withOpacity(0.08)
                        : _surfaceHigh,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: isOwn
                            ? _accent.withOpacity(0.2)
                            : _border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name,
                          style: GoogleFonts.cairo(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: _accent)),
                      if (replyTo != null) ...[
                        const SizedBox(height: 2),
                        Text('↩ رداً على $replyTo',
                            style: GoogleFonts.cairo(
                                fontSize: 10,
                                color: _textSecondary,
                                fontStyle: FontStyle.italic)),
                      ],
                      const SizedBox(height: 4),
                      Text(text,
                          style: GoogleFonts.cairo(
                              fontSize: 13, color: _textPrimary)),
                    ],
                  ),
                ),
                // أزرار الرد + البلاغ
                Row(children: [
                  if (onReply != null)
                    GestureDetector(
                      onTap: onReply,
                      child: Padding(
                        padding:
                            const EdgeInsets.only(top: 4, left: 6),
                        child: Text('رد',
                            style: GoogleFonts.cairo(
                                fontSize: 11, color: _textSecondary)),
                      ),
                    ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => _reportComment(docId),
                    child: Padding(
                      padding: const EdgeInsets.only(top: 4, right: 4),
                      child: Text('بلاغ',
                          style: GoogleFonts.cairo(
                              fontSize: 10,
                              color: _textSecondary.withOpacity(0.5))),
                    ),
                  ),
                ]),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── بلاغ على تعليق ────────────────────────────────────────────────────────
  Future<void> _reportComment(String commentId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    await FirebaseFirestore.instance.collection('reports').add({
      'type':       'comment',
      'commentId':  commentId,
      'novelId':    _novelId,
      'reportedBy': user.uid,
      'createdAt':  FieldValue.serverTimestamp(),
    });
    _showSnack('تم إرسال البلاغ ✅', Colors.green);
  }

  // ── التبليغ عن محتوى الفصل ────────────────────────────────────────────────
  void _showReportDialog() {
    String? selectedReason;
    final detailsCtrl = TextEditingController();
    const reasons = [
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
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 16),
          decoration: const BoxDecoration(
            color: Color(0xFF161920),
            borderRadius:
                BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('تبليغ عن محتوى',
                        style: GoogleFonts.cairo(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: Colors.redAccent)),
                    IconButton(
                        icon: const Icon(Icons.close,
                            color: _textSecondary),
                        onPressed: () => Navigator.pop(ctx)),
                  ],
                ),
                ...reasons.map((r) => RadioListTile<String>(
                      value:      r,
                      groupValue: selectedReason,
                      onChanged:  (v) => setS(() => selectedReason = v),
                      title: Text(r,
                          style: GoogleFonts.cairo(
                              fontSize: 13, color: _textPrimary)),
                      activeColor:     Colors.redAccent,
                      dense:           true,
                      contentPadding:  EdgeInsets.zero,
                    )),
                const SizedBox(height: 8),
                TextField(
                  controller: detailsCtrl,
                  maxLines: 2,
                  style: GoogleFonts.cairo(
                      color: _textPrimary, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'تفاصيل إضافية (اختياري)',
                    hintStyle: GoogleFonts.cairo(
                        color: _textSecondary, fontSize: 13),
                    filled:    true,
                    fillColor: _surfaceHigh,
                    contentPadding: const EdgeInsets.all(10),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide:
                            const BorderSide(color: _border)),
                    enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide:
                            const BorderSide(color: _border)),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                      foregroundColor: Colors.white,
                      padding:
                          const EdgeInsets.symmetric(vertical: 14),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: selectedReason == null
                        ? null
                        : () async {
                            final user =
                                FirebaseAuth.instance.currentUser;
                            if (user == null) return;
                            await FirebaseFirestore.instance
                                .collection('reports')
                                .add({
                              'novelId':   _novelId,
                              'chapterId': _chapterId,
                              'reportedBy': user.uid,
                              'reason':    selectedReason,
                              'details':   detailsCtrl.text.trim(),
                              'createdAt':
                                  FieldValue.serverTimestamp(),
                            });
                            if (ctx.mounted) {
                              Navigator.pop(ctx);
                              _showSnack('تم إرسال تبليغك ✅',
                                  Colors.green);
                            }
                          },
                    child: Text('إرسال التبليغ',
                        style: GoogleFonts.cairo(
                            fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── مساعد Snackbar ────────────────────────────────────────────────────────
  void _showSnack(String msg, Color bg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: GoogleFonts.cairo()),
      backgroundColor: bg,
      behavior: SnackBarBehavior.floating,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final content = widget.novel['content'] ?? '';
    final chNum   = widget.novel['chapterNumber'] ?? '1';
    final currentUser  = FirebaseAuth.instance.currentUser;
    final authorId     = widget.novel['authorId'] ?? '';
    final isOwner      = currentUser?.uid == authorId;

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: _textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.novel['title'] ?? '',
                style: GoogleFonts.cairo(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: _accent),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
            Text('الفصل $chNum',
                style: GoogleFonts.cairo(
                    fontSize: 11, color: _textSecondary)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.text_decrease_rounded,
                color: _textSecondary, size: 20),
            onPressed: () {
              if (_fontSize > 12) setState(() => _fontSize -= 2);
            },
          ),
          IconButton(
            icon: const Icon(Icons.text_increase_rounded,
                color: _textPrimary, size: 20),
            onPressed: () {
              if (_fontSize < 30) setState(() => _fontSize += 2);
            },
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: _textSecondary),
            color: _surface,
            onSelected: (v) {
              if (v == 'report') _showReportDialog();
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'report',
                child: Row(children: [
                  const Icon(Icons.flag_outlined,
                      color: Colors.redAccent, size: 16),
                  const SizedBox(width: 8),
                  Text('تبليغ عن محتوى',
                      style: GoogleFonts.cairo(
                          fontSize: 13, color: _textPrimary)),
                ]),
              ),
            ],
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: _border),
        ),
      ),

      body: content.isEmpty
          ? Center(
              child: Text('لا يوجد محتوى لهذا الفصل.',
                  style: GoogleFonts.cairo(color: _textSecondary)))
          : SingleChildScrollView(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(
                  horizontal: 22, vertical: 20),
              child: Directionality(
                textDirection: TextDirection.rtl,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // عنوان الفصل
                    Text(
                      widget.novel['chapterTitle'] ?? 'الفصل $chNum',
                      style: GoogleFonts.cairo(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: _accent),
                    ),
                    const SizedBox(height: 4),

                    // استعادة موضع القراءة
                    if (_savedPagePercent > 0.02)
                      Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: _accent.withOpacity(0.07),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: _accent.withOpacity(0.2)),
                        ),
                        child: Text(
                          'استُعيد موضع قراءتك عند ${(_savedPagePercent * 100).toInt()}٪',
                          style: GoogleFonts.cairo(
                              fontSize: 12, color: _accent),
                        ),
                      ),

                    Text(
                      'بقلم: ${widget.novel['author'] ?? 'كاتب مجهول'}',
                      style: GoogleFonts.cairo(
                          fontSize: 12, color: _textSecondary),
                    ),
                    Divider(height: 28, color: _border),

                    // المحتوى
                    Text(
                      content,
                      style: GoogleFonts.cairo(
                        fontSize: _fontSize,
                        height: 2.0,
                        color: Colors.grey.shade300,
                      ),
                    ),

                    const SizedBox(height: 40),
                    Center(
                      child: Text(
                        '— نهاية الفصل $chNum —',
                        style: GoogleFonts.cairo(
                            fontSize: 13,
                            color: _textSecondary,
                            fontStyle: FontStyle.italic),
                      ),
                    ),
                    const SizedBox(height: 30),

                    // ── شريط التقييم ──────────────────────────────────
                    // لا يظهر للكاتب نفسه
                    if (!isOwner) ...[
                      if (!_canRate)
                        _buildReadProgress()
                      else if (!_hasRated)
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _isRatingLoading
                                ? null
                                : _showRatingSheet,
                            icon: const Icon(Icons.star_rounded,
                                color: Color(0xFF0D0F14)),
                            label: Text('قيّم هذا الفصل',
                                style: GoogleFonts.cairo(
                                    fontWeight: FontWeight.w700)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _gold,
                              foregroundColor:
                                  const Color(0xFF0D0F14),
                              padding: const EdgeInsets.symmetric(
                                  vertical: 14),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.circular(12)),
                            ),
                          ),
                        )
                      else
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color:
                                    Colors.green.withOpacity(0.2)),
                          ),
                          child: Row(children: [
                            const Icon(Icons.check_circle,
                                color: Colors.green, size: 18),
                            const SizedBox(width: 8),
                            Text(
                              'قيّمت هذا الفصل بـ $_userRating نجوم ✓',
                              style: GoogleFonts.cairo(
                                  fontSize: 13,
                                  color: Colors.green,
                                  fontWeight: FontWeight.w700),
                            ),
                          ]),
                        ),
                    ],

                    const SizedBox(height: 80),
                  ],
                ),
              ),
            ),

      // ── شريط أسفل ─────────────────────────────────────────────────────
      bottomNavigationBar: StreamBuilder<DocumentSnapshot>(
        stream: _novelId.isEmpty
            ? null
            : _novelRef.snapshots(),
        builder: (_, snap) {
          final data = snap.hasData && snap.data!.exists
              ? snap.data!.data() as Map<String, dynamic>
              : <String, dynamic>{};

          return Container(
            padding: const EdgeInsets.symmetric(
                vertical: 10, horizontal: 24),
            decoration: const BoxDecoration(
              color: Color(0xFF13151C),
              border: Border(top: BorderSide(color: _border)),
            ),
            child: SafeArea(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  // إعجاب
                  GestureDetector(
                    onTap: _isLikeLoading ? null : _toggleLike,
                    child: Row(children: [
                      _isLikeLoading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  color: Colors.redAccent,
                                  strokeWidth: 2))
                          : Icon(
                              _isLiked
                                  ? Icons.favorite
                                  : Icons.favorite_border,
                              size: 22,
                              color: Colors.redAccent),
                      const SizedBox(width: 6),
                      Text('$_likesCount',
                          style: GoogleFonts.cairo(
                              fontSize: 13,
                              color: _textSecondary)),
                    ]),
                  ),

                  // تعليق
                  GestureDetector(
                    onTap: _showCommentsSheet,
                    child: Row(children: [
                      const Icon(Icons.chat_bubble_outline_rounded,
                          size: 22, color: _accent),
                      const SizedBox(width: 6),
                      Text('تعليق',
                          style: GoogleFonts.cairo(
                              fontSize: 13, color: _accent)),
                    ]),
                  ),

                  // قراء
                  Row(children: [
                    const Icon(Icons.remove_red_eye_outlined,
                        size: 18, color: Colors.blueGrey),
                    const SizedBox(width: 4),
                    Text(
                      (data['readers'] ?? 0).toString(),
                      style: GoogleFonts.cairo(
                          fontSize: 13, color: _textSecondary),
                    ),
                  ]),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildReadProgress() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _gold.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _gold.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Text('اقرأ الفصل لتتمكن من التقييم',
                style: GoogleFonts.cairo(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: _gold)),
            const SizedBox(width: 6),
            Icon(Icons.star_rounded, size: 14, color: _gold),
          ]),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value:           _readProgress,
              minHeight:       6,
              backgroundColor: _border,
              valueColor:
                  AlwaysStoppedAnimation<Color>(_gold),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${(_readProgress * 100).toInt()}٪ — يُفعَّل التقييم عند 70٪',
            style: GoogleFonts.cairo(
                fontSize: 11, color: _textSecondary),
          ),
        ],
      ),
    );
  }
}