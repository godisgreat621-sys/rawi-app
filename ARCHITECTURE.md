# معمارية منصة راوي

## نظرة عامة

تطبيق Flutter Web لنشر وقراءة الروايات العربية، مبني على Firebase مع نمط MVVM + Repository.

---

## هيكل المجلدات

```
lib/
├── core/
│   ├── constants.dart          # ثوابت عامة (أحجام الخطوط، الألوان)
│   └── image_utils.dart        # تحسين روابط Cloudinary تلقائياً
├── models/
│   ├── novel_model.dart        # Novel, Chapter
│   └── library_item.dart       # LibraryItem (للكاتب)
├── providers/
│   ├── novels_provider.dart    # منطق الروايات + Firestore (637+ سطر)
│   └── theme_provider.dart     # الوضع الليلي/النهاري
├── repositories/
│   ├── novel_repository.dart   # saveReadingProgress, saveDraft
│   └── user_repository.dart    # رفع الصور إلى Cloudinary
├── view_models/
│   └── auth_view_model.dart    # تسجيل الدخول/الخروج + Google Sign-In
└── views/
    ├── auth/                   # AuthScreen
    ├── home/
    │   ├── home_screen.dart        # المكتبة الرئيسية (1240+ سطر)
    │   ├── novel_detail_screen.dart # تفاصيل الرواية + التعليقات
    │   ├── novel_reader_screen.dart # القارئ (2033+ سطر)
    │   └── main_navigation_screen.dart
    ├── writer/
    │   ├── writer_screen.dart      # لوحة الكاتب
    │   ├── add_novel_screen.dart   # نشر رواية/فصل
    │   ├── writer_stats_screen.dart # إحصائيات الكاتب (#26)
    │   └── writer_onboarding_screen.dart # استقبال الكاتب الجديد (#40)
    ├── leaderboard_screen.dart     # المتصدرون (#21)
    ├── reading_lists_screen.dart   # قوائم القراءة (#30)
    ├── notifications_screen.dart   # الإشعارات (مع تجميع #36)
    ├── profile_screen.dart         # الملف الشخصي
    ├── author_screen.dart          # صفحة الكاتب العامة
    ├── admin_screen.dart           # لوحة الأدمن (9 تبويبات)
    └── onboarding_screen.dart      # استقبال القارئ الجديد
```

---

## تدفق البيانات

```
UI (Views/Widgets)
    ↕ Provider.watch / context.read
ViewModels / Providers (ChangeNotifier)
    ↕ await
Repositories (static methods)
    ↕ SDK calls
Firebase (Firestore / Auth / Storage / Analytics)
Cloudinary (صور الأغلفة والملفات الشخصية)
```

---

## قواعد البيانات (Firestore)

| المجموعة | الوصف |
|---|---|
| `users/{uid}` | بيانات المستخدم، النقاط، الدور |
| `users/{uid}/readingProgress/{novelId}` | تقدم القراءة لكل رواية |
| `users/{uid}/readingLists/{listName}` | قوائم القراءة المخصصة |
| `users/{uid}/pointsHistory` | سجل تغييرات النقاط |
| `novels/{novelId}` | بيانات الرواية |
| `novels/{novelId}/chapters` | فصول الرواية |
| `novels/{novelId}/chapters/{id}/comments` | التعليقات |
| `notifications/{notifId}` | الإشعارات |
| `drafts/{draftId}` | المسودات |
| `support_requests/{id}` | طلبات الدعم |
| `system_settings/admin_config` | قائمة إيميلات الأدمن |

---

## الحزم الرئيسية

| الحزمة | الغرض |
|---|---|
| `firebase_core / auth / firestore` | المصادقة وقاعدة البيانات |
| `firebase_analytics` | تتبع الأحداث |
| `firebase_crashlytics` | تتبع الأعطال (غير Web) |
| `firebase_remote_config` | إعدادات بعيدة للأدمن |
| `provider` | إدارة الحالة (ChangeNotifier) |
| `rxdart` | دمج Streams (Rx.combineLatest2) |
| `cloudinary` (http) | رفع وتحسين الصور |
| `device_info_plus` | معرّف الجهاز الحقيقي |
| `connectivity_plus` | مراقبة حالة الاتصال |
| `shared_preferences` | تخزين محلي للكاش والإعدادات |
| `google_fonts` | خطوط عربية (Cairo, Amiri, Tajawal, Lateef) |

---

## أنماط التصميم

- **MVVM**: AuthViewModel ↔ AuthScreen
- **Repository**: NovelRepository, UserRepository تعزل منطق Firebase
- **Provider**: NovelsProvider, ThemeProvider يُشاركان الحالة
- **WriteBatch**: جميع عمليات الكتابة المتعددة ذرية
- **Offline First**: `persistenceEnabled: true` في Firestore

---

## الأمان

- قواعد Firestore في `firestore.rules` — تفحص دور الأدمن من Firestore
- قائمة الأدمن في `system_settings/admin_config/adminEmails` (لا في الكود)
- CSP محكم في `web/index.html`
- صور Cloudinary بـ unsigned preset (مقبول للويب)
- `isActiveUser()` يمنع المستخدمين الموقوفين من النشر
