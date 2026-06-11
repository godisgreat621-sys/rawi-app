import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:my_first_app/repositories/novel_repository.dart';
import '../../providers/novels_provider.dart';

class AddNovelScreen extends StatefulWidget {
  /// novelId و novelTitle → وضع فصل جديد لرواية موجودة
  final String? novelId;
  final String? novelTitle;
  final String? draftId;

  const AddNovelScreen({
    super.key,
    this.novelId,
    this.novelTitle,
    this.draftId,
  });

  @override
  State<AddNovelScreen> createState() => _AddNovelScreenState();
}

class _AddNovelScreenState extends State<AddNovelScreen> {
  final _novelTitleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _chapterTitleController = TextEditingController();
  final _contentController = TextEditingController();
  String _selectedCategory = 'عام';
  bool _isPublishing = false;
  bool _isSavingDraft = false;
  int _wordCount = 0;
  String? _currentDraftId;
  DateTime? _lastPublishedDate;
  Timer? _timer24h;

  // #12 آخر وقت حفظ تلقائي
  DateTime? _lastAutoSaveTime;
  // #13 وضع الكتابة بدون إلهاء
  bool _distractionFree = false;
  // #18 ملاحظة خاصة للكاتب
  final _noteController = TextEditingController();

  // ── ألوان المظهر الجديد ──────────────────────────────────────────────────
  Color _bg            = const Color(0xFF0D0F14);
  Color _surface       = const Color(0xFF161920);
  static const _accent        = Color(0xFFC4A87A);
  Color _border        = const Color(0xFF252836);
  Color _textPrimary   = const Color(0xFFECECEC);
  Color _textSecondary = const Color(0xFF6B7280);
  static const _gold          = Color(0xFFD4A843);

  Timer? _autosaveTimer;

  static const int _minWords = 500;
  static const int _maxWords = 5000;

  bool get _isNewNovel => widget.novelId == null;
  bool get _isDraftMode => widget.draftId != null;

  final List<String> _categories = [
    'عام',
    'فانتازيا',
    'رعب',
    'رومانسية',
    'غموض',
    'تاريخية',
    'خيال علمي',
  ];
  // #13 وضع "قريباً" — ينشر الرواية بدون فصول
  bool _isComingSoon = false;

  @override
  void initState() {
    super.initState();
    _currentDraftId = widget.draftId;
    _contentController.addListener(_updateWordCount);
    if (_currentDraftId != null) {
      _loadDraft();
    }
    _fetchLastPublished();
    _timer24h = Timer.periodic(const Duration(minutes: 1), (t) => setState(() {}));
    _startAutosave();
  }

