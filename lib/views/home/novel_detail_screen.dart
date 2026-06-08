import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:my_first_app/providers/novels_provider.dart';
import 'package:my_first_app/views/home/novel_reader_screen.dart';
import 'package:my_first_app/views/writer/add_novel_screen.dart';
import 'package:my_first_app/views/author_screen.dart';
import 'package:my_first_app/repositories/user_repository.dart';

class NovelDetailScreen extends StatefulWidget {
  final Map<String, dynamic> novel;
  const NovelDetailScreen({super.key, required this.novel});

  @override
  State<NovelDetailScreen> createState() => _NovelDetailScreenState();
}

class _NovelDetailScreenState extends State<NovelDetailScreen> {
  // ── ألوان ─────────────────────────────────────────────────────────────────
  static const _bg           = Color(0xFF0D0F14);
  static const _surface      = Color(0xFF161920);
  static const _surfaceHigh  = Color(0xFF1E2130);
  static const _accent       = Color(0xFFC4A87A);
  static const _border       = Color(0xFF252836);
  static const _textPrimary  = Color(0xFFECECEC);
  static const _textSecondary= Color(0xFF6B7280);
  static const _gold         = Color(0xFFD4A843);

  bool _isFollowing        = false;
  bool _isFollowLoading    = false;
  bool _isFollowingNovel   = false;
  Set<String> _readChapterIds = {};
  // #17 رفع غلاف الرواية بعد النشر
  bool _isUploadingCover   = false;

  // ── ألوان الغلاف بحسب التصنيف ──────────────────────────────────────────────
  static const _categoryColors = <String, Color>{
    'فانتازيا':  Color(0xFF2D1F4E),
    'رومانسية':  Color(0xFF4E1F2D),
    'رعب':       Color(0xFF1F2D20),
    'غموض':      Color(0xFF1F2A4E),
    'تاريخية':   Color(0xFF4E3A1F),
    'خيال علمي': Color(0xFF1F3A4E),
    'عام':       Color(0xFF252836),
  };

  @override
  void initState() {
    super.initState();
    _checkIfFollowing();
    _checkIfFollowingNovel();
    _loadReadChapterIds();
    _trackPresence(); // #33
  }

  @override
  void dispose() {
    _removePresence(); // #33
    super.dispose();
  }

  Future<void> _checkIfFollowing() async {
    final user     = FirebaseAuth.instance.currentUser;
    final authorId = widget.novel['authorId'];
    if (user == null || authorId == null || authorId.isEmpty) return;
    final doc = await FirebaseFirestore.instance
        .collection('users').doc(user.uid)
        .collection('following').doc(authorId).get();
    if (mounted) setState(() => _isFollowing = doc.exists);
  }

  Future<void> _checkIfFollowingNovel() async {
    final user    = FirebaseAuth.instance.currentUser;
    final novelId = widget.novel['id'] ?? '';
    if (user == null || novelId.isEmpty) return;
    final doc = await FirebaseFirestore.instance
        .collection('users').doc(user.uid)
        .collection('followedNovels').doc(novelId).get();
    if (mounted) setState(() => _isFollowingNovel = doc.exists);
  }

  Future<void> _toggleFollowNovel() async {
    final user    = FirebaseAuth.instance.currentUser;
    final novelId = widget.novel['id'] ?? '';
    if (user == null || novelId.isEmpty) return;
    final ref = FirebaseFirestore.instance
        .collection('users').doc(user.uid)
        .collection('followedNovels').doc(novelId);
    // #30 مرجع عكسي: novels/{id}/followers/{uid}
    final novelFollowerRef = FirebaseFirestore.instance
        .collection('novels').doc(novelId)
        .collection('followers').doc(user.uid);
    if (_isFollowingNovel) {
      await ref.delete();
      await novelFollowerRef.delete();
    } else {
      await ref.set({'novelId': novelId, 'followedAt': FieldValue.serverTimestamp()});
      await novelFollowerRef.set({'followedAt': FieldValue.serverTimestamp()});
    }
    if (mounted) setState(() => _isFollowingNovel = !_isFollowingNovel);
  }

  Future<void> _loadReadChapterIds() async {
    final user    = FirebaseAuth.instance.currentUser;
    final novelId = widget.novel['id'] ?? '';
    if (user == null || novelId.isEmpty) return;
    final doc = await FirebaseFirestore.instance
        .collection('users').doc(user.uid)
        .collection('readingProgress').doc(novelId).get();
    if (mounted && doc.exists) {
      final ids = List<String>.from(
          (doc.data() as Map<String,dynamic>?)?['readChapterIds'] ?? []);
      setState(() => _readChapterIds = ids.toSet());
    }
  }

  void _shareNovel(String title, String novelId) {
    final text = '📖 "$title"\n\nاقرأها الآن على راوي 🌙\nhttps://rawi-app.vercel.app';
    Share.share(text, subject: title);
  }

