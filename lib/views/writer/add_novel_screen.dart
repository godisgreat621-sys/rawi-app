import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:my_first_app/repositories/user_repository.dart';
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
  String? _coverUrl;
  bool _isUploadingCover = false;

  String _selectedCategory = 'عام';
  bool _isPublishing = false;
  bool _isSavingDraft = false;
  int _wordCount = 0;
  String? _currentDraftId;

  // ── ألوان المظهر الجديد ──────────────────────────────────────────────────
  static const _bg            = Color(0xFF0D0F14);
  static const _surface       = Color(0xFF161920);
  static const _surfaceHigh   = Color(0xFF1E2130);
  static const _accent        = Color(0xFF8BAF7C);
  static const _border        = Color(0xFF252836);
  static const _textPrimary   = Color(0xFFECECEC);
  static const _textSecondary = Color(0xFF6B7280);
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

  @override
  void initState() {
    super.initState();
    _currentDraftId = widget.draftId;
    _contentController.addListener(_updateWordCount);
    if (_currentDraftId != null) {
      // If it's a draft, load its content
      _loadDraft();
    } else if (widget.novelId != null && widget.novelTitle == null) {
      // If it's a new chapter for an existing novel, but novelTitle wasn't passed, fetch it.
      // This happens when navigating from WriterScreen to add a chapter to an existing novel.
      _fetchNovelTitle(widget.novelId!).then((title) => setState(() => _novelTitleController.text = title ?? ''));
    }
    _startAutosave();
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
    if (_wordCount >= 30) {
      _saveDraft(silent: true);
    }

    _novelTitleController.dispose();
    _descriptionController.dispose();
    _chapterTitleController.dispose();
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
    if (_wordCount < 30) {
      if (!silent)
        _showError('يجب أن يحتوي الفصل على 30 كلمة على الأقل لحفظ المسودة');
      return;
    }
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
        coverUrl: _coverUrl,
        wordCount: _wordCount,
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
      if (mounted && !silent) setState(() => _isSavingDraft = false);
      if (!silent) _showError('خطأ أثناء حفظ المسودة. حاول لاحقاً.');
    }
  }

  String? _validateDraft() {
    if (_chapterTitleController.text.trim().isEmpty) {
      return 'الرجاء إدخال عنوان الفصل';
    }
    if (_isNewNovel && _novelTitleController.text.trim().isEmpty) {
      return 'الرجاء إدخال عنوان الرواية لحفظ المسودة';
    }
    if (_wordCount < 30) {
      return 'يجب أن يحتوي الفصل على 30 كلمة على الأقل لحفظ المسودة';
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
      if (!mounted) return;
      if (_wordCount >= 30) {
        await _saveDraft(silent: true);
      }
    });
  }

  // Fetch novel title if it's a chapter draft and title isn't provided
  Future<String?> _fetchNovelTitle(String novelId) async {
    try {
      final doc = await FirebaseFirestore.instance.collection('novels').doc(novelId).get();
      return doc.data()?['title'] as String?;
    } catch (e) {
      return null;
    }
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
        coverUrl: _coverUrl,
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isNewNovel
                ? 'تم نشر روايتك والفصل الأول! 🚀'
                : 'تم نشر الفصل الجديد! 🚀',
            style: GoogleFonts.cairo(),
          ),
          backgroundColor: Colors.green,
        ),
      );
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
  // Build
  // ─────────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        title: Text(
          _isNewNovel ? 'رواية جديدة 🖋️' : 'فصل جديد — "${widget.novelTitle ?? _novelTitleController.text}"',
          style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 15, color: _textPrimary),
        ),
        actions: [
          TextButton(
            onPressed: _isSavingDraft ? null : _saveDraft,
            child: _isSavingDraft
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: _accent),
                  )
                : Text(
                    'حفظ مسودة',
                    style: GoogleFonts.cairo(
                      color: _accent,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
          ),
          TextButton(
            onPressed: _isPublishing ? null : _publish,
            child: _isPublishing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: _gold),
                  )
                : Text(
                    'نشر 🚀',
                    style: GoogleFonts.cairo(
                      color: _gold,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_isDraftMode)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _accent.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _accent.withOpacity(0.2)),
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
              _field(
                controller: _novelTitleController,
                hint: 'عنوان الرواية...',
                fontSize: 22,
                bold: true,
              ),
              const SizedBox(height: 12),
              // اختيار غلاف الرواية
              GestureDetector(
                onTap: _isUploadingCover ? null : () async {
                  setState(() => _isUploadingCover = true);
                  final url = await UserRepository.pickAndUploadImage('novel_covers');
                  setState(() {
                    _coverUrl = url;
                    _isUploadingCover = false;
                  });
                },
                child: Container(
                  height: 150,
                  width: 100,
                  decoration: BoxDecoration(
                    color: _surfaceHigh,
                    borderRadius: BorderRadius.circular(12),
                    image: _coverUrl != null 
                      ? DecorationImage(image: NetworkImage(_coverUrl!), fit: BoxFit.cover)
                      : null,
                  ),
                  child: _isUploadingCover 
                    ? const Center(child: CircularProgressIndicator(color: _accent))
                    : _coverUrl == null 
                      ? Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.add_photo_alternate_outlined, color: _textSecondary),
                            Text('غلاف', style: GoogleFonts.cairo(fontSize: 10, color: _textSecondary)),
                          ],
                        )
                      : null,
                ),
              ),
              if (_coverUrl != null) 
                TextButton(
                  onPressed: () => setState(() => _coverUrl = null),
                  child: Text('حذف الغلاف', style: GoogleFonts.cairo(color: Colors.redAccent, fontSize: 12)),
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
              const Divider(height: 28, color: _border),
            ],

            // ── عنوان الفصل ──
            _field(
              controller: _chapterTitleController,
              hint: _isNewNovel ? 'عنوان الفصل الأول...' : 'عنوان الفصل...',
              fontSize: 17,
              bold: true,
            ),
            const Divider(height: 24, color: _border),

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
            const SizedBox(height: 20),

            // ── بطاقة شروط النشر الإرشادية (تظهر للفصول فقط) ──
            if (!_isNewNovel) _conditionsCard(),

            const SizedBox(height: 80),
          ],
        ),
      ),
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
      style: GoogleFonts.cairo(
        fontSize: fontSize,
        fontWeight: bold ? FontWeight.bold : FontWeight.normal,
        height: lineHeight,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.cairo(color: Colors.grey),
        border: InputBorder.none,
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // كارت عرض شروط النشر
  // ─────────────────────────────────────────────────────────────────────────────
  Widget _conditionsCard() {
    final items = [
      (Icons.hourglass_top, 'انتظار 24 ساعة (3 نقاط)'),
      (Icons.auto_stories, 'تقييم 3 فصول لكتّاب آخرين (3 نقاط)'),
      (Icons.star, 'الحصول على 3 تقييمات لفصلك السابق (4 نقاط)'),
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
}