  Future<void> _fetchLastPublished() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    if (doc.exists && doc.data()?['lastPublished'] != null) {
      setState(() => _lastPublishedDate = (doc.data()?['lastPublished'] as Timestamp).toDate());
    }
  }

  void _updateWordCount() {
    final text = _contentController.text.trim();
    setState(() {
      _wordCount = text.isEmpty ? 0 : text.split(RegExp(r'\s+')).length;
    });
  }

  @override
  void dispose() {
    _autosaveTimer?.cancel();
    _timer24h?.cancel();
    if (_contentController.text.isNotEmpty) {
      _saveDraft(silent: true);
    }

    _novelTitleController.dispose();
    _descriptionController.dispose();
    _chapterTitleController.dispose();
    _noteController.dispose(); // #18
    _contentController
      ..removeListener(_updateWordCount)
      ..dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // التحقق المحلي من الحقول
  // ─────────────────────────────────────────────────────────────────────────────
  String? _validateLocal() {
    if (_isNewNovel && _novelTitleController.text.trim().isEmpty) {
      return 'الرجاء إدخال عنوان الرواية';
    }
    // #13 في وضع "قريباً" لا نحتاج فصلاً
    if (_isComingSoon) return null;
    if (_chapterTitleController.text.trim().isEmpty) {
      return 'الرجاء إدخال عنوان الفصل';
    }
    if (_wordCount < _minWords) {
      return 'الفصل يحتاج $_minWords كلمة على الأقل (حالياً: $_wordCount)';
    }
    if (_wordCount > _maxWords) {
      return 'الفصل لا يتجاوز $_maxWords كلمة (حالياً: $_wordCount)';
    }
    return null;
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // التحقق من شروط النشر الذكية من قاعدة البيانات (للفصول الجديدة فقط)
  // ─────────────────────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> _checkPublishingRequirements() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null)
      return {'canPublish': false, 'reason': 'يجب تسجيل الدخول أولاً'};

    // الرواية الجديدة مع فصلها الأول معفية من شروط الانتظار والتقييم المسبق
    if (_isNewNovel) return {'canPublish': true};

    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    if (!userDoc.exists) return {'canPublish': true};

    final data = userDoc.data()!;
    final lastPublished = data['lastPublished'] as Timestamp?;
    
    if (lastPublished != null) {
      final diff = DateTime.now().difference(lastPublished.toDate());
      if (diff.inHours < 24) {
        final hoursLeft = 24 - diff.inHours;
        return {
          'canPublish': false,
          'reason': 'قيد الـ 24 ساعة: يرجى الانتظار $hoursLeft ساعة إضافية قبل نشر الفصل التالي.\n\nاستغل هذا الوقت في قراءة وتقييم أعمال زملائك لتطوير مهاراتك!',
        };
      }
    }

    return {'canPublish': true};
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // نشر
  // ─────────────────────────────────────────────────────────────────────────────
  Future<void> _saveDraft({bool silent = false}) async {
    final draftError = _validateDraft();
    if (draftError != null) {
      if (!silent) _showError(draftError);
      return;
    }
    if (!silent) setState(() => _isSavingDraft = true);

    try {
      final id = await NovelRepository.saveDraft(
        draftId: _currentDraftId,
        isNewNovel: _isNewNovel,
        novelId: widget.novelId,
        novelTitle: _novelTitleController.text.trim(),
        description: _descriptionController.text.trim(),
        category: _selectedCategory,
        chapterTitle: _chapterTitleController.text.trim(),
        chapterContent: _contentController.text.trim(),
        coverUrl: null,
        wordCount: _wordCount,
        privateNote: _noteController.text.trim(),
      );

      if (id != null) {
        _currentDraftId = id;
      }

      if (!mounted) return;
      if (!silent) setState(() => _isSavingDraft = false);

      if (!silent) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تم حفظ المسودة بنجاح.', style: GoogleFonts.cairo()),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) setState(() => _isSavingDraft = false);
      if (!silent && mounted) _showError('خطأ أثناء حفظ المسودة: ${e.toString().replaceFirst('Exception: ', '')}');
    }
  }

  String? _validateDraft() {
    if (_chapterTitleController.text.trim().isEmpty) {
      return 'الرجاء إدخال عنوان الفصل';
    }
    if (_isNewNovel && _novelTitleController.text.trim().isEmpty) {
      return 'الرجاء إدخال عنوان الرواية لحفظ المسودة';
    }
    return null;
  }

  Future<void> _loadDraft() async {
    final draftDoc = await FirebaseFirestore.instance
        .collection('drafts')
        .doc(widget.draftId)
        .get();
    if (!draftDoc.exists) return;
    final data = draftDoc.data()!;

    setState(() {
      _selectedCategory = data['category'] ?? _selectedCategory;
      _novelTitleController.text = data['novelTitle'] ?? '';
      _descriptionController.text = data['description'] ?? '';
      _chapterTitleController.text = data['chapterTitle'] ?? '';
      _contentController.text = data['chapterContent'] ?? '';
      _wordCount = (data['wordCount'] ?? 0) as int;
    });
  }

  void _startAutosave() {
    _autosaveTimer?.cancel();
    _autosaveTimer = Timer.periodic(const Duration(seconds: 20), (_) async {
      if (!mounted || _contentController.text.isEmpty) return;
      await _saveDraft(silent: true);
      if (mounted) setState(() => _lastAutoSaveTime = DateTime.now()); // #12
    });
  }

  Future<void> _publish() async {
    final localError = _validateLocal();
    if (localError != null) {
      _showError(localError);
      return;
    }

    setState(() => _isPublishing = true);
    final reqCheck = await _checkPublishingRequirements();
    if (!reqCheck['canPublish']) {
      setState(() => _isPublishing = false);
      _showError(reqCheck['reason']);
      return;
    }

    final provider = context.read<NovelsProvider>();
    String? error;

    if (_currentDraftId != null) {
      error = await provider.publishDraft(_currentDraftId!);
    } else if (_isNewNovel && _isComingSoon) {
      // #13 نشر رواية "قريباً" بدون فصل
      error = await provider.addNovel(
        title:          _novelTitleController.text.trim(),
        description:    _descriptionController.text.trim(),
        category:       _selectedCategory,
        chapterTitle:   '',
        chapterContent: '',
        wordCount:      0,
        coverUrl:       null,
        status:         'coming_soon',
      );
    } else if (_isNewNovel) {
      final isDup = await provider.isContentDuplicate(
        _contentController.text.trim(),
      );
      if (isDup) {
        setState(() => _isPublishing = false);
        _showError('محتوى الفصل مشابه جداً لفصل موجود على المنصة ❌');
        return;
      }
      error = await provider.addNovel(
        title: _novelTitleController.text.trim(),
        description: _descriptionController.text.trim(),
        category: _selectedCategory,
        chapterTitle: _chapterTitleController.text.trim(),
        chapterContent: _contentController.text.trim(),
        wordCount: _wordCount,
        coverUrl: null,
      );
    } else {
      error = await provider.addChapter(
        novelId: widget.novelId!,
        chapterTitle: _chapterTitleController.text.trim(),
        chapterContent: _contentController.text.trim(),
        wordCount: _wordCount,
      );
    }

    if (!mounted) return;
    setState(() => _isPublishing = false);

    if (error != null) {
      _showError(error);
    } else {
      if (mounted) Navigator.pop(context);
      // #17 إشعار برفع الغلاف بعد النشر
      if (_isNewNovel && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'تم نشر روايتك! يمكنك الآن رفع صورة الغلاف من صفحة الرواية 🖼️',
              style: GoogleFonts.cairo(),
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 5),
          ),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تم نشر الفصل الجديد! 🚀', style: GoogleFonts.cairo()),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: GoogleFonts.cairo()),
        backgroundColor: Colors.redAccent,
      ),
    );
  }

  Widget _buildPublishTimer() {
    if (_lastPublishedDate == null) return const SizedBox();
    final now = DateTime.now();
    final diff = now.difference(_lastPublishedDate!);
    if (diff.inHours >= 24) return const SizedBox();

    final remaining = const Duration(hours: 24) - diff;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: _gold.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10), border: Border.all(color: _gold.withValues(alpha: 0.3))),
      child: Row(
        children: [
          const Icon(Icons.timer_outlined, color: _gold, size: 18),
          const SizedBox(width: 10),
          Expanded(child: Text('الوقت المتبقي للنشر: ${remaining.inHours} ساعة و ${remaining.inMinutes % 60} دقيقة', style: GoogleFonts.cairo(fontSize: 12, color: _gold, fontWeight: FontWeight.bold))),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // عداد الكلمات الاحترافي (شريط تقدم بصرى متطور)
  // ─────────────────────────────────────────────────────────────────────────────
  Widget _wordCounterBar() {
    Color color;
    String label;
    if (_wordCount < _minWords) {
      color = Colors.orange;
      label = 'يحتاج ${_minWords - _wordCount} كلمة أخرى';
    } else if (_wordCount > _maxWords) {
      color = Colors.red;
      label = 'تجاوزت الحد المسموح';
    } else {
      color = _accent;
      label = 'ضمن الحد المسموح ✓';
    }

    final progress = (_wordCount / _maxWords).clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: GoogleFonts.cairo(fontSize: 11, color: color)),
            Text(
              '$_wordCount / $_maxWords',
              style: GoogleFonts.cairo(
                fontSize: 12,
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 5,
            backgroundColor: _border,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // مكون الحقل الموحد لمنع تكرار الأكواد
  // ─────────────────────────────────────────────────────────────────────────────
  Widget _field({
    required TextEditingController controller,
    required String hint,
    int? maxLines = 1,
    double fontSize = 14,
    bool bold = false,
    double lineHeight = 1.6,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: maxLines == null
          ? TextInputType.multiline
          : TextInputType.text,
      textDirection: TextDirection.rtl,
      textAlignVertical: TextAlignVertical.top,
      autocorrect: false,
      style: GoogleFonts.cairo(
        fontSize: fontSize,
        fontWeight: bold ? FontWeight.bold : FontWeight.normal,
        height: lineHeight,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.cairo(color: Colors.grey),
        border: InputBorder.none,
        floatingLabelBehavior: FloatingLabelBehavior.never,
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // كارت عرض شروط النشر
  // ─────────────────────────────────────────────────────────────────────────────
  Widget _conditionsCard() {
    final items = [
      (Icons.hourglass_top, 'الانتظار 24 ساعة بين الفصول'),
      (Icons.edit, 'الفصل بين 500 و5000 كلمة'),
    ];
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'شروط نشر الفصل:',
            style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 13, color: _textPrimary),
          ),
          const SizedBox(height: 8),
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: Row(
                children: [
                  if (item.$1 is IconData)
                    Icon(
                      item.$1 as IconData,
                      size: 16,
                      color: _accent,
                    )
                  else
                    Text(
                      item.$1.toString(),
                      style: const TextStyle(fontSize: 14),
                    ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      item.$2,
                      style: GoogleFonts.cairo(
                        fontSize: 12,
                        color: _textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Build
  // ─────────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    _bg           = const Color(0xFF0D0F14);
    _surface      = const Color(0xFF161920);
    _border       = const Color(0xFF252836);
    _textPrimary  = const Color(0xFFECECEC);
    _textSecondary= const Color(0xFF6B7280);
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        title: Text(
          _isNewNovel ? 'رواية جديدة' : 'فصل جديد — "${widget.novelTitle ?? _novelTitleController.text}"',
          style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 15, color: _textPrimary),
        ),
        actions: [
          // #13 زر وضع التركيز
          IconButton(
            icon: Icon(_distractionFree ? Icons.fullscreen_exit : Icons.fullscreen,
                color: _textSecondary, size: 20),
            tooltip: 'وضع التركيز',
            onPressed: () => setState(() => _distractionFree = !_distractionFree),
          ),
          TextButton(
            onPressed: _isSavingDraft ? null : _saveDraft,
            child: _isSavingDraft
                ? const SizedBox(width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: _accent))
                : Text('حفظ مسودة',
                    style: GoogleFonts.cairo(color: _accent, fontWeight: FontWeight.bold, fontSize: 14)),
          ),
          TextButton(
            onPressed: _isPublishing ? null : _publish,
            child: _isPublishing
                ? const SizedBox(width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: _gold))
                : Text('نشر',
                    style: GoogleFonts.cairo(color: _gold, fontWeight: FontWeight.w700, fontSize: 14)),
          ),
        ],
      ),
      // #13 وضع التركيز: إخفاء كل شيء ما عدا المحتوى
      body: _distractionFree
          ? _buildDistractionFreeMode()
          : SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildPublishTimer(),
            if (_isDraftMode)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _accent.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _accent.withValues(alpha: 0.2)),
                ),
                child: Text(
                  'تحرير مسودة محفوظة',
                  style: GoogleFonts.cairo(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: _accent,
                  ),
                ),
              ),

            // ── حقول الرواية الجديدة فقط ──
            if (_isNewNovel) ...[
              // #13 زر "قريباً"
              Row(children: [
                Switch(
                  value: _isComingSoon,
                  activeColor: _accent,
                  onChanged: (v) => setState(() => _isComingSoon = v),
                ),
                const SizedBox(width: 8),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('وضع "قريباً"',
                      style: GoogleFonts.cairo(fontSize: 13, color: _textPrimary, fontWeight: FontWeight.w600)),
                  Text('انشر الرواية الآن وأضف الفصل لاحقاً',
                      style: GoogleFonts.cairo(fontSize: 10, color: _textSecondary)),
                ]),
              ]),
              Divider(color: _border, height: 20),
              _field(
                controller: _novelTitleController,
                hint: 'عنوان الرواية...',
                fontSize: 22,
                bold: true,
              ),
              const SizedBox(height: 4),
              // #17 إشعار: الغلاف يُرفع بعد النشر
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: _accent.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _accent.withValues(alpha: 0.18)),
                ),
                child: Row(children: [
                  const Icon(Icons.info_outline, size: 14, color: _accent),
                  const SizedBox(width: 8),
                  Text('صورة الغلاف تُضاف من صفحة الرواية بعد النشر',
                      style: GoogleFonts.cairo(fontSize: 11, color: _accent)),
                ]),
              ),
              const Divider(height: 28),

              // التصنيفات الأفقية المميزة
              SizedBox(
                height: 38,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _categories.length,
                  itemBuilder: (_, i) {
                    final cat = _categories[i];
                    final sel = cat == _selectedCategory;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedCategory = cat),
                      child: Container(
                        margin: const EdgeInsets.only(left: 8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: sel ? _accent : _surface,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: sel ? _accent : _border,
                          ),
                        ),
                        child: Text(
                          cat,
                          style: GoogleFonts.cairo(fontSize: 12, color: sel ? _bg : _textSecondary, fontWeight: sel ? FontWeight.bold : FontWeight.normal),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),

              _field(
                controller: _descriptionController,
                hint: 'اكتب ملخصاً قصيراً لجذب القراء...',
                maxLines: 3,
              ),
              Divider(height: 28, color: _border),
            ],

            // ── عنوان الفصل ──
            _field(
              controller: _chapterTitleController,
              hint: _isNewNovel ? 'عنوان الفصل الأول...' : 'عنوان الفصل...',
              fontSize: 17,
              bold: true,
            ),
            Divider(height: 24, color: _border),

            // ── محتوى الفصل ──
            _field(
              controller: _contentController,
              hint: 'اكتب الفصل هنا...',
              maxLines: null,
              fontSize: 16,
              lineHeight: 1.9,
            ),

            const SizedBox(height: 20),
            _wordCounterBar(),
            const SizedBox(height: 12),

            // #12 مؤشر آخر حفظ تلقائي
            if (_lastAutoSaveTime != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(children: [
                  Icon(Icons.cloud_done_outlined, size: 13, color: _textSecondary),
                  const SizedBox(width: 4),
                  Text(
                    'آخر حفظ: ${_lastAutoSaveTime!.hour.toString().padLeft(2,'0')}:${_lastAutoSaveTime!.minute.toString().padLeft(2,'0')}',
                    style: GoogleFonts.cairo(fontSize: 10, color: _textSecondary),
                  ),
                ]),
              ),

            // #18 ملاحظة خاصة بالكاتب (لا تُنشر للقراء)
            Divider(height: 24, color: _border),
            Row(children: [
              Icon(Icons.lock_outline, size: 13, color: _textSecondary),
              const SizedBox(width: 6),
              Text('ملاحظة خاصة (لك فقط)',
                  style: GoogleFonts.cairo(fontSize: 11, color: _textSecondary)),
            ]),
            const SizedBox(height: 6),
            _field(
              controller: _noteController,
              hint: 'ملاحظاتك الخاصة عن هذا الفصل...',
              maxLines: 3,
              fontSize: 13,
            ),
            const SizedBox(height: 16),

            // ── بطاقة شروط النشر الإرشادية (تظهر للفصول فقط) ──
            if (!_isNewNovel) _conditionsCard(),

            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  // #13 وضع الكتابة بدون إلهاء
  Widget _buildDistractionFreeMode() {
    return SafeArea(
      child: Column(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: TextField(
                controller: _contentController,
                maxLines: null,
                expands: true,
                keyboardType: TextInputType.multiline,
                textAlignVertical: TextAlignVertical.top,
                autocorrect: false,
                style: GoogleFonts.cairo(
                    fontSize: 17, height: 2.0, color: _textPrimary),
                decoration: InputDecoration(
                  hintText: 'اكتب بحرية...',
                  hintStyle: GoogleFonts.cairo(color: _textSecondary),
                  border: InputBorder.none,
                  alignLabelWithHint: true,
                ),
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              color: _surface,
              border: Border(top: BorderSide(color: _border)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('$_wordCount كلمة',
                    style: GoogleFonts.cairo(
                        fontSize: 12, color: _textSecondary)),
                TextButton.icon(
                  onPressed: () => setState(() => _distractionFree = false),
                  icon: const Icon(Icons.fullscreen_exit, size: 16, color: _accent),
                  label: Text('خروج', style: GoogleFonts.cairo(color: _accent, fontSize: 12)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

