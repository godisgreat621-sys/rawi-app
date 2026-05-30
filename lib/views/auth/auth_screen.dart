import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:my_first_app/view_models/auth_view_model.dart';

// المسار النسبي الذكي للوصول إلى الملاحة الحية 🎯

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoginMode = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _submitAuthForm() async {
    if (!_formKey.currentState!.validate()) return;

    final authViewModel = Provider.of<AuthViewModel>(context, listen: false);
    String? errorMessage;

    if (_isLoginMode) {
      errorMessage = await authViewModel.login(
        _emailController.text.trim(),
        _passwordController.text.trim(),
      );
    } else {
      errorMessage = await authViewModel.signUp(
        _emailController.text.trim(),
        _passwordController.text.trim(),
      );
    }

    if (errorMessage != null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage, style: GoogleFonts.cairo()),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
    // لا نحتاج Navigator هنا — AuthWrapper يتولى الانتقال تلقائياً
  }

  @override
  Widget build(BuildContext context) {
    final authViewModel = Provider.of<AuthViewModel>(context);
    final theme = Theme.of(context);

    // تجهيز ستايل موحد لخط Cairo
    final TextStyle cairoStyle = GoogleFonts.cairo();

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'رواة 📝',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.cairo(
                    fontSize: 40,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _isLoginMode
                      ? 'سجل دخولك لتستمتع بأجمل الروايات'
                      : 'أنشئ حسابك وابدأ رحلتك في عالم الكتابة والقراءة',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.cairo(color: Colors.grey, fontSize: 14),
                ),
                const SizedBox(height: 40),

                // حقل البريد الإلكتروني مع تطبيق الخط على التلميحات والنصوص المكتوبة
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  style: cairoStyle,
                  decoration: InputDecoration(
                    labelText: 'البريد الإلكتروني',
                    labelStyle: cairoStyle,
                    hintStyle: cairoStyle,
                    errorStyle: cairoStyle,
                    prefixIcon: const Icon(Icons.email_outlined),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  validator: (value) {
                    if (value == null ||
                        value.isEmpty ||
                        !value.contains('@')) {
                      return 'يرجى إدخال بريد إلكتروني صحيح';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // حقل كلمة المرور مع تطبيق الخط بالكامل
                TextFormField(
                  controller: _passwordController,
                  obscureText: true,
                  style: cairoStyle,
                  decoration: InputDecoration(
                    labelText: 'كلمة المرور',
                    labelStyle: cairoStyle,
                    hintStyle: cairoStyle,
                    errorStyle: cairoStyle,
                    prefixIcon: const Icon(Icons.lock_outline),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.length < 6) {
                      return 'كلمة المرور يجب ألا تقل عن 6 أحرف';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),

                ElevatedButton(
                  onPressed: authViewModel.isLoading ? null : _submitAuthForm,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: authViewModel.isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.black,
                          ),
                        )
                      : Text(
                          _isLoginMode ? 'تسجيل الدخول' : 'إنشاء حساب جديد',
                          style: GoogleFonts.cairo(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
                const SizedBox(height: 16),

                TextButton(
                  onPressed: () {
                    setState(() {
                      _isLoginMode = !_isLoginMode;
                    });
                  },
                  child: Text(
                    _isLoginMode
                        ? 'ليس لديك حساب؟ أنشئ حساباً الآن'
                        : 'لديك حساب بالفعل؟ سجل دخولك',
                    style: GoogleFonts.cairo(
                      color: theme.colorScheme.secondary,
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
}
