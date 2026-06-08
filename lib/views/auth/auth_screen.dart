import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:my_first_app/view_models/auth_view_model.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  bool _isLoginMode = true;
  bool _obscurePassword = true;
  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  // ── الألوان الثابتة ──────────────────────────────────────────────────────────
  static const _bg = Color(0xFF0F1117);
  static const _surface = Color(0xFF1A1D27);
  static const _accent = Color(0xFFC4A87A); // أخضر زيتوني هادئ
  static const _accentDim = Color(0x33C4A87A);
  static const _textPrimary = Color(0xFFEAEAEA);
  static const _textSecondary = Color(0xFF7A8090);
  static const _border = Color(0xFF2A2D3A);

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _animController.forward();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    _animController.dispose();
    super.dispose();
  }

  void _switchMode() {
    setState(() {
      _isLoginMode = !_isLoginMode;
      _formKey.currentState?.reset();
    });
    _animController.reset();
    _animController.forward();
  }

  Future<void> _signInWithGoogle() async {
    final auth  = Provider.of<AuthViewModel>(context, listen: false);
    final error = await auth.signInWithGoogle();
    if (error != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(error, style: GoogleFonts.cairo()),
        backgroundColor: Colors.redAccent.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ));
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final auth = Provider.of<AuthViewModel>(context, listen: false);
    final error = _isLoginMode
        ? await auth.login(
            _emailController.text.trim(),
            _passwordController.text.trim(),
          )
        : await auth.signUp(
            _emailController.text.trim(),
            _passwordController.text.trim(),
            displayName: _nameController.text.trim(),
          );
    if (error != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(error, style: GoogleFonts.cairo()),
        backgroundColor: Colors.redAccent.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ));
    } else if (!_isLoginMode && mounted) {
      // #32 إرسال بريد التحقق بعد التسجيل
      try {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null && !user.emailVerified) {
          await user.sendEmailVerification();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('تم إرسال رسالة تحقق إلى بريدك 📧',
                  style: GoogleFonts.cairo(fontSize: 12)),
              backgroundColor: const Color(0xFFC4A87A),
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 5),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ));
          }
        }
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthViewModel>(context);

    return Scaffold(
      backgroundColor: _bg,
      body: FadeTransition(
        opacity: _fadeAnim,
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding:
                  const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ── الشعار ──────────────────────────────────────────────
                    Column(
                      children: [
                        // نعرض الجزء العلوي من الصورة فقط (الهلال) ونقطع المنطقة الداكنة السفلية
                        SizedBox(
                          height: 76,
                          child: ClipRect(
                            child: OverflowBox(
                              maxHeight: 110,
                              maxWidth: 110,
                              alignment: Alignment.topCenter,
                              child: Image.asset('logo.png', width: 110, height: 110),
                            ),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'راوي',
                          style: GoogleFonts.cairo(
                            fontSize: 32,
                            fontWeight: FontWeight.w700,
                            color: _textPrimary,
                            letterSpacing: 1,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          'بداية كل رواية؛ إشراق عالم جديد',
                          style: GoogleFonts.cairo(
                            fontSize: 12,
                            color: _textSecondary,
                            fontWeight: FontWeight.w400,
                            letterSpacing: 0.3,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            color: _accentDim,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: _accent.withValues(alpha: 0.25)),
                          ),
                          child: Text(
                            'روايات عربية أصيلة من كتّاب مجتمع راوي',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.cairo(
                              fontSize: 12,
                              color: _accent,
                              height: 1.6,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 32),

                    // ── تبديل تسجيل / إنشاء ──────────────────────────────
                    Container(
                      height: 44,
                      decoration: BoxDecoration(
                        color: _surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _border),
                      ),
                      child: Row(
                        children: [
                          _modeTab('دخول', true),
                          _modeTab('حساب جديد', false),
                        ],
                      ),
                    ),

                    const SizedBox(height: 28),

                    // ── حقل الاسم (تسجيل فقط) ───────────────────────────
                    if (!_isLoginMode) ...[
                      _buildField(
                        controller: _nameController,
                        label: 'اسم العرض',
                        hint: 'ما اسمك بين القراء؟',
                        icon: Icons.person_outline_rounded,
                        validator: (v) =>
                            v == null || v.trim().isEmpty
                                ? 'أدخل اسمك'
                                : null,
                      ),
                      const SizedBox(height: 14),
                    ],

                    // ── البريد ───────────────────────────────────────────
                    _buildField(
                      controller: _emailController,
                      label: 'البريد الإلكتروني',
                      hint: 'example@email.com',
                      icon: Icons.alternate_email_rounded,
                      keyboardType: TextInputType.emailAddress,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'بريد إلكتروني غير صحيح';
                        final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
                        return emailRegex.hasMatch(v.trim()) ? null : 'بريد إلكتروني غير صحيح';
                      },
                    ),
                    const SizedBox(height: 14),

                    // ── كلمة المرور ───────────────────────────────────────
                    _buildField(
                      controller: _passwordController,
                      label: 'كلمة المرور',
                      hint: '••••••••',
                      icon: Icons.lock_outline_rounded,
                      obscure: _obscurePassword,
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                          color: _textSecondary,
                          size: 20,
                        ),
                        onPressed: () =>
                            setState(() => _obscurePassword = !_obscurePassword),
                      ),
                      validator: (v) =>
                          v == null || v.length < 6
                              ? 'كلمة المرور 6 أحرف على الأقل'
                              : null,
                    ),

                    const SizedBox(height: 28),

                    // ── زر الإرسال ───────────────────────────────────────
                    SizedBox(
                      height: 52,
                      child: ElevatedButton(
                        onPressed: auth.isLoading ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _accent,
                          foregroundColor: const Color(0xFF0F1117),
                          disabledBackgroundColor: _accentDim,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: auth.isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Color(0xFF0F1117),
                                ),
                              )
                            : Text(
                                _isLoginMode ? 'تسجيل الدخول' : 'إنشاء حساب',
                                style: GoogleFonts.cairo(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.3,
                                ),
                              ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // ── فاصل أو ─────────────────────────────────────────
                    Row(children: [
                      const Expanded(child: Divider(color: Color(0xFF2A2D3A))),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text('أو',
                            style: GoogleFonts.cairo(color: _textSecondary, fontSize: 12)),
                      ),
                      const Expanded(child: Divider(color: Color(0xFF2A2D3A))),
                    ]),

                    const SizedBox(height: 16),

                    // ── زر Google ────────────────────────────────────────
                    SizedBox(
                      height: 52,
                      child: OutlinedButton(
                        onPressed: auth.isLoading ? null : _signInWithGoogle,
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFF2A2D3A)),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          backgroundColor: const Color(0xFF1A1D27),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const FaIcon(
                              FontAwesomeIcons.google,
                              size: 20,
                              color: Color(0xFF4285F4),
                            ),
                            const SizedBox(width: 10),
                            Text('المتابعة بـ Google',
                                style: GoogleFonts.cairo(
                                    fontSize: 14,
                                    color: _textPrimary,
                                    fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── تاب التبديل ─────────────────────────────────────────────────────────────
  Widget _modeTab(String label, bool isLogin) {
    final selected = _isLoginMode == isLogin;
    return Expanded(
      child: GestureDetector(
        onTap: selected ? null : _switchMode,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: selected ? _accent : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Center(
            child: Text(
              label,
              style: GoogleFonts.cairo(
                fontSize: 13,
                fontWeight:
                    selected ? FontWeight.w700 : FontWeight.w400,
                color: selected ? const Color(0xFF0F1117) : _textSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── حقل الإدخال ─────────────────────────────────────────────────────────────
  Widget _buildField({
    required TextEditingController controller,
    required String label,
    String hint = '',
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    bool obscure = false,
    Widget? suffixIcon,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscure,
      textDirection: TextDirection.rtl,
      autocorrect: false,
      style: GoogleFonts.cairo(color: _textPrimary, fontSize: 14),
      validator: validator,
      decoration: InputDecoration(
        hintText: label,
        hintStyle: GoogleFonts.cairo(color: _textSecondary, fontSize: 13),
        prefixIcon: Icon(icon, color: _textSecondary, size: 20),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: _surface,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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
          borderSide: const BorderSide(color: _accent, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              BorderSide(color: Colors.redAccent.shade700, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              BorderSide(color: Colors.redAccent.shade700, width: 1.5),
        ),
        errorStyle: GoogleFonts.cairo(fontSize: 11),
      ),
    );
  }
}