  void _showReadingListsSheet(String novelId, String novelTitle) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final predefined = ['أريد القراءة', 'أقرأ الآن', 'المفضلة', 'مكتملة'];
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
            Text('أضف إلى قائمة',
                style: GoogleFonts.cairo(
                    fontSize: 16, fontWeight: FontWeight.w700, color: _textPrimary)),
            const SizedBox(height: 14),
            ...predefined.map((listName) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.playlist_add_rounded, color: _accent),
              title: Text(listName,
                  style: GoogleFonts.cairo(color: _textPrimary, fontSize: 14)),
              onTap: () async {
                final listRef = FirebaseFirestore.instance
                    .collection('users').doc(user.uid)
                    .collection('readingLists').doc(listName);
                await listRef.set({
                  'name': listName,
                  'novelIds': FieldValue.arrayUnion([novelId]),
                  'updatedAt': FieldValue.serverTimestamp(),
                }, SetOptions(merge: true));
                if (ctx.mounted) Navigator.pop(ctx);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text('أُضيف إلى "$listName" ✓', style: GoogleFonts.cairo()),
                    backgroundColor: _accent,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ));
                }
              },
            )),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleFollow() async {
    final user     = FirebaseAuth.instance.currentUser;
    final authorId = widget.novel['authorId'];
    if (user == null || authorId == null || authorId.isEmpty) return;
    if (user.uid == authorId) return;
    setState(() => _isFollowLoading = true);

    await context.read<NovelsProvider>().toggleFollow(authorId);
    
    if (mounted) setState(() {
      _isFollowing = !_isFollowing;
      _isFollowLoading = false;
    });
  }

  // #33 تتبع وجود المستخدم في صفحة الرواية (القراء الحاليون)
  Future<void> _trackPresence() async {
    final user = FirebaseAuth.instance.currentUser;
    final novelId = widget.novel['id'] ?? '';
    if (user == null || novelId.isEmpty) return;
    await FirebaseFirestore.instance
        .collection('novels').doc(novelId)
        .collection('presences').doc(user.uid)
        .set({'lastSeen': FieldValue.serverTimestamp()});
  }

  Future<void> _removePresence() async {
    final user = FirebaseAuth.instance.currentUser;
    final novelId = widget.novel['id'] ?? '';
    if (user == null || novelId.isEmpty) return;
    await FirebaseFirestore.instance
        .collection('novels').doc(novelId)
        .collection('presences').doc(user.uid)
        .delete();
  }

  // #35 إرسال هدية نقاط للكاتب
  Future<void> _sendGift(String authorId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.uid == authorId) return;
    final senderDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    final senderPts = (senderDoc.data()?['points'] as num?)?.toInt() ?? 0;
    if (senderPts < 5) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('رصيدك أقل من 5 نقاط', style: GoogleFonts.cairo()),
        backgroundColor: Colors.redAccent,
      ));
      return;
    }
    final batch = FirebaseFirestore.instance.batch();
    final senderRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
    final authorRef = FirebaseFirestore.instance.collection('users').doc(authorId);
    batch.update(senderRef, {'points': FieldValue.increment(-5)});
    batch.update(authorRef, {'points': FieldValue.increment(5)});
    await batch.commit();
    // سجل النقاط
    await senderRef.collection('pointsHistory').add({
      'delta': -5, 'reason': 'هدية للكاتب', 'createdAt': FieldValue.serverTimestamp()});
    await authorRef.collection('pointsHistory').add({
      'delta': 5, 'reason': 'هدية من قارئ', 'createdAt': FieldValue.serverTimestamp()});
    // إشعار للكاتب
    await FirebaseFirestore.instance.collection('notifications').add({
      'userId': authorId, 'type': 'gift',
      'message': 'أرسل لك أحد القراء هدية 5 نقاط!',
      'isRead': false, 'createdAt': FieldValue.serverTimestamp(),
    });
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('تم إرسال الهدية ✅', style: GoogleFonts.cairo()),
      backgroundColor: Colors.green,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  // #23 إرسال الرواية لصديق كإشعار
  void _sendToFriend(String novelId, String novelTitle) {
    final searchCtrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: _surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) {
          List<Map<String, dynamic>> results = [];
          Future<void> search(String q) async {
            if (q.trim().isEmpty) { setS(() => results = []); return; }
            final snap = await FirebaseFirestore.instance
                .collection('users')
                .where('displayName', isGreaterThanOrEqualTo: q.trim())
                .where('displayName', isLessThanOrEqualTo: '${q.trim()}')
                .limit(8).get();
            setS(() => results = snap.docs
                .map((d) => {'uid': d.id, ...d.data()})
                .toList());
          }

          return Padding(
            padding: EdgeInsets.only(
                left: 20, right: 20, top: 20,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 20),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text('أرسل لصديق',
                  style: GoogleFonts.cairo(fontSize: 15,
                      fontWeight: FontWeight.w700, color: _textPrimary)),
              const SizedBox(height: 12),
              TextField(
                controller: searchCtrl,
                onChanged: search,
                style: GoogleFonts.cairo(fontSize: 13, color: _textPrimary),
                decoration: InputDecoration(
                  hintText: 'ابحث باسم المستخدم...',
                  hintStyle: GoogleFonts.cairo(color: _textSecondary, fontSize: 12),
                  prefixIcon: const Icon(Icons.search, color: _textSecondary, size: 18),
                  filled: true, fillColor: _surfaceHigh,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 10),
              ...results.map((r) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  radius: 18,
                  backgroundColor: _surfaceHigh,
                  backgroundImage: ((r['profilePicture'] as String?) != null && (r['profilePicture'] as String).isNotEmpty)
                      ? NetworkImage(r['profilePicture']) as ImageProvider
                      : const AssetImage('logo.png'),
                  child: null,
                ),
                title: Text(r['displayName'] ?? '',
                    style: GoogleFonts.cairo(fontSize: 13, color: _textPrimary)),
                trailing: IconButton(
                  icon: const Icon(Icons.send_rounded, color: _accent, size: 18),
                  onPressed: () async {
                    await FirebaseFirestore.instance
                        .collection('notifications').add({
                      'userId':    r['uid'],
                      'type':      'friend_recommendation',
                      'message':   '${FirebaseAuth.instance.currentUser?.displayName ?? 'مستخدم'} رشّح لك رواية "$novelTitle" 📖',
                      'novelId':   novelId,
                      'isRead':    false,
                      'createdAt': FieldValue.serverTimestamp(),
                    });
                    if (ctx.mounted) Navigator.pop(ctx);
                    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text('تم إرسال الترشيح ✅',
                          style: GoogleFonts.cairo()),
                      backgroundColor: Colors.green,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ));
                  },
                ),
              )),
            ]),
          );
        },
      ),
    );
  }

  // #22 مراجعة نقدية طويلة
  void _showLongReviewSheet(String novelId, String novelTitle) {
    final ctrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: _surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
            left: 20, right: 20, top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('مراجعة نقدية — $novelTitle',
              style: GoogleFonts.cairo(fontSize: 15, fontWeight: FontWeight.w700, color: _textPrimary)),
          const SizedBox(height: 4),
          Text('مراجعتك ستظهر في صفحة الرواية للجميع',
              style: GoogleFonts.cairo(fontSize: 11, color: _textSecondary)),
          const SizedBox(height: 14),
          TextField(
            controller: ctrl,
            maxLines: 6,
            maxLength: 1000,
            textDirection: TextDirection.rtl,
            textAlignVertical: TextAlignVertical.top,
            autocorrect: false,
            style: GoogleFonts.cairo(fontSize: 13, color: _textPrimary),
            decoration: InputDecoration(
              hintText: 'اكتب مراجعتك التفصيلية هنا...',
              hintStyle: GoogleFonts.cairo(color: _textSecondary, fontSize: 12),
              filled: true,
              fillColor: _surfaceHigh,
              alignLabelWithHint: true,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () async {
                final user = FirebaseAuth.instance.currentUser;
                final text = ctrl.text.trim();
                if (user == null || text.isEmpty) return;
                await FirebaseFirestore.instance
                    .collection('novels').doc(novelId)
                    .collection('reviews').doc(user.uid).set({
                  'text':      text,
                  'authorId':  user.uid,
                  'createdAt': FieldValue.serverTimestamp(),
                });
                if (ctx.mounted) { Navigator.pop(ctx); }
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text('تم نشر مراجعتك ✅', style: GoogleFonts.cairo()),
                    backgroundColor: Colors.green,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ));
                }
              },
              style: ElevatedButton.styleFrom(
                  backgroundColor: _accent, foregroundColor: _bg,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              child: Text('نشر المراجعة', style: GoogleFonts.cairo(fontWeight: FontWeight.w700)),
            ),
          ),
        ]),
      ),
    );
  }

  // #12 مقتطف مميز + #14 إجازة — للكاتب من شيت التعديل
  void _showExcerptSheet(String novelId, String currentExcerpt) {
    final ctrl = TextEditingController(text: currentExcerpt);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: _surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
            left: 20, right: 20, top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('مقتطف مميز',
              style: GoogleFonts.cairo(fontSize: 15, fontWeight: FontWeight.w700, color: _textPrimary)),
          const SizedBox(height: 12),
          TextField(
            controller: ctrl, maxLines: 4, maxLength: 300,
            textDirection: TextDirection.rtl,
            textAlignVertical: TextAlignVertical.top,
            autocorrect: false,
            style: GoogleFonts.cairo(fontSize: 13, color: _textPrimary),
            decoration: InputDecoration(
              hintText: 'اختر جملة مميزة من روايتك لتظهر للقراء...',
              hintStyle: GoogleFonts.cairo(color: _textSecondary, fontSize: 12),
              filled: true, fillColor: _surfaceHigh,
              alignLabelWithHint: true,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(width: double.infinity,
            child: ElevatedButton(
              onPressed: () async {
                await FirebaseFirestore.instance.collection('novels').doc(novelId)
                    .update({'excerpt': ctrl.text.trim()});
                if (ctx.mounted) Navigator.pop(ctx);
              },
              style: ElevatedButton.styleFrom(
                  backgroundColor: _gold, foregroundColor: _bg,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              child: Text('حفظ المقتطف', style: GoogleFonts.cairo(fontWeight: FontWeight.w700)),
            ),
          ),
        ]),
      ),
    );
  }

  // #37 تجميد الرواية (أدمن)
  Future<void> _toggleFreezeNovel(String novelId, bool isFrozen) async {
    await FirebaseFirestore.instance.collection('novels').doc(novelId)
        .update({'isFrozen': !isFrozen});
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(!isFrozen ? 'تم تجميد الرواية ❄️' : 'تم رفع التجميد ✅',
          style: GoogleFonts.cairo()),
      backgroundColor: !isFrozen ? Colors.blueGrey : Colors.green,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  // #17 رفع الغلاف بعد النشر (للكاتب فقط)
  Future<void> _uploadCover() async {
    if (_isUploadingCover) return;
    setState(() => _isUploadingCover = true);
    try {
      final novelId = widget.novel['id'] ?? '';
      final url = await UserRepository.pickAndUploadImage('novel_covers');
      await FirebaseFirestore.instance
          .collection('novels').doc(novelId)
          .update({'coverUrl': url});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('تم تحديث الغلاف ✅', style: GoogleFonts.cairo()),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', ''),
              style: GoogleFonts.cairo()),
          backgroundColor: Colors.redAccent,
        ));
      }
    } finally {
      if (mounted) setState(() => _isUploadingCover = false);
    }
  }

  // #20 حساب معدل النشر (متوسط أيام بين الفصول)
  Future<String> _calcPublishRate(String novelId) async {
    final snap = await FirebaseFirestore.instance
        .collection('novels').doc(novelId)
        .collection('chapters')
        .orderBy('createdAt')
        .get();
    if (snap.docs.length < 2) return '';
    final dates = snap.docs
        .map((d) => (d.data()['createdAt'] as Timestamp?)?.toDate())
        .whereType<DateTime>()
        .toList();
    if (dates.length < 2) return '';
    int totalDays = 0;
    for (int i = 1; i < dates.length; i++) {
      totalDays += dates[i].difference(dates[i - 1]).inDays;
    }
    final avg = (totalDays / (dates.length - 1)).round();
    if (avg == 0) return 'فصل يومياً';
    if (avg == 1) return 'فصل كل يوم';
    return 'فصل كل $avg أيام تقريباً';
  }

  // ── تعديل الرواية ──────────────────────────────────────────────────────────
  void _showEditSheet(Map<String, dynamic> novelData) {
    final titleCtrl = TextEditingController(
        text: novelData['title'] ?? widget.novel['title']);
    final descCtrl = TextEditingController(
        text: novelData['description'] ?? widget.novel['description']);
    String selectedCat = novelData['category'] ?? widget.novel['category'] ?? 'عام';
    final titleChanged = novelData['titleChanged'] ?? false;
    final readers      = (novelData['readers'] ?? 0) as int;
    final canEditTitle = !titleChanged && readers < 10;

    const categories = [
      'عام', 'فانتازيا', 'رعب', 'رومانسية',
      'غموض', 'تاريخية', 'خيال علمي',
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Container(
          padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom),
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
                    Text('تعديل الرواية',
                        style: GoogleFonts.cairo(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: _textPrimary)),
                    IconButton(
                      icon: const Icon(Icons.close, color: _textSecondary),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),

                // العنوان
                if (canEditTitle) ...[
                  Text('العنوان — يمكن تعديله مرة واحدة قبل 10 قراء',
                      style: GoogleFonts.cairo(
                          fontSize: 11, color: Colors.orange)),
                  const SizedBox(height: 6),
                  _sheetField(titleCtrl, 'عنوان الرواية'),
                  const SizedBox(height: 14),
                ] else ...[
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _surfaceHigh,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(children: [
                      const Icon(Icons.lock_outline,
                          size: 15, color: _textSecondary),
                      const SizedBox(width: 8),
                      Text('العنوان مقفل',
                          style: GoogleFonts.cairo(
                              fontSize: 12, color: _textSecondary)),
                    ]),
                  ),
                  const SizedBox(height: 14),
                ],

                // التصنيف
                Text('التصنيف',
                    style: GoogleFonts.cairo(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: _textPrimary)),
                const SizedBox(height: 8),
                SizedBox(
                  height: 36,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: categories.map((cat) {
                      final sel = cat == selectedCat;
                      return GestureDetector(
                        onTap: () => setS(() => selectedCat = cat),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          margin: const EdgeInsets.only(left: 8),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: sel ? _accent : _surfaceHigh,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                                color: sel ? _accent : _border),
                          ),
                          child: Text(cat,
                              style: GoogleFonts.cairo(
                                  fontSize: 12,
                                  color: sel
                                      ? const Color(0xFF0D0F14)
                                      : _textSecondary,
                                  fontWeight: sel
                                      ? FontWeight.w700
                                      : FontWeight.w400)),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 14),

                // الوصف
                Text('الوصف',
                    style: GoogleFonts.cairo(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: _textPrimary)),
                const SizedBox(height: 8),
                _sheetField(descCtrl, 'وصف الرواية...', maxLines: 3),
                const SizedBox(height: 18),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _accent,
                      foregroundColor: const Color(0xFF0D0F14),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    onPressed: () async {
                      final updates = <String, dynamic>{
                        'description': descCtrl.text.trim(),
                        'category':    selectedCat,
                      };
                      if (canEditTitle &&
                          titleCtrl.text.trim() !=
                              (novelData['title'] ?? widget.novel['title'])) {
                        updates['title']        = titleCtrl.text.trim();
                        updates['titleChanged'] = true;
                      }
                      await FirebaseFirestore.instance
                          .collection('novels')
                          .doc(widget.novel['id'])
                          .update(updates);
                      if (ctx.mounted) Navigator.pop(ctx);
                    },
                    child: Text('حفظ التعديلات',
                        style: GoogleFonts.cairo(fontWeight: FontWeight.w700)),
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

  Widget _sheetField(TextEditingController ctrl, String hint,
      {int maxLines = 1}) {
    return TextField(
      controller: ctrl,
      maxLines: maxLines,
      textDirection: TextDirection.rtl,
      textAlignVertical: TextAlignVertical.top,
      autocorrect: false,
      style: GoogleFonts.cairo(color: _textPrimary, fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.cairo(color: _textSecondary, fontSize: 13),
        filled: true,
        fillColor: _surfaceHigh,
        alignLabelWithHint: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _accent, width: 1.5),
        ),
      ),
    );
  }

  // ── إكمال الرواية ──────────────────────────────────────────────────────────
  Future<void> _confirmComplete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _surface,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('إعلان اكتمال الرواية',
            style: GoogleFonts.cairo(
                fontWeight: FontWeight.w700, color: _textPrimary)),
        content: Text(
          'بعد الإعلان لن تتمكن من إضافة فصول جديدة.',
          style: GoogleFonts.cairo(color: _textSecondary, height: 1.6),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('إلغاء',
                  style: GoogleFonts.cairo(color: _textSecondary))),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text('تأكيد',
                  style: GoogleFonts.cairo(
                      color: Colors.green, fontWeight: FontWeight.w700))),
        ],
      ),
    );
    if (confirmed == true) {
      await FirebaseFirestore.instance
          .collection('novels')
          .doc(widget.novel['id'])
          .update({
        'status':      'completed',
        'completedAt': FieldValue.serverTimestamp(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('الرواية مكتملة الآن ✅',
              style: GoogleFonts.cairo()),
          backgroundColor: Colors.green,
        ));
      }
    }
  }

  // ── حذف الرواية ────────────────────────────────────────────────────────────
  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _surface,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('حذف الرواية',
            style: GoogleFonts.cairo(
                fontWeight: FontWeight.w700, color: _textPrimary)),
        content: Text('هل أنت متأكد؟ لا يمكن التراجع.',
            style: GoogleFonts.cairo(color: _textSecondary)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('إلغاء',
                  style: GoogleFonts.cairo(color: _textSecondary))),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text('حذف',
                  style: GoogleFonts.cairo(
                      color: Colors.redAccent,
                      fontWeight: FontWeight.w700))),
        ],
      ),
    );
    if (confirmed == true) {
      await FirebaseFirestore.instance
          .collection('novels')
          .doc(widget.novel['id'])
          .delete();
      if (mounted) Navigator.pop(context);
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final authorId    = widget.novel['authorId'] ?? '';
    final isOwner     = currentUser?.uid == authorId;
    final novelId     = widget.novel['id'] ?? '';
    final category    = widget.novel['category'] ?? 'عام';
    final coverBg     = _categoryColors[category] ?? _surfaceHigh;
    final coverUrl    = widget.novel['coverUrl'] as String?;

    return Scaffold(
      backgroundColor: _bg,
      body: CustomScrollView(
        slivers: [
          // ── AppBar + غلاف ────────────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 320,
            pinned: true,
            backgroundColor: _bg,
            elevation: 0,
            leading: Padding(
              padding: const EdgeInsets.all(8),
              child: CircleAvatar(
                backgroundColor: _surface,
                child: IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new_rounded,
                      color: _textPrimary, size: 16),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),
            actions: [
              // زر المشاركة
              Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 8),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  CircleAvatar(
                    backgroundColor: _surface,
                    child: IconButton(
                      icon: const Icon(Icons.share_outlined, color: _textSecondary, size: 18),
                      tooltip: 'مشاركة',
                      onPressed: () => _shareNovel(widget.novel['title'] ?? '', novelId),
                    ),
                  ),
                  const SizedBox(width: 6),
                  // #23 إرسال لصديق
                  CircleAvatar(
                    backgroundColor: _surface,
                    child: IconButton(
                      icon: const Icon(Icons.person_add_alt_1_outlined,
                          color: _textSecondary, size: 18),
                      tooltip: 'أرسل لصديق',
                      onPressed: () => _sendToFriend(
                          novelId, widget.novel['title'] ?? ''),
                    ),
                  ),
                ]),
              ),
              // زر متابعة الرواية — للقراء فقط
              if (!isOwner)
                Padding(
                  padding: const EdgeInsets.only(top: 8, bottom: 8),
                  child: CircleAvatar(
                    backgroundColor: _surface,
                    child: IconButton(
                      icon: Icon(
                        _isFollowingNovel ? Icons.notifications_active_rounded : Icons.notifications_none_rounded,
                        color: _isFollowingNovel ? _accent : _textSecondary,
                        size: 18,
                      ),
                      onPressed: _toggleFollowNovel,
                    ),
                  ),
                ),
              // زر الإبلاغ — للقراء فقط
              if (!isOwner)
                Padding(
                  padding: const EdgeInsets.only(top: 8, bottom: 8),
                  child: CircleAvatar(
                    backgroundColor: _surface,
                    child: IconButton(
                      icon: const Icon(Icons.flag_outlined, color: Colors.redAccent, size: 18),
                      tooltip: 'إبلاغ',
                      onPressed: () => _showNovelReportDialog(novelId),
                    ),
                  ),
                ),
              // قائمة إجراءات الكاتب (نقطتان عمودية)
              if (isOwner)
                StreamBuilder<DocumentSnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('novels').doc(novelId).snapshots(),
                  builder: (_, snap) {
                    final data = snap.hasData && snap.data!.exists
                        ? snap.data!.data() as Map<String, dynamic>
                        : <String, dynamic>{};
                    final isHiatus = data['status'] == 'hiatus';
                    return Padding(
                      padding: const EdgeInsets.only(top: 8, bottom: 8, right: 4),
                      child: PopupMenuButton<String>(
                        icon: CircleAvatar(
                          backgroundColor: _surface,
                          child: const Icon(Icons.more_vert_rounded,
                              color: _textSecondary, size: 18),
                        ),
                        color: _surface,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: const BorderSide(color: _border),
                        ),
                        onSelected: (val) async {
                          if (val == 'excerpt') {
                            _showExcerptSheet(novelId, data['excerpt'] ?? '');
                          } else if (val == 'hiatus') {
                            await FirebaseFirestore.instance
                                .collection('novels').doc(novelId)
                                .update({'status': isHiatus ? 'ongoing' : 'hiatus'});
                          } else if (val == 'edit') {
                            _showEditSheet(data);
                          } else if (val == 'delete') {
                            _confirmDelete();
                          }
                        },
                        itemBuilder: (_) => [
                          PopupMenuItem(
                            value: 'excerpt',
                            child: Row(children: [
                              const Icon(Icons.format_quote_rounded, color: _gold, size: 16),
                              const SizedBox(width: 10),
                              Text('مقتطف مميز',
                                  style: GoogleFonts.cairo(color: _textPrimary, fontSize: 13)),
                            ]),
                          ),
                          PopupMenuItem(
                            value: 'hiatus',
                            child: Row(children: [
                              Icon(
                                isHiatus
                                    ? Icons.play_circle_outline_rounded
                                    : Icons.pause_circle_outline_rounded,
                                color: isHiatus ? _accent : Colors.orange,
                                size: 16,
                              ),
                              const SizedBox(width: 10),
                              Text(
                                isHiatus ? 'استئناف النشر' : 'إجازة مؤقتة',
                                style: GoogleFonts.cairo(color: _textPrimary, fontSize: 13),
                              ),
                            ]),
                          ),
                          PopupMenuItem(
                            value: 'edit',
                            child: Row(children: [
                              const Icon(Icons.edit_outlined, color: _accent, size: 16),
                              const SizedBox(width: 10),
                              Text('تعديل الرواية',
                                  style: GoogleFonts.cairo(color: _textPrimary, fontSize: 13)),
                            ]),
                          ),
                          const PopupMenuDivider(),
                          PopupMenuItem(
                            value: 'delete',
                            child: Row(children: [
                              const Icon(Icons.delete_outline, color: Colors.redAccent, size: 16),
                              const SizedBox(width: 10),
                              Text('حذف الرواية',
                                  style: GoogleFonts.cairo(
                                      color: Colors.redAccent, fontSize: 13)),
                            ]),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              // #37 تجميد (أدمن فقط)
              StreamBuilder<DocumentSnapshot>(
                stream: FirebaseFirestore.instance.collection('users')
                    .doc(currentUser?.uid ?? '').snapshots(),
                builder: (_, snap) {
                  final isAdmin = (snap.data?.data() as Map?)? ['role'] == 'admin';
                  if (!isAdmin) return const SizedBox.shrink();
                  return StreamBuilder<DocumentSnapshot>(
                    stream: FirebaseFirestore.instance.collection('novels').doc(novelId).snapshots(),
                    builder: (_, ns) {
                      final isFrozen = (ns.data?.data() as Map?)?['isFrozen'] == true;
                      return IconButton(
                        icon: Icon(isFrozen ? Icons.lock_open_rounded : Icons.lock_rounded,
                            color: Colors.blueGrey, size: 18),
                        tooltip: isFrozen ? 'رفع التجميد' : 'تجميد الرواية',
                        onPressed: () => _toggleFreezeNovel(novelId, isFrozen),
                      );
                    },
                  );
                },
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  // خلفية شفافة من الغلاف — بدون ضبابية مثل البروفايل
                  if (coverUrl != null)
                    Opacity(
                      opacity: 0.30,
                      child: CachedNetworkImage(imageUrl: coverUrl, fit: BoxFit.cover,
                          memCacheWidth: 800,
                          errorWidget: (_, e, s) => Container(color: coverBg)),
                    )
                  else
                    Container(color: coverBg),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          _bg.withValues(alpha: 0.55),
                          _bg.withValues(alpha: 0.30),
                          _bg.withValues(alpha: 0.88),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                  // الغلاف المركزي الكبير
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 48),
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          GestureDetector(
                            onTap: coverUrl == null ? null : () {
                              showDialog(
                                context: context,
                                builder: (_) => GestureDetector(
                                  onTap: () => Navigator.pop(context),
                                  child: Dialog(
                                    backgroundColor: Colors.transparent,
                                    insetPadding: const EdgeInsets.all(20),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(16),
                                      child: CachedNetworkImage(imageUrl: coverUrl, fit: BoxFit.contain, memCacheWidth: 600),
                                    ),
                                  ),
                                ),
                              );
                            },
                            child: Container(
                              width: 160,
                              height: 230,
                              decoration: BoxDecoration(
                                color: coverBg,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: _border, width: 1.5),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.6),
                                    blurRadius: 30,
                                    offset: const Offset(0, 12),
                                  ),
                                ],
                                image: coverUrl != null
                                    ? DecorationImage(
                                        image: NetworkImage(coverUrl),
                                        fit: BoxFit.cover)
                                    : null,
                              ),
                              child: coverUrl == null
                                  ? Icon(Icons.auto_stories_rounded,
                                      size: 60,
                                      color: _accent.withValues(alpha: 0.4))
                                  : null,
                            ),
                          ),
                          // زر رفع/تغيير الغلاف للكاتب
                          if (isOwner)
                            Positioned(
                              bottom: 8,
                              left: 8,
                              child: GestureDetector(
                                onTap: _uploadCover,
                                child: Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: _accent,
                                    shape: BoxShape.circle,
                                    boxShadow: [BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.5),
                                      blurRadius: 8,
                                    )],
                                  ),
                                  child: _isUploadingCover
                                      ? const Padding(
                                          padding: EdgeInsets.all(8),
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.black))
                                      : const Icon(Icons.camera_alt_rounded,
                                          size: 17, color: Colors.black),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(1),
              child: Container(height: 1, color: _border),
            ),
          ),

          // ── المحتوى ─────────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('novels').doc(novelId).snapshots(),
              builder: (_, novelSnap) {
                final novelData =
                    novelSnap.hasData && novelSnap.data!.exists
                        ? novelSnap.data!.data() as Map<String, dynamic>
                        : <String, dynamic>{};
                final isCompleted = novelData['status'] == 'completed';
                final title = novelData['title'] ??
                    widget.novel['title'] ?? '';
                final authorName = novelData['authorName'] ??
                    widget.novel['author'] ?? 'كاتب مجهول';
                final desc = novelData['description'] ??
                    widget.novel['description'] ?? '';
                final cat = novelData['category'] ??
                    widget.novel['category'] ?? 'عام';

                return Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // تصنيف + حالة
                      Row(children: [
                        _badge(cat, _accent.withValues(alpha: 0.15), _accent),
                        if (isCompleted) ...[
                          const SizedBox(width: 8),
                          _badge('مكتملة ✅',
                              Colors.green.withValues(alpha: 0.12), Colors.green),
                        ],
                      ]),
                      const SizedBox(height: 12),

                      // العنوان
                      Text(title,
                          style: GoogleFonts.cairo(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: _textPrimary)),

                      const SizedBox(height: 8),

                      // الكاتب + متابعة
                      Row(
                        mainAxisAlignment:
                            MainAxisAlignment.spaceBetween,
                        children: [
                          GestureDetector(
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => AuthorScreen(
                                  authorId:   authorId,
                                  authorName: authorName,
                                ),
                              ),
                            ),
                            child: Row(children: [
                              const Icon(Icons.person_outline_rounded,
                                  size: 15, color: _accent),
                              const SizedBox(width: 5),
                              Text(authorName,
                                  style: GoogleFonts.cairo(
                                      fontSize: 13,
                                      color: _accent,
                                      decoration:
                                          TextDecoration.underline,
                                      decorationColor: _accent)),
                            ]),
                          ),
                          if (!isOwner && authorId.isNotEmpty)
                            _isFollowLoading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                        color: _accent, strokeWidth: 2))
                                : GestureDetector(
                                    onTap: _toggleFollow,
                                    child: AnimatedContainer(
                                      duration: const Duration(
                                          milliseconds: 200),
                                      padding:
                                          const EdgeInsets.symmetric(
                                              horizontal: 14,
                                              vertical: 6),
                                      decoration: BoxDecoration(
                                        color: _isFollowing
                                            ? _surface
                                            : _accent,
                                        borderRadius:
                                            BorderRadius.circular(20),
                                        border: Border.all(
                                            color: _isFollowing
                                                ? _border
                                                : _accent),
                                      ),
                                      child: Text(
                                        _isFollowing ? 'متابَع' : 'تابع',
                                        style: GoogleFonts.cairo(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: _isFollowing
                                              ? _textSecondary
                                              : const Color(0xFF0D0F14),
                                        ),
                                      ),
                                    ),
                                  ),
                        ],
                      ),
                      const SizedBox(height: 18),

                      // الإحصائيات
                      Container(
                        padding: const EdgeInsets.symmetric(
                            vertical: 14, horizontal: 8),
                        decoration: BoxDecoration(
                          color: _surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: _border),
                        ),
                        child: Row(
                          mainAxisAlignment:
                              MainAxisAlignment.spaceAround,
                          children: [
                            _stat(Icons.star_rounded,
                                (novelData['rating'] ?? 0.0)
                                    .toStringAsFixed(1),
                                'التقييم',
                                color: _gold),
                            _vDiv(),
                            _stat(Icons.favorite_rounded,
                                (novelData['likes'] ?? 0).toString(),
                                'إعجاب',
                                color: Colors.redAccent),
                            _vDiv(),
                            _stat(Icons.remove_red_eye_rounded,
                                (novelData['readers'] ?? 0).toString(),
                                'قارئ'),
                            _vDiv(),
                            _stat(Icons.menu_book_rounded,
                                (novelData['chaptersCount'] ?? 0)
                                    .toString(),
                                'فصل'),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),

                      // #33 القراء الحاليون
                      StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('novels').doc(novelId)
                            .collection('presences').snapshots(),
                        builder: (_, snap) {
                          final count = snap.hasData ? snap.data!.docs.length : 0;
                          if (count == 0) return const SizedBox.shrink();
                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                            decoration: BoxDecoration(
                              color: Colors.green.withValues(alpha: 0.07),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.green.withValues(alpha: 0.2)),
                            ),
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                              Container(width: 7, height: 7,
                                  decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle)),
                              const SizedBox(width: 7),
                              Text('$count ${count == 1 ? 'شخص يتصفح' : 'أشخاص يتصفحون'} الآن',
                                  style: GoogleFonts.cairo(fontSize: 11, color: Colors.green)),
                            ]),
                          );
                        },
                      ),

                      // #35 زر الهدية
                      if (!isOwner && authorId.isNotEmpty)
                        Align(
                          alignment: AlignmentDirectional.centerEnd,
                          child: GestureDetector(
                            onTap: () => _sendGift(authorId),
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                              decoration: BoxDecoration(
                                color: _gold.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: _gold.withValues(alpha: 0.35)),
                              ),
                              child: Row(mainAxisSize: MainAxisSize.min, children: [
                                const Icon(Icons.redeem_rounded, size: 14, color: _gold),
                                const SizedBox(width: 6),
                                Text('أرسل هدية 5 نقاط',
                                    style: GoogleFonts.cairo(fontSize: 12, color: _gold, fontWeight: FontWeight.w600)),
                              ]),
                            ),
                          ),
                        ),
                      const SizedBox(height: 6),

                      // #20 معدل النشر
                      if ((novelData['chaptersCount'] ?? 0) > 1)
                        FutureBuilder<String>(
                          future: _calcPublishRate(novelId),
                          builder: (_, snap) {
                            final rate = snap.data ?? '';
                            if (rate.isEmpty) return const SizedBox.shrink();
                            return Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 7),
                              decoration: BoxDecoration(
                                color: _surfaceHigh,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: _border),
                              ),
                              child: Row(children: [
                                const Icon(Icons.schedule_rounded,
                                    size: 14, color: _textSecondary),
                                const SizedBox(width: 6),
                                Text('معدل النشر: $rate',
                                    style: GoogleFonts.cairo(
                                        fontSize: 12,
                                        color: _textSecondary)),
                              ]),
                            );
                          },
                        ),
                      const SizedBox(height: 10),

                      // #14 إجازة مؤقتة
                      if (novelData['status'] == 'hiatus')
                        Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.orange.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                          ),
                          child: Row(children: [
                            const Icon(Icons.pause_circle_outline_rounded,
                                color: Colors.orange, size: 16),
                            const SizedBox(width: 8),
                            Text('الرواية في إجازة مؤقتة — ستعود قريباً',
                                style: GoogleFonts.cairo(fontSize: 12, color: Colors.orange)),
                          ]),
                        ),

                      // الوصف
                      _sectionTitle('نبذة عن الرواية'),
                      const SizedBox(height: 8),
                      Text(
                        desc.toString().isEmpty
                            ? 'لا يوجد وصف لهذه الرواية.'
                            : desc,
                        style: GoogleFonts.cairo(
                          fontSize: 14,
                          height: 1.8,
                          color: _textSecondary,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // #12 مقتطف مميز
                      if ((novelData['excerpt'] as String? ?? '').isNotEmpty) ...[
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: _gold.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(12),
                            border: Border(
                              right: BorderSide(color: _gold, width: 3),
                            ),
                          ),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text('مقتطف مميز',
                                style: GoogleFonts.cairo(fontSize: 10, color: _gold,
                                    fontWeight: FontWeight.w700)),
                            const SizedBox(height: 6),
                            Text(novelData['excerpt'],
                                style: GoogleFonts.cairo(
                                    fontSize: 13, color: _textSecondary,
                                    fontStyle: FontStyle.italic, height: 1.7)),
                          ]),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // #22 مراجعة نقدية (للقراء فقط)
                      if (!isOwner && currentUser != null)
                        Align(
                          alignment: AlignmentDirectional.centerEnd,
                          child: TextButton.icon(
                            onPressed: () => _showLongReviewSheet(novelId, title),
                            icon: const Icon(Icons.rate_review_outlined,
                                size: 16, color: _textSecondary),
                            label: Text('كتابة مراجعة نقدية',
                                style: GoogleFonts.cairo(
                                    fontSize: 12, color: _textSecondary)),
                          ),
                        ),

                      const SizedBox(height: 24),

                      // زر إضافة لقائمة قراءة
                      if (FirebaseAuth.instance.currentUser != null && !isOwner) ...[
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () => _showReadingListsSheet(novelId, title),
                            icon: const Icon(Icons.playlist_add_rounded, color: _accent, size: 18),
                            label: Text('أضف إلى قائمة قراءة',
                                style: GoogleFonts.cairo(color: _accent, fontWeight: FontWeight.w600)),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: _accent.withValues(alpha: 0.4)),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],

                      // الفصول
                      Row(
                        mainAxisAlignment:
                            MainAxisAlignment.spaceBetween,
                        children: [
                          _sectionTitle('الفصول'),
                          if (isOwner && !isCompleted)
                            GestureDetector(
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => AddNovelScreen(
                                    novelId:    novelId,
                                    novelTitle: title,
                                  ),
                                ),
                              ),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: _accent.withValues(alpha: 0.12),
                                  borderRadius:
                                      BorderRadius.circular(8),
                                  border: Border.all(
                                      color:
                                          _accent.withValues(alpha: 0.3)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.add,
                                        size: 14, color: _accent),
                                    const SizedBox(width: 4),
                                    Text('فصل جديد',
                                        style: GoogleFonts.cairo(
                                            fontSize: 12,
                                            color: _accent,
                                            fontWeight:
                                                FontWeight.w700)),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // قائمة الفصول
                      StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('novels')
                            .doc(novelId)
                            .collection('chapters')
                            .orderBy('chapterNumber')
                            .snapshots(),
                        builder: (_, chapSnap) {
                          if (chapSnap.connectionState ==
                              ConnectionState.waiting) {
                            return const Center(
                                child: CircularProgressIndicator(
                                    color: _accent, strokeWidth: 2));
                          }
                          if (!chapSnap.hasData ||
                              chapSnap.data!.docs.isEmpty) {
                            return Padding(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 20),
                              child: Center(
                                  child: Text('لا توجد فصول بعد.',
                                      style: GoogleFonts.cairo(
                                          color: _textSecondary))),
                            );
                          }

                          return ListView.builder(
                            shrinkWrap: true,
                            physics:
                                const NeverScrollableScrollPhysics(),
                            itemCount: chapSnap.data!.docs.length,
                            itemBuilder: (_, i) {
                              final ch = chapSnap.data!.docs[i];
                              final chData =
                                  ch.data() as Map<String, dynamic>;
                              final chNum =
                                  chData['chapterNumber'] ?? (i + 1);
                              final wc = chData['wordCount'] ?? 0;
                              final rt = (chData['rating'] ?? 0.0)
                                  .toDouble();
                              final rtCt =
                                  chData['ratingsCount'] ?? 0;

                              return GestureDetector(
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => NovelReaderScreen(
                                      novel: {
                                        'id':           novelId,
                                        'chapterId':    ch.id,
                                        'chapterTitle': chData['title'] ?? '',
                                        'chapterNumber': chNum is int ? chNum : int.tryParse(chNum.toString()) ?? (i + 1),
                                        'title':        title,
                                        'author':       authorName,
                                        'authorName':   authorName,
                                        'content':      chData['content'] ?? '',
                                        'likes':        (novelData['likes'] ?? 0).toString(),
                                        'readers':      (novelData['readers'] ?? 0).toString(),
                                        'authorId':     authorId,
                                        'chaptersList': chapSnap.data!.docs.map((d) => {
                                          'id':            d.id,
                                          'title':         (d.data() as Map)['title'] ?? '',
                                          'content':       (d.data() as Map)['content'] ?? '',
                                          'chapterNumber': (d.data() as Map)['chapterNumber'] ?? 1,
                                        }).toList(),
                                      },
                                    ),
                                  ),
                                ),
                                child: Container(
                                  margin: const EdgeInsets.only(
                                      bottom: 10),
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: _surface,
                                    borderRadius:
                                        BorderRadius.circular(12),
                                    border:
                                        Border.all(color: _border),
                                  ),
                                  child: Row(children: [
                                    // رقم الفصل
                                    Container(
                                      width: 36,
                                      height: 36,
                                      decoration: BoxDecoration(
                                        color: _accent.withValues(alpha: 0.12),
                                        borderRadius:
                                            BorderRadius.circular(10),
                                      ),
                                      child: Center(
                                        child: Text('$chNum',
                                            style: GoogleFonts.cairo(
                                                fontWeight:
                                                    FontWeight.w700,
                                                color: _accent,
                                                fontSize: 13)),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            chData['title'] ??
                                                'فصل $chNum',
                                            style: GoogleFonts.cairo(
                                              fontWeight:
                                                  FontWeight.w700,
                                              fontSize: 13,
                                              color: _textPrimary,
                                            ),
                                          ),
                                          const SizedBox(height: 3),
                                          Row(children: [
                                            Text(
                                              '$wc كلمة',
                                              style: GoogleFonts.cairo(
                                                  fontSize: 11,
                                                  color:
                                                      _textSecondary),
                                            ),
                                            if (rtCt > 0) ...[
                                              Text('  ·  ',
                                                  style: GoogleFonts
                                                      .cairo(
                                                          fontSize: 11,
                                                          color:
                                                              _textSecondary)),
                                              Icon(
                                                  Icons.star_rounded,
                                                  size: 11,
                                                  color: _gold),
                                              const SizedBox(width: 2),
                                              Text(
                                                '${rt.toStringAsFixed(1)} ($rtCt)',
                                                style: GoogleFonts.cairo(
                                                    fontSize: 11,
                                                    color:
                                                        _textSecondary),
                                              ),
                                            ],
                                          ]),
                                        ],
                                      ),
                                    ),
                                    if (_readChapterIds.contains(ch.id))
                                      const Padding(
                                        padding: EdgeInsets.only(left: 6),
                                        child: Icon(Icons.check_circle_rounded,
                                            size: 16, color: _accent),
                                      ),
                                    const Icon(
                                        Icons.arrow_forward_ios_rounded,
                                        size: 13,
                                        color: _textSecondary),
                                  ]),
                                ),
                              );
                            },
                          );
                        },
                      ),

                      // زر الاكتمال
                      if (isOwner && !isCompleted) ...[
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: _confirmComplete,
                            icon: const Icon(
                                Icons.check_circle_outline,
                                color: Colors.green,
                                size: 18),
                            label: Text('أعلن اكتمال الرواية',
                                style: GoogleFonts.cairo(
                                    color: Colors.green,
                                    fontWeight: FontWeight.w700)),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(
                                  color: Colors.green),
                              padding: const EdgeInsets.symmetric(
                                  vertical: 14),
                              shape: RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                      ],

                      const SizedBox(height: 40),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ── مساعدات ───────────────────────────────────────────────────────────────
  Widget _badge(String text, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
          color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(text,
          style: GoogleFonts.cairo(
              fontSize: 12, fontWeight: FontWeight.w700, color: fg)),
    );
  }

  Widget _sectionTitle(String text) {
    return Row(children: [
      Container(
        width: 3,
        height: 16,
        decoration: BoxDecoration(
            color: _accent, borderRadius: BorderRadius.circular(2)),
      ),
      const SizedBox(width: 8),
      Text(text,
          style: GoogleFonts.cairo(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: _textSecondary)),
    ]);
  }

  Widget _stat(IconData icon, String val, String label, {Color? color}) {
    return Column(children: [
      Icon(icon, color: color ?? _accent, size: 20),
      const SizedBox(height: 3),
      Text(val,
          style: GoogleFonts.cairo(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: _textPrimary)),
      Text(label,
          style:
              GoogleFonts.cairo(fontSize: 10, color: _textSecondary)),
    ]);
  }

  Widget _vDiv() =>
      Container(height: 36, width: 1, color: _border);

  // ── إبلاغ عن الرواية (غلاف / عنوان) ─────────────────────────────────────
  void _showNovelReportDialog(String novelId) {
    String? selected;
    bool sending = false;
    final reasons = ['غلاف غير لائق', 'عنوان مسيء', 'محتوى مخالف', 'انتحال هوية', 'أخرى'];
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(builder: (ctx, setSt) => AlertDialog(
        backgroundColor: _surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('إبلاغ عن الرواية', style: GoogleFonts.cairo(fontWeight: FontWeight.w700, color: _textPrimary)),
        content: SizedBox(width: 340, child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('سبب البلاغ', style: GoogleFonts.cairo(fontSize: 12, color: _textSecondary)),
          const SizedBox(height: 8),
          Wrap(spacing: 6, runSpacing: 6, children: reasons.map((r) => GestureDetector(
            onTap: () => setSt(() => selected = r),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: selected == r ? _accent.withValues(alpha: 0.15) : _surfaceHigh,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: selected == r ? _accent : _border),
              ),
              child: Text(r, style: GoogleFonts.cairo(fontSize: 12, color: selected == r ? _accent : _textSecondary)),
            ),
          )).toList()),
          const SizedBox(height: 12),
          TextField(
            controller: ctrl,
            style: GoogleFonts.cairo(fontSize: 12, color: _textPrimary),
            maxLines: 3,
            textAlignVertical: TextAlignVertical.top,
            autocorrect: false,
            decoration: InputDecoration(
              hintText: 'تفاصيل إضافية (اختياري)',
              hintStyle: GoogleFonts.cairo(fontSize: 12, color: _textSecondary),
              filled: true, fillColor: _surfaceHigh,
              alignLabelWithHint: true,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: _border)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: _border)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: _accent)),
              contentPadding: const EdgeInsets.all(10),
            ),
          ),
        ])),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('إلغاء', style: GoogleFonts.cairo(color: _textSecondary))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            onPressed: (selected == null || sending) ? null : () async {
              setSt(() => sending = true);
              final uid = FirebaseAuth.instance.currentUser?.uid;
              if (uid == null) { setSt(() => sending = false); return; }
              // فحص البلاغات المكررة
              final existing = await FirebaseFirestore.instance
                  .collection('reports')
                  .where('reportedBy', isEqualTo: uid)
                  .where('novelId', isEqualTo: novelId)
                  .where('type', isEqualTo: 'novel')
                  .limit(1)
                  .get();
              if (existing.docs.isNotEmpty) {
                if (ctx.mounted) Navigator.pop(ctx);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text('لقد أرسلت بلاغاً عن هذه الرواية من قبل', style: GoogleFonts.cairo()),
                    backgroundColor: Colors.orange, behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ));
                }
                return;
              }
              final novel = await FirebaseFirestore.instance.collection('novels').doc(novelId).get();
              await FirebaseFirestore.instance.collection('reports').add({
                'type': 'novel',
                'reason': selected,
                'details': ctrl.text.trim(),
                'reportedBy': uid,
                'reportedUser': novel.data()?['authorId'] ?? '',
                'novelId': novelId,
                'status': 'pending',
                'createdAt': FieldValue.serverTimestamp(),
              });
              if (ctx.mounted) Navigator.pop(ctx);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text('تم إرسال البلاغ ✅', style: GoogleFonts.cairo()),
                  backgroundColor: Colors.green, behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ));
              }
            },
            child: sending
                ? const SizedBox(height: 18, width: 18,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : Text('إرسال', style: GoogleFonts.cairo(color: Colors.white)),
          ),
        ],
      )),
    );
  }
}

