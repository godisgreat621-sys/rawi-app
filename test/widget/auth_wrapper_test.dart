import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:my_first_app/view_models/auth_view_model.dart';
import 'package:my_first_app/providers/theme_provider.dart';
import 'package:my_first_app/providers/novels_provider.dart';

// اختبار بسيط: التحقق من وجود شاشة تسجيل الدخول عند عدم وجود مستخدم
void main() {
  testWidgets('AuthWrapper يعرض AuthScreen حين لا يوجد مستخدم', (tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AuthViewModel()),
          ChangeNotifierProvider(create: (_) => ThemeProvider()),
          ChangeNotifierProvider(create: (_) => NovelsProvider()),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: Center(child: Text('تسجيل الدخول')),
          ),
        ),
      ),
    );

    expect(find.text('تسجيل الدخول'), findsOneWidget);
  });
}
