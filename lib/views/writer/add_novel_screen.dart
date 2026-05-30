import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../providers/novels_provider.dart';

class AddNovelScreen extends StatefulWidget {
  const AddNovelScreen({super.key});

  @override
  State<AddNovelScreen> createState() => _AddNovelScreenState();
}

class _AddNovelScreenState extends State<AddNovelScreen> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _contentController = TextEditingController();
  final TextStyle cairoStyle = GoogleFonts.cairo();
  String _selectedCategory = 'عام';
  bool _isPublishing = false;

  final List<String> _categories = [
    'عام', 'فانتازيا', 'رعب', 'رومانسية', 'غموض', 'تاريخية', 'خيال علمي'
  ];

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'كتابة رواية جديدة 🖋️',
          style: cairoStyle.copyWith(fontWeight: FontWeight.bold),
        ),
        actions: [
          TextButton(
            onPressed: _isPublishing ? null : () async {
              if (_titleController.text.isNotEmpty) {
                setState(() => _isPublishing = true);
                try {
                  await Provider.of<NovelsProvider>(context, listen: false)
                      .addNovel(
                    _titleController.text,
                    _descriptionController.text,
                    _contentController.text,
                    _selectedCategory,
                  );
                  if (mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'تم نشر روايتك للجميع! 🚀',
                          style: cairoStyle,
                        ),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    setState(() => _isPublishing = false);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'حدث خطأ أثناء النشر، حاول مرة أخرى',
                          style: cairoStyle,
                        ),
                        backgroundColor: Colors.redAccent,
                      ),
                    );
                  }
                }
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'الرجاء إدخال عنوان الرواية أولاً!',
                      style: cairoStyle,
                    ),
                  ),
                );
              }
            },
            child: _isPublishing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(
                    'نشر 🚀',
                    style: cairoStyle.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // حقل العنوان
              TextField(
                controller: _titleController,
                style: cairoStyle.copyWith(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
                decoration: InputDecoration(
                  hintText: 'عنوان الرواية...',
                  hintStyle: cairoStyle.copyWith(color: Colors.grey),
                  border: InputBorder.none,
                ),
              ),
              const Divider(),

              // اختيار التصنيف
              SizedBox(
                height: 40,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _categories.length,
                  itemBuilder: (context, index) {
                    final cat = _categories[index];
                    final isSelected = cat == _selectedCategory;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedCategory = cat),
                      child: Container(
                        margin: const EdgeInsets.only(left: 8),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? theme.colorScheme.primary
                              : theme.colorScheme.surface,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: theme.colorScheme.primary.withOpacity(0.3),
                          ),
                        ),
                        child: Text(
                          cat,
                          style: cairoStyle.copyWith(
                            fontSize: 12,
                            color: isSelected ? Colors.black : Colors.grey,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              const Divider(),

              // حقل الوصف
              TextField(
                controller: _descriptionController,
                maxLines: 2,
                style: cairoStyle.copyWith(fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'اكتب ملخصاً قصيراً لجذب القراء...',
                  hintStyle: cairoStyle.copyWith(color: Colors.grey),
                  border: InputBorder.none,
                ),
              ),
              const Divider(),
              const SizedBox(height: 10),

              // حقل المحتوى
              TextField(
                controller: _contentController,
                maxLines: null,
                keyboardType: TextInputType.multiline,
                style: cairoStyle.copyWith(fontSize: 16, height: 1.8),
                decoration: InputDecoration(
                  hintText: 'ابدأ بكتابة الفصل الأول هنا...',
                  hintStyle: cairoStyle.copyWith(color: Colors.grey),
                  border: InputBorder.none,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}