import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart'; // استدعاء مكتبة الخطوط

class FirebaseConfig {
  static const String apiKey = "AIzaSyC8bX7BV6xepbMHDH_Qz1-m3e-ENNUxI3E";
  static const String authDomain = "rawi-app-da746.firebaseapp.com";
  static const String projectId = "rawi-app-da746";
  static const String storageBucket = "rawi-app-da746.firebasestorage.app";
  static const String messagingSenderId = "181320126312";
  static const String appId = "1:181320126312:web:164c9094f394c2372650dd";
}

class AppThemes {
  // المظهر الداكن الافتراضي لـ "رواة"
  static final ThemeData darkTheme = ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: const Color(0xFF121212),
    primaryColor: const Color(0xFFE5A93C),
    colorScheme: const ColorScheme.dark(
      primary: Color(0xFFE5A93C),
      secondary: Color(0xFF64B5F6),
      surface: Color(0xFF1E1E1E),
    ),
    // تطبيق خط Cairo الفخم على كل النصوص الداكنة
    textTheme: GoogleFonts.cairoTextTheme(ThemeData.dark().textTheme).copyWith(
      bodyLarge: const TextStyle(color: Color(0xFFE0E0E0), fontSize: 18),
      bodyMedium: const TextStyle(color: Color(0xFFFFBDBB), fontSize: 16),
    ),
    useMaterial3: true,
  );

  // Mظهر الفاتح البديل
  static final ThemeData lightTheme = ThemeData(
    brightness: Brightness.light,
    scaffoldBackgroundColor: const Color(0xFFF9F9F9),
    primaryColor: const Color(0xFFB37D14),
    colorScheme: const ColorScheme.light(
      primary: Color(0xFFB37D14),
      secondary: Color(0xFF1E88E5),
      surface: Colors.white,
    ),
    // تطبيق خط Cairo على النصوص الفاتحة أيضاً
    textTheme: GoogleFonts.cairoTextTheme(ThemeData.light().textTheme),
    useMaterial3: true,
  );
}