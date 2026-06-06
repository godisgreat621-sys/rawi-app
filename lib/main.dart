import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'firebase_options.dart';

import 'package:my_first_app/view_models/auth_view_model.dart';
import 'package:my_first_app/providers/theme_provider.dart';
import 'package:my_first_app/providers/novels_provider.dart';
import 'package:my_first_app/views/auth/auth_screen.dart';
import 'package:my_first_app/views/home/main_navigation_screen.dart';
import 'core/constants.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // تخزين Firestore محلياً للقراءة بدون إنترنت (#16)
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );

  // #47 تتبع الأعطال — فقط خارج بيئة الويب
  if (!kIsWeb) {
    FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
    PlatformDispatcher.instance.onError = (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return true;
    };
  }

  // #46 تفعيل Analytics
  await FirebaseAnalytics.instance.setAnalyticsCollectionEnabled(true);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthViewModel()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => NovelsProvider()),
      ],
      child: const RawiApp(),
    ),
  );
}

class RawiApp extends StatelessWidget {
  const RawiApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return MaterialApp(
      title: 'منصة راوي',
      debugShowCheckedModeBanner: false,
      locale: const Locale('ar', 'AE'),
      supportedLocales: const [Locale('ar', 'AE')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData(
        brightness: themeProvider.isDarkMode
            ? Brightness.dark
            : Brightness.light,
        scaffoldBackgroundColor: themeProvider.isDarkMode
            ? const Color(0xFF121212)
            : Colors.white,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFFFD700),
          brightness: themeProvider.isDarkMode
              ? Brightness.dark
              : Brightness.light,
        ),
        textTheme: GoogleFonts.cairoTextTheme(
          themeProvider.isDarkMode
              ? ThemeData.dark().textTheme
              : ThemeData.light().textTheme,
        ).apply(fontSizeFactor: kBaseFontFactor),
        iconTheme: const IconThemeData(size: kIconMedium),
      ),
      home: const AuthWrapper(),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final authViewModel = Provider.of<AuthViewModel>(context);

    if (authViewModel.currentUser != null) {
      return const MainNavigationScreen();
    }
    return const AuthScreen();
  }
}
