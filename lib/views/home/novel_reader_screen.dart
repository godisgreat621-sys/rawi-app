import 'dart:async';
import 'package:flutter/material.dart';

import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:my_first_app/providers/novels_provider.dart';
import 'package:my_first_app/repositories/novel_repository.dart';
import 'package:my_first_app/views/home/novel_detail_screen.dart';
import 'package:my_first_app/views/author_screen.dart';

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

  // وضع القراءة الكاملة — يُخفي الشريطين بعد ثانية، ويعود بالضغط
  bool   _showControls = true;
  Timer? _hideControlsTimer;

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

  // #9 ألوان خلفية القراءة
  Color  _readerBg    = const Color(0xFF0D0F14);
  // #29 تقدم التمرير
  double _scrollProgress = 0.0;
  // #20 كاش محتوى الفصل في الذاكرة — بحد أقصى 50 فصل
  static final Map<String, String> _contentCache = {};
  static const int _maxCacheSize = 50;
  // #47 محتوى محفوظ offline
  bool _isOfflineCached = false;
  // #28 Pagination التعليقات
  int  _commentsLimit   = 20;
  // #2 إظهار زر العودة لأعلى
  bool _showBackToTop   = false;
  // #1 خط القراءة المختار
  String _fontFamily = 'Cairo';
  // #3 وضع التصفح بصفحات
  bool _pagedMode = false;
  int  _pageIndex  = 0;
  late PageController _pageController;

  final _scrollController        = ScrollController();
  final _commentController       = TextEditingController();
  final _ratingCommentController = TextEditingController();
  int _commentCharCount = 0;

  @override
  void initState() {
    super.initState();
    _likesCount = int.tryParse(widget.novel['likes']?.toString() ?? '') ?? 0;
    // #20 كاش: احمّل من الذاكرة فوراً إن وُجد مع حد الحجم
    if (_chapterId.isNotEmpty && !_contentCache.containsKey(_chapterId) &&
        widget.novel['content'] != null) {
      if (_contentCache.length >= _maxCacheSize) {
        _contentCache.remove(_contentCache.keys.first);
      }
      _contentCache[_chapterId] = widget.novel['content'];
    }
    _pageController = PageController();

    _scrollController.addListener(() {
      final show = _scrollController.hasClients && _scrollController.offset > 400;
      if (show != _showBackToTop) setState(() => _showBackToTop = show);
    });
    _checkIfLiked();
    _incrementReaders();
    _loadUserRating();
    _loadReadingProgress();
    _loadGlobalFontPref(); // #8
    _saveContentOffline(); // #47 حفظ للكاش
    _initOfflineContent(); // #47 تحميل من الكاش إن لزم
    _scrollController.addListener(_onScrollChanged);
    _commentController.addListener(() {
      setState(() => _commentCharCount = _commentController.text.trim().length);
    });
    _startReadTimer();
    _startAutoSave();
    _startHideTimer(seconds: 1); // يُخفي أشرطة التحكم تلقائياً بعد ثانية
  }

  @override
  void dispose() {
    // FLAG_SECURE cleared — Android only, skipped on web
    _readTimer?.cancel();
    _saveTimer?.cancel();
    _hideControlsTimer?.cancel();
    _scrollController.dispose();
    _pageController.dispose();
    _commentController.dispose();
    _ratingCommentController.dispose();
    _saveProgress();
    super.dispose();
  }

  // ── وضع القراءة الكاملة ───────────────────────────────────────────────────
  void _startHideTimer({int seconds = 1}) {
    _hideControlsTimer?.cancel();
    _hideControlsTimer = Timer(Duration(seconds: seconds), () {
      if (mounted) setState(() => _showControls = false);
    });
  }

  void _toggleControls() {
    _hideControlsTimer?.cancel();
    setState(() => _showControls = !_showControls);
    if (_showControls) _startHideTimer(seconds: 3);
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

  // #47 حفظ المحتوى للقراءة بدون إنترنت
  Future<void> _saveContentOffline() async {
    final content = widget.novel['content'] as String?;
    if (content == null || content.isEmpty || _chapterId.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('ch_$_chapterId', content);
    } catch (_) {}
  }

  // #47 تحميل من الكاش إذا كان المحتوى فارغاً (وضع بدون إنترنت)
  Future<void> _initOfflineContent() async {
    final content = widget.novel['content'] as String?;
    if (content != null && content.isNotEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString('ch_$_chapterId');
      if (cached != null && cached.isNotEmpty && mounted) {
        _contentCache[_chapterId] = cached;
        setState(() => _isOfflineCached = true);
      }
    } catch (_) {}
  }

  // #8 تحميل حجم الخط العالمي + #1 نوع الخط من Firestore
  Future<void> _loadGlobalFontPref() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    final data = doc.data() as Map<String, dynamic>?;
    if (!mounted) return;
    setState(() {
      final pref = data?['preferredFontSize'];
      if (pref != null) _fontSize = (pref as num).toDouble().clamp(12.0, 30.0);
      final font = data?['preferredFont'] as String?;
      if (font != null) _fontFamily = font;
    });
  }

  // #8 حفظ حجم الخط + #1 نوع الخط عالمياً
  Future<void> _saveGlobalFontPref() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    await FirebaseFirestore.instance.collection('users').doc(user.uid)
        .set({'preferredFontSize': _fontSize, 'preferredFont': _fontFamily},
            SetOptions(merge: true));
  }

  // #1 تطبيق الخط المختار
  TextStyle _contentStyle() {
    final color = Colors.grey.shade300;
    switch (_fontFamily) {
      case 'Amiri':
        return GoogleFonts.amiri(fontSize: _fontSize, height: 2.0, color: color);
      case 'Tajawal':
        return GoogleFonts.tajawal(fontSize: _fontSize, height: 2.0, color: color);
      case 'Lateef':
        return GoogleFonts.lateef(fontSize: _fontSize + 2, height: 2.0, color: color);
      default:
        return GoogleFonts.cairo(fontSize: _fontSize, height: 2.0, color: color);
    }
  }

  // #1 اختيار الخط
  void _showFontPicker() {
    const fonts = ['Cairo', 'Amiri', 'Tajawal', 'Lateef'];
    showModalBottomSheet(
      context: context,
      backgroundColor: _surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('نوع الخط',
                style: GoogleFonts.cairo(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: _textPrimary)),
            const SizedBox(height: 14),
            ...fonts.map((f) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Radio<String>(
                    value: f,
                    groupValue: _fontFamily,
                    activeColor: _accent,
                    onChanged: (v) {
                      setState(() => _fontFamily = v!);
                      _saveGlobalFontPref();
                      Navigator.pop(ctx);
                    },
                  ),
                  title: Text('نموذج النص — $f',
                      style: f == 'Amiri'
                          ? GoogleFonts.amiri(fontSize: 16, color: _textPrimary)
                          : f == 'Tajawal'
                              ? GoogleFonts.tajawal(fontSize: 15, color: _textPrimary)
                              : f == 'Lateef'
                                  ? GoogleFonts.lateef(fontSize: 17, color: _textPrimary)
                                  : GoogleFonts.cairo(fontSize: 14, color: _textPrimary)),
                )),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // #9 تغيير خلفية القراءة
  void _showBgColorPicker() {
    final options = <String, Color>{
      'داكن':      const Color(0xFF0D0F14),
      'رمادي':     const Color(0xFF1A1C24),
      'بني دافئ':  const Color(0xFF1C1510),
      'أزرق ليلي': const Color(0xFF0D1117),
    };
    showModalBottomSheet(
      context: context,
      backgroundColor: _surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('لون خلفية القراءة',
                style: GoogleFonts.cairo(fontSize: 15, fontWeight: FontWeight.w700, color: _textPrimary)),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: options.entries.map((e) => GestureDetector(
                onTap: () {
                  setState(() => _readerBg = e.value);
                  Navigator.pop(ctx);
                },
                child: Column(children: [
                  Container(
                    width: 48, height: 48,
                    decoration: BoxDecoration(
                      color: e.value,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _readerBg == e.value ? _accent : _border,
                        width: _readerBg == e.value ? 2.5 : 1,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(e.key, style: GoogleFonts.cairo(fontSize: 11, color: _textSecondary)),
                ]),
              )).toList(),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _onScrollChanged() {
    if (!_scrollController.hasClients) return;
    final max = _scrollController.position.maxScrollExtent;
    if (max <= 0) return;
    final progress = (_scrollController.offset / max).clamp(0.0, 1.0);
    _savedPagePercent = progress;
    if ((progress - _scrollProgress).abs() > 0.005) {
      setState(() => _scrollProgress = progress);
    }
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
      // #21 تحديث وقت القراءة الأسبوعي
      final user = FirebaseAuth.instance.currentUser;
      if (user != null && _secondsRead > 0) {
        await FirebaseFirestore.instance.collection('users').doc(user.uid)
            .set({'weeklyReadingSeconds': FieldValue.increment(_secondsRead)},
                SetOptions(merge: true));
      }
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
    if (!prog.exists) {
      await _novelRef.update({'readers': FieldValue.increment(1)});
      // #35 إشعار الأصدقاء الذين يقرأون نفس الرواية
      if (!mounted) return;
      final provider = context.read<NovelsProvider>();
      final uDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final name = uDoc.data()?['displayName']?.toString() ?? 'قارئ';
      final title = widget.novel['title'] ?? '';
      provider.notifyFriendsReading(_novelId, title, name);
    }
    // #3 تسجيل الفصل ضمن الفصول المقروءة
    if (_chapterId.isNotEmpty) {
      await progressRef.set({
        'readChapterIds': FieldValue.arrayUnion([_chapterId]),
      }, SetOptions(merge: true));
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
              aId, nd?['title'] ?? '', name, _novelId);
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

    setState(() => _isPostingComment = true);

    // جلب اسم المستخدم وصورته
    final uDoc = await FirebaseFirestore.instance
        .collection('users').doc(user.uid).get();
    final uData = uDoc.data() as Map<String,dynamic>?;
    final name           = uData?['displayName'] ?? user.email ?? 'مجهول';
    final profilePicture = uData?['profilePicture'] ?? '';

    await _novelRef.collection('comments').add({
      'text':                 text,
      'authorId':             user.uid,
      'authorName':           name,
      'authorProfilePicture': profilePicture,
      'chapterId':            _chapterId,
      'replyToId':            replyToId,
      'replyToName':          replyToName,
      'createdAt':            FieldValue.serverTimestamp(),
      'reported':             false,
    });

    // إشعار صاحب الرد إذا كان هذا رداً
    if (replyToId != null && mounted) {
      await context.read<NovelsProvider>().notifyUserOfReply(
          replyToId, widget.novel['title'] ?? '', name, text, _novelId);
    }

    // إشعار الكاتب
    final nd  = (await _novelRef.get()).data() as Map<String,dynamic>?;
    final aId = nd?['authorId'] ?? '';
    if (aId.isNotEmpty && aId != user.uid && mounted) {
      await context.read<NovelsProvider>().notifyAuthorOfComment(
          aId, widget.novel['title'] ?? '', name, _novelId);
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
                    Text('تعليق',
                        style: GoogleFonts.cairo(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: _textPrimary)),
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
                    onPressed: (tempRating == 0 || charCount == 0)
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

    // #19 هل هذا أول تقييم للفصل؟
    final existingRatings = await _chapterRef.collection('ratings').get();
    final isFirstRater = existingRatings.docs.isEmpty;

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
      if (mounted) {
        await context.read<NovelsProvider>().notifyAuthorOfRating(
            authorId, nd?['title'] ?? '',
            widget.novel['chapterTitle'] ?? '', name, _novelId, _chapterId);
      }
    }

    // نقاط المُقيِّم (+2 إضافية لأول مقيّم)
    final earnedPts = isFirstRater ? 7 : 5;
    await FirebaseFirestore.instance
        .collection('users').doc(user.uid)
        .update({
      'points':             FieldValue.increment(earnedPts),
      'ratingsGiven':       FieldValue.increment(1),
      'lastActivity':       FieldValue.serverTimestamp(),
      'appliedIdlePeriods': 0,
    });
    // سجل النقاط #18
    await FirebaseFirestore.instance
        .collection('users').doc(user.uid)
        .collection('pointsHistory').add({
      'delta':     earnedPts,
      'reason':    isFirstRater ? 'تقييم فصل (أول مقيّم! +2 إضافية)' : 'تقييم فصل',
      'createdAt': FieldValue.serverTimestamp(),
    });

    // متوسط تقييم الرواية
    final allChapters = await _novelRef.collection('chapters').get();
    if (allChapters.docs.isNotEmpty) {
      final novelAvg = allChapters.docs.fold<double>(
              0, (s, d) => s + ((d.data()['rating'] ?? 0.0) as num).toDouble()) /
          allChapters.docs.length;
      final newRating = double.parse(novelAvg.toStringAsFixed(1));
      await _novelRef.update({'rating': newRating});

      // #39 إشعار المؤلف إذا دخلت الرواية قائمة أعلى 10 تقييماً
      if (newRating >= 4.0 && authorId.isNotEmpty) {
        final topSnap = await FirebaseFirestore.instance
            .collection('novels')
            .orderBy('rating', descending: true)
            .limit(10)
            .get();
        final topIds = topSnap.docs.map((d) => d.id).toList();
        if (topIds.contains(_novelId)) {
          final nd = (await _novelRef.get()).data() as Map<String,dynamic>?;
          final rank = topIds.indexOf(_novelId) + 1;
          await FirebaseFirestore.instance.collection('notifications').add({
            'userId':    authorId,
            'type':      'top_rated',
            'message':   'روايتك "${nd?['title'] ?? ''}" دخلت قائمة أعلى $rank رواية تقييماً! 🏆',
            'novelId':   _novelId,
            'isRead':    false,
            'createdAt': FieldValue.serverTimestamp(),
          });
        }
      }
    }

    if (mounted) {
      setState(() {
        _userRating       = rating;
        _hasRated         = true;
        _isRatingLoading  = false;
      });
      _showSnack('شكراً على تقييمك! +5 نقاط ⭐', _gold);
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

              // ── قائمة التعليقات ──────────────────────────────────────
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('novels')
                      .doc(_novelId)
                      .collection('comments')
                      .orderBy('createdAt', descending: false)
                      .limit(_commentsLimit) // #28
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
                      itemCount: roots.length + 1, // +1 لزر "تحميل المزيد"
                      itemBuilder: (_, i) {
                        if (i == roots.length) {
                          if (allDocs.length < _commentsLimit) return const SizedBox.shrink();
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: TextButton(
                              onPressed: () => setState(() => _commentsLimit += 20),
                              child: Text('تحميل المزيد',
                                  style: GoogleFonts.cairo(color: _accent, fontSize: 13)),
                            ),
                          );
                        }
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
                            // #14 الردود مع خط رابط بصري
                            if (replies.isNotEmpty)
                              Container(
                                margin: const EdgeInsets.only(right: 18),
                                padding: const EdgeInsets.only(right: 14),
                                decoration: BoxDecoration(
                                  border: Border(
                                    right: BorderSide(
                                      color: _accent.withValues(alpha: 0.35),
                                      width: 2,
                                    ),
                                  ),
                                ),
                                child: Column(
                                  children: replies.map((r) {
                                    return _buildCommentBubble(
                                      ctx: ctx,
                                      docId: r.id,
                                      data:  r.data() as Map<String, dynamic>,
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
                    if (replyToName != null)
                      Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(color: _accent.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                        child: Row(children: [
                          const Icon(Icons.reply, size: 14, color: _accent),
                          const SizedBox(width: 8),
                          Expanded(child: Text('الرد على $replyToName', style: GoogleFonts.cairo(fontSize: 12, color: _accent))),
                          GestureDetector(
                            onTap: () => setS(() { replyToId = null; replyToName = null; }),
                            child: const Icon(Icons.close, size: 14, color: _textSecondary),
                          )
                        ]),
                      ),
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
          // الأفاتار — قابل للنقر للانتقال لصفحة الكاتب
          GestureDetector(
            onTap: authorId.isNotEmpty && !isOwn
                ? () => Navigator.push(ctx, MaterialPageRoute(
                    builder: (_) => AuthorScreen(authorId: authorId, authorName: name)))
                : null,
            child: Builder(builder: (_) {
              final pic = (data['authorProfilePicture'] as String?) ?? '';
              if (pic.isNotEmpty) {
                return CircleAvatar(
                  radius: isReply ? 14 : 18,
                  backgroundImage: NetworkImage(pic),
                  backgroundColor: _accent.withValues(alpha: 0.15),
                );
              }
              return CircleAvatar(
                radius: isReply ? 14 : 18,
                backgroundColor: _accent.withValues(alpha: 0.15),
                child: Text(
                  name.isNotEmpty ? name[0].toUpperCase() : '؟',
                  style: GoogleFonts.cairo(
                      fontWeight: FontWeight.w700,
                      color: _accent,
                      fontSize: isReply ? 11 : 13),
                ),
              );
            }),
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
                        ? _accent.withValues(alpha: 0.08)
                        : _surfaceHigh,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: isOwn
                            ? _accent.withValues(alpha: 0.2)
                            : _border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      GestureDetector(
                        onTap: authorId.isNotEmpty && !isOwn
                            ? () => Navigator.push(ctx, MaterialPageRoute(
                                builder: (_) => AuthorScreen(authorId: authorId, authorName: name)))
                            : null,
                        child: Text(name,
                            style: GoogleFonts.cairo(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: _accent,
                                decoration: authorId.isNotEmpty && !isOwn ? TextDecoration.underline : null,
                                decorationColor: _accent)),
                      ),
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
                // #32 إعجاب + رد + بلاغ
                Row(children: [
                  if (onReply != null)
                    GestureDetector(
                      onTap: onReply,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 4, left: 6),
                        child: Text('رد', style: GoogleFonts.cairo(fontSize: 11, color: _textSecondary)),
                      ),
                    ),
                  const SizedBox(width: 8),
                  // زر الإعجاب بالتعليق
                  GestureDetector(
                    onTap: () async {
                      final uid = FirebaseAuth.instance.currentUser?.uid;
                      if (uid == null) return;
                      final ref = _novelRef.collection('comments').doc(docId);
                      final likedBy = List<String>.from(data['likedBy'] ?? []);
                      if (likedBy.contains(uid)) {
                        await ref.update({
                          'likes': FieldValue.increment(-1),
                          'likedBy': FieldValue.arrayRemove([uid]),
                        });
                      } else {
                        await ref.update({
                          'likes': FieldValue.increment(1),
                          'likedBy': FieldValue.arrayUnion([uid]),
                        });
                      }
                    },
                    child: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(
                          (List<String>.from(data['likedBy'] ?? []))
                                  .contains(FirebaseAuth.instance.currentUser?.uid)
                              ? Icons.favorite_rounded
                              : Icons.favorite_outline_rounded,
                          size: 13,
                          color: Colors.redAccent,
                        ),
                        const SizedBox(width: 3),
                        Text('${data['likes'] ?? 0}',
                            style: GoogleFonts.cairo(fontSize: 10, color: _textSecondary)),
                      ]),
                    ),
                  ),
                  const Spacer(),
                  if (isOwn)
                    GestureDetector(
                      onTap: () => _deleteComment(docId),
                      child: Padding(
                        padding: const EdgeInsets.only(top: 4, left: 12),
                        child: Text('حذف', style: GoogleFonts.cairo(fontSize: 11, color: Colors.redAccent)),
                      ),
                    ),
                  GestureDetector(
                    onTap: () => _showReportCommentDialog(docId),
                    child: Padding(
                      padding: const EdgeInsets.only(top: 4, right: 4),
                      child: Text('بلاغ',
                          style: GoogleFonts.cairo(fontSize: 10, color: _textSecondary.withValues(alpha: 0.5))),
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



  void _showReportCommentDialog(String commentId) {
    String? selectedReason;
    const reasons = ['محتوى مسيء', 'سب/قذف', 'حرق أحداث', 'سرقة أدبية', 'أخرى'];
    showModalBottomSheet(
      context: context,
      backgroundColor: _surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('لماذا تبلغ عن هذا التعليق؟', style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: _textPrimary)),
              const SizedBox(height: 10),
              ...reasons.map((r) => RadioListTile<String>(
                title: Text(r, style: GoogleFonts.cairo(fontSize: 13, color: _textSecondary)),
                value: r,
                groupValue: selectedReason,
                onChanged: (v) => setS(() => selectedReason = v),
                activeColor: _accent,
              )),
              const SizedBox(height: 10),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, minimumSize: const Size(double.infinity, 45)),
                onPressed: selectedReason == null ? null : () async {
                  final user = FirebaseAuth.instance.currentUser;
                  Navigator.pop(ctx);
                  _showSnack('تم إرسال البلاغ فوراً ✅ سيتم مراجعته', Colors.green);
                  if (user != null) {
                    // احصل على صاحب التعليق
                    final commentDoc = await FirebaseFirestore.instance
                        .collection('novels').doc(_novelId)
                        .collection('comments').doc(commentId).get();
                    final commentData = commentDoc.data();
                    final reportedUid = commentData?['authorId'] as String?;

                    await FirebaseFirestore.instance.collection('reports').add({
                      'type': 'comment',
                      'commentId': commentId,
                      'novelId': _novelId,
                      'reason': selectedReason,
                      'reportedBy': user.uid,
                      'reportedUser': reportedUid,
                      'createdAt': FieldValue.serverTimestamp(),
                    });

                    // الحظر التلقائي محذوف: يجب أن يكون قرار الحظر من الأدمن فقط
                  }
                },
                child: Text('إرسال البلاغ', style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
              )
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _deleteComment(String commentId) async {
    await FirebaseFirestore.instance.collection('novels').doc(_novelId).collection('comments').doc(commentId).delete();
    _showSnack('تم حذف التعليق بنجاح', _textSecondary);
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
                              'type':        'chapter',
                              'novelId':     _novelId,
                              'chapterId':   _chapterId,
                              'reportedBy':  user.uid,
                              'reportedUser': widget.novel['authorId'] ?? '',
                              'reason':      selectedReason,
                              'details':     detailsCtrl.text.trim(),
                              'status':      'pending',
                              'createdAt':   FieldValue.serverTimestamp(),
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
    final content      = widget.novel['content'] ?? '';
    final chNum        = widget.novel['chapterNumber'] ?? '1';
    final currentUser  = FirebaseAuth.instance.currentUser;
    final authorId     = widget.novel['authorId'] ?? '';
    final isOwner      = currentUser?.uid == authorId;

    final words      = content.split(RegExp(r'\s+')).length;
    final totalPages = (words / 350).ceil().clamp(1, 9999);
    final curPage    = ((_scrollProgress * totalPages)).ceil().clamp(1, totalPages);

    final chaptersList = List<Map<String,dynamic>>.from(widget.novel['chaptersList'] ?? []);
    final curIdx = chaptersList.indexWhere((c) => c['id'] == _chapterId);

    return Scaffold(
      backgroundColor: _readerBg,
      extendBodyBehindAppBar: true,
      extendBody: true,
      // #2 زر العودة لأعلى — يختفي في وضع القراءة الكاملة
      floatingActionButton: (_showBackToTop && _showControls)
          ? FloatingActionButton.small(
              backgroundColor: _accent,
              foregroundColor: _bg,
              onPressed: () => _scrollController.animateTo(
                  0, duration: const Duration(milliseconds: 400), curve: Curves.easeOut),
              child: const Icon(Icons.arrow_upward_rounded, size: 18),
            )
          : null,
      body: GestureDetector(
        onTap: _toggleControls,
        behavior: HitTestBehavior.translucent,
        child: Stack(
          children: [
            // ── محتوى القراءة ──────────────────────────────────────────
            content.isEmpty
                ? Center(child: Text('لا يوجد محتوى لهذا الفصل.',
                    style: GoogleFonts.cairo(color: _textSecondary)))
                : _pagedMode
                    ? _buildPagedContent(content, chNum, isOwner)
                    : SingleChildScrollView(
                        controller: _scrollController,
                        padding: EdgeInsets.only(
                          left: 22, right: 22,
                          top: _showControls ? kToolbarHeight + 28 : 24,
                          bottom: 100,
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
                                    fontWeight: FontWeight.w700,
                                    color: _accent),
                              ),
                              if (_isOfflineCached)
                                Container(
                                  margin: const EdgeInsets.only(top: 4, bottom: 4),
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                                  ),
                                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                                    const Icon(Icons.wifi_off_rounded, size: 12, color: Colors.orange),
                                    const SizedBox(width: 5),
                                    Text('محتوى محفوظ مؤقتاً',
                                        style: GoogleFonts.cairo(fontSize: 10, color: Colors.orange)),
                                  ]),
                                ),
                              const SizedBox(height: 4),
                              if (_savedPagePercent > 0.02)
                                Container(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: _accent.withValues(alpha: 0.07),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: _accent.withValues(alpha: 0.2)),
                                  ),
                                  child: Text(
                                    'استُعيد موضع قراءتك عند ${(_savedPagePercent * 100).toInt()}٪',
                                    style: GoogleFonts.cairo(fontSize: 12, color: _accent),
                                  ),
                                ),
                              Text(
                                'بقلم: ${widget.novel['author'] ?? 'كاتب مجهول'}',
                                style: GoogleFonts.cairo(fontSize: 12, color: _textSecondary),
                              ),
                              Divider(height: 28, color: _border),
                              Text(content, style: _contentStyle()),
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
                              if (!isOwner) ...[
                                if (!_canRate)
                                  _buildReadProgress()
                                else if (!_hasRated)
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton.icon(
                                      onPressed: _isRatingLoading ? null : _showRatingSheet,
                                      icon: const Icon(Icons.star_rounded, color: Color(0xFF0D0F14)),
                                      label: Text('قيّم هذا الفصل',
                                          style: GoogleFonts.cairo(fontWeight: FontWeight.w700)),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: _gold,
                                        foregroundColor: const Color(0xFF0D0F14),
                                        padding: const EdgeInsets.symmetric(vertical: 14),
                                        elevation: 0,
                                        shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(12)),
                                      ),
                                    ),
                                  )
                                else
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.green.withValues(alpha: 0.08),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: Colors.green.withValues(alpha: 0.2)),
                                    ),
                                    child: Row(children: [
                                      const Icon(Icons.check_circle, color: Colors.green, size: 18),
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
                              _buildSimilarNovels(),
                              if (chaptersList.isNotEmpty && curIdx >= 0)
                                Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      if (curIdx > 0)
                                        OutlinedButton.icon(
                                          onPressed: () => _navigateToChapter(chaptersList[curIdx - 1]),
                                          icon: const Icon(Icons.chevron_right_rounded, size: 16),
                                          label: Text('السابق', style: GoogleFonts.cairo(fontSize: 12)),
                                          style: OutlinedButton.styleFrom(foregroundColor: _accent,
                                              side: BorderSide(color: _accent.withValues(alpha: 0.4))),
                                        )
                                      else const SizedBox.shrink(),
                                      if (curIdx < chaptersList.length - 1)
                                        OutlinedButton.icon(
                                          onPressed: () => _navigateToChapter(chaptersList[curIdx + 1]),
                                          icon: const Icon(Icons.chevron_left_rounded, size: 16),
                                          label: Text('التالي', style: GoogleFonts.cairo(fontSize: 12)),
                                          style: OutlinedButton.styleFrom(foregroundColor: _accent,
                                              side: BorderSide(color: _accent.withValues(alpha: 0.4))),
                                        )
                                      else const SizedBox.shrink(),
                                    ],
                                  ),
                                ),
                              const SizedBox(height: 80),
                            ],
                          ),
                        ),
                      ),

            // ── شريط أعلى (يختفي/يظهر) ────────────────────────────────
            AnimatedSlide(
              offset: _showControls ? Offset.zero : const Offset(0, -1),
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOut,
              child: IgnorePointer(
                ignoring: !_showControls,
                child: Container(
                  color: _readerBg.withValues(alpha: 0.95),
                  child: SafeArea(
                    bottom: false,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // شريط علوي مخصص بدلاً من AppBar لتجنب fontSize null
                        SizedBox(
                          height: kToolbarHeight,
                          child: Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.close_rounded, color: _textPrimary, size: 22),
                                onPressed: () => Navigator.pop(context),
                              ),
                              Expanded(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(widget.novel['title'] ?? '',
                                        style: GoogleFonts.cairo(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w700,
                                            color: _accent),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis),
                                    Text('الفصل $chNum  •  صفحة $curPage/$totalPages',
                                        style: GoogleFonts.cairo(
                                            fontSize: 11, color: _textSecondary)),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.text_decrease_rounded,
                                    color: _textSecondary, size: 20),
                                onPressed: () {
                                  if (_fontSize > 12) {
                                    setState(() => _fontSize -= 2);
                                    _saveGlobalFontPref();
                                  }
                                },
                              ),
                              IconButton(
                                icon: const Icon(Icons.text_increase_rounded,
                                    color: _textPrimary, size: 20),
                                onPressed: () {
                                  if (_fontSize < 30) {
                                    setState(() => _fontSize += 2);
                                    _saveGlobalFontPref();
                                  }
                                },
                              ),
                              PopupMenuButton<String>(
                                icon: const Icon(Icons.more_vert, color: _textSecondary, size: 22),
                                color: _surface,
                                onSelected: (v) {
                                  if (v == 'report') { _showReportDialog(); }
                                  if (v == 'bg')     { _showBgColorPicker(); }
                                  if (v == 'font')   { _showFontPicker(); }
                                  if (v == 'paged')  { setState(() { _pagedMode = !_pagedMode; _pageIndex = 0; }); }
                                },
                                itemBuilder: (_) => [
                                  PopupMenuItem(value: 'font', child: Row(children: [
                                    const Icon(Icons.font_download_outlined, color: _accent, size: 16),
                                    const SizedBox(width: 8),
                                    Text('نوع الخط', style: GoogleFonts.cairo(fontSize: 13, color: _textPrimary)),
                                  ])),
                                  PopupMenuItem(value: 'paged', child: Row(children: [
                                    Icon(_pagedMode ? Icons.view_stream_outlined : Icons.menu_book_outlined,
                                        color: _accent, size: 16),
                                    const SizedBox(width: 8),
                                    Text(_pagedMode ? 'تمرير عمودي' : 'تصفح بصفحات',
                                        style: GoogleFonts.cairo(fontSize: 13, color: _textPrimary)),
                                  ])),
                                  PopupMenuItem(value: 'bg', child: Row(children: [
                                    const Icon(Icons.palette_outlined, color: _accent, size: 16),
                                    const SizedBox(width: 8),
                                    Text('لون الخلفية', style: GoogleFonts.cairo(fontSize: 13, color: _textPrimary)),
                                  ])),
                                  PopupMenuItem(value: 'report', child: Row(children: [
                                    const Icon(Icons.flag_outlined, color: Colors.redAccent, size: 16),
                                    const SizedBox(width: 8),
                                    Text('تبليغ عن محتوى', style: GoogleFonts.cairo(fontSize: 13, color: _textPrimary)),
                                  ])),
                                ],
                              ),
                            ],
                          ),
                        ),
                        // #29 شريط تقدم القراءة
                        LinearProgressIndicator(
                          value: _scrollProgress,
                          backgroundColor: _border,
                          valueColor: AlwaysStoppedAnimation<Color>(_accent),
                          minHeight: 3,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // ── شريط أسفل (يختفي/يظهر) ────────────────────────────────
            Positioned(
              bottom: 0, left: 0, right: 0,
              child: AnimatedSlide(
                offset: _showControls ? Offset.zero : const Offset(0, 1),
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeInOut,
                child: IgnorePointer(
                  ignoring: !_showControls,
                  child: StreamBuilder<DocumentSnapshot>(
                    stream: _novelId.isEmpty ? null : _novelRef.snapshots(),
                    builder: (_, snap) {
                      final data = snap.hasData && snap.data!.exists
                          ? snap.data!.data() as Map<String, dynamic>
                          : <String, dynamic>{};
                      return Container(
                        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 24),
                        decoration: BoxDecoration(
                          color: const Color(0xFF13151C).withValues(alpha: 0.97),
                          border: const Border(top: BorderSide(color: _border)),
                        ),
                        child: SafeArea(
                          top: false,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              GestureDetector(
                                onTap: _isLikeLoading ? null : _toggleLike,
                                child: Row(children: [
                                  _isLikeLoading
                                      ? const SizedBox(width: 18, height: 18,
                                          child: CircularProgressIndicator(color: Colors.redAccent, strokeWidth: 2))
                                      : Icon(_isLiked ? Icons.favorite : Icons.favorite_border,
                                          size: 22, color: Colors.redAccent),
                                  const SizedBox(width: 6),
                                  Text('$_likesCount',
                                      style: GoogleFonts.cairo(fontSize: 13, color: _textSecondary)),
                                ]),
                              ),
                              GestureDetector(
                                onTap: _showCommentsSheet,
                                child: Row(children: [
                                  const Icon(Icons.chat_bubble_outline_rounded, size: 22, color: _accent),
                                  const SizedBox(width: 6),
                                  Text('تعليق', style: GoogleFonts.cairo(fontSize: 13, color: _accent)),
                                ]),
                              ),
                              Row(children: [
                                const Icon(Icons.remove_red_eye_outlined, size: 18, color: Colors.blueGrey),
                                const SizedBox(width: 4),
                                Text((data['readers'] ?? 0).toString(),
                                    style: GoogleFonts.cairo(fontSize: 13, color: _textSecondary)),
                              ]),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // #3 وضع التصفح بصفحات
  Widget _buildPagedContent(String content, int chNum, bool isOwner) {
    const wordsPerPage = 350;
    final words = content.split(RegExp(r'\s+'));
    final pages = <String>[];
    for (int i = 0; i < words.length; i += wordsPerPage) {
      pages.add(words.sublist(i, (i + wordsPerPage).clamp(0, words.length)).join(' '));
    }
    if (pages.isEmpty) pages.add(content);

    return Column(
      children: [
        Expanded(
          child: PageView.builder(
            controller: _pageController,
            onPageChanged: (i) {
              setState(() {
                _pageIndex  = i;
                _scrollProgress = (i + 1) / pages.length;
              });
            },
            itemCount: pages.length + 1,
            itemBuilder: (_, i) {
              if (i == pages.length) {
                // صفحة النهاية
                return Directionality(
                  textDirection: TextDirection.rtl,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: Text('— نهاية الفصل $chNum —',
                              style: GoogleFonts.cairo(
                                  fontSize: 14,
                                  color: _textSecondary,
                                  fontStyle: FontStyle.italic)),
                        ),
                        const SizedBox(height: 24),
                        if (!isOwner) ...[
                          if (!_canRate) _buildReadProgress()
                          else if (!_hasRated)
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: _isRatingLoading ? null : _showRatingSheet,
                                icon: const Icon(Icons.star_rounded, color: Color(0xFF0D0F14)),
                                label: Text('قيّم هذا الفصل',
                                    style: GoogleFonts.cairo(fontWeight: FontWeight.w700)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _gold,
                                  foregroundColor: const Color(0xFF0D0F14),
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                              ),
                            ),
                        ],
                        _buildSimilarNovels(),
                      ],
                    ),
                  ),
                );
              }
              return Directionality(
                textDirection: TextDirection.rtl,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
                  child: Text(pages[i], style: _contentStyle()),
                ),
              );
            },
          ),
        ),
        // شريط التنقل بين الصفحات
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: _surface,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_right_rounded, color: _textSecondary),
                onPressed: _pageIndex > 0
                    ? () => _pageController.previousPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut)
                    : null,
              ),
              Text('${_pageIndex + 1} / ${pages.length + 1}',
                  style: GoogleFonts.cairo(fontSize: 13, color: _textSecondary)),
              IconButton(
                icon: const Icon(Icons.chevron_left_rounded, color: _textSecondary),
                onPressed: _pageIndex < pages.length
                    ? () => _pageController.nextPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut)
                    : null,
              ),
            ],
          ),
        ),
      ],
    );
  }

  // #4 التنقل بين الفصول
  void _navigateToChapter(Map<String, dynamic> chapter) {
    Navigator.pushReplacement(context, MaterialPageRoute(
      builder: (_) => NovelReaderScreen(novel: {
        ...widget.novel,
        'chapterId':    chapter['id']    ?? '',
        'chapterTitle': chapter['title'] ?? '',
        'content':      chapter['content'] ?? '',
        'chapterNumber': chapter['chapterNumber'] ?? 1,
        'chaptersList': widget.novel['chaptersList'] ?? [],
      }),
    ));
  }

  // #24 روايات مشابهة بنفس التصنيف
  Widget _buildSimilarNovels() {
    final category = (widget.novel['category'] ?? '') as String;
    if (category.isEmpty) return const SizedBox.shrink();
    return FutureBuilder<QuerySnapshot>(
      future: FirebaseFirestore.instance
          .collection('novels')
          .where('category', isEqualTo: category)
          .orderBy('rating', descending: true)
          .limit(7)
          .get(),
      builder: (_, snap) {
        if (!snap.hasData) return const SizedBox.shrink();
        final novels = snap.data!.docs
            .where((d) => d.id != _novelId)
            .take(5)
            .toList();
        if (novels.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Divider(height: 32, color: _border),
            Text('قد يعجبك أيضاً — $category',
                style: GoogleFonts.cairo(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: _textPrimary)),
            const SizedBox(height: 12),
            SizedBox(
              height: 148,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                reverse: true,
                itemCount: novels.length,
                itemBuilder: (_, i) {
                  final d     = novels[i].data() as Map<String, dynamic>;
                  final cover  = d['coverUrl'] as String?;
                  final title  = (d['title']      ?? '') as String;
                  final author = (d['authorName'] ?? '') as String;
                  return GestureDetector(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => NovelDetailScreen(novel: {
                          'id':       novels[i].id,
                          'title':    title,
                          'author':   author,
                          'coverUrl': cover,
                        }),
                      ),
                    ),
                    child: Container(
                      width: 82,
                      margin: const EdgeInsets.only(left: 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: cover != null && cover.isNotEmpty
                                ? Image.network(cover,
                                    width: 82, height: 106, fit: BoxFit.cover)
                                : Container(
                                    width: 82, height: 106,
                                    color: _surfaceHigh,
                                    child: const Icon(Icons.book_outlined,
                                        color: _textSecondary, size: 28)),
                          ),
                          const SizedBox(height: 4),
                          Text(title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.cairo(
                                  fontSize: 10, color: _textPrimary)),
                          Text(author,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.cairo(
                                  fontSize: 9, color: _textSecondary)),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildReadProgress() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _gold.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _gold.withValues(alpha: 0.2)),
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