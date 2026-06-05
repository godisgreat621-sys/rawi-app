import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class PrivacyScreen extends StatelessWidget {
  final bool isFirstTime;
  const PrivacyScreen({super.key, this.isFirstTime = false});

  static const _bg           = Color(0xFF0D0F14);
  static const _surface      = Color(0xFF161920);
  static const _accent       = Color(0xFF8BAF7C);
  static const _border       = Color(0xFF252836);
  static const _textPrimary  = Color(0xFFECECEC);
  static const _textSecondary= Color(0xFF6B7280);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        title: Text('سياسة الخصوصية والشروط',
            style: GoogleFonts.cairo(
                fontWeight: FontWeight.w700,
                color: _textPrimary,
                fontSize: 15)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isFirstTime) ...[
              Container(
                padding: const EdgeInsets.all(14),
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: _accent.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _accent.withOpacity(0.25)),
                ),
                child: Row(children: [
                  const Icon(Icons.info_outline, color: _accent, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text('يرجى قراءة شروط الاستخدام وسياسة الخصوصية قبل الاستمرار.',
                        style: GoogleFonts.cairo(fontSize: 12, color: _accent)),
                  ),
                ]),
              ),
            ],

            _section('مرحباً بك في منصة راوي',
                'راوي منصة عربية للقصص والروايات تهدف إلى تمكين الكتّاب من نشر إبداعاتهم وتمكين القراء من الاستمتاع بمحتوى متنوع وأصيل.'),

            _section('جمع البيانات واستخدامها',
                '• نجمع عنوان البريد الإلكتروني لأغراض تسجيل الدخول والتواصل.\n'
                '• نخزن تقدم القراءة والتقييمات لتحسين تجربتك.\n'
                '• لا نشارك بياناتك مع أطراف ثالثة لأغراض تجارية.\n'
                '• الصور المرفوعة تُخزَّن على Cloudinary بشكل آمن.'),

            _section('ملكية المحتوى',
                '• أنت تحتفظ بحقوق الملكية الفكرية لما تنشره.\n'
                '• بالنشر على المنصة تمنح راوي حق عرض محتواك للقراء.\n'
                '• يُحظر نشر أي محتوى مسروق أو منتهك لحقوق الآخرين.'),

            _section('قواعد المجتمع',
                '• يُحظر نشر محتوى مسيء أو يحتوي على إساءة موجهة لأفراد.\n'
                '• يُحظر النشر بأكثر من مرة واحدة كل 24 ساعة للحفاظ على جودة المحتوى.\n'
                '• التقييمات يجب أن تعكس رأيك الحقيقي.\n'
                '• تكرار البلاغات على حساب يعرّضه للحظر المؤقت أو الدائم.'),

            _section('نظام النقاط والمكافآت',
                '• نقاط المنصة رمزية ولا قيمة مالية لها.\n'
                '• تُمنح النقاط لتعزيز التفاعل الإيجابي.\n'
                '• للمنصة الحق في تعديل نظام النقاط في أي وقت.'),

            _section('الخصوصية وحق الحذف',
                '• يمكنك طلب حذف حسابك وبياناتك في أي وقت من خلال الدعم الفني.\n'
                '• نحتفظ بحق الاحتفاظ ببعض البيانات لأسباب قانونية وأمنية.'),

            _section('التعديلات على السياسة',
                'قد نعدّل هذه السياسة من وقت لآخر. سيتم إعلامك بأي تغييرات جوهرية عبر الإشعارات داخل التطبيق.'),

            _section('التواصل معنا',
                'لأي استفسارات تخص الخصوصية أو شروط الاستخدام، يمكنك التواصل عبر نظام الدعم الفني داخل التطبيق.'),

            const SizedBox(height: 30),

            if (isFirstTime)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _accent,
                    foregroundColor: _bg,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: Text('أوافق على الشروط',
                      style: GoogleFonts.cairo(fontWeight: FontWeight.w700, fontSize: 14)),
                ),
              )
            else
              Text('آخر تحديث: يونيو 2026',
                  style: GoogleFonts.cairo(fontSize: 11, color: _textSecondary)),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _section(String title, String body) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: GoogleFonts.cairo(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: _textPrimary)),
          const SizedBox(height: 8),
          Text(body,
              style: GoogleFonts.cairo(
                  fontSize: 13, height: 1.7, color: _textSecondary)),
        ],
      ),
    );
  }
}
