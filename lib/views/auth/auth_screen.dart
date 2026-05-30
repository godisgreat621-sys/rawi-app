import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:my_first_app/view_models/auth_view_model.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  bool _isLoginMode = true;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
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
        displayName: _nameController.text.trim(),
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
  }

  @override
  Widget build(BuildContext context) {
    final authViewModel = Provider.of<AuthViewModel>(context);
    final theme = Theme.of(context);
    final cairoStyle = GoogleFonts.cairo();

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
                      : 'أنشئ حسابك وابدأ رحلتك في عالم الكتابة',
                  textAlign: TextAlign.center,
                  style:
                      GoogleFonts.cairo(color: Colors.grey, fontSize: 14),
                ),
                const SizedBox(height: 40),

                // حقل الاسم — يظهر فقط عند التسجيل
                if (!_isLoginMode) ...[
                  TextFormField(
                    controller: _nameController,
                    style: cairoStyle,
                    decoration: InputDecoration(
                      labelText: 'اسم العرض',
                      labelStyle: cairoStyle,
                      hintText: 'الاسم الذي سيراه القراء',
                      hintStyle:
                          cairoStyle.copyWith(color: Colors.grey, fontSize: 13),
                      prefixIcon: const Icon(Icons.person_outline),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    validator: (value) {
                      if (!_isLoginMode &&
                          (value == null || value.trim().isEmpty)) {
                        return 'يرجى إدخال اسم العرض';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                ],

                // البريد الإلكتروني
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  style: cairoStyle,
                  decoration: InputDecoration(
                    labelText: 'البريد الإلكتروني',
                    labelStyle: cairoStyle,
                    hintStyle: cairoStyle,
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

                // كلمة المرور
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  style: cairoStyle,
                  decoration: InputDecoration(
                    labelText: 'كلمة المرور',
                    labelStyle: cairoStyle,
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(_obscurePassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined),
                      onPressed: () => setState(
                          () => _obscurePassword = !_obscurePassword),
                    ),
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
                  onPressed:
                      authViewModel.isLoading ? null : _submitAuthForm,
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
                          _isLoginMode ? 'تسجيل الدخول' : 'إنشاء حساب',
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
                      _formKey.currentState?.reset();
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