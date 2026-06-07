import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:my_first_app/providers/novels_provider.dart';

class SupportRequestScreen extends StatefulWidget {
  const SupportRequestScreen({super.key});

  @override
  State<SupportRequestScreen> createState() => _SupportRequestScreenState();
}

class _SupportRequestScreenState extends State<SupportRequestScreen> {
  String _type = 'spelling';
  final _originalCtrl = TextEditingController();
  final _correctedCtrl = TextEditingController();
  final _messageCtrl = TextEditingController();
  bool _isSending = false;

  @override
  void dispose() {
    _originalCtrl.dispose();
    _correctedCtrl.dispose();
    _messageCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendRequest() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    if (_type == 'spelling' &&
        (_originalCtrl.text.trim().isEmpty ||
            _correctedCtrl.text.trim().isEmpty)) {
      _showError('يرجى إدخال النص الأصلي والنص الصحيح.');
      return;
    }
    if (_type != 'spelling' && _messageCtrl.text.trim().length < 20) {
      _showError('يرجى كتابة وصف مفصل من 20 حرفاً على الأقل.');
      return;
    }

    if (mounted) setState(() => _isSending = true);
    final response = await context.read<NovelsProvider>().sendSupportRequest(
      type: _type,
      title: _type == 'spelling'
          ? 'تصحيح إملائي'
          : _type == 'violation'
          ? 'إزالة مخالفة'
          : 'طلب إكمال',
      description: _type == 'spelling'
          ? 'من "${_originalCtrl.text.trim()}" إلى "${_correctedCtrl.text.trim()}"'
          : _messageCtrl.text.trim(),
    );
    if (mounted) setState(() => _isSending = false);

    if (response != null) {
      _showError(response);
      return;
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'تم إرسال طلب الدعم بنجاح.',
            style: GoogleFonts.cairo(),
          ),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.cairo()),
        backgroundColor: Colors.redAccent,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'طلب دعم',
          style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'اختر نوع الطلب',
              style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _buildChip('تصحيح إملائي', 'spelling', theme),
                const SizedBox(width: 10),
                _buildChip('إزالة مخالفة', 'violation', theme),
                const SizedBox(width: 10),
                _buildChip('طلب إكمال', 'completion', theme),
              ],
            ),
            const SizedBox(height: 24),
            if (_type == 'spelling') ...[
              TextField(
                controller: _originalCtrl,
                textDirection: TextDirection.rtl,
                autocorrect: false,
                style: GoogleFonts.cairo(fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'النص الخاطئ',
                  hintStyle: GoogleFonts.cairo(fontSize: 14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _correctedCtrl,
                textDirection: TextDirection.rtl,
                autocorrect: false,
                style: GoogleFonts.cairo(fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'النص الصحيح',
                  hintStyle: GoogleFonts.cairo(fontSize: 14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ] else ...[
              TextField(
                controller: _messageCtrl,
                maxLines: 5,
                textDirection: TextDirection.rtl,
                textAlignVertical: TextAlignVertical.top,
                autocorrect: false,
                style: GoogleFonts.cairo(fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'اترك التفاصيل هنا...',
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: _isSending ? null : _sendRequest,
                child: _isSending
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(
                        'أرسل طلب الدعم',
                        style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChip(String label, String value, ThemeData theme) {
    final selected = _type == value;
    return GestureDetector(
      onTap: () => setState(() => _type = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? theme.colorScheme.primary
              : Colors.grey.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? theme.colorScheme.primary : Colors.transparent,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.cairo(
            color: selected ? Colors.black : Colors.grey,
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
