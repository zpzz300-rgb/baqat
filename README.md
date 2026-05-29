# 📡 باقات الاتصالات - Flutter

## هيكل المشروع

```
lib/
├── main.dart                    # نقطة البداية
├── models/
│   └── models.dart              # Group, Member, Rental, WorkNum, AppDB
├── providers/
│   └── app_provider.dart        # State management + SharedPreferences
├── services/
│   └── app_theme.dart           # الألوان والثيم
├── screens/
│   ├── home_screen.dart         # الشاشة الرئيسية (Header + Nav + Groups)
│   ├── profit_screen.dart       # الأرباح
│   ├── guarantors_screen.dart   # الكفلاء
│   ├── rentals_screen.dart      # المؤجرة
│   ├── archive_screen.dart      # الأرشيف
│   ├── gifts_screen.dart        # الهدايا
│   ├── activity_screen.dart     # سجل النشاط
│   ├── dataio_screen.dart       # البيانات (تصدير/استيراد)
│   ├── deleted_screen.dart      # المحذوفون
│   ├── reminders_screen.dart    # التنبيهات
│   └── worknums_screen.dart     # أرقام العمل
└── widgets/
    ├── group_card.dart          # كارد المجموعة
    ├── member_card.dart         # كارد العميل + Drawer
    ├── common.dart              # StatChip, GradientButton, AppSnackbar, Forms
    ├── pin_dialog.dart          # نافذة الـ PIN
    ├── add_group_modal.dart     # إضافة مجموعة
    ├── add_member_modal.dart    # إضافة عميل
    ├── edit_group_modal.dart    # تعديل مجموعة
    ├── edit_member_modal.dart   # تعديل عميل
    ├── settings_modal.dart      # الإعدادات
    └── ai_modal.dart            # مساعد AI
```

## خطوات التشغيل

```bash
# 1. تثبيت الـ dependencies
flutter pub get

# 2. تشغيل على Android
flutter run

# 3. بناء APK
flutter build apk --release
```

## المسار
```
C:\Users\omr\StudioProjects\telecom_flutter\
```

## ملاحظات مهمة
- البيانات محفوظة في SharedPreferences بنفس مفتاح HTML: `tcm_v3`
- الـ PIN الافتراضي: `123456`
- مفتاح AI: الـ API key بتاع Anthropic لازم يتضاف في `ai_modal.dart`
